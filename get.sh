#!/usr/bin/env bash
# Installs Belay from its repository, or updates an install, piped from curl:
#   curl -fsSL https://raw.githubusercontent.com/felipearpa/belay/main/get.sh | bash
# The clone is $BELAY_HOME when set, else the one the fap-* skill links in the CLI homes
# point into, else ~/.belay. When that folder doesn't exist,
# clones the repository ($BELAY_REPO, else the GitHub URL) there, then opens the clone's
# picker with keys read from /dev/tty, or, without a terminal, installs everything with
# build.sh --all. When it exists, fast-forwards it from its upstream, stopping on uncommitted
# changes or commits the upstream lacks, then shows what build.sh would change for the saved
# selection, waits for enter, and builds; without a terminal it builds without waiting.
# Written for bash 3.2. Everything runs from main, called on the last line, so bash has read
# the whole script from the pipe before anything that could read stdin starts.
set -euo pipefail

default_repo="https://github.com/felipearpa/belay.git"
through_links="the skill links"

# These mirror lib.sh; get.sh runs before the clone, and so lib.sh, exists.
claude_home="${CLAUDE_HOME:-$HOME/.claude}"
codex_home="${CODEX_HOME:-$HOME/.codex}"
shown_path() { if [[ "$1" == "$HOME/"* ]]; then echo "~/${1#"$HOME/"}"; else echo "$1"; fi; }

# stdin is the pipe from curl, so a terminal means stdout is one and /dev/tty opens.
has_terminal() { [[ -t 1 ]] && (: </dev/tty) 2>/dev/null; }

# Prints the first line after "get.sh: " and the rest as they are, then exits.
stop() {
  printf 'get.sh: %s\n' "$1" >&2
  shift
  (( $# == 0 )) || printf '%s\n' "$@" >&2
  exit 1
}

# Each takes the reason without its ending, then any further lines.
stop_install() { local reason="$1"; shift; stop "$reason, so nothing was installed." "$@"; }
# For stops in a clone's git state, after which git fetch may have moved its remote refs.
stop_update() {
  local reason="$1"; shift
  stop "$reason; nothing was installed, and the clone's files, its HEAD and your home folders are unchanged." "$@"
}

# Opens the clone's picker with keys read from /dev/tty, or installs everything without one.
hand_off() {
  if has_terminal; then
    exec "$clone/install.sh" </dev/tty
  fi
  echo "No terminal for the picker; installing everything with build.sh --all"
  exec "$clone/build.sh" --all </dev/null
}

# --- Finding the clone ----------------------------------------------------------------------

# Mirrors lib.sh's is_clone_link without a clone to compare with: a link into a skills
# folder at an entry of the same name. Prints that folder's parent.
clone_of_link() {
  local target
  [[ -L "$1" ]] || return 0
  target="$(readlink "$1")"
  [[ "$target" == */skills/"$(basename "$1")" ]] && echo "${target%/skills/*}"
  return 0
}

# Prints the clone each fap-* skill link in a skills folder points into, one per line.
clones_of_skill_links() {
  local link
  for link in "$1"/fap-*; do clone_of_link "$link"; done
}

linked_clones() {
  {
    clones_of_skill_links "$claude_home/skills"
    clones_of_skill_links "$codex_home/skills"
  } | sort -u
}

stop_on_mixed_links() {
  stop_install "$through_links in $(shown_path "$claude_home") and $(shown_path "$codex_home") point at more than one clone" \
    "$(sed 's/^/  /' <<< "$1")" \
    "Set BELAY_HOME to the clone to update."
}

# Sets clone and found_through.
find_clone() {
  local linked
  if [[ -n "${BELAY_HOME:-}" ]]; then
    clone="$BELAY_HOME"; found_through="BELAY_HOME"; return
  fi
  linked="$(linked_clones)"
  [[ "$linked" != *$'\n'* ]] || stop_on_mixed_links "$linked"
  if [[ -n "$linked" ]]; then
    clone="$linked"; found_through="$through_links"; return
  fi
  clone="$HOME/.belay"; found_through="the default folder"
}

installed_from_clone() { linked_clones | grep -qxF "$clone"; }

# --- First install ---------------------------------------------------------------------------

first_install() {
  local repo="${BELAY_REPO:-$default_repo}"
  echo "Cloning $repo into $(shown_path "$clone")"
  git clone --quiet "$repo" "$clone"
  hand_off
}

# --- Update ---------------------------------------------------------------------------------

stop_unless_git_clone() {
  local top
  top="$(git -C "$clone" rev-parse --show-toplevel 2>/dev/null)" || top=""
  [[ -n "$top" && "$top" == "$(cd "$clone" && pwd -P)" ]] && return
  stop_install "$shown exists but is not a git clone" \
    "To install afresh, move it away or set BELAY_HOME to another folder."
}

stop_on_uncommitted_changes() {
  local changes
  changes="$(git -C "$clone" status --porcelain --untracked-files=no)"
  [[ -z "$changes" ]] && return
  stop_update "$shown has changes that aren't committed" \
    "$(sed 's/^/  /' <<< "$changes")" \
    "Commit or stash them, then run this again."
}

# Sets upstream to the current branch's upstream, such as origin/main.
find_upstream() {
  local branch
  branch="$(git -C "$clone" symbolic-ref --short -q HEAD)" \
    || stop_update "$shown has no branch checked out" \
      "Check out the branch to update, then run this again."
  upstream="$(git -C "$clone" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" \
    || stop_update "branch $branch in $shown has no upstream to update from" \
      "Set one with git branch --set-upstream-to origin/$branch inside it, then run this again."
}

# Run after the fetch, so a commit already pushed from elsewhere doesn't count as local.
stop_unless_fast_forward() {
  local ahead behind
  ahead="$(git -C "$clone" rev-list --count "$upstream..HEAD")"
  behind="$(git -C "$clone" rev-list --count "HEAD..$upstream")"
  (( ahead == 0 )) && return
  (( behind == 0 )) || stop_update "$shown and $upstream have diverged" \
    "Reconcile them with git inside it, then run this again."
  stop_update "$shown has $ahead commit(s) that $upstream lacks" \
    "Push them or move them to another branch, then run this again."
}

pull_from_upstream() {
  local before after
  git -C "$clone" fetch --quiet || stop_update "couldn't fetch $upstream into $shown"
  stop_unless_fast_forward
  before="$(git -C "$clone" rev-parse --short HEAD)"
  git -C "$clone" merge --ff-only --quiet "$upstream" \
    || stop_update "git couldn't fast-forward $shown to $upstream"
  after="$(git -C "$clone" rev-parse --short HEAD)"
  if [[ "$before" == "$after" ]]; then echo "Already up to date with $upstream at $after"
  else echo "Updated from $before to $after ($upstream)"; fi
}

# A clone without install.conf either installed everything without a terminal or had its
# picker left with nothing chosen, so an update never assumes everything was wanted. Run
# before the fetch, so a clone this stops on is left as it was.
stop_on_nothing_to_rebuild() {
  [[ -f "$clone/install.conf" ]] || has_terminal || installed_from_clone \
    || stop_install "$shown has no saved selection and nothing is installed from it" \
      "Run this command in a terminal to choose, or run $shown/build.sh --all."
}

rebuild_without_selection() {
  echo "No saved selection in $shown/install.conf"
  hand_off
}

rebuild() {
  local answer
  [[ -f "$clone/install.conf" ]] || rebuild_without_selection
  if ! has_terminal; then
    echo "No terminal; rebuilding the saved selection"
    exec "$clone/build.sh" </dev/null
  fi
  if "$clone/build.sh" --check >/dev/null 2>&1; then
    echo "The install already matches the saved selection; nothing to write."
    exit 0
  fi
  "$clone/build.sh" --dry-run </dev/null
  printf 'Press enter to write these changes, or type q and enter to leave. '
  read -r answer </dev/tty || answer=q
  [[ -z "$answer" ]] || { echo "Nothing was installed."; exit 0; }
  exec "$clone/build.sh" </dev/null
}

stop_on_missing_clone() {
  if [[ "$found_through" == "$through_links" ]]; then
    stop_install "the skill links point at $shown, which no longer exists" \
      "To install afresh, set BELAY_HOME for bash, for example BELAY_HOME=~/.belay."
  fi
  stop_install "$shown is a broken link" \
    "To install afresh, remove it or set BELAY_HOME to another folder."
}

update() {
  [[ -e "$clone" ]] || stop_on_missing_clone
  stop_unless_git_clone
  clone="$(cd "$clone" && pwd)"
  shown="$(shown_path "$clone")"
  echo "Found the belay clone at $shown through $found_through"
  stop_on_nothing_to_rebuild
  stop_on_uncommitted_changes
  find_upstream
  pull_from_upstream
  rebuild
}

main() {
  git --version >/dev/null 2>&1 || stop "needs git; install it and run this again"
  find_clone
  shown="$(shown_path "$clone")"
  if [[ "$found_through" != "$through_links" && ! -e "$clone" && ! -L "$clone" ]]; then
    first_install
  fi
  update
}

main "$@"
