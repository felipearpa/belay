# AGENTS.md

This repository is Markdown and four shell scripts, `get.sh`, `build.sh`, `install.sh`,
and the `lib.sh` the last two source: agent prompts and skills that `build.sh`
installs into Claude Code and Codex. There is no app to build and no test suite; the
checks below are the build.

## Checks

Run them from the repository root. Check 1 is the quick one while editing; check 3
covers it and runs before a commit, with check 4 when an agent source changed and check
5 when `.claude-plugin/` did. Never run any of them against your real `~/.claude` or
`~/.codex`.

1. Install everything into a temporary home and confirm nothing is stale. `--all`
   ignores the selection saved in `install.conf`, so every skill and agent is checked.

   ```bash
   tmp="$(mktemp -d)"
   CLAUDE_HOME="$tmp/claude" CODEX_HOME="$tmp/codex" ./build.sh --all
   CLAUDE_HOME="$tmp/claude" CODEX_HOME="$tmp/codex" ./build.sh --check --all   # exits 0, prints "up to date"
   rm -rf "$tmp"
   ```

2. Render every Mermaid block with `mmdc`, the Mermaid CLI, to catch a diagram that
   GitHub would show as an error. It needs a Chrome or Chromium binary in
   `PUPPETEER_EXECUTABLE_PATH`; the path below is the macOS one.

   ```bash
   out="$(mktemp -d)"
   export PUPPETEER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
   mmdc -i README.md -o "$out/README.md"
   mmdc -i docs/structure.md -o "$out/structure.md"
   rm -rf "$out"
   ```

   Each command exits 0 and lists one ✅ line per diagram, plus one for the output file.

3. Install through `get.sh` as the README's one-line command does, with no terminal and
   no network. `git clone` carries only committed files, so the check commits the
   working tree into a temporary copy and points `BELAY_REPO` at it. With its output
   sent to a file, `get.sh` has no terminal and runs `build.sh --all`. The second run is
   the update: with a new commit in the temporary copy and `BELAY_HOME` unset, it
   finds the clone through the skill links, fast-forwards it, and rebuilds. `HOME`
   points into the temporary folder for that run so a missed link can't reach the real
   `~/.belay`.

   ```bash
   tmp="$(mktemp -d)"
   cp -R . "$tmp/repo"
   git -C "$tmp/repo" add -A
   git -C "$tmp/repo" -c user.name=check -c user.email=check@localhost commit -q --allow-empty --no-verify -m check
   cat get.sh | CLAUDE_HOME="$tmp/claude" CODEX_HOME="$tmp/codex" BELAY_HOME="$tmp/belay" BELAY_REPO="$tmp/repo" bash > "$tmp/get.log" 2>&1
   git -C "$tmp/belay" remote get-url origin   # prints $tmp/repo
   CLAUDE_HOME="$tmp/claude" CODEX_HOME="$tmp/codex" "$tmp/belay/build.sh" --check --all   # exits 0, prints "up to date"
   sed -n 2p "$tmp/claude/agents/fap-implementer.md"   # "Generated from $tmp/belay by build.sh. ..."
   echo "update check" >> "$tmp/repo/README.md"
   git -C "$tmp/repo" -c user.name=check -c user.email=check@localhost commit -q --no-verify -am update
   cat get.sh | env -u BELAY_HOME HOME="$tmp/home" CLAUDE_HOME="$tmp/claude" CODEX_HOME="$tmp/codex" BELAY_REPO="$tmp/repo" bash > "$tmp/update.log" 2>&1
   sed -n 1p "$tmp/update.log"   # "Found the belay clone at $tmp/belay through the skill links"
   git -C "$tmp/belay" log -1 --format=%s   # prints "update"
   CLAUDE_HOME="$tmp/claude" CODEX_HOME="$tmp/codex" "$tmp/belay/build.sh" --check --all   # exits 0, prints "up to date"
   rm -rf "$tmp"
   ```

4. Confirm the agents committed in `agents/` match what `agent-sources/` renders to. The
   same command runs on GitHub for every pull request and every push to `main`
   (`.github/workflows/agents.yml`). It writes nothing and touches no home folder.

   ```bash
   ./build.sh --render-agents --check   # exits 0, prints "up to date"
   ```

   It exits 1 and names each file that is stale, missing, left from a removed source
   (`no agent source`), or not rendered there at all (`foreign:`); the convention below
   fixes all but the last, which is moved out of `agents/` by hand.

5. Validate the plugin manifests in `.claude-plugin/`. It needs the `claude` binary, so
   it runs here and not on GitHub; the temporary configuration folder keeps `claude`
   from writing into your real `~/.claude`.

   ```bash
   tmp="$(mktemp -d)"
   CLAUDE_CONFIG_DIR="$tmp" claude plugin validate .   # exits 0, ends with "Validation passed with warnings"
   rm -rf "$tmp"
   ```

   The one manifest warning accepted is that `plugin.json` has no `version`. Its plugin
   directory warnings (no icon, `.DS_Store` files on disk that aren't committed) don't
   change the result.

## Files that change together

- `README.md` and `docs/structure.md` describe the same system, so a change to one,
  including adding, renaming, or removing a skill or agent, is checked against the other.

## Conventions

- Edit the sources here, never the generated files under `~/.claude` or `~/.codex`.
- `agents/` holds generated files that are committed, because the Claude Code plugin
  loads them as they are in git. Never edit them: edit `agent-sources/`, run
  `./build.sh --render-agents`, and commit what it changed in `agents/` with the sources.
  Ordinary `build.sh` runs never write there.
- Agents name no model; every agent inherits the session's model in both CLIs.
- Graphics are Mermaid blocks only, so GitHub renders them without assets.
