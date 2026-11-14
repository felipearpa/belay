#!/usr/bin/env bash
# Generates the Claude Code and Codex registrations for every agent under agent-sources/
# (from its AGENT.md and agent-sources/common.md) and links the skills under skills/ into
# each CLI's skills folder, for the selection the flags describe, else
# the one saved in install.conf, else everything, and removes what it installed earlier
# that the selection no longer holds. --dry-run lists what that run would do, file by
# file, and writes nothing. --render-agents writes the finished Claude Code agents into
# agents/, the files committed for the plugin, removes those whose source is gone, and
# writes nothing else; with --check it only reports what in agents/ is stale, missing,
# orphaned, or not rendered there.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
conf="$here/install.conf"
. "$here/lib.sh"
usage_line="Usage: ./build.sh [--check | --dry-run] [--all | [--claude] [--codex] [--skills flow,<skill>,...]]
       ./build.sh --render-agents [--check]"
usage() {
  echo "build.sh: $1" >&2
  echo "$usage_line" >&2
  exit 2
}

# --- Selection ----------------------------------------------------------------------------

targeted() { in_list "$1" "$targets"; }

optional_skills="$(optional_skill_names)"

known_in_order() {
  local kind="$1" known="$2" given="$3" origin="$4" name result=""
  for name in $given; do
    in_list "$name" "$known" || usage "unknown $kind '$name' in $origin (one of: $known)"
  done
  for name in $known; do
    in_list "$name" "$given" && result+=" $name"
  done
  echo "${result# }"
}

set -f # so a name like '*' from the flags or install.conf isn't globbed
check=0; dry_run=0; all=0; flagged=0; render_only=0
targets=""; skills=""
while (( $# )); do
  case "$1" in
    --check) check=1 ;;
    --dry-run) dry_run=1 ;;
    --all) all=1 ;;
    --render-agents) render_only=1 ;;
    --claude) targets="$targets claude"; flagged=1 ;;
    --codex) targets="$targets codex"; flagged=1 ;;
    --skills)
      (( $# > 1 )) || usage "--skills needs a comma-separated list"
      skills+=" ${2//,/ }"
      flagged=1; shift ;;
    *) usage "unknown option '$1'" ;;
  esac
  shift
done
(( all && flagged )) && usage "--all can't be combined with a selection"
(( check && flagged )) && usage "--check takes no selection"
(( check && dry_run )) && usage "--check and --dry-run can't be combined"
if (( render_only )); then
  (( dry_run || all || flagged )) && usage "--render-agents takes no other option than --check"
  all=1 # renders every agent, and never reads or writes install.conf
fi

if (( flagged )); then
  origin="the flags"
elif (( ! all )) && [[ -f "$conf" ]]; then
  origin="install.conf"
  read_selection "$conf" || {
    echo "build.sh: $conf couldn't be read${selection_error:+ ($selection_error)}; fix it or delete it, then run build.sh again" >&2
    exit 1
  }
else
  origin=""
  targets="claude codex"; skills="flow $optional_skills"
fi
targets="$(known_in_order target "claude codex" "$targets" "$origin")" || exit 2
skills="$(known_in_order skill "flow $optional_skills" "$skills" "$origin")" || exit 2
[[ -n "$targets" ]] || usage "no target in $origin; add --claude, --codex, or both"

if (( flagged && ! dry_run )); then
  printf 'targets="%s"\nskills="%s"\n' "$targets" "$skills" > "$conf"
elif [[ "$origin" == install.conf ]]; then
  echo "using the selection in $conf"
fi

skill_folders="$(skill_folders_of "$skills")"
set +f

if (( render_only )); then
  notice="Generated from agent-sources/ $generated_mark"
else
  notice="Generated from $(shown_path "$here") $generated_mark"
fi
stale=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

strip_frontmatter() {
  local file="$1"
  awk '
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm { if ($0 == "---") in_fm = 0; next }
    !started && $0 == "" { next }
    { started = 1; print }
  ' "$file"
}

# A double-quoted string with \ and " escaped reads the same in YAML and TOML.
quoted() {
  local s="${1//\\/\\\\}"
  printf '"%s"' "${s//\"/\\\"}"
}

prompt_body() {
  strip_frontmatter "$1" | awk -v cf="$here/agent-sources/common.md" '
    $0 == "{{common}}" { while ((getline line < cf) > 0) print line; close(cf); next }
    { print }
  '
}

render_claude() {
  printf -- '---\n# %s\nname: %s\ndescription: %s\n' "$notice" "$name" "$(quoted "$description")"
  [[ -n "$tools" ]] && printf 'tools: %s\n' "$tools"
  printf -- '---\n\n%s\n' "$body"
}

render_codex() {
  printf '# %s\nname = "%s"\ndescription = %s\n' "$notice" "$name" "$(quoted "$description")"
  printf "\ndeveloper_instructions = '''\n%s\n'''\n" "$body"
}

planned_rows="$tmp/planned-rows"
planned_notes="$tmp/planned-notes"
: > "$planned_rows"; : > "$planned_notes"
planned() {
  (( dry_run )) || return 0
  printf '%s\t%s\t%s\t%s\n' "$1" "$(shown_path "$2")" "${3:-}" "$2" >> "$planned_rows"
}
note() {
  if (( dry_run )); then echo "note: $1" >> "$planned_notes"; else echo "note: $1"; fi
}
print_planned() {
  awk -F '\t' -v claude="$claude_home/" -v codex="$codex_home/" \
      -v shown_claude="$(shown_path "$claude_home")" -v shown_codex="$(shown_path "$codex_home")" '
    BEGIN { rank["overwrite"] = 1; rank["remove"] = 2; rank["new"] = 3; rank["unchanged"] = 4 }
    {
      row[rank[$1], ++count[rank[$1]]] = $0
      if (length($2) > width) width = length($2)
      if ($1 == "unchanged") next
      changes++
      if (index($4, claude) == 1) claude_changed = 1
      if (index($4, codex) == 1) codex_changed = 1
    }
    END {
      for (r = 1; r <= 4; r++)
        for (i = 1; i <= count[r]; i++) {
          split(row[r, i], field, "\t")
          if (field[3] == "") printf "%-10s %s\n", field[1], field[2]
          else printf "%-10s %-*s  %s\n", field[1], width, field[2], field[3]
        }
    }
    END {
      while ((getline line < notes) > 0) print line
      if (!changes) { print "Nothing changes: the install already matches this selection."; exit }
      if (!claude_changed) print "Nothing is written to " shown_claude "."
      if (!codex_changed) print "Nothing is written to " shown_codex "."
    }
  ' notes="$planned_notes" "$planned_rows"
}

exists() { [[ -e "$1" || -L "$1" ]]; }

place() {
  local rendered="$1" target="$2" overwrite_remark="${3:-}" status=overwrite
  if cmp -s "$rendered" "$target"; then planned unchanged "$target"; return; fi
  exists "$target" || { status=new; overwrite_remark=""; }
  if (( check )); then echo "stale: $target"; stale=1
  elif (( dry_run )); then planned "$status" "$target" "$overwrite_remark"
  else mkdir -p "$(dirname "$target")"; cp "$rendered" "$target"; echo "wrote $target"; fi
}

remove_from_home() {
  local path="$1" reason="$2"
  if (( check )); then echo "stale: $path ($reason)"; stale=1
  elif (( dry_run )); then planned remove "$path" "($reason)"
  else rm "$path"; echo "removed $path ($reason)"; fi
}

home_of() { if [[ "$1" == claude ]]; then echo "$claude_home"; else echo "$codex_home"; fi; }
when_targeted() { if targeted "$1"; then echo "$2"; fi; }

# --- Agents -----------------------------------------------------------------------------

agent_overwrite_remark() {
  [[ -f "$1" ]] && ! grep -q "$generated_mark" "$1" && echo "(not from build.sh; no backup)"
}

# Validates every agent source and renders it into $tmp as <name>.md and <name>.toml,
# listing the names in order in names. Writes nowhere else.
names=()
render_agents() {
  local agent_md dir name description tools body
  [[ -f "$here/agent-sources/common.md" ]] || { echo "Missing agent-sources/common.md" >&2; exit 1; }
  for agent_md in "$here"/agent-sources/*/AGENT.md; do
    dir="$(dirname "$agent_md")"
    name="$(frontmatter_value name "$agent_md")"
    description="$(frontmatter_value description "$agent_md")"
    ! grep -q '^model: ' "$agent_md" || { echo "$agent_md: agents name no model; every agent inherits the session's" >&2; exit 1; }
    tools="$(frontmatter_value tools "$agent_md")"
    [[ -n "$name" && -n "$description" ]] || { echo "$agent_md frontmatter needs name and description" >&2; exit 1; }
    [[ "$name" == "$(basename "$dir")" ]] || { echo "$agent_md: name must match its folder" >&2; exit 1; }
    case "$description" in
      \"* | \'* | \>* | \|*) echo "$agent_md: write the description unquoted on one line; build.sh quotes it" >&2; exit 1 ;;
      *": "* | *" #"*) echo "$agent_md: the description can't hold ': ' or ' #'; YAML reads them as structure" >&2; exit 1 ;;
    esac
    grep -q '^{{common}}$' "$agent_md" || { echo "$agent_md: needs a {{common}} line" >&2; exit 1; }
    body="$(prompt_body "$agent_md")"
    if [[ "$body" == *"'''"* ]]; then
      echo "$name: the prompt contains ''' which a TOML literal string can't hold" >&2; exit 1
    fi
    render_claude > "$tmp/$name.md"
    render_codex > "$tmp/$name.toml"
    names+=("$name")
  done
}

agent_sources=""
for agent_md in "$here"/agent-sources/*/AGENT.md; do
  agent_sources+=" $(basename "$(dirname "$agent_md")")"
done

remove_unselected_agents() {
  local folder="$1" extension="$2" wanted="$3" generated base
  for generated in "$folder"/*."$extension"; do
    [[ -f "$generated" ]] || continue
    grep -q "$generated_mark" "$generated" || continue
    base="$(basename "${generated%.*}")"
    in_list "$base" "$wanted" && continue
    if in_list "$base" "$agent_sources"; then remove_from_home "$generated" "not selected"
    else remove_from_home "$generated" "no agent source"; fi
  done
}

# The finished agents committed in agents/, for the plugin; nothing in the homes changes.
# One file per source is written, a generated file whose source is gone is removed, and
# anything else there (the plugin would load it as an agent) is reported and left alone,
# or under --check fails it. Hidden files, such as .DS_Store, aren't looked at.
if (( render_only )); then
  render_agents
  for name in "${names[@]}"; do
    place "$tmp/$name.md" "$here/agents/$name.md"
  done
  remove_unselected_agents "$here/agents" md "${names[*]+${names[*]}}"
  for entry in "$here"/agents/*; do
    exists "$entry" || continue
    if [[ -f "$entry" && "$entry" == *.md ]]; then
      in_list "$(basename "$entry" .md)" "${names[*]+${names[*]}}" && continue
      grep -q "$generated_mark" "$entry" && continue
    fi
    if (( check )); then echo "foreign: $entry (not rendered from agent-sources/)"; stale=1
    else note "$entry is not rendered from agent-sources/ and the plugin would load it as an agent; left alone"; fi
  done
  if (( check )); then
    (( stale == 0 )) && echo "up to date"
    exit $stale
  fi
  exit 0
fi

if in_list flow "$skills"; then
  render_agents
  for name in "${names[@]}"; do
    if targeted claude; then place "$tmp/$name.md" "$claude_home/agents/$name.md" "$(agent_overwrite_remark "$claude_home/agents/$name.md")"; fi
    if targeted codex; then place "$tmp/$name.toml" "$codex_home/agents/$name.toml" "$(agent_overwrite_remark "$codex_home/agents/$name.toml")"; fi
    (( dry_run )) || echo "$name: $(wc -w < "$tmp/$name.md" | tr -d ' ') words"
  done
fi

remove_unselected_agents "$claude_home/agents" md "$(when_targeted claude "${names[*]+${names[*]}}")"
remove_unselected_agents "$codex_home/agents" toml "$(when_targeted codex "${names[*]+${names[*]}}")"

# --- Skills -----------------------------------------------------------------------------

# Links target to the skill of the same name in this clone's skills folder. Any real file
# or folder already at target is left alone and reported.
link_into_clone() {
  local target="$1" source="$here/skills/$(basename "$1")"
  if [[ -L "$target" ]]; then
    if is_clone_link "$target"; then planned unchanged "$target"; return; fi
    if (( check )); then echo "stale: $target links elsewhere"; stale=1
    elif (( dry_run )); then planned overwrite "$target" "(links elsewhere; repointed into this clone)"
    else ln -sfn "$source" "$target"; echo "linked $target"; fi
  elif [[ -e "$target" ]]; then
    note "$(shown_path "$target") exists and is not a link; left alone"
  elif (( check )); then
    echo "stale: $target missing"; stale=1
  elif (( dry_run )); then
    planned new "$target" "→ link into this clone"
  else
    mkdir -p "$(dirname "$target")"; ln -s "$source" "$target"; echo "linked $target"
  fi
}

# Removes the links in folder that point into the clone's skills folder at a skill that
# is gone, or at one whose name isn't in wanted.
remove_unselected_links() {
  local folder="$1" wanted="$2" link
  for link in "$folder"/*; do
    [[ -L "$link" && "$(readlink "$link")" == "$here/skills/"* ]] || continue
    if [[ ! -e "$link" ]]; then remove_from_home "$link" "skill removed"
    elif is_clone_link "$link" && ! in_list "$(basename "$link")" "$wanted"; then
      remove_from_home "$link" "not selected"
    fi
  done
}

for cli in claude codex; do
  cli_skills="$(home_of "$cli")/skills"
  wanted="$(when_targeted "$cli" "$skill_folders")"
  for skill in $wanted; do
    link_into_clone "$cli_skills/$skill"
  done
  remove_unselected_links "$cli_skills" "$wanted"
done

if (( check )); then
  (( stale == 0 )) && echo "up to date"
  exit $stale
fi
if (( dry_run )); then
  print_planned
  exit 0
fi
(( flagged )) && echo "Saved the selection to $conf; a plain ./build.sh reapplies it."
echo "Restart running sessions to load the changes."
