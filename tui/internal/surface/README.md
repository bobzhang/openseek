# bobzhang/openseek/tui/internal/surface

> The passive, terminal-agnostic render-data vocabulary for one frame.

`surface` defines the opaque value types that describe *what* to draw, without
performing any IO. Styled `Span`s form a `Line`; lines plus a `Cursor` form a
`Surface`, which is one rendered frame. The `doc` and `render` layers build
surfaces from semantic state; the `viewport` engine consumes them to paint a
real terminal. It sits below the terminal renderer in the TUI layering.

## Responsibilities

- Provide immutable `Style`, `Span`, `Line`, `Cursor`, and `Surface` value types
  describing a frame.
- Normalize invariants at construction time: `Surface::new` forces `width >= 1`
  and clamps the cursor inside the rows and width, so the renderer never has to
  re-validate.
- Offer simple accessors and frame-shaping helpers (`Surface::with_max_rows`,
  `Surface::line_at`) for fitting a frame into a bounded region.
- Boundary: it performs no IO and knows nothing about a specific terminal — it
  is pure render data; placement and drawing belong to `viewport`.

## Public API

Types (all opaque value types):

- `Style` — terminal styling (foreground, background, underline).
- `Span` — a string fragment with a style.
- `Line` — one row: a sequence of styled spans.
- `Cursor` — a 0-based (row, col) cell offset.
- `Surface` — render output for one viewport frame.

Constructors:

- `Style::new(foreground?, background?, underline?)` — build a style; defaults to unstyled.
- `Span::new(text, style?)` — span from text and an optional style.
- `Line::new(spans)` — line from its styled spans.
- `Cursor::new(row~, col~)` — cursor at a 0-based offset.
- `Surface::new(width~, rows~, cursor~)` — frame; normalizes width and cursor.

Accessors / helpers:

- `Style::foreground`, `Style::background`, `Style::underline`.
- `Span::text`, `Span::style`.
- `Line::spans`, `Line::text` — spans, and text with styling stripped.
- `Cursor::row`, `Cursor::col`.
- `Surface::height`, `Surface::cursor`.
- `Surface::line_at(row)` — line at `row`, or an empty line when out of range.
- `Surface::with_max_rows(max_rows)` — first `max_rows` rows as a new surface.

## Layering

Depends on `moonbit-community/tty/color`. This is an `internal/` package: it is
only importable within `tui/`, not by code outside it.
