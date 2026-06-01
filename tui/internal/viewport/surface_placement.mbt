// Mapping a `@surface.Surface` onto physical terminal rows. These helpers pair
// surface content with the live area's `top`/`height`, so they belong to the
// renderer rather than the terminal-agnostic surface vocabulary.

///|
/// The surface line shown at terminal row `row`, given a live area that starts
/// at `top` and spans `height` rows. `None` when the row falls outside the live
/// band or past the surface's own rows.
fn line_at_terminal_row(
  surface : @surface.Surface,
  row~ : Int,
  top~ : Int,
  height~ : Int,
) -> @surface.Line? {
  let index = row - top
  if index >= 0 && index < height && index < surface.height() {
    Some(surface.line_at(index))
  } else {
    None
  }
}

///|
/// Whether two surfaces place the cursor on the same physical cell, accounting
/// for each surface's live-area `top`.
fn same_terminal_cursor(
  surface : @surface.Surface,
  other : @surface.Surface,
  top~ : Int,
  other_top~ : Int,
) -> Bool {
  top + surface.cursor().row() == other_top + other.cursor().row() &&
  surface.cursor().col() == other.cursor().col()
}
