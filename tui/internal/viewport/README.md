# bobzhang/openseek/tui/internal/viewport

> Inline DECSTBM rendering engine: native scrollback for committed output, a bottom-anchored live area redrawn in place.

`viewport` drives a real `@tty.Tty` to render a readline-style inline UI. The
committed transcript lives in the terminal's NATIVE scrollback, while a
bottom-anchored live area (composer/status/activity) is redrawn in place with
row-level diffing. It sits above the pure `internal/geometry` placement math and
below the higher-level TUI loop, translating semantic `@surface` frames into the
DECSTBM scroll-region tricks that keep committed rows in scrollback.

## Responsibilities

- Place a live area at the cursor row on first draw (`enter`), anchoring it so
  committed output above stays put.
- Redraw the live area in place over its previous frame using row-level diffing,
  repainting only changed rows.
- Scroll committed rows into native scrollback (via DECSTBM margins,
  `reverse_index`, and newlines) when the live area grows or when transcript rows
  are inserted above it.
- Rebuild the screen from semantic transcript rows on resize (clear screen +
  scrollback, redraw), since a resize can reflow the terminal's row cache.
- Manage autowrap (disabled while drawing full-width rows, restored after) and
  always restore margins/style/autowrap/cursor on teardown.
- Boundary: this is the IO layer. All row arithmetic and clamping is delegated to
  `internal/geometry`, which is pure; `viewport` performs the actual terminal
  writes and cursor queries.

## Public API

Types:

- `Viewport` — the rendering engine; holds terminal size, the live area's
  `@geometry.Geometry?` placement (`None` until first placed), and a frame cache
  for diffing/clearing.

Lifecycle and size:

- `Viewport::new() -> Self` — create with default size and no placed area.
- `Viewport::cols(Self) -> Int` — current terminal width in columns.
- `Viewport::refresh_size(Self, @tty.Tty)` — re-query window size and re-clamp;
  falls back to defaults if the size can't be read.
- `Viewport::enter(Self, @tty.Tty, @surface.Surface, timeout_ms~)` — draw the
  live area for the first time, anchored at the queried cursor row.
- `Viewport::leave(Self, @tty.Tty)` — restore margins/style/autowrap/cursor and
  drop the live area.

Drawing:

- `Viewport::redraw(Self, @tty.Tty, @surface.Surface)` — redraw in place over the
  previous frame, holding `top`; a no-op before `enter`.
- `Viewport::insert_before(Self, @tty.Tty, Array[@surface.Line])` — commit
  transcript rows above the live area, scrolling earlier rows into scrollback.
- `Viewport::replay_with_rows_before(Self, @tty.Tty, Array[@surface.Line], @surface.Surface)`
  — rebuild the DECSTBM screen after a resize from semantic transcript rows.

## Layering

Depends on `internal/geometry` (placement math), `internal/terminal_size`,
`internal/surface` (semantic frames), and `moonbit-community/tty` (terminal IO).
This is an `internal/` package: it is only importable within `tui/`, not from
outside the module.
