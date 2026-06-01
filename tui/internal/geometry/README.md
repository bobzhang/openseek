# bobzhang/openseek/tui/internal/geometry

> Pure, total math for placing the bottom-anchored live viewport on the terminal.

`geometry` is the side-effect-free arithmetic behind placing the inline live area
that `internal/viewport` renders. It models a row region (`top`/`height`/`bottom`)
and clamps app-chosen placements into a drawable range, so the viewport never has
to re-validate geometry. Coordinates are 1-based, matching ANSI cursor
addressing. It sits below `internal/viewport` and depends only on
`internal/terminal_size`.

## Responsibilities

- Represent a rectangular block of terminal rows: 1-based start `top`, row count
  `height`, derived `bottom = top + height - 1`.
- Clamp a desired live-area height into `1 ..= size.rows()`.
- Compute the lowest start row (`calculate_max_top`) that still fits the whole
  area on screen, and clamp an app-desired `top` into that range.
- Compute the redraw span (the terminal-row interval a redraw must repaint) as
  the screen-clamped union of the old footprint and new area.
- Boundary: this package is PURE math only — every function is total and
  side-effect free, performs no IO, and emits results already clamped to a
  drawable range. All terminal writes live in `internal/viewport`.

## Public API

Types:

- `Geometry` — a row region; `Geometry::new(top~, height~)`, with accessors
  `top()`, `height()`, and `bottom()` (`top + height - 1`).

Placement functions (all over `@terminal_size.TerminalSize`):

- `clamp_height(size, height) -> Int` — clamp height into `1 ..= size.rows()`.
- `calculate_max_top(size, height) -> Int` — lowest start row that keeps the area
  fully on screen (floored at row 1).
- `clamp_top(size, height, top) -> Int` — clamp a desired `top` into
  `1 ..= calculate_max_top`.
- `calculate_redraw_span(old, new, screen_rows~, old_content_unknown~) -> (Int, Int)`
  — the `[top, bottom]` interval to repaint (union of old/new, clamped to screen;
  extended to the screen bottom when the old content is unknown). `top > bottom`
  means nothing to repaint.

## Layering

Depends only on `internal/terminal_size`. This is an `internal/` package: it is
only importable within `tui/`, not from outside the module.
