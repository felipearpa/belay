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

# A link build.sh made: it points at the skill of the same name in the clone's skills folder.
is_clone_link() { [[ -L "$1" && "$(readlink "$1")" == "$here/skills/$(basename "$1")" ]]; }

# An agent generated from any clone counts; a skill link counts only into this clone.
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

claude_home="${CLAUDE_HOME:-$HOME/.claude}"
codex_home="${CODEX_HOME:-$HOME/.codex}"

# Sets targets and skills from the file, or selection_error to the shell's first complaint
# and returns 1 when the file doesn't source cleanly. The final "." keeps an empty last
# list from being lost to command substitution.
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
