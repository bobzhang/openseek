///|
struct Style {
  foreground : @color.Color
  background : @color.Color
  underline : Bool
} derive(Eq)

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
}

///|
fn normalize_surface_width(width : Int) -> Int {
  if width < 1 {
    1
  } else {
    width
  }
}

///|
fn normalize_surface_index(value : Int, max_value : Int) -> Int {
  @clamp.int(value, min=0, max=max_value)
}

///|
fn normalize_surface_cursor(
  rows : Array[Line],
  width : Int,
  cursor : Cursor,
) -> Cursor {
  let max_row = if rows.length() == 0 { 0 } else { rows.length() - 1 }
  let max_col = if width <= 1 { 0 } else { width - 1 }
  {
    row: normalize_surface_index(cursor.row, max_row),
    col: normalize_surface_index(cursor.col, max_col),
  }
}

///|
/// Render output for one viewport frame.
///
/// `Ui` builds a fresh `Surface` from semantic state such as composer text,
/// status text, and terminal width, then passes it to `Viewport` for placement
/// and terminal drawing. `Viewport` does not build surfaces because it should
/// not own composer/status state, but it does cache the last drawn surface so
/// redraws can diff physical terminal rows and skip unchanged content.
///
/// A `Surface` always has a cursor. `Ui` produces one for the interactive
/// composer, and `Viewport` places that surface on the terminal.
///
/// Invariant: `width >= 1`, `cursor.row` is inside `rows` when any row exists,
/// and `cursor.col` is inside `width`. Construction normalizes these values so
/// terminal drawing does not need to defensively adjust them again.
struct Surface {
  width : Int
  rows : Array[Line]
  cursor : Cursor
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
fn Span::same_as(self : Span, other : Span) -> Bool {
  self.text == other.text && self.style == other.style
}

///|
fn Line::same_as(self : Line, other : Line) -> Bool {
  if self.spans.length() != other.spans.length() {
    return false
  }
  for index, span in self.spans {
    if other.spans.get(index) is Some(other_span) {
      if !span.same_as(other_span) {
        return false
      }
    } else {
      return false
    }
  }
  true
}

///|
fn Line::same_optional(left : Line?, right : Line?) -> Bool {
  if left is Some(left) {
    if right is Some(right) {
      left.same_as(right)
    } else {
      false
    }
  } else {
    right is None
  }
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
  let width = normalize_surface_width(width)
  let cursor = normalize_surface_cursor(rows, width, cursor)
  { width, rows, cursor }
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
fn Surface::with_max_rows(self : Surface, max_rows : Int) -> Surface {
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

///|
fn Surface::line_at_terminal_row(
  self : Surface,
  row~ : Int,
  top~ : Int,
  height~ : Int,
) -> Line? {
  let index = row - top
  if index >= 0 && index < height {
    self.rows.get(index)
  } else {
    None
  }
}

///|
fn Surface::same_terminal_cursor(
  self : Surface,
  other : Surface,
  top~ : Int,
  other_top~ : Int,
) -> Bool {
  top + self.cursor.row == other_top + other.cursor.row &&
  self.cursor.col == other.cursor.col
}
