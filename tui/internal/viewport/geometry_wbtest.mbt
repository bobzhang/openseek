///|
test "normalized_height clamps into 1..=rows" {
  let size = @layout.TerminalSize::new(rows=10, cols=80)
  inspect(normalized_height(size, 0), content="1")
  inspect(normalized_height(size, 4), content="4")
  inspect(normalized_height(size, 99), content="10")
}

///|
test "max_top_for leaves room for height and floors at row 1" {
  let size = @layout.TerminalSize::new(rows=10, cols=80)
  inspect(max_top_for(size, 4), content="7")
  inspect(max_top_for(size, 10), content="1")
  // Live area taller than the screen still starts at row 1.
  inspect(max_top_for(size, 20), content="1")
}

///|
test "normalized_top clamps into 1..=max_top_for" {
  let size = @layout.TerminalSize::new(rows=10, cols=80)
  inspect(normalized_top(size, 4, 0), content="1")
  inspect(normalized_top(size, 4, 5), content="5")
  inspect(normalized_top(size, 4, 99), content="7")
  // This is how the live area grows: holding `top` while the taller area still
  // fits, then raising it by just enough once it would overflow the bottom. On a
  // 12-row screen with the area at top 8, a height of 5 still fits (stays 8) but
  // a height of 6 does not (rises to 7).
  let screen = @layout.TerminalSize::new(rows=12, cols=80)
  inspect(normalized_top(screen, 5, 8), content="8")
  inspect(normalized_top(screen, 6, 8), content="7")
}

///|
fn span_str(span : (Int, Int)) -> String {
  "\{span.0}..\{span.1}"
}

///|
test "redraw_span unions the old and new live-area footprints" {
  // Same placement: repaint just that region.
  inspect(
    span_str(
      redraw_span(
        Some({ top: 8, height: 3 }),
        new_top=8,
        new_height=3,
        screen_rows=12,
        old_content_unknown=false,
      ),
    ),
    content="8..10",
  )
  // Shrinking: still cover the row the live area vacated at the bottom.
  inspect(
    span_str(
      redraw_span(
        Some({ top: 8, height: 3 }),
        new_top=8,
        new_height=2,
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
      redraw_span(
        Some({ top: 6, height: 3 }),
        new_top=8,
        new_height=3,
        screen_rows=12,
        old_content_unknown=false,
      ),
    ),
    content="6..10",
  )
  // First placement (no old region): repaint just the new area.
  inspect(
    span_str(
      redraw_span(
        None,
        new_top=3,
        new_height=4,
        screen_rows=12,
        old_content_unknown=false,
      ),
    ),
    content="3..6",
  )
  // Dropped old content: extend to the screen bottom to clear stale rows.
  inspect(
    span_str(
      redraw_span(
        Some({ top: 8, height: 3 }),
        new_top=2,
        new_height=4,
        screen_rows=12,
        old_content_unknown=true,
      ),
    ),
    content="2..12",
  )
}
