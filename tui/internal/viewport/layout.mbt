// Pure geometry for placing the live input viewport on the terminal.
//
// Coordinate model (all rows 1-based, matching ANSI cursor addressing):
//
//   row 1          ─┐
//   ...             │  scrollback: committed transcript, owned by the
//   top - 1         ─┘  terminal's native scroll history (above the live area)
//   top            ─┐
//   ...             │  live area: `height` rows redrawn in place by the app
//   top+height-1   ─┘  (this row is `bottom`)
//   ...                blank rows below the live area, if any
//   size.rows          last on-screen row
//
// `top` is the terminal row where the live area starts, `height` how many rows
// it occupies, and `bottom = top + height - 1`. The live area must fit on
// screen, so `top` is clamped to `max_top_for` — the lowest start row that
// still leaves `height` rows above `size.rows`.
//
// Every function here is total and side-effect free: results are clamped into a
// drawable range so the terminal-facing code in `viewport.mbt` never has to
// re-validate geometry.

///|
const DefaultTerminalRows : Int = 24

///|
const DefaultTerminalCols : Int = 80

///|
priv struct TerminalSize {
  rows : Int
  cols : Int
}

///|
/// Replace non-positive dimensions with defaults so a terminal reporting an
/// unknown (zero) size still yields a drawable grid.
fn normalize_terminal_size(size : TerminalSize) -> TerminalSize {
  {
    rows: if size.rows < 1 {
      DefaultTerminalRows
    } else {
      size.rows
    },
    cols: if size.cols < 1 {
      DefaultTerminalCols
    } else {
      size.cols
    },
  }
}

///|
/// Clamp a desired live-area height into `1 ..= size.rows`.
fn normalized_height(size : TerminalSize, height : Int) -> Int {
  @clamp.int(height, min=1, max=size.rows)
}

///|
/// The lowest `top` that still fits `height` rows on screen
/// (`size.rows - height + 1`), floored at row 1 when the live area is taller
/// than the screen.
fn max_top_for(size : TerminalSize, height : Int) -> Int {
  let top = size.rows - height + 1
  if top < 1 {
    1
  } else {
    top
  }
}

///|
/// Clamp a desired `top` into `1 ..= max_top_for(size, height)`.
fn normalized_top(size : TerminalSize, height : Int, top : Int) -> Int {
  @clamp.int(top, min=1, max=max_top_for(size, height))
}

///|
/// Bottom-most row of a live area at `top` spanning `height` rows, or 0 when the
/// live area has not been drawn yet (`top`/`height` still 0).
fn bottom_of(top~ : Int, height~ : Int) -> Int {
  if top <= 0 || height <= 0 {
    0
  } else {
    top + height - 1
  }
}

///|
/// The terminal-row interval `[top, bottom]` a redraw must repaint.
///
/// It is the union of the new live area and the previous frame's footprint — so
/// rows the live area vacates get cleared, not just the new ones — clamped to
/// the screen. When the previous frame's content was dropped
/// (`old_content_unknown`), the interval extends to the screen bottom to clear
/// any stale rows below it. A result with `top > bottom` means nothing needs
/// repainting.
fn redraw_span(
  old_top~ : Int,
  old_height~ : Int,
  new_top~ : Int,
  new_height~ : Int,
  screen_rows~ : Int,
  old_content_unknown~ : Bool,
) -> (Int, Int) {
  let has_old_region = old_top > 0 && old_height > 0
  let old_bottom = if has_old_region {
    old_top + old_height - 1
  } else {
    new_top - 1
  }
  let new_bottom = if new_height > 0 {
    new_top + new_height - 1
  } else {
    new_top - 1
  }
  let top = if has_old_region && old_top < new_top { old_top } else { new_top }
  let bottom = if old_bottom > new_bottom { old_bottom } else { new_bottom }
  let bottom = if old_content_unknown { screen_rows } else { bottom }
  let top = if top < 1 { 1 } else { top }
  let bottom = if bottom > screen_rows { screen_rows } else { bottom }
  (top, bottom)
}
