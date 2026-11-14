# What build.sh and install.sh share; both source this after setting $here to the clone.

flow_skills="fap-explore fap-slice fap-build"
generated_mark="by build.sh. Edit the sources there."

in_list() { [[ " $2 " == *" $1 "* ]]; }

skill_folders_of() {
  local skill folders=""
  for skill in $1; do
    if [[ "$skill" == flow ]]; then folders+=" $flow_skills"; else folders+=" $skill"; fi
  done
  echo "${folders# }"
}

optional_skill_names() {
  local skill_dir skill list=""
  for skill_dir in "$here"/skills/*/; do
    skill="$(basename "$skill_dir")"
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    in_list "$skill" "$flow_skills" || list="${list:+$list }$skill"
  done
  echo "$list"
}

frontmatter_value() {
  local key="$1" file="$2"
  awk -v key="$key" '
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---" { exit }
    in_fm && index($0, key ": ") == 1 { print substr($0, length(key) + 3) }
  ' "$file"
}

shown_path() { if [[ "$1" == "$HOME/"* ]]; then echo "~/${1#"$HOME/"}"; else echo "$1"; fi; }

# A folder reached through a symlink has more than one spelling; links and notices keep the
# spelling they were written with, so they are compared by the folder they resolve to.
same_folder() {
  local first second
  [[ "$1" == "$2" ]] && return 0
  first="$(cd -P "$1" 2>/dev/null && pwd)" && second="$(cd -P "$2" 2>/dev/null && pwd)" \
    && [[ -n "$first" && "$first" == "$second" ]]
}

links_into_clone() {
  local target
  [[ -L "$1" ]] || return 1
  target="$(readlink "$1")"
  [[ "$target" == /*/skills/* ]] && same_folder "${target%/skills/*}" "$here"
}
is_clone_link() { links_into_clone "$1" && [[ "$(readlink "$1")" == */skills/"$(basename "$1")" ]]; }

notice_line() {
  case "$1" in
    *.md) awk 'NR == 1 && $0 != "---" { exit } NR == 2 { print; exit }' "$1" ;;
    *) head -n 1 "$1" ;;
  esac
}
# The clone as the notice names it, shortened by shown_path.
notice_clone() {
  local clone
  clone="$(notice_line "$1")"
  clone="${clone#"# Generated from "}"
  echo "${clone%" $generated_mark"}"
}
is_generated() {
  local clone
  [[ "$(notice_line "$1")" == "# Generated from "*" $generated_mark" ]] || return 1
  [[ -n "${2:-}" ]] || return 0
  clone="$(notice_clone "$1")"
  [[ "$clone" != "~/"* ]] || clone="$HOME/${clone#"~/"}"
  same_folder "$clone" "$2"
}

has_generated_agent() {
  local home="$1" extension="$2" only_from_clone="${3:-}" file
  for file in "$home"/agents/*."$extension"; do
    [[ -f "$file" ]] && is_generated "$file" "$only_from_clone" && return 0
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

claude_home="${CLAUDE_HOME:-$HOME/.claude}"
codex_home="${CODEX_HOME:-$HOME/.codex}"

# The final "." keeps an empty last list from being lost to command substitution.
read_selection() {
  local file="$1" saved
  if ! saved="$(targets="" skills=""
      . "$file" 2>/dev/null && printf '%s\n%s\n.' "${targets:-}" "${skills:-}")"; then
    selection_error="$( (. "$file") 2>&1 >/dev/null || true)"
    selection_error="${selection_error%%$'\n'*}"
    selection_error="${selection_error#"$file": }"
    return 1
  fi
  { read -r targets; read -r skills; } <<< "$saved"
}
