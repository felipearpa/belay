#!/usr/bin/env bash
# One-screen picker for what build.sh installs; enter shows what build.sh --dry-run lists
# for the ticks, and a second enter runs build.sh with the same flags.
# Written for bash 3.2: no associative arrays, no fractional read -t.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
conf="$here/install.conf"
. "$here/lib.sh"

stop_without_terminal() {
  cat >&2 <<'EOF'
install.sh needs a terminal to show its picker.
Without one, install everything with:
  ./build.sh --all
or choose a part with the flags, for example:
  ./build.sh --claude --codex --skills flow
EOF
  exit 1
}
[[ -t 0 && -t 1 ]] || stop_without_terminal

skills_ticked_at_first="flow"

kinds=(); names=(); labels=(); notes=(); ticks=()
add_item() {
  kinds+=("$1"); names+=("$2"); labels+=("$3"); notes+=("$4"); ticks+=("$5")
}
items_of() {
  local i
  for i in "${!kinds[@]}"; do [[ "${kinds[i]}" != "$1" ]] || echo "$i"; done
}

add_targets() {
  add_item target claude "Claude Code" "$(shown_path "$claude_home")" 1
  add_item target codex "Codex" "$(shown_path "$codex_home")" 0
}

add_skills() {
  local agents=("$here"/agents/*/AGENT.md) skill description tick
  local flow_note="${flow_skills// /, } and the ${#agents[@]} agents"
  add_item skill flow "The flow" "$flow_note" 1
  for skill in $(optional_skill_names); do
    description="$(frontmatter_value description "$here/skills/$skill/SKILL.md")"
    tick=0; in_list "$skill" "$skills_ticked_at_first" && tick=1
    add_item skill "$skill" "$skill" "${description%%. *}" "$tick"
  done
}

add_targets
add_skills

claude=0; codex=1
cursor=0
message=""

tick_saved() {
  local kind="$1" saved_names="$2" i
  for i in $(items_of "$kind"); do
    if in_list "${names[i]}" "$saved_names"; then ticks[i]=1; else ticks[i]=0; fi
  done
}

has_generated_agent() {
  local file
  for file in "$1"/agents/*."$2"; do
    [[ -f "$file" ]] && grep -q "$generated_mark" "$file" && return 0
  done
  return 1
}
has_skill_link() {
  local home="$1" folder
  for folder in $2; do
    is_clone_link "$home/skills/$folder" && return 0
  done
  return 1
}
skill_installed() {
  local folders
  folders="$(skill_folders_of "$1")"
  has_skill_link "$claude_home" "$folders" && return 0
  has_skill_link "$codex_home" "$folders" && return 0
  [[ "$1" == flow ]] || return 1
  has_generated_agent "$claude_home" md || has_generated_agent "$codex_home" toml
}
installed_names() {
  local kind="$1" is_installed="$2" i list=""
  for i in $(items_of "$kind"); do
    "$is_installed" "${names[i]}" && list+=" ${names[i]}"
  done
  echo "$list"
}
all_skill_folders() {
  local i
  for i in $(items_of skill); do skill_folders_of "${names[i]}"; done
}

open_on_installed() {
  local skills folders claude_found=0 codex_found=0
  skills="$(installed_names skill skill_installed)"
  folders="$(all_skill_folders)"
  if has_generated_agent "$claude_home" md || has_skill_link "$claude_home" "$folders"; then
    claude_found=1
  fi
  if has_generated_agent "$codex_home" toml || has_skill_link "$codex_home" "$folders"; then
    codex_found=1
  fi
  (( claude_found || codex_found )) || return 0
  ticks[claude]=$claude_found
  ticks[codex]=$codex_found
  tick_saved skill "$skills"
}

open_on_saved_selection() {
  local targets="" skills="" selection_error=""
  [[ -f "$conf" ]] || { open_on_installed; return 0; }
  if ! read_selection "$conf"; then
    message="install.conf couldn't be read${selection_error:+ ($selection_error)}; showing the defaults."
    return 0
  fi
  tick_saved target "$targets"
  tick_saved skill "$skills"
}
open_on_saved_selection

label_width() {
  local kind="$1" i width=0
  for i in $(items_of "$kind"); do
    (( ${#labels[i]} > width )) && width=${#labels[i]}
  done
  echo "$width"
}

read_terminal_size() {
  rows=""; columns=""
  read -r rows columns < <(stty size 2>/dev/null) || true
  (( ${columns:-0} > 0 )) || columns="$(tput cols 2>/dev/null || true)"
  (( ${columns:-0} > 0 )) || columns=80
  (( ${rows:-0} > 0 )) || rows="$(tput lines 2>/dev/null || true)"
  (( ${rows:-0} > 0 )) || rows=24
}
read_terminal_size
target_width="$(label_width target)"
skill_width="$(label_width skill)"

item_line() {
  local i="$1" width="$2" pointer=" " box="[ ]" row room
  (( i == cursor )) && pointer="▸"
  (( ticks[i] )) && box="[x]"
  printf -v row ' %s %s %-*s   ' "$pointer" "$box" "$width" "${labels[i]}"
  room=$(( columns - ${#row} - 1 ))
  (( room > 0 )) || room=0
  printf '%s%s\n' "$row" "${notes[i]:0:$room}"
}

group_lines() {
  local kind="$1" width="$2" i
  for i in $(items_of "$kind"); do item_line "$i" "$width"; done
}

screen() {
  printf ' Belay installer\n\n Install into\n'
  group_lines target "$target_width"
  printf '\n Skills\n'
  group_lines skill "$skill_width"
  printf '\n ↑↓ move   space toggle   a all   n none   enter continue   q quit\n'
  [[ -z "$message" ]] || printf '\n %s\n' "$message"
}

draw() {
  local frame
  frame="$("$1")"
  printf '\033[H\033[2J%s\n' "$frame"
}

move() {
  local next=$(( cursor + $1 ))
  (( next >= 0 && next < ${#kinds[@]} )) && cursor=$next
  true
}

tick_all() {
  local i
  for i in "${!ticks[@]}"; do ticks[i]=$1; done
}

read_key() {
  local key rest=""
  IFS= read -rsn1 key || { echo quit; return; }
  if [[ "$key" == $'\033' ]]; then
    IFS= read -rsn2 -t 1 rest || true
    key="$key$rest"
  fi
  case "$key" in
    $'\033[A' | $'\033OA') echo up ;;
    $'\033[B' | $'\033OB') echo down ;;
    " ") echo toggle ;;
    "") echo enter ;;
    a | A) echo all ;;
    n | N) echo none ;;
    b | B) echo back ;;
    q | Q) echo quit ;;
    *) echo other ;;
  esac
}

ticked_names() {
  local kind="$1" i list=""
  for i in $(items_of "$kind"); do
    (( ticks[i] )) && list="${list:+$list,}${names[i]}"
  done
  echo "$list"
}

build_flags() {
  local skills
  (( ticks[claude] )) && printf '%s\n' --claude
  (( ticks[codex] )) && printf '%s\n' --codex
  skills="$(ticked_names skill)"
  [[ -z "$skills" ]] || printf '%s\n' --skills "$skills"
  true
}

terminal_state="$(stty -g)"
open_screen() { stty -echo; tput smcup 2>/dev/null || true; tput civis 2>/dev/null || true; }
close_screen() { tput cnorm 2>/dev/null || true; tput rmcup 2>/dev/null || true; stty "$terminal_state"; }

chosen_flags=()
dry_run_output=""

choose_ticked() {
  local flag
  if ! (( ticks[claude] || ticks[codex] )); then
    message="Tick Claude Code, Codex, or both to continue."
    return 1
  fi
  chosen_flags=()
  while IFS= read -r flag; do chosen_flags+=("$flag"); done < <(build_flags)
}

plan_install() {
  local first_line
  if ! dry_run_output="$("$here/build.sh" --dry-run "${chosen_flags[@]}" 2>&1)"; then
    first_line=${dry_run_output%%$'\n'*}
    message="build.sh can't install this: ${first_line#build.sh: }"
    return 1
  fi
}

is_row() { [[ "$1" == new\ * || "$1" == overwrite\ * || "$1" == remove\ * || "$1" == unchanged\ * ]]; }

list_lines=()
notes_shown=()
first_shown=0

fitted() {
  local text="$1" room=$(( columns - 1 ))
  if (( ${#text} > room )); then text="${text:0:$(( room - 1 ))}…"; fi
  printf '%s' "$text"
}

# Sets status, path and remark from a row of the dry run. build.sh pads the path column
# with spaces and puts two or more before a remark.
parse_plan_line() {
  local rest
  status="${1%% *}"
  rest="${1#"$status"}"; rest="${rest#"${rest%%[! ]*}"}"
  path="${rest%%  *}"; remark="${rest#"$path"}"; remark="${remark#"${remark%%[! ]*}"}"
}

format_row() {
  local status="$1" path="$2" remark="$3" width="$4" row
  printf -v row '   %-10s %-*s  %s' "$status" "$width" "$path" "$remark"
  (( ${#row} < columns )) || printf -v row '   %-10s %s  %s' "$status" "$path" "$remark"
  [[ -n "$remark" ]] || printf -v row '   %-10s %s' "$status" "$path"
  fitted "$row"
}

lay_out_plan() {
  local line status path remark width=0 unchanged=0 i
  local statuses=() paths=() remarks=()
  list_lines=(); notes_shown=(); first_shown=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if ! is_row "$line"; then notes_shown+=("$(fitted " $line")"); continue; fi
    parse_plan_line "$line"
    if [[ "$status" == unchanged ]]; then unchanged=$(( unchanged + 1 )); continue; fi
    statuses+=("$status"); paths+=("$path"); remarks+=("$remark")
    (( ${#path} > width )) && width=${#path}
  done <<< "$dry_run_output"
  for i in ${statuses[@]+"${!statuses[@]}"}; do
    list_lines+=("$(format_row "${statuses[i]}" "${paths[i]}" "${remarks[i]}" "$width")")
  done
  if (( unchanged == 1 )); then list_lines+=("   unchanged  1 file")
  elif (( unchanged > 1 )); then list_lines+=("   unchanged  $unchanged files"); fi
  true
}

saved_line=" Your choices are saved in install.conf; ./build.sh reapplies them."
footer=" enter install   b back   q quit"
scroll_footer=" enter install   ↑↓ scroll   b back   q quit"

wrapped_height() { echo $(( (${#1} + columns - 1) / columns )); }

list_room() {
  local fixed=$(( 4 + 1 + ${#notes_shown[@]} + $(wrapped_height "$saved_line") + 1 + $(wrapped_height "$scroll_footer") ))
  local room=$(( rows - 1 - fixed ))
  (( room > 2 )) || room=2
  echo "$room"
}

list_scrolls() { (( ${#list_lines[@]} > $(list_room) )); }

scroll_list() {
  local last=$(( ${#list_lines[@]} - $(list_room) + 1 ))
  first_shown=$(( first_shown + $1 ))
  (( first_shown < last )) || first_shown=$last
  (( first_shown > 0 )) || first_shown=0
}

shown_list() {
  local count=${#list_lines[@]} visible i above below
  if ! list_scrolls; then
    for i in ${list_lines[@]+"${!list_lines[@]}"}; do printf '%s\n' "${list_lines[i]}"; done
    return
  fi
  visible=$(( $(list_room) - 1 ))
  for (( i = first_shown; i < first_shown + visible; i++ )); do printf '%s\n' "${list_lines[i]}"; done
  above=$first_shown
  below=$(( count - first_shown - visible ))
  if (( above && below )); then printf '   ↑ %d more above, ↓ %d more below\n' "$above" "$below"
  elif (( below )); then printf '   ↓ %d more below\n' "$below"
  else printf '   ↑ %d more above\n' "$above"; fi
}

confirm_screen() {
  local note
  printf ' Belay installer\n\n This will write\n\n'
  shown_list
  printf '\n'
  for note in ${notes_shown[@]+"${notes_shown[@]}"}; do printf '%s\n' "$note"; done
  printf '%s\n' "$saved_line"
  if list_scrolls; then printf '\n%s\n' "$scroll_footer"
  else printf '\n%s\n' "$footer"; fi
}

install_chosen() {
  close_screen
  trap - EXIT
  echo "./build.sh ${chosen_flags[*]}"
  exec "$here/build.sh" "${chosen_flags[@]}"
}

leave() { close_screen; trap - EXIT; echo "Nothing was installed."; exit 0; }

confirm() {
  while true; do
    draw confirm_screen
    case "$(read_key)" in
      up) scroll_list -1 ;;
      down) scroll_list 1 ;;
      enter) install_chosen ;;
      back) return ;;
      quit) leave ;;
    esac
  done
}

open_screen
trap close_screen EXIT
while true; do
  draw screen
  message=""
  case "$(read_key)" in
    up) move -1 ;;
    down) move 1 ;;
    toggle) ticks[cursor]=$(( 1 - ticks[cursor] )) ;;
    all) tick_all 1 ;;
    none) tick_all 0 ;;
    enter) if choose_ticked && plan_install; then lay_out_plan; confirm; fi ;;
    quit) leave ;;
  esac
done
