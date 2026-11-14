# Installing Belay

The [README](../README.md#install) has the plugin and the one-line install. This page
has the rest: updating the plugin, switching to it from the scripts, and adding Codex
next to it; then, for the scripts, where the clone goes, how an update finds it and when
it stops, installing part of it, what `build.sh` writes into your home folders,
uninstalling, and Codex.

## The plugin

The [README](../README.md#install) gives the two commands that install the plugin, the
names its commands carry, and why to pick it or the scripts for Claude Code, not both.

To update it, run `/plugin` in a session and update Belay there, or, in a shell, refresh
the marketplace, then the plugin; either way, restart running sessions afterwards.
`/plugin` also removes it.

```bash
claude plugin marketplace update belay
claude plugin update belay@belay
```

The plugin has no version number, so every commit to the repository is an update.
Claude Code keeps its own copy of the whole repository under `~/.claude/plugins/`,
scripts included, and loads only its `skills/` and `agents/`. Don't run the scripts from
that copy: `get.sh` ignores where it runs from and would add a script install next to the
plugin, and `install.sh` and `build.sh` would link the skills into a folder the next
plugin update replaces.

### Switching to the plugin

To move Claude Code from the scripts to the plugin, remove the script install from
Claude Code in the clone, then install the plugin and restart running sessions:

```bash
cd ~/.belay                        # or wherever your clone is
./build.sh --uninstall --claude    # removes Belay from Claude Code, keeps Codex
```

This removes the agent files and skill links `build.sh` put in `~/.claude` (see
[Uninstalling](#uninstalling)) and saves Codex's install as the selection, so the
one-line command keeps updating Codex alone. Keep the clone while Codex uses it. Without
Codex, run `./build.sh --uninstall` instead, then delete the clone.

### Codex next to the plugin

With the plugin in Claude Code, install Codex alone from a clone. Don't use the one-line
command for this: its picker opens with Claude Code ticked, and without a terminal it
installs into both.

```bash
git clone https://github.com/felipearpa/belay.git ~/.belay
~/.belay/build.sh --codex --skills flow   # writes nothing into ~/.claude
```

The choice is saved in `install.conf`, so from then on the one-line command updates
Codex alone.

## The one-line install

```bash
curl -fsSL https://raw.githubusercontent.com/felipearpa/belay/main/get.sh | bash
```

`get.sh` clones the repository into `~/.belay` and opens the picker, `install.sh`, from
that clone. To clone somewhere else, set `BELAY_HOME` for bash:

```bash
curl -fsSL https://raw.githubusercontent.com/felipearpa/belay/main/get.sh | BELAY_HOME=~/code/belay bash
```

With no terminal to show the picker on, in CI or with its output sent to a file, it
installs everything with `build.sh --all` instead. Afterwards, `~/.belay/build.sh --check`
exits 0 and prints "up to date" when the install matches your choice.

### Updating

Run the same command again to update. It finds your clone through `BELAY_HOME`, else the
skill links in your home folders, else `~/.belay`, says which, and fast-forwards it from
its origin. It then lists every file the update would change for the choice saved in
`install.conf` and writes them when you press enter; with no terminal it writes them
without asking. With no saved choice it opens the picker instead, or, with no terminal,
reinstalls everything only when something is already installed from that clone.

The update stops before it installs anything when the clone has changes you haven't
committed (files git doesn't track don't count), commits its origin lacks, a branch that
has diverged from its origin (history rewritten upstream), no branch checked out, or a
branch with no upstream, and when the skill links point at more than one clone or at a
folder that is no longer a git clone; the message says which and what to do. The fetch
may have refreshed what git knows about the origin, but the clone's files, its HEAD, and
your home folders are unchanged. In a clone you manage yourself, `git pull` and
`./build.sh` inside it still update by hand.

## Managing the clone yourself

Clone it wherever you like and run the picker from it:

```bash
git clone https://github.com/felipearpa/belay.git
cd belay
./install.sh         # pick the CLIs and skills on one screen, then install them
./build.sh --check   # exits 0 and prints "up to date" when the install matches your choice
```

`install.sh` lists Claude Code and Codex, the flow, and any other skill, each with a tick
you change with the arrow keys and space (`a` ticks all, `n` none). It opens on the
choice saved in `install.conf` when there is one; without it, on what `build.sh` already
installed in your home folders, and on the defaults when nothing is. Enter shows every
file the install would add, overwrite, or remove; a second enter runs `build.sh` with
the matching flags (see [Installing part of it](#installing-part-of-it)), which saves the
choice, `b` goes back with your ticks, and `q` leaves without installing. Run on its own
without a terminal, it stops and points at `./build.sh --all` or the flags. Read
[What build.sh touches](#what-buildsh-touches) before you install.

The skills are linked, not copied, so keep the clone where it is: moving or deleting it
breaks them. Run `./build.sh` again after you edit or pull, then restart running
sessions. To install somewhere other than `~/.claude` and `~/.codex`, set `CLAUDE_HOME`
and `CODEX_HOME`.

## Installing part of it

With no flags and no saved choice, `build.sh` installs everything into both CLIs. Flags
choose a part instead, the same ones `install.sh` passes:

```bash
./build.sh --claude --skills flow
```

- `--claude`, `--codex`: where to install; name at least one.
- `--skills`: `flow` (fap-explore, fap-slice, fap-build and the six agents, which
  are installed only with it). Any other folder added under `skills/` is accepted by
  name.

A list you leave out is empty. `build.sh` saves the choice to `install.conf` in the
clone (git ignores it), and a later plain `./build.sh` installs the same choice again, as
the one-line command does after it pulls an update. `./build.sh --all` installs
everything and leaves `install.conf` as it is; delete the file to go back to everything
by default. Add `--dry-run` to any of these to list what the run would do, file by file,
without writing anything, `install.conf` included. An unknown flag or a name with no
source stops the run with a usage line, and an `install.conf` that doesn't read cleanly
stops it before anything is written; fix or delete the file.

Each run keeps your home folders in step with the choice: a skill you drop loses its
links, the agent files go when the flow is dropped, and a CLI you drop loses its skill
links and its agent files. `./build.sh --check` compares against the saved choice, and
`./build.sh --check --all` against everything.

## Optional tools

The code-metrics tool a project's `AGENTS.md` names is installed apart from this
repository, and `build.sh` installs none. Today that is `crapper`
(https://github.com/felipearpa/crapper): clone it and put its launcher on the PATH
through a short script that `exec`s it, since a symlink breaks its venv lookup.

## What build.sh touches

`build.sh` writes into your home folder, into the CLIs and items you chose (see
[Installing part of it](#installing-part-of-it); everything by default). Before anything
is written, `install.sh` shows a confirmation screen: one line per file it changes,
marked `overwrite`, `remove` or `new` in that order, and a count of the `unchanged` ones,
from `./build.sh --dry-run` with the same flags, so the second enter writes exactly that
list. A list longer than the terminal scrolls with the arrow keys. An `overwrite` of an
agent file `build.sh` didn't generate says "no backup": the file is replaced and its old
content is gone, so copy it first or untick it. Before you run `build.sh`, know that it:

- **Writes agent files.** With the flow, one `~/.claude/agents/<name>.md` per agent in
  the README's [Agents](../README.md#the-pieces) table, and the same six as
  `~/.codex/agents/*.toml`, each starting with a line that names the clone it was
  generated from, such as "Generated from ~/.belay by build.sh". A file there with the
  same name is overwritten. A file in those folders that `build.sh` generated earlier is
  deleted when its agent no longer exists here, the flow isn't chosen, or its CLI isn't.
- **Links skills.** One symlink per chosen skill in `~/.claude/skills/` and
  `~/.codex/skills/`. An existing symlink with the same name is repointed at this clone;
  a real folder with the same name is left alone and reported. A symlink `build.sh`
  made, named after a skill and pointing at that skill in this clone, is deleted when
  the skill or its CLI isn't chosen, and any symlink into this clone's `skills/` is
  deleted once its skill no longer exists.

Nothing else in your home folders is read or written.

`./build.sh --check` changes and creates nothing; it lists what differs from the saved
choice (from everything with `--all`) and exits 1 if anything does. `./build.sh --dry-run`
writes nothing either; it lists every file the run would touch, as `install.sh` shows it.
To try the install without touching your real setup, point it at a temporary folder:
`CLAUDE_HOME="$(mktemp -d)" CODEX_HOME="$(mktemp -d)" ./build.sh`.

## Uninstalling

The one-line command doesn't uninstall; `build.sh` does, run in the clone. Preview it,
then run one of the last two:

```bash
cd ~/.belay                        # or wherever your clone is
./build.sh --uninstall --dry-run   # lists what would be removed, and removes nothing
./build.sh --uninstall             # removes Belay from Claude Code and Codex
./build.sh --uninstall --claude    # removes it from Claude Code only, and keeps Codex
```

It removes only what `build.sh` installed: the agent files it generated, recognized by
their "Generated from" line, and the skill links that point into this clone. A real file
or folder with a skill's name, an agent's file it didn't generate, and a link into
another clone stay, each named in a note; run `--uninstall` from that other clone to
remove its links. `install.conf` is never read: removing from both CLIs deletes it, and
removing from one (`--claude` or `--codex`) saves what is installed in the other as the
selection, so the next update reinstalls only that one, or deletes it when nothing is.

The clone stays, and the last lines say where; delete it yourself when nothing uses it.
After uninstalling from both, the one-line command finds nothing installed: on a
terminal it opens the picker, and without one it stops and says so. With the skill links
gone it finds a clone outside `~/.belay` only through `BELAY_HOME`, so run without it,
it would clone Belay again into `~/.belay`, or update another clone when skill links into
that one remain; the uninstall warns when either applies.

## Codex

Codex is supported through the scripts. `build.sh` writes each agent as
`~/.codex/agents/<name>.toml` and links each chosen skill into `~/.codex/skills/`. The
agents name no model, so each inherits the session's model and, in Codex, its reasoning
effort. To install into Codex alone, run `./build.sh --codex --skills flow` (see
[Installing part of it](#installing-part-of-it), and
[Codex next to the plugin](#codex-next-to-the-plugin) when Claude Code has the plugin).
Run the skills the way Codex runs skills.

One step hasn't been tried in Codex yet: sending a fix round or an adjustment to the
agent that already did the work, so it keeps its context. fap-build does this with the
implementer, the verifier, and the reviewer; Claude Code does it with SendMessage. Where
the CLI can't address an agent that is already running, the skills start a new agent of
that role instead and give it the slice's log entry and its list of changed files.
