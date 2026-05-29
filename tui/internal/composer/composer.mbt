///|
const MinTextRows : Int = 1

///|
pub const DefaultMaxTextRows : Int = 4

///|
fn line_count(text : String) -> Int {
  @text.split_lines(text).length()
}

///|
fn normalize_max_text_rows(max_text_rows : Int) -> Int {
  if max_text_rows < MinTextRows {
    MinTextRows
  } else {
    max_text_rows
  }
}

///|
fn is_newline_grapheme(grapheme : StringView) -> Bool {
  grapheme.to_owned() == "\n"
}

///|
fn line_display_width(lines : Array[String], line : Int) -> Int {
  @text.display_width(@text.line_at(lines, line))
}

///|
fn visible_text_rows_for(text : String, max_text_rows : Int) -> Int {
  let rows = line_count(text)
  let max_text_rows = normalize_max_text_rows(max_text_rows)
  if rows < MinTextRows {
    MinTextRows
  } else if rows > max_text_rows {
    max_text_rows
  } else {
    rows
  }
}

///|
fn max_view_start(text : String, max_text_rows : Int) -> Int {
  let value = line_count(text) - visible_text_rows_for(text, max_text_rows)
  if value < 0 {
    0
  } else {
    value
  }
}

///|
fn clamp_view_start(
  text : String,
  view_start : Int,
  max_text_rows : Int,
) -> Int {
  @clamp.int(view_start, min=0, max=max_view_start(text, max_text_rows))
}

///|
priv struct CursorPoint {
  line : Int
  grapheme_column : Int
  display_column : Int
}

///|
/// Semantic mode for the live composer.
///
/// `Input` is normal agent-steering text. `Shell` changes the first prompt to
/// `! ` and makes the submitted text become a shell command.
enum Mode {
  Input
  Shell
} derive(Eq)

///|
fn Mode::prompt_prefix(self : Mode) -> String {
  match self {
    Input => "> "
    Shell => "! "
  }
}

///|
pub fn Mode::is_input(self : Mode) -> Bool {
  self == Input
}

///|
pub fn Mode::is_shell(self : Mode) -> Bool {
  self == Shell
}

///|
fn cursor_point_for(text : String, cursor : Int) -> CursorPoint {
  let target = @clamp.int(cursor, min=0, max=@text.grapheme_count(text))
  let mut index = 0
  let mut line = 0
  let mut grapheme_column = 0
  let mut display_column = 0
  for grapheme in @grapheme.grapheme_iter(text) {
    if index >= target {
      break
    }
    if is_newline_grapheme(grapheme) {
      line = line + 1
      grapheme_column = 0
      display_column = 0
    } else {
      grapheme_column = grapheme_column + 1
      display_column = display_column + @unicodewidth.str_width(grapheme)
    }
    index = index + 1
  }
  { line, grapheme_column, display_column }
}

///|
fn line_start_cursor(text : String, line : Int) -> Int {
  let line = @clamp.int(line, min=0, max=line_count(text) - 1)
  if line == 0 {
    0
  } else {
    let mut index = 0
    let mut current_line = 0
    for grapheme in @grapheme.grapheme_iter(text) {
      index = index + 1
      if is_newline_grapheme(grapheme) {
        current_line = current_line + 1
        if current_line == line {
          break
        }
      }
    }
    index
  }
}

///|
fn cursor_for_line_display_column(
  text : String,
  line : Int,
  display_column : Int,
) -> Int {
  let lines = @text.split_lines(text)
  let line = @clamp.int(line, min=0, max=lines.length() - 1)
  let target = @clamp.int(
    display_column,
    min=0,
    max=line_display_width(lines, line),
  )
  let mut grapheme_column = 0
  let mut width = 0
  for grapheme in @grapheme.grapheme_iter(@text.line_at(lines, line)) {
    let next_width = @unicodewidth.str_width(grapheme)
    if width + next_width > target {
      break
    }
    width = width + next_width
    grapheme_column = grapheme_column + 1
  }
  line_start_cursor(text, line) + grapheme_column
}

///|
fn ensure_cursor_visible(
  text : String,
  cursor : Int,
  view_start : Int,
  max_text_rows : Int,
) -> Int {
  let point = cursor_point_for(text, cursor)
  let visible_rows = visible_text_rows_for(text, max_text_rows)
  let mut start = clamp_view_start(text, view_start, max_text_rows)
  if point.line < start {
    start = point.line
  } else if point.line >= start + visible_rows {
    start = point.line - visible_rows + 1
  }
  clamp_view_start(text, start, max_text_rows)
}

///|
/// Mutable state model for the multiline composer.
///
/// `Model` owns the user-editable text, cursor position, semantic mode, the
/// maximum editable rows the composer may grow to, and the first visible
/// logical line in the composer text area. It does not emit terminal sequences;
/// terminal anchoring and rendering belong to the root `Ui`.
struct Model {
  mut text : String
  mut cursor : Int
  mut preferred_column : Int?
  mut view_start : Int
  max_text_rows : Int
  mut mode : Mode
}

///|
fn make_model(
  text : String,
  cursor : Int,
  preferred_column : Int?,
  view_start : Int,
  max_text_rows? : Int = DefaultMaxTextRows,
  mode? : Mode = Input,
) -> Model {
  let max_text_rows = normalize_max_text_rows(max_text_rows)
  let cursor = @clamp.int(cursor, min=0, max=@text.grapheme_count(text))
  let view_start = ensure_cursor_visible(
    text, cursor, view_start, max_text_rows,
  )
  { text, cursor, preferred_column, view_start, max_text_rows, mode }
}

///|
pub fn Model::new(max_text_rows? : Int = DefaultMaxTextRows) -> Model {
  Model::from_text("", max_text_rows~)
}

///|
fn Model::from_text(
  text : String,
  max_text_rows? : Int = DefaultMaxTextRows,
) -> Model {
  make_model(text, @text.grapheme_count(text), None, 0, max_text_rows~)
}

///|
pub fn Model::reset(self : Model) -> Unit {
  self.set_state("", 0, None, 0, mode=Input)
}

///|
pub fn Model::replace(self : Model, text : String, mode~ : Mode) -> Unit {
  self.set_state(text, @text.grapheme_count(text), None, 0, mode~)
}

///|
fn Model::cursor_point(self : Model) -> CursorPoint {
  cursor_point_for(self.text, self.cursor)
}

///|
/// Return the current text that should be submitted to the caller.
///
/// In shell mode, the leading `!` prompt marker is not part of this text.
pub fn Model::text(self : Model) -> String {
  self.text
}

///|
/// Return the semantic mode for the current composer text.
///
/// `Input` mode submits normal agent-steering text. `Shell` mode keeps the
/// leading `!` marker out of editable text and submits a command.
pub fn Model::mode(self : Model) -> Mode {
  self.mode
}

///|
/// Current number of editable rows that should be rendered.
///
/// The composer starts at one row, grows with hard-newline input, and stops at
/// `max_text_rows`. When the text has more logical lines than this value,
/// `view_start` scrolls the visible window instead of growing further.
pub fn Model::visible_text_rows(self : Model) -> Int {
  visible_text_rows_for(self.text, self.max_text_rows)
}

///|
/// Return the logical input line displayed at a composer row.
///
/// `row` is relative to the visible composer text area, not the terminal. A
/// missing row returns an empty string so renderers can draw a fixed surface
/// for the current frame without special-casing short buffers.
pub fn Model::visible_line(self : Model, row : Int) -> String {
  @text.line_at(@text.split_lines(self.text), self.view_start + row)
}

///|
/// Return the prompt prefix for a visible composer row.
///
/// The first visible row gets either `> ` or `! ` when it is also the first
/// logical input line. Continuation rows use two spaces so wrapped prompt
/// content lines up with the editable text.
pub fn Model::input_prefix(self : Model, row_index : Int) -> String {
  if self.view_start == 0 && row_index == 0 {
    self.mode.prompt_prefix()
  } else {
    "  "
  }
}

///|
/// Cursor row within the visible composer text area.
///
/// The returned row is clamped to the current visible row count, so terminal
/// renderers can move relative to the current composer surface even when the
/// underlying cursor is temporarily outside the visible window.
pub fn Model::cursor_row(self : Model) -> Int {
  let row = self.cursor_point().line - self.view_start
  if row < 0 {
    0
  } else if row >= self.visible_text_rows() {
    self.visible_text_rows() - 1
  } else {
    row
  }
}

///|
pub fn Model::cursor_at_first_line(self : Model) -> Bool {
  self.cursor_point().line == 0
}

///|
pub fn Model::cursor_at_last_line(self : Model) -> Bool {
  self.cursor_point().line >= line_count(self.text) - 1
}

///|
/// Cursor column offset within the terminal row that contains the prompt.
///
/// The result is a display-cell offset from column 1, including the prompt
/// prefix width. It is based on grapheme/display-width measurement, not byte
/// length.
pub fn Model::cursor_offset(self : Model, cols : Int) -> Int {
  let lines = @text.split_lines(self.text)
  let point = self.cursor_point()
  let row = self.cursor_row()
  let prefix = self.input_prefix(row)
  let line = @text.line_at(lines, point.line)
  let before_cursor = @text.grapheme_slice(line, 0, point.grapheme_column)
  let visible = @text.truncate_line(
    before_cursor,
    cols - @text.display_width(prefix),
  )
  @text.display_width(prefix) + @text.display_width(visible)
}

///|
fn Model::set_state(
  self : Model,
  text : String,
  cursor : Int,
  preferred_column : Int?,
  view_start : Int,
  mode? : Mode = Input,
) -> Unit {
  let cursor = @clamp.int(cursor, min=0, max=@text.grapheme_count(text))
  self.text = text
  self.cursor = cursor
  self.preferred_column = preferred_column
  self.view_start = ensure_cursor_visible(
    text,
    cursor,
    view_start,
    self.max_text_rows,
  )
  self.mode = mode
}

///|
fn Model::move_to_cursor(
  self : Model,
  cursor : Int,
  preferred_column : Int?,
) -> Unit {
  self.set_state(
    self.text,
    cursor,
    preferred_column,
    self.view_start,
    mode=self.mode,
  )
}

///|
fn Model::delete_range(self : Model, start : Int, end : Int) -> Unit {
  let length = @text.grapheme_count(self.text)
  let start = @clamp.int(start, min=0, max=length)
  let end = @clamp.int(end, min=start, max=length)
  let prefix = @text.grapheme_slice(self.text, 0, start)
  let suffix = @text.grapheme_slice(self.text, end, length)
  self.set_state(prefix + suffix, start, None, self.view_start, mode=self.mode)
}

///|
pub fn Model::insert(self : Model, text : String) -> Unit {
  let prefix = @text.grapheme_slice(self.text, 0, self.cursor)
  let suffix = @text.grapheme_slice(
    self.text,
    self.cursor,
    @text.grapheme_count(self.text),
  )
  self.set_state(
    prefix + text + suffix,
    self.cursor + @text.grapheme_count(text),
    None,
    self.view_start,
    mode=self.mode,
  )
}

///|
pub fn Model::insert_user_text(self : Model, text : String) -> Unit {
  if self.mode.is_input() && self.text.length() == 0 && self.cursor == 0 {
    match text {
      [.. "!", .. rest] => {
        let rest_text = rest.to_owned()
        self.set_state(
          rest_text,
          @text.grapheme_count(rest_text),
          None,
          self.view_start,
          mode=Shell,
        )
      }
      _ => self.insert(text)
    }
  } else {
    self.insert(text)
  }
}

///|
pub fn Model::delete_before(self : Model) -> Unit {
  if self.cursor <= 0 {
    self.set_state(self.text, 0, None, self.view_start, mode=Input)
  } else {
    let prefix = @text.grapheme_slice(self.text, 0, self.cursor - 1)
    let suffix = @text.grapheme_slice(
      self.text,
      self.cursor,
      @text.grapheme_count(self.text),
    )
    self.set_state(
      prefix + suffix,
      self.cursor - 1,
      None,
      self.view_start,
      mode=self.mode,
    )
  }
}

///|
pub fn Model::delete_after(self : Model) -> Unit {
  let length = @text.grapheme_count(self.text)
  if self.cursor >= length {
    self.set_state(
      self.text,
      self.cursor,
      None,
      self.view_start,
      mode=self.mode,
    )
  } else {
    let prefix = @text.grapheme_slice(self.text, 0, self.cursor)
    let suffix = @text.grapheme_slice(self.text, self.cursor + 1, length)
    self.set_state(
      prefix + suffix,
      self.cursor,
      None,
      self.view_start,
      mode=self.mode,
    )
  }
}

///|
pub fn Model::move_left(self : Model) -> Unit {
  self.move_to_cursor(self.cursor - 1, None)
}

///|
pub fn Model::move_right(self : Model) -> Unit {
  self.move_to_cursor(self.cursor + 1, None)
}

///|
pub fn Model::move_home(self : Model) -> Unit {
  let point = self.cursor_point()
  self.move_to_cursor(line_start_cursor(self.text, point.line), None)
}

///|
pub fn Model::move_end(self : Model) -> Unit {
  let point = self.cursor_point()
  let lines = @text.split_lines(self.text)
  self.move_to_cursor(
    cursor_for_line_display_column(
      self.text,
      point.line,
      line_display_width(lines, point.line),
    ),
    None,
  )
}

///|
pub fn Model::kill_before(self : Model) -> Unit {
  let point = self.cursor_point()
  self.delete_range(line_start_cursor(self.text, point.line), self.cursor)
}

///|
pub fn Model::kill_after(self : Model) -> Unit {
  let point = self.cursor_point()
  let lines = @text.split_lines(self.text)
  self.delete_range(
    self.cursor,
    cursor_for_line_display_column(
      self.text,
      point.line,
      line_display_width(lines, point.line),
    ),
  )
}

///|
pub fn Model::move_vertical(self : Model, delta : Int) -> Unit {
  let point = self.cursor_point()
  let lines = @text.split_lines(self.text)
  let target_line = @clamp.int(
    point.line + delta,
    min=0,
    max=lines.length() - 1,
  )
  let preferred_column = self.preferred_column.unwrap_or(point.display_column)
  self.move_to_cursor(
    cursor_for_line_display_column(self.text, target_line, preferred_column),
    Some(preferred_column),
  )
}
