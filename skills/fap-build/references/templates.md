# Templates

Write every plan file from these. Keep the headings; drop a section only when it would
be empty.

## proposal.md

Written by fap-explore, read by the user, the challenge agents, and fap-slice. It says
what is proposed and why; `plan.md` says how it is built.

```markdown
# <Title>

Status: <draft | challenged | approved> · <date of the last change>

## Problem
<What is wrong or missing today, for whom, how it is handled now, and why that doesn't serve.>

## Outcome
<What is true when this is done, in product terms. The Done when items of plan.md break it down.>

## Approach
<The shape of the solution: which parts of the product it touches, how data flows, what is stored and what is derived. A Mermaid diagram when it crosses layers. The agreed look, when there is one: each render under `design/` with what it shows.>

## Decisions
- <Decision>. Instead of <option>: <why it lost>.

## Out of scope
- <What this leaves alone, including the near things it deliberately doesn't do.>

## Risks
- <What could make this fail or cost more than it looks, and how the plan should face it. An assumption nothing has run yet ends with `tracer candidate`.>

## Open questions
- <What only the user can settle, with the options.>
```

Problem names what exists today, not only what is missing: a proposal is where extending
what the project has beats building anew, and that needs the current state written down.
Approach gives the shape of the solution in product and architecture terms, with no
tasks and no file lists; those are the plan's. Each decision keeps the option it was
chosen over and why, so the challenge agents and a later session don't propose it again.
fap-explore sets Status to `draft` when it writes the file and to `challenged` after the
challenge round; fap-slice sets it to `approved` when it plans from the proposal.

## plan.md

```markdown
# <Title>

## Goal
Problem: <What is wrong or missing today, and for whom.>

Outcome: <What is true when the plan is done, in product terms.>

## Done when
- When <trigger>, <observable result>.
- Given <precondition>, when <trigger>, <observable result>.

## Decisions
- <Decision>. Instead of <option>: <why it lost>.

## Out of scope
- <What the agents must leave alone.>

## Read first
- <path the agents should read before the code the tasks name>

## Environment
- <One fact per bullet: a device with its OS or API level, an account, the backend or
  build variant, what may be written and what to clean up, whether captures may show
  real account data, anything else the checks need.>

## Slices

### 1. <Title>
- Tracer: <the assumption this slice runs for the first time, in one sentence>
- You will see: <the observable result in product terms, no paths: a screen, a response, a file>

- [ ] 1.1 <One sentence: what changes and where, in plain words, at most one backticked name>
  - Check: <the build, flow, or test that proves the task>
- [ ] 1.2 …

### 2. <Title>
- You will see: …

- [ ] 2.1 …
  - Check: …
```

Goal is two short paragraphs. Problem says what happens today and who it affects;
Outcome says what is true afterwards, in product terms, and is what the Done when items
break down. When the plan is one feature for one kind of user, a single user story
("As a …, I want …, so that …") may replace the two paragraphs. When the plan comes from a proposal, Goal is instead one
line pointing at `.fap/<slug>/proposal.md` and the Outcome copied from it; the proposal
holds the problem and the design decisions.

The Done when items are the plan's acceptance criteria: each is one observable behavior,
written as a trigger and a result, with a `Given` only when a precondition matters. The
verifier checks every one of them against the product after the last slice.

Each decision names the option it was chosen over and why that option lost, so a later
session doesn't propose it again. Decisions taken during the build are appended here. When the plan comes from a proposal,
this section holds only what was decided after it, while planning or building; the
design decisions stay in the proposal.

Read first holds paths only, the proposal first when the plan comes from one. Build and test commands, conventions, and constraints live
in the repository's instruction files, which every agent reads. Nothing an agent will
need may exist only in a conversation or a memory. Answers the user gives during the
build are appended under Environment or Decisions.

When the plan changes what the person sees (a screen, a component, a state), the agreed
look lives as images under `.fap/<slug>/design/`, one per screen or state, named for
what they show (`2-checkout.png`, `button-states-dark.png`). Each is listed under Read
first before the code paths, after the proposal when there is one. One Decisions bullet names them: "The agreed look is the
set of images under `.fap/<slug>/design/`, listed under Read first: <what each shows>.
Rendered from the design the user approved on <date>; <what in them is sample data>.
Where the images and the prose differ, the prose in this file wins." The check of each
task that builds a screen names its render ("on the device, the checkout step matches
`2-checkout.png`"), so the verifier compares its capture against it.

Slices: each is one `###` section, numbered in build order. The header bullets are for
the person reading the plan, in product terms (no paths, no identifiers): `Tracer`, on
tracer slices only, names the assumption to look at hardest when reviewing; `You will
see` describes the result as the user will observe it.

Tasks: the task line is one sentence under about fifteen words saying what changes and
where in plain words, with at most one backticked name. A task that adds a test says in
that sentence which rule, bug, contract, or state transition the test protects. Its one
sub-bullet, `Check`, names the build, flow, or test that proves the task. A slice is
closed when all its tasks are ticked.

## log.md

One entry per slice, appended as the slice runs; the headings are fixed so a later
session can resume from the file.

```markdown
## Slice 1: <title> — <date>
State: <implementing | fixing round N | awaiting review | stopped: fix loop exhausted | closed>

### Implementer
<Status per task in one line each; file count and a summary, with the path of the slice's `.files` list; assumptions.>

### Verifier
<Pass/fail per task; defects; rounds back to the implementer and what each fixed.>

### Reviewer
<Blocking findings and the fix-loop rounds that resolved them; advisory findings, each marked `open` or `resolved in <round>` at slice close; the open ones go to the plan review.>

### User review
<Each round: what the user asked to change and what changed,
and whether it was also recorded in plan.md; finally "Approved".>

### Commit
<hash and subject; then the files the user excluded, each with its snapshot hash, so a later slice doesn't ask again.>

### Follow-ups
<Problems outside the change, with locations, for a later plan.>
```

After the last slice, one more entry headed `## Plan review — <date>` with the same
Reviewer, Verifier, and Commit sections.

The `State` line is what a later session resumes from: `fap-build` sets it at every
transition and treats any slice whose state isn't `closed` as the one to continue.

## verification.md

Written by the verifier only. One section per slice, headed `<Slice title> (<date>)`,
listing each check, its result, and where the evidence is, and ending with a
`Not verified:` list: every check it could not run, and every check that passed without
reaching the behavior the task names (a `null` where the task is about a value, a flow
that stops before the changed code), each in one line with the reason. Each fix round
adds a `Fix round <R> (<date>)` subsection under that slice's section, with the checks
rerun and each earlier defect as resolved or not. The orchestrator appends
`Accepted without <check> by the user.` when the user accepts a check that wasn't run.

After the last slice, the plan review's verifier appends a final section headed
`Done when (<date>)`: one line per Done when item, checked live against the product,
with `proven` and the evidence, or `not proven` with what it observed instead. An item
that is not proven is a gap in the plan, reported to the user, not a pass.
