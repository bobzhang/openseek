# bobzhang/openseek/tui/core

> The semantic model — Input/Event/ToolStatus/ToolCall/TranscriptItem — and its projection into `@doc.Doc`.

`core` owns the meaning of what flows through the UI: the inputs a user submits,
the events handed to the application loop, and the transcript items that make up a
committed conversation. For each renderable type it also attaches a logical
projection into `@doc.Doc` via `impl @doc.ToDoc`. It sits above `doc` (which owns
the styling/wrapping vocabulary and the `ToDoc` trait) and below `render` and the
root `tui` package, which re-exports these types.

## Responsibilities

- Define the semantic input type `Input` (`Prompt`/`Command`) with its `prefix`
  and `text` accessors.
- Define `Event` (`Queue`/`Steer`/`Interrupt`/`Quit`), the user-driven events
  handed to the application loop.
- Define the transcript vocabulary: `ToolStatus`, `ToolCall`, and `TranscriptItem`.
- Attach each type's `@doc.ToDoc` projection — these impls must live here because
  the orphan rule places a trait impl in the type's home package.
- Select styling for tool calls via `ToolStatus::style`.
- It leaves the styling/wrapping vocabulary and layout to `doc`, and composition,
  rendering, and IO to `render` and `tui`.

## Public API

Input:
- `Input` (`Prompt`/`Command`) — `prefix() -> String`, `text() -> String`.
- `impl @doc.ToDoc for Input` — prefixed, prompt-styled projection.

Events:
- `Event` (`Queue`/`Steer`/`Interrupt`/`Quit`).

Transcript:
- `ToolStatus` (`InProgress`/`Completed`/`Failed`/`Declined`).
- `ToolCall` — `ToolCall(title, status?, details?)`.
- `TranscriptItem` (`Input`/`Response`/`Reasoning`/`ToolCall`/`Error`).
- `impl @doc.ToDoc for TranscriptItem` — bulleted, status-styled projection.

Note: cross-package callers invoke a projection as `@doc.ToDoc::to_doc(value)`;
the dot-call `value.to_doc()` only resolves inside `core` itself.

## Layering

Depends on `doc` for the `Doc`/`Text`/`Span`/`Style` vocabulary and the `ToDoc`
trait it implements, and on `internal/text` for unicode-aware line splitting used
when projecting multi-line inputs. It has no IO; rendering and the terminal
session belong to higher layers.
