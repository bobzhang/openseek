///|
struct Renderer {
  mut previous : Buffer?
}

///|
pub fn Renderer::new() -> Renderer {
  { previous: None }
}

///|
pub fn Renderer::reset(self : Renderer) -> Unit {
  self.previous = None
}

///|
async fn Style::apply(self : Style, tty : @tty.Tty) -> Unit {
  if self.foreground != Default {
    tty.set_foreground(self.foreground)
  }
  if self.background != Default {
    tty.set_background(self.background)
  }
  if self.underline {
    tty.underline()
  }
}

///|
async fn write_styled(tty : @tty.Tty, text : String, style : Style) -> Unit {
  style.apply(tty)
  tty.write(text)
  tty.reset_style()
}

///|
async fn write_buffer_row(tty : @tty.Tty, buffer : Buffer, row : Int) -> Unit {
  tty.set_cursor_position(row + 1, 1)
  let mut pending = StringBuilder()
  let mut pending_style = Style::default()
  let mut has_pending = false
  for col in 0..<buffer.cols {
    let cell = buffer.cell(row, col)
    if cell.width == 0 {
      continue
    }
    if has_pending && cell.style != pending_style {
      write_styled(tty, pending.to_string(), pending_style)
      pending = StringBuilder()
      has_pending = false
    }
    if !has_pending {
      pending_style = cell.style
      has_pending = true
    }
    if cell.text == "" {
      pending.write_char(' ')
    } else {
      pending.write_string(cell.text)
    }
  }
  if has_pending {
    write_styled(tty, pending.to_string(), pending_style)
  }
}

///|
pub async fn Renderer::draw(
  self : Renderer,
  tty : @tty.Tty,
  next : Buffer,
) -> Unit {
  let previous = self.previous
  let mut changed = false
  tty.hide_cursor()
  match previous {
    Some(previous) if previous.same_size(next) =>
      for row in 0..<next.rows {
        if !previous.same_row(next, row) {
          write_buffer_row(tty, next, row)
          changed = true
        }
      }
    _ =>
      for row in 0..<next.rows {
        write_buffer_row(tty, next, row)
        changed = true
      }
  }
  tty.show_cursor()
  let cursor = next.cursor()
  if changed || previous.map(old => old.cursor() != cursor).unwrap_or(true) {
    tty.set_cursor_position(cursor.row + 1, cursor.col + 1)
  }
  self.previous = Some(next)
}
