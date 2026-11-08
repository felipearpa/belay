---
name: fap-slice
description: Turn a goal, or a .fap/<slug>/proposal.md written by fap-explore, into a .fap/<slug>/plan.md ready to build. Complete the goal, cut the work into slices with their tracer, check the cut against the slicing rules, and stop without implementing anything. Use when the user wants the plan and its tasks written or reviewed.
argument-hint: "[goal, or the slug of a .fap/ proposal or plan]"
---

# Plan in slices

This session writes the plan and builds nothing. The result is `.fap/<slug>/plan.md`.
`fap-build` then builds it one slice at a time, each with the user's review.

Read `references/slicing.md` here and `fap-build`'s `references/templates.md` before
writing the plan.

## 1. Pick the plan

- If the argument is the slug of a `.fap/<slug>/` directory whose `plan.md` has ticked
  tasks, the plan is being built. Say so and stop, unless the user asks to re-cut the
  pending slices: then change only slices with no ticked task, and say what changed.
- If that `plan.md` has no ticked task, the plan is written but not started. Announce `Reviewing plan: .fap/<slug>/`, read it, and go to step 4.
- If that directory holds a `proposal.md` and no `plan.md`, the plan comes from the
  proposal. Announce `Planning from: .fap/<slug>/proposal.md`, read it, and set its
  Status line to `approved`: handing it to this skill is the user's approval.
- Otherwise the goal is the argument, or what the user has been discussing. If `.fap/`
  holds proposals without a plan, or plans with unticked tasks, mention them in one line
  in case the user meant one of them. Choose a short kebab-case slug and announce
  `Using plan: .fap/<slug>/`.

## 2. Learn the code

Read the repository's instruction files, then the code the goal
touches: the closest existing implementation, its callers, tests, and any design docs.
For a wide search, start an `Explore` agent and read what it points to.

When the goal comes with decisions already made, in a proposal, in this conversation, or
in the argument, keep them and its out of scope as written and resolve its open questions
with the user first; don't ask again what it already decides. Ask the user about product
decisions the goal leaves open (behavior, stored data, public API, visible changes)
before writing the plan; make smaller calls yourself and record them as decisions.

When the goal adds a requirement to an existing design, ask what would have been built
had it been there from the start, and plan toward that in slices rather than bolting the
requirement on; record the choice under Decisions, with the bolt-on named as the option
that lost. Decide the data shape before the logic: a slice settles what is stored, what
is derived, and who owns it before the slices that compute on it.

When the goal changes what the person sees (a screen, a component, a state), the plan
carries the agreed look as images under `.fap/<slug>/design/`, as `templates.md`
describes, before the slices are cut. Take them from what already exists, in this order:
renders the proposal names (already under `design/`), a design approved in this
conversation (export each screen or state as an image), or images the user supplies.
When none exists, propose the look in the conversation: name the audience, the screen's
job, a compact palette, type roles, and one distinctive feature tied to the subject;
critique it against the brief and revise what reads generic; render it and get the
user's yes before writing the plan. Don't plan a screen whose look nobody has seen.
Then list the images under Read first, write the Decisions bullet, and make each screen
task's check name its render.

## 3. Write plan.md

Create `plan.md` from the template:

- Write the Goal as Problem and Outcome, or as one user story when the plan is one
  feature for one kind of user. From a proposal, the Goal is one line pointing at it and
  the Outcome copied from it. Write the Done when items: one per thing that must hold
  when the plan is done, each a trigger and an observable result, checkable on its own;
  from a proposal, they break down its Outcome.
- From a proposal, Decisions holds only what is decided while planning; the design
  decisions stay in the proposal, and Read first lists the proposal before the code
  paths.
- Build and test commands live in the repository's instruction files, which every
  agent reads, never in the plan. If the goal needs a command those files lack, propose
  adding it there, with the user's yes, before writing the plan. Nothing an agent will
  need may exist only in this conversation or in a memory: it goes into the instruction
  files or into the plan.
- Fill Environment with what the checks need to run: devices, accounts, the backend or
  build variant, what the agents may write and must clean up afterwards, whether
  captures may show real account data. Take it from the instruction files and from what
  the user has said; ask once about the rest, so `fap-build` doesn't have to ask at
  every slice.
- Read the instruction files for what must change together with the code: release notes,
  documentation that describes behavior, migrations, runbooks. For each one the goal
  touches, add a task to the slice that changes the behavior it describes, or name it
  under Out of scope. When the instruction files list nothing of the kind, ask the user
  once whether the repository keeps such files, and suggest recording the answer there.
- Cut the tasks into slices as `slicing.md` says and write them as the template shows. A
  proposal's risk marked `tracer candidate` is an assumption nobody has seen run: give it
  a tracer slice placed as early as its dependencies allow, or say under Decisions why
  it needs none.

## 4. Check the cut

Before showing the plan, read its Slices section against `slicing.md` and the template,
and fix what fails. Then check across the plan: every Done when item has a slice whose
checks establish its behavior (an item with none means a missing task, or an item that
isn't a behavior and leaves the list), and everything the instruction files say changes
with the code, and the goal touches, has a task or an Out of scope line. From a
proposal, also check that no task crosses its Out of scope and that every `tracer
candidate` has its tracer or its reason.

Then say in one line what each tracer proves, or that the plan has none and why, and
list each Done when item with the slice that establishes it.

## 5. Hand over

Show the user `plan.md`, apply the edits they ask for, and stop. Tell them to run the
fap-build skill with the slug to build the first slice.

## Guardrails

- Don't write or change product code. The only files you write are
  `.fap/<slug>/plan.md`, the images under `.fap/<slug>/design/`, and the Status line of
  `.fap/<slug>/proposal.md`.
- Decisions the user made, in the proposal, in the argument, or in this conversation,
  are settled; record them, don't reopen them.
- When the user's edits change the cut, run step 4 again before handing over.
