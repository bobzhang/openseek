# bobzhang/openseek/tui/internal/terminal_size

> An opaque, always-positive terminal dimension.

`terminal_size` holds one small opaque type, `TerminalSize`, carrying the
on-screen rows and columns. Its constructor normalizes any non-positive
dimension a terminal may report (for example a zero size queried before the
first `ioctl`) to sane defaults (24×80), so consumers can treat `rows`/`cols`
as always `>= 1` without re-validating. It is a leaf data type used throughout
the TUI wherever a terminal size is passed around.

## Responsibilities

- Carry the on-screen terminal dimensions as a single opaque value.
- Normalize non-positive dimensions to the 24×80 defaults at construction.
- Provide a default size for use before a real size is known.
- Boundary: pure data only; it queries no terminal and performs no IO.

## Public API

Types

- `TerminalSize` — opaque on-screen dimensions, guaranteed positive.

Functions

- `TerminalSize::new(rows~ : Int, cols~ : Int) -> Self` — build a size,
  replacing any non-positive dimension with its default.
- `TerminalSize::default() -> Self` — the fallback 24×80 size.
- `TerminalSize::rows(Self) -> Int` — number of on-screen rows.
- `TerminalSize::cols(Self) -> Int` — number of on-screen columns.

## Layering

No dependencies. This is an `internal/` package: it is only importable within
`tui/`.
