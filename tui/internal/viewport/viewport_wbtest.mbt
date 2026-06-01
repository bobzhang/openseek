///|
test "viewport starts undrawn and normalizes stored geometry" {
  let viewport = Viewport::new(height=20)
  viewport.set_size(@layout.TerminalSize::new(rows=8, cols=80))
  inspect(viewport.top(), content="0")
  inspect(viewport.height(), content="0")
  inspect(viewport.cache is Fresh, content="true")
  viewport.set_geometry(top=99, height=4)
  inspect(viewport.top(), content="5")
  inspect(viewport.bottom(), content="8")
}

///|
test "viewport growth uses blank space below before moving upward" {
  let viewport = Viewport::new(height=5)
  viewport.set_size(@layout.TerminalSize::new(rows=12, cols=80))
  viewport.set_geometry(top=8, height=3)
  inspect(viewport.next_top(height=5), content="8")
  inspect(viewport.next_top(height=6), content="7")
}

///|
test "viewport remembers stale frame footprint after resize invalidates frame" {
  let viewport = Viewport::new(height=4)
  viewport.set_size(@layout.TerminalSize::new(rows=10, cols=80))
  viewport.set_geometry(top=6, height=4)
  viewport.cache = Drawn(
    @surface.Surface::new(
      width=80,
      rows=[
        @surface.Line::new([]),
        @surface.Line::new([]),
        @surface.Line::new([]),
        @surface.Line::new([]),
        @surface.Line::new([]),
      ],
      cursor=@surface.Cursor::new(row=1, col=0),
    ),
  )
  viewport.set_size(@layout.TerminalSize::new(rows=8, cols=40))
  let (stale_top, stale_height) = match viewport.cache {
    Stale(top~, height~) => (top, height)
    _ => (-1, -1)
  }
  inspect(stale_top, content="6")
  inspect(stale_height, content="5")
  inspect(viewport.top(), content="5")
  inspect(viewport.cache.surface() is None, content="true")
}

///|
test "terminal cursor comparison includes viewport top" {
  let rows = [@surface.Line::new([]), @surface.Line::new([])]
  let left = @surface.Surface::new(
    width=10,
    rows~,
    cursor=@surface.Cursor::new(row=1, col=3),
  )
  let same = @surface.Surface::new(
    width=10,
    rows~,
    cursor=@surface.Cursor::new(row=0, col=3),
  )
  let moved_row = @surface.Surface::new(
    width=10,
    rows~,
    cursor=@surface.Cursor::new(row=1, col=3),
  )
  let moved_col = @surface.Surface::new(
    width=10,
    rows~,
    cursor=@surface.Cursor::new(row=0, col=4),
  )
  inspect(same_terminal_cursor(left, same, top=4, other_top=5), content="true")
  inspect(
    same_terminal_cursor(left, moved_row, top=4, other_top=5),
    content="false",
  )
  inspect(
    same_terminal_cursor(left, moved_col, top=4, other_top=5),
    content="false",
  )
}
