# bobzhang/openseek/tui/render

> The view layer that lays the composer area out into a render surface.

`render` turns the live composer state into render data: `composer_surface`
takes the editing `@composer.Model` plus styled status/activity text and queued
follow-up inputs and stacks them into a single `@surface.Surface` — queued-input
preview rows, an optional activity block, the bordered composer body, the status
line, and cursor placement on the active input row. It is pure and
terminal-agnostic, performing no IO, and sits above the composer/surface
internals as the public composer view for `tui/`.

## Responsibilities

- Lay the composer model, status/activity text, and queued inputs out into one
  `@surface.Surface` for a given column width.
- Draw separator borders, prompt rows, the status line (with `notice` taking
  precedence over `status`), and a numbered queued-input preview block.
- Resize the composer for the current width and place the cursor on the active
  input row so wrapping, scrolling, and cursor agree with what is drawn.
- Boundary: pure view layout only; no terminal IO, no input handling, no
  composer mutation beyond resizing for the draw.

## Public API

Functions

- `composer_surface(@composer.Model, activity~ : @doc.Text?, queued_inputs~ : Array[@core.Input], status~ : @doc.Text, notice~ : @doc.Text?, cols~ : Int) -> @surface.Surface`
  — lay the composer area out for `cols` columns into a render surface.

## Layering

Depends on `core`, `doc`, `internal/composer`, `internal/surface`, and
`internal/text`. This is a public sub-package of `tui` (not `internal/`), so it
is importable from outside `tui/`.
