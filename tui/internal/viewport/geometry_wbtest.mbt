///|
test "clamp_height clamps into 1..=rows" {
  let size = @layout.TerminalSize::new(rows=10, cols=80)
  inspect(clamp_height(size, 0), content="1")
  inspect(clamp_height(size, 4), content="4")
  inspect(clamp_height(size, 99), content="10")
}

///|
test "calculate_max_top leaves room for height and floors at row 1" {
  let size = @layout.TerminalSize::new(rows=10, cols=80)
  inspect(calculate_max_top(size, 4), content="7")
  inspect(calculate_max_top(size, 10), content="1")
  // Live area taller than the screen still starts at row 1.
  inspect(calculate_max_top(size, 20), content="1")
}

///|
test "clamp_top clamps into 1..=calculate_max_top" {
  let size = @layout.TerminalSize::new(rows=10, cols=80)
  inspect(clamp_top(size, 4, 0), content="1")
  inspect(clamp_top(size, 4, 5), content="5")
  inspect(clamp_top(size, 4, 99), content="7")
  // This is how the live area grows: holding `top` while the taller area still
  // fits, then raising it by just enough once it would overflow the bottom. On a
  // 12-row screen with the area at top 8, a height of 5 still fits (stays 8) but
  // a height of 6 does not (rises to 7).
  let screen = @layout.TerminalSize::new(rows=12, cols=80)
  inspect(clamp_top(screen, 5, 8), content="8")
  inspect(clamp_top(screen, 6, 8), content="7")
}

///|
fn span_str(span : (Int, Int)) -> String {
  "\{span.0}..\{span.1}"
}

///|
test "calculate_enter_span repaints just the new area, clamped" {
  inspect(
    span_str(calculate_enter_span({ top: 3, height: 4 }, screen_rows=12)),
    content="3..6",
  )
  // Clamped to the screen bottom.
  inspect(
    span_str(calculate_enter_span({ top: 10, height: 5 }, screen_rows=12)),
    content="10..12",
  )
}

///|
test "calculate_redraw_span unions the old and new live-area footprints" {
  // Same placement: repaint just that region.
  inspect(
    span_str(
      calculate_redraw_span(
        { top: 8, height: 3 },
        { top: 8, height: 3 },
        screen_rows=12,
        old_content_unknown=false,
      ),
    ),
    content="8..10",
  )
  // Shrinking: still cover the row the live area vacated at the bottom.
  inspect(
    span_str(
      calculate_redraw_span(
        { top: 8, height: 3 },
        { top: 8, height: 2 },
        screen_rows=12,
        old_content_unknown=false,
      ),
    ),
    content="8..10",
  )
  // Live area moved down (e.g. after insert): repaint from the old top so the
  // rows it left behind are cleared.
  inspect(
    span_str(
      calculate_redraw_span(
        { top: 6, height: 3 },
        { top: 8, height: 3 },
        screen_rows=12,
        old_content_unknown=false,
      ),
    ),
    content="6..10",
  )
  // Dropped old content: extend to the screen bottom to clear stale rows.
  inspect(
    span_str(
      calculate_redraw_span(
        { top: 8, height: 3 },
        { top: 2, height: 4 },
        screen_rows=12,
        old_content_unknown=true,
      ),
    ),
    content="2..12",
  )
}
