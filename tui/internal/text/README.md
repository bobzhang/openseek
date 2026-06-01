# bobzhang/openseek/tui/internal/text

> Unicode-aware string helpers shared across the TUI.

`text` is a small set of pure helper functions for measuring and slicing strings
the way a terminal sees them: display width (East-Asian width aware), truncation
to a column budget, splitting on newlines, safe indexed line access, and
grapheme counting and slicing. It is a leaf utility used by higher TUI layers
that build and lay out rendered text.

## Responsibilities

- Measure display width in terminal cells, accounting for wide characters.
- Truncate a string to a column budget with an ellipsis, breaking on grapheme
  boundaries.
- Split text into lines on `\n` and access a line by index safely.
- Count and slice text by grapheme cluster, with clamped (non-erroring) bounds.
- Boundary: pure string computation only — no IO, no styling, no layout state.

## Public API

- `display_width(text) -> Int` — width in terminal cells (East-Asian aware).
- `truncate_line(text, cols) -> String` — fit to `cols` cells, append `…` when truncated.
- `split_lines(text) -> Array[String]` — split on `\n`; always at least one element.
- `line_at(lines, index) -> String` — line at `index`, or `""` when out of range.
- `grapheme_count(text) -> Int` — number of grapheme clusters.
- `grapheme_slice(text, start, end) -> String` — slice `[start, end)` by grapheme, bounds clamped.

## Layering

Depends on `grapheme` and `unicodewidth`. This is an `internal/` package: it is
only importable within `tui/`, not by code outside it.
