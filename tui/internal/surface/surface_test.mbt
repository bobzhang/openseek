///|
test "surface cursor is normalized when stored" {
  let rows = [Line::new([]), Line::new([])]
  let surface = Surface::new(width=4, rows~, cursor=Cursor::new(row=9, col=9))
  inspect(surface.cursor().row(), content="1")
  inspect(surface.cursor().col(), content="3")
}

///|
test "with_max_rows keeps the leading rows" {
  let rows = [
    Line::new([Span::new("a")]),
    Line::new([Span::new("b")]),
    Line::new([Span::new("c")]),
  ]
  let surface = Surface::new(width=10, rows~, cursor=Cursor::new(row=0, col=0))
  let capped = surface.with_max_rows(2)
  inspect(capped.height(), content="2")
  inspect(capped.line_at(0).text(), content="a")
  inspect(capped.line_at(1).text(), content="b")
  // A bound at or above the row count is a no-op.
  inspect(surface.with_max_rows(9).height(), content="3")
}

///|
test "line equality includes span text and style" {
  let green = Style::new(foreground=Basic(BrightGreen))
  let red = Style::new(foreground=Basic(BrightRed))
  let left = Line::new([Span::new("x", style=green)])
  let same = Line::new([Span::new("x", style=green)])
  let different_text = Line::new([Span::new("y", style=green)])
  let different_style = Line::new([Span::new("x", style=red)])
  assert_true(left == same)
  assert_false(left == different_text)
  assert_false(left == different_style)
  // Optional lines compare through the derived equality too.
  assert_true((Some(left) : Line?) == Some(same))
  assert_false((Some(left) : Line?) == None)
}
