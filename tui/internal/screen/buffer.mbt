///|
struct Cell {
  text : String
  width : Int
  style : Style
} derive(Eq)

///|
struct Buffer {
  rows : Int
  cols : Int
  cells : Array[Cell]
  mut cursor : Cursor
}

///|
fn blank_cell() -> Cell {
  { text: "", width: 1, style: Style::default() }
}

///|
pub fn Buffer::new(rows~ : Int, cols~ : Int) -> Buffer {
  let rows = if rows < 1 { 1 } else { rows }
  let cols = if cols < 1 { 1 } else { cols }
  let cells : Array[Cell] = []
  for _ in 0..<(rows * cols) {
    cells.push(blank_cell())
  }
  { rows, cols, cells, cursor: Cursor::new(row=0, col=0) }
}

///|
pub fn Buffer::rows(self : Buffer) -> Int {
  self.rows
}

///|
pub fn Buffer::cols(self : Buffer) -> Int {
  self.cols
}

///|
pub fn Buffer::cursor(self : Buffer) -> Cursor {
  self.cursor
}

///|
fn Buffer::index(self : Buffer, row : Int, col : Int) -> Int {
  row * self.cols + col
}

///|
fn Buffer::cell(self : Buffer, row : Int, col : Int) -> Cell {
  self.cells[self.index(row, col)]
}

///|
fn Buffer::set_cell(self : Buffer, row : Int, col : Int, cell : Cell) -> Unit {
  self.cells[self.index(row, col)] = cell
}

///|
pub fn Buffer::set_cursor(self : Buffer, row~ : Int, col~ : Int) -> Unit {
  self.cursor = {
    row: row.clamp(min=0, max=self.rows - 1),
    col: col.clamp(min=0, max=self.cols - 1),
  }
}

///|
pub fn Buffer::write_text(
  self : Buffer,
  rect : Rect,
  row~ : Int,
  col~ : Int,
  text~ : String,
  style? : Style = Style::default(),
) -> Unit {
  let target_row = rect.y + row
  guard target_row >= rect.y && target_row < rect.bottom() else { return }
  let mut target_col = rect.x + col
  let end_col = rect.right()
  for grapheme in @grapheme.grapheme_iter(text) {
    let fragment = grapheme.to_owned()
    let width = @unicodewidth.str_width(fragment)
    let width = if width < 1 { 1 } else { width }
    guard target_col + width <= end_col && target_col + width <= self.cols else {
      return
    }
    if target_col >= 0 && target_row >= 0 && target_row < self.rows {
      self.set_cell(target_row, target_col, { text: fragment, width, style })
      if width > 1 {
        for offset in 1..<width {
          self.set_cell(target_row, target_col + offset, {
            text: "",
            width: 0,
            style,
          })
        }
      }
    }
    target_col += width
  }
}

///|
pub fn Buffer::write_line(
  self : Buffer,
  rect : Rect,
  row~ : Int,
  line : Line,
) -> Unit {
  let mut col = 0
  for span in line.spans {
    self.write_text(rect, row~, col~, text=span.text, style=span.style)
    col += @unicodewidth.str_width(span.text)
  }
}

///|
pub fn Buffer::row_text(self : Buffer, row : Int) -> String {
  let builder = StringBuilder()
  guard row >= 0 && row < self.rows else { return "" }
  for col in 0..<self.cols {
    let cell = self.cell(row, col)
    if cell.width > 0 {
      if cell.text == "" {
        builder.write_char(' ')
      } else {
        builder.write_string(cell.text)
      }
    }
  }
  builder.to_string()
}

///|
fn Buffer::same_size(self : Buffer, other : Buffer) -> Bool {
  self.rows == other.rows && self.cols == other.cols
}

///|
fn Buffer::same_row(self : Buffer, other : Buffer, row : Int) -> Bool {
  guard self.same_size(other) && row >= 0 && row < self.rows else {
    return false
  }
  for col in 0..<self.cols {
    if self.cell(row, col) != other.cell(row, col) {
      return false
    }
  }
  true
}
