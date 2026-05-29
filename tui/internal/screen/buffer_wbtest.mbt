///|
test "buffer writes ascii and wide cells" {
  let buffer = Buffer::new(rows=2, cols=6)
  let rect = Rect::new(x=0, y=0, width=6, height=2)
  buffer.write_text(rect, row=0, col=0, text="a你b")
  inspect(buffer.row_text(0), content="a你b  ")
}

///|
test "buffer clips writes to rect" {
  let buffer = Buffer::new(rows=2, cols=6)
  let rect = Rect::new(x=1, y=0, width=3, height=1)
  buffer.write_text(rect, row=0, col=0, text="abcd")
  inspect(buffer.row_text(0), content=" abc  ")
}

///|
test "buffer row comparison includes styles" {
  let left = Buffer::new(rows=1, cols=3)
  let right = Buffer::new(rows=1, cols=3)
  let rect = Rect::new(x=0, y=0, width=3, height=1)
  left.write_text(rect, row=0, col=0, text="x", style=Style::default())
  right.write_text(
    rect,
    row=0,
    col=0,
    text="x",
    style=Style::new(foreground=Basic(Red)),
  )
  inspect(left.same_row(right, 0), content="false")
}
