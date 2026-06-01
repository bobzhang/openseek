///|
test "doc layout wraps styled text by display width" {
  inspect(
    @doc.Doc::plain("abcdef").layout(width=3).map(line => line.text()).join("|"),
    content="abc|def",
  )
  inspect(
    @doc.Doc::plain("你好世界")
    .layout(width=4)
    .map(line => line.text())
    .join("|"),
    content="你好|世界",
  )
}

///|
test "wrap expands tabs to the next stop and drops other control chars" {
  // `\t` expands to spaces up to the next 8-column tab stop so following text
  // is not shoved to a terminal tab stop we never accounted for.
  inspect(
    @doc.Text::plain("a\tb").wrap(width=40).map(line => line.text()).join("|"),
    content="a       b",
  )
  inspect(
    @doc.Text::plain("abcdef\tg")
    .wrap(width=40)
    .map(line => line.text())
    .join("|"),
    content="abcdef  g",
  )
  // `\r` and other C0 controls are dropped entirely (a raw `\r` would return
  // the cursor to column 1 and overwrite the line).
  inspect(
    @doc.Text::plain("x\ry").wrap(width=40).map(line => line.text()).join("|"),
    content="xy",
  )
}

///|
test "doc constructors copy mutable arrays" {
  let spans = [@doc.Span::plain("a")]
  let text = @doc.Text::Text(spans)
  spans.push(@doc.Span::plain("b"))
  inspect(text.wrap(width=20).map(line => line.text()).join("|"), content="a")
  let texts = [@doc.Text::plain("a")]
  let doc = @doc.Doc::Doc(texts)
  texts.push(@doc.Text::plain("b"))
  inspect(doc.layout(width=20).map(line => line.text()).join("|"), content="a")
}
