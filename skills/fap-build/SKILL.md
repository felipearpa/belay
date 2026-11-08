---
name: fap-build
description: Build the next pending slice of a .fap/<slug>/plan.md written by fap-slice. The slice runs through the implementer, verifier, and reviewer agents, waits for the user's review, and this session commits it, tracks progress under .fap/, and brings questions to the user. Use when the user wants a slice built, or is continuing an unfinished plan.
argument-hint: "[slug]"
---

# Build a slice

This session coordinates; the agents do the work. `fap-implementer` writes code,
`fap-verifier` checks it, `fap-reviewer` reads it; this session commits it. The plan lives
in the repository at `.fap/<slug>/plan.md`, written with `fap-slice`. Agents don't edit the
plan files, and this session doesn't edit product code.

Each run builds one slice, the next pending one, and stops at the user's review before
closing it. The user runs this skill again for the next slice.

```
1 pick plan ─→ 2 show slices
                      │
                      ▼
   3 prepare ─→ 4 implement ─→ 5 reconcile ─→ 6 verify + review
                     ▲                                        │
                     │  7 fix loop: defects or blocking       │
                     │    findings, ≤2 rounds; after the      │
                     │    second: stop uncommitted, ask       │
                     ├────────────────────────────────────────┤
                     │  adjustments, no limit                 │ ok
                     ├────────────────────────┐               ▼
                     │                        └──── 8 user review
                     │                                        │
                     └── each fix: the same implementer,      ▼ approved
                         then 5 onward                    9 commit ─→ 10 close
                                                              │
                                                              │ last slice
                                                              ▼
                                                  11 plan review ─→ 12 finish
```

If `fap-implementer` or `fap-verifier` is missing in this session, say so and stop. If
`fap-reviewer` is missing, say so and run the loop without that step.

Read `references/templates.md` before writing any plan file.

## 1. Pick the plan

The argument is the plan's slug. Without one, use the only `.fap/<slug>/` with unticked
tasks, or ask the user to choose when there are several. The plan needs a Slices
section; without one, tell the user to plan it with the fap-slice skill first, and stop.

Announce `Using plan: .fap/<slug>/`.

## 2. Show the slices

Read `plan.md`, and `log.md` and `verification.md` if they exist. A slice is closed when
all its tasks are ticked. Refer to tasks by their plan number (`2.1`). Show the title,
`N/M tasks complete`, and every slice with its number and title, marked closed, pending,
or awaiting review. The slice to build is the first that isn't closed.

A slice whose `State:` line in `log.md` isn't `closed` is one that was left open: resume
where the state says instead of starting over. `implementing` resumes at step 5 when
`.fap/<slug>/snapshots/s<N>.before` exists and no `.after` does, otherwise at step 6;
`fixing round N` at step 5 of that round; `awaiting review` at step 8; `stopped: fix
loop exhausted` asks the user whether to send one more round or leave the slice as it
is. A `.before` snapshot whose slice has no log entry is also an open slice: write its
entry with `State: implementing` and resume at step 5.

## 3. Prepare the slice

- Record the working tree. Snapshots live in `.fap/<slug>/snapshots/`, next to the plan,
  and are deleted with it; create that directory with a `.gitignore` holding a single
  `*` the first time, so the snapshots never show in `git status` whether or not the
  repository tracks `.fap/`. Run this with `<file>` set to
  `.fap/<slug>/snapshots/s<N>.before`:

  ```bash
  ( cd "$(git rev-parse --show-toplevel)" && mkdir -p "$(dirname "<file>")" && {
    git rev-parse HEAD
    { git -c core.quotePath=false diff --name-only --no-renames HEAD
      git -c core.quotePath=false ls-files --others --exclude-standard; } | sort -u |
    while IFS= read -r f; do
      if [ -f "$f" ]; then shasum "$f"; else echo "deleted  $f"; fi
    done
  } > "<file>" )
  ```

- Read the plan's Environment section and list what this slice's checks need from it:
  devices, OS or API levels, simulators or emulators, signed-in accounts, credentials,
  backends, external services. Check what's available, following what the project's
  instruction files say about devices and environments, and otherwise with the
  platform's standard tools.
- Ask the user once about what the section leaves open or what is missing: connect it,
  allow creating it or downloading images, or accept those checks as not verified. When
  checks save or change data and the section doesn't say, ask which backend or build
  variant to use, whether the agents may write to shared or production data with that
  account, and what to clean up afterwards. For a personal physical device, ask whether
  the agents may reinstall the app or clear its data. When a check signs in, ask which
  account to use and whether captures showing real account data may be saved in the
  repository. Write every answer into the Environment section, so the next slice and
  the next session don't ask again.

The implementer and the verifier read these from the plan.

## 4. Implement

Start the slice's entry in `log.md` from the template with `State: implementing`. Then
start one `fap-implementer` agent for the slice and keep its ID. Where the CLI lets you
name it, use `impl_s<N>`.

Its brief gives:

- The path of `plan.md` to read first, plus its `Read first` paths. Give paths; don't
  paste contents.
- The tasks in scope, with their plan numbers and full text, and an instruction to
  leave every other task alone.
- Nothing that isn't in the plan. The agent starts with a fresh context and can't see
  this conversation, so a decision made here since the plan was written goes into
  `plan.md` first, under Decisions or Environment, and the brief points at it.

The agents already return questions instead of guessing, treat plan files as read-only,
run the checks each task names, and report in their fixed formats. Don't repeat those
rules in a brief.

## 5. Reconcile

When the implementer reports, run the step 3 command into `snapshots/s<N>.after` (in a
fix or adjustment round, into `snapshots/s<N>.after.r<R>`) and `diff` it against the
`.before` file. Every added, changed, or removed line is a file that changed during the
slice; a removed line means the file went back to its committed state. If the first line
(HEAD) changed, something was committed: also list `git diff --name-only <old HEAD>
HEAD`. The result is the slice's file list, and it is the truth: compare it with the
files the implementer reported and point out any it didn't mention. If a plan file
changed, tell the user.

Write the list to `snapshots/s<N>.files`, one path per line, rewriting it after every
round. Every later step and every brief reads that file; the log keeps the count, a
summary, and the path. Fill the log entry's Implementer section.

## 6. Verify and review

Start the `fap-verifier` (`ver_s<N>`) and the `fap-reviewer` (`rev_s<N>`) at the same time;
both are read-only over the same file list.

- The verifier's brief gives the path of `plan.md`, the tasks in scope with their full
  text, the path of the slice's `.files` list, the implementer's reported checks, the
  path of `verification.md`, and that it may write that file and captures under
  `verification/`.
- The reviewer's brief gives the path of `plan.md`, the slice's tasks, the path of the
  `.files` list, and the code-metrics output the implementer's report carries when
  there is any.

Wait for both and fill the Verifier and Reviewer sections of the log. Advisory findings
go to the log without asking the user; the plan review in step 11 reconsiders them with
the whole diff. Follow-ups go to the log's Follow-ups section, never into the plan.

An open question from any agent that says the plan is missing a piece of this change (a
file the instruction files say changes with the code, a behavior the goal names that no
task covers) is not a follow-up: show it to the user now and offer to add the task to
the plan, in this slice before it closes or as a later slice. Questions about code
outside the change go to Follow-ups.

Every task passes and there is no blocking finding: go to step 8. Otherwise go to
step 7.

## 7. Fix loop

Set `State: fixing round <R>`. Send the verifier's defects and the reviewer's blocking
findings to the same implementer as one brief, continuing its context; when the CLI
can't address an agent that is already running, start a new one of that role and give
it the slice's log entry and the path of its `.files` list. Repeat step 5.
Then, at the same time, send the fix diff to the same verifier for the checks the fix
affects and to the same reviewer for a re-review: for each earlier finding, resolved or
not, and any new problem in the lines the fix changed. An unresolved defect, an
unresolved blocking finding, or a new one starts another round. At most two rounds;
after the second, stop the slice uncommitted, set `State: stopped: fix loop exhausted`,
record it in the log, and ask the user. Record each round in the log. Then go to step 8.

## 8. User review

Set `State: awaiting review` and add the User review section to the slice's log entry,
then show the user:

- What changed, as behavior, and the slice's file list
- How to see it themselves: the command to build or run, or the flow to follow on a
  device
- The verifier's results with their evidence, checks that weren't run, and the
  reviewer's findings and how they were resolved
- The reviewer's code-metrics groups (split, test first, leave) when the project has a
  metrics command; when three or more functions are flagged and the command prints a
  map, paste the map as printed, never redrawn

Then wait for the user's answer.

- **Approved**: write "Approved" in the User review section and go to step 9.
- **Adjustments**: record the request in the User review section. If the request states
  something that should hold beyond this slice (a convention, a rule about tests,
  naming, or comments, a choice of account or variant), also append it to `plan.md`
  under Decisions before sending it on; a one-off edit to this slice's files stays in
  the log only. Send the request to the slice's implementer, or to a new `fap-implementer`
  with the slice's log entry and the path of its `.files` list when the earlier one is
  gone. Then repeat step 5 and run the verifier on the checks the change affects, and
  come back to this step. The reviewer doesn't run, since the user is reviewing the
  result; when the user asks for the adjustment "with review", also run the reviewer's
  re-review as in step 7 before coming back. There is no round limit; the user decides.
  If a request changes the plan's scope or design, update `plan.md` first and say what
  changed.

## 9. Commit

Commit the slice yourself, from the slice's `.files` list and nothing else:

1. Compare the file list with the before-snapshot. A file that was already modified or
   untracked before the slice began carries work that isn't the slice's: list those
   files and ask the user whether to include them, exclude them, or split them. Don't
   guess. Record each excluded file with its hash from the snapshot in the log's Commit
   section; in a later slice of the same plan, a file recorded there with the same hash
   is excluded again without asking.
2. Stage exactly the listed files with `git add -A -- <file>...`. Confirm with
   `git status --porcelain` that the index holds only those paths; if it already held
   other staged changes, stop and ask.
3. Read the repository's commit style from `git log --oneline -20` and its instruction
   files, and keep its form: prefix, subject length, mood. The subject names the plan's
   title and the slice; the body has one line per task number saying what changed, plus
   the attribution lines the project uses, if any.
4. Never push, amend, rebase, reset, or stash. Record the hash in the log.

If the user says they will commit themselves, skip this step and record "manual" in the
log instead.

## 10. Close the slice

- Tick a task (`- [ ]` → `- [x]`) when the implementer's Status is done and the
  verifier's Status is pass. A task that is partly done, not done, or failed
  verification stays unticked.
- For a task whose check the verifier could not run, leave it unticked and tell the user
  exactly what wasn't verified. Leave the verifier's `Not verified` list in
  `verification.md` as written, including a check that passed only on a degenerate
  case; the plan review reads it. If the user accepts it, append `Accepted without
  <check> by the user.` to that slice's section of `verification.md`, then tick the
  task. If the user already accepted that check in step 3, don't ask again.
- Every answer or instruction the user gave during this slice that a later brief would
  need goes into `plan.md` now, if it isn't there yet: a design change to Decisions and
  the slices it affects, anything else to Decisions or Environment. Say what was added.
  Nothing an agent will need may stay only in this conversation.
- Mark each advisory finding in the slice's log entry `open` or `resolved in <fix round
  or user-review round>`, checked against the slice's diff: a fix or adjustment round
  may have covered it without saying so.
- Finish the slice's entry in the log, set `State: closed`, recount the checkboxes in
  `plan.md`, and confirm the progress.
- Delete the slice's `.before` and `.after*` snapshots once its commit is made. Keep
  `.files` until step 11.
- Close the slice's agents if the CLI keeps agents open.

If slices remain, show `N/M tasks complete` and stop; the user runs this skill again for
the next one. If this was the last slice, go to step 11.

## 11. Plan review

After the last slice, start at the same time:

- one `fap-reviewer` agent with the path of `plan.md`, the plan's goal, the union of every
  slice's `.files` list, the advisory findings still marked `open` in the log, and, when
  the instruction files name a code-metrics command, its output over that union (run it
  once here, on the file list), for the plan review: simplification and reuse, and, when the plan's Goal points at a
  proposal, its path too, for the contrast with what was proposed.
  First check that union against `git diff --name-only <first slice's commit>^..HEAD`
  plus the current working-tree changes, and tell the user about any file in one and
  not the other;
- one `fap-verifier` agent with the paths of `plan.md` and `verification.md`, and the
  instruction to check every Done when item live against the product, as
  `templates.md` describes, and append the `Done when` section to `verification.md`.

Show the user the reviewer's findings and any Done when item that is not proven, once.
A not-proven item is a gap in the plan, not in the code: ask whether to accept it as
is (append `Accepted without proof by the user.` to that line) or to add the missing
task to the plan with `fap-slice` and build it as one more slice.

Send the findings the user accepts to a new `fap-implementer` agent as one brief; the plan
doesn't change. Then run the fix loop from step 7 with that implementer, a `fap-verifier`,
and the same reviewer, and finish with step 9. Log it under `Plan review`. Then delete
the plan's `snapshots/` directory.

## 12. Finish

Show:

- The tasks completed, by number, and `N/M tasks complete`
- Each Done when item with proven, accepted, or not proven
- The functions the plan left flagged by the code-metrics command, grouped as the plan
  reviewer judged them, and the map as printed when the command prints one
- Anything not verified and any open questions
- The commits made
- The follow-ups collected in the log, each with a decision from the user: fix it now
  (one `fap-implementer` run through the fix loop of step 7 and the commit of step 9, or a
  new plan with `fap-slice` when it is bigger than a slice) or drop it. None is carried
  anywhere else; the code is the only record.
- The decisions added to `plan.md` during the build that aren't specific to this plan:
  for each, offer to move it to the repository's instruction file, so later plans don't
  have to carry it
- That `.fap/<slug>/` can stay as the record of the work or be deleted

## Guardrails

- Don't write or fix product code in this session. Send fixes back to the implementer.
  The commit in step 9 is the one git write this session makes.
- Edit `plan.md` only to write Environment answers in step 3, to record decisions in
  steps 4, 8, and 10, or when an answer changes the design, and say so each time.
  Otherwise your only edits are ticking its boxes, writing `log.md`, and appending
  acceptance lines to `verification.md`.
- One slice per run, never more.
- Give agents paths, not pasted contents. They start with a fresh context, so a brief
  carries nothing that isn't in the plan or the slice's `.files` list: anything decided
  in this conversation since the plan was written is written into `plan.md` before the
  brief that needs it.
