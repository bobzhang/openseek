///|
struct Style {
  foreground : @color.Color
  background : @color.Color
  underline : Bool
} derive(Eq, Debug)

///|
struct Span {
  text : String
  style : Style
}

///|
struct Line {
  spans : Array[Span]
}

///|
struct Cursor {
  row : Int
  col : Int
} derive(Eq, Debug)

///|
struct Surface {
  width : Int
  rows : Array[Line]
  cursor : Cursor
}

///|
fn normalize_index(value : Int, max_value : Int) -> Int {
  @clamp.int(value, min=0, max=max_value)
}

///|
fn normalize_width(width : Int) -> Int {
  if width < 1 {
    1
  } else {
    width
  }
}

///|
fn normalize_cursor(rows : Array[Line], width : Int, cursor : Cursor) -> Cursor {
  let max_row = if rows.length() == 0 { 0 } else { rows.length() - 1 }
  let max_col = if width <= 1 { 0 } else { width - 1 }
  {
    row: normalize_index(cursor.row, max_row),
    col: normalize_index(cursor.col, max_col),
  }
}

///|
pub fn Style::default() -> Style {
  { foreground: Default, background: Default, underline: false }
}

///|
pub fn Style::new(
  foreground? : @color.Color = Default,
  background? : @color.Color = Default,
  underline? : Bool = false,
) -> Style {
  { foreground, background, underline }
}

///|
pub fn Span::new(text : String, style? : Style = Style::default()) -> Span {
  { text, style }
}

///|
pub fn Line::new(spans : Array[Span]) -> Line {
  { spans, }
}

///|
pub fn Line::text(self : Line) -> String {
  let builder = StringBuilder()
  for span in self.spans {
    builder.write_string(span.text)
  }
  builder.to_string()
}

///|
pub fn Cursor::new(row~ : Int, col~ : Int) -> Cursor {
  { row, col }
}

///|
pub fn Cursor::row(self : Cursor) -> Int {
  self.row
}

///|
pub fn Cursor::col(self : Cursor) -> Int {
  self.col
}

///|
pub fn Surface::new(
  width~ : Int,
  rows~ : Array[Line],
  cursor~ : Cursor,
) -> Surface {
  let width = normalize_width(width)
  let cursor = normalize_cursor(rows, width, cursor)
  { width, rows, cursor }
}

///|
pub fn Surface::width(self : Surface) -> Int {
  self.width
}

///|
pub fn Surface::height(self : Surface) -> Int {
  self.rows.length()
}

///|
pub fn Surface::cursor(self : Surface) -> Cursor {
  self.cursor
}

///|
pub fn Surface::with_max_rows(self : Surface, max_rows : Int) -> Surface {
  let row_count = if max_rows < 0 {
    0
  } else if max_rows > self.rows.length() {
    self.rows.length()
  } else {
    max_rows
  }
  let rows : Array[Line] = []
  for index in 0..<row_count {
    rows.push(self.rows[index])
  }
  Surface::new(width=self.width, rows~, cursor=self.cursor)
}

///|
pub fn Surface::line_at(self : Surface, row : Int) -> Line {
  if self.rows.get(row) is Some(line) {
    line
  } else {
    Line::new([])
  }
}
