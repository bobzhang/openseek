///|
test "viewport starts undrawn and normalizes stored geometry" {
  let viewport = Viewport::new(height=20)
  viewport.set_size({ rows: 8, cols: 80 })
  inspect(viewport.top, content="0")
  inspect(viewport.height, content="0")
  inspect(viewport.cache is Fresh, content="true")
  viewport.set_geometry(top=99, height=4)
  inspect(viewport.max_top(), content="5")
  inspect(viewport.top, content="5")
  inspect(viewport.bottom(), content="8")
}

///|
test "viewport growth uses blank space below before moving upward" {
  let viewport = Viewport::new(height=5)
  viewport.set_size({ rows: 12, cols: 80 })
  viewport.set_geometry(top=8, height=3)
  inspect(viewport.next_top(height=5), content="8")
  inspect(viewport.next_top(height=6), content="7")
}

///|
test "viewport remembers stale frame footprint after resize invalidates frame" {
  let viewport = Viewport::new(height=4)
  viewport.set_size({ rows: 10, cols: 80 })
  viewport.set_geometry(top=6, height=4)
  viewport.cache = Drawn(
    Surface::new(
      width=80,
      rows=[
        Line::new([]),
        Line::new([]),
        Line::new([]),
        Line::new([]),
        Line::new([]),
      ],
      cursor={ row: 1, col: 0 },
    ),
  )
  viewport.set_size({ rows: 8, cols: 40 })
  let (stale_top, stale_height) = match viewport.cache {
    Stale(top~, height~) => (top, height)
    _ => (-1, -1)
  }
  inspect(stale_top, content="6")
  inspect(stale_height, content="5")
  inspect(viewport.top, content="5")
  inspect(viewport.cache.surface() is None, content="true")
}

///|
test "surface cursor is normalized when stored" {
  let rows = [Line::new([]), Line::new([])]
  let surface = Surface::new(width=4, rows~, cursor={ row: 9, col: 9 })
  inspect(surface.cursor.row, content="1")
  inspect(surface.cursor.col, content="3")
}

///|
test "surface terminal cursor comparison includes viewport top" {
  let rows = [Line::new([]), Line::new([])]
  let left = Surface::new(width=10, rows~, cursor={ row: 1, col: 3 })
  let same = Surface::new(width=10, rows~, cursor={ row: 0, col: 3 })
  let moved_row = Surface::new(width=10, rows~, cursor={ row: 1, col: 3 })
  let moved_col = Surface::new(width=10, rows~, cursor={ row: 0, col: 4 })
  inspect(left.same_terminal_cursor(same, top=4, other_top=5), content="true")
  inspect(
    left.same_terminal_cursor(moved_row, top=4, other_top=5),
    content="false",
  )
  inspect(
    left.same_terminal_cursor(moved_col, top=4, other_top=5),
    content="false",
  )
}

///|
test "line comparison includes span styles" {
  let green = Style::new(foreground=Basic(BrightGreen))
  let red = Style::new(foreground=Basic(BrightRed))
  let left = Line::new([Span::new("x", style=green)])
  let same = Line::new([Span::new("x", style=green)])
  let different_text = Line::new([Span::new("y", style=green)])
  let different_style = Line::new([Span::new("x", style=red)])
  inspect(Line::same_optional(Some(left), Some(same)), content="true")
  inspect(
    Line::same_optional(Some(left), Some(different_text)),
    content="false",
  )
  inspect(
    Line::same_optional(Some(left), Some(different_style)),
    content="false",
  )
  inspect(Line::same_optional(None, None), content="true")
  inspect(Line::same_optional(Some(left), None), content="false")
}
