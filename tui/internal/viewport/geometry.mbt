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
//   size.rows()        last on-screen row
//
// `top` is the terminal row where the live area starts, `height` how many rows
// it occupies, and `bottom = top + height - 1`. The live area must fit on
// screen, so `top` is clamped to `max_top_for` — the lowest start row that
// still leaves `height` rows above `size.rows()`.
//
// Every function here is total and side-effect free: results are clamped into a
// drawable range so the rest of `viewport.mbt` never has to re-validate
// geometry. They take an already-normalized `@layout.TerminalSize`, so screen
// dimensions are always positive; only the app-chosen `top`/`height` are clamped
// here.

///|
/// Clamp a desired live-area height into `1 ..= size.rows()`.
fn normalized_height(size : @layout.TerminalSize, height : Int) -> Int {
  height.clamp(min=1, max=size.rows())
}

///|
/// The lowest the live area's `top` may sit and still fit entirely on screen,
/// floored at row 1 when the live area is taller than the screen.
///
/// This is just `bottom <= size.rows()` solved for `top`. The live area spans
/// `top ..= top + height - 1`, so requiring its last row to land on or above the
/// last physical row gives:
///
///   top + height - 1 <= size.rows()   ⟺   top <= size.rows() - height + 1
///
/// Clamping `top` to this bound therefore guarantees the whole `height`-row
/// block is visible — e.g. `rows=24, height=7` gives `18`, and `bottom = 18 + 7
/// - 1 = 24` sits exactly on the screen bottom. `height` is pre-clamped to
/// `<= rows` by `normalized_height`, so the bound is always `>= 1` and the clamp
/// range stays non-empty.
fn max_top_for(size : @layout.TerminalSize, height : Int) -> Int {
  let top = size.rows() - height + 1
  if top < 1 {
    1
  } else {
    top
  }
}

///|
/// Clamp an app-desired `top` into `1 ..= max_top_for(size, height)`.
///
/// The desired `top` comes from outside terminal geometry — the queried cursor
/// row on the first draw, or the previous frame's `top` afterwards — so it can
/// sit too low to fit the live area below it; clamping raises it just enough.
fn normalized_top(size : @layout.TerminalSize, height : Int, top : Int) -> Int {
  top.clamp(min=1, max=max_top_for(size, height))
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
  old : Geometry?,
  new_top~ : Int,
  new_height~ : Int,
  screen_rows~ : Int,
  old_content_unknown~ : Bool,
) -> (Int, Int) {
  let old_bottom = match old {
    Some(g) => g.bottom()
    None => new_top - 1
  }
  let new_bottom = if new_height > 0 {
    new_top + new_height - 1
  } else {
    new_top - 1
  }
  let top = match old {
    Some(g) if g.top < new_top => g.top
    _ => new_top
  }
  let bottom = if old_bottom > new_bottom { old_bottom } else { new_bottom }
  let bottom = if old_content_unknown { screen_rows } else { bottom }
  let top = if top < 1 { 1 } else { top }
  let bottom = if bottom > screen_rows { screen_rows } else { bottom }
  (top, bottom)
}
