# Slicing

A plan's tasks are grouped into slices. A slice is the unit of the loop: one implementer
run, one verification, one review, one commit.

## What a slice is

- Something the verifier can check end to end: when the slice is done, a build, a flow,
  or a test proves it, without waiting for a later slice.
- Small enough for one implementer run: about two to six tasks, and no more than a
  handful of files. Split a larger group.
- Vertical inside one deployable: one flow from its entry point through every layer it
  needs (view, view model, use case, repository, API client), rather than one layer for
  every flow. Order the tasks the way the implementer should build them.
- One slice per deployable when a change crosses deployables (an API and the apps that
  consume it). The API slice comes first, with its contract check, so the app slices
  build against something that runs.
- Numbered in the order they are built, and built only on the slices before it: an app
  slice after the API slice it consumes, a second flow after the shared component the
  first one introduced. If two candidate slices depend on each other, they are one
  slice.

## Tracer slices

A tracer is the thinnest kept path through every layer an assumption touches, built to the
project's quality bar, not a throwaway spike. A slice is a tracer when it runs an
assumption nobody has seen run: a new integration between two systems, a new
infrastructure path, a third-party API, a library used for the first time. Place it as
early as its dependencies allow, so the assumption is tested before other slices build on
it. A plan with no such assumption has no tracer.

Mark each tracer with a `Tracer:` bullet naming the assumption, so the user knows what
to look at hardest when reviewing that slice.

## Not slices

- A group named after a layer ("models", "repositories", "views") with no flow that runs
  at the end.
- A "cleanup" or "refactor" group collected from things noticed along the way. Those go
  to the log as follow-ups.
