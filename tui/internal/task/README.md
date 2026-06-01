# bobzhang/openseek/tui/internal/task

> A single-slot async task runner for the TUI.

`task` wraps `@async/aqueue` into a tiny `Queue` that accepts at most one
in-flight job and runs jobs one at a time on a worker loop. The TUI uses it to
run a single agent task at a time: callers `wait` on a job and a single
long-lived `run` loop executes them serially. It sits at the bottom of the TUI
concurrency layer, below the agent/event plumbing.

## Responsibilities

- Accept submitted async jobs and run them serially on one worker loop.
- Let a caller `wait` on a job and receive its result (or raised error) back.
- Bound concurrency to a single in-flight task via the queue `kind`.
- Boundary: only sequencing and result/error relay; it owns no task logic,
  scheduling policy, or IO.

## Public API

Types

- `Queue` — single-slot async task runner.

Functions

- `Queue::Queue(kind~ : @aqueue.Kind) -> Self` — build a queue with the given
  submission-slot kind (e.g. `Blocking(1)`).
- `Queue::run(Self) -> Unit` — worker loop; runs submitted jobs to completion
  one at a time, forever.
- `Queue::wait(Self, async () -> T) -> T` — submit a job and await its result,
  propagating any error it raises.

## Layering

Depends on `moonbitlang/async/aqueue` (and `async`). This is an `internal/`
package: it is only importable within `tui/`.
