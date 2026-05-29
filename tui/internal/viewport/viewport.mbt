///|
/// `CSI ?7 l` — disable autowrap (DECAWM off). The renderer draws full-width
/// rows itself; without this, a glyph in the last column wraps to a new physical
/// line and a later resize can reflow stale rows back into the live area.
const DisableAutoWrap : String = "\u001b[?7l"

///|
/// `CSI ?7 h` — re-enable autowrap (DECAWM on). Always paired with
/// `DisableAutoWrap` so normal terminal output wraps again afterwards.
const EnableAutoWrap : String = "\u001b[?7h"

///|
/// Full reset before a from-scratch redraw, as a sequence of CSI ops:
///   - `CSI r`   reset the scroll region to the whole screen
///   - `CSI 0 m` reset text style
///   - `CSI H`   cursor home
///   - `CSI 2 J` erase the visible screen
///   - `CSI 3 J` erase the scrollback buffer
///   - `CSI H`   cursor home again (after the erases)
const ClearScreenAndScrollback : String = "\u001b[r\u001b[0m\u001b[H\u001b[2J\u001b[3J\u001b[H"

///|
struct Viewport {
  // Invariant after the first draw: `size.rows >= 1`, `size.cols >= 1`,
  // `1 <= height <= size.rows`, and `1 <= top <= max_top()`.
  //
  // Before the live area has been drawn, `top == 0` and `height == 0`. This
  // matches readline's model: output can be written before the input area
  // exists, and the first redraw anchors the live area at the current terminal
  // cursor.
  // 1-based terminal row where the live input viewport starts.
  mut top : Int
  mut size : TerminalSize
  // Number of physical rows currently occupied by the live input viewport.
  // This is derived from the latest `Surface` height, so it includes rows such
  // as queued-input previews, activity, separator, composer text, and status.
  // It intentionally excludes transcript rows inserted above the viewport.
  mut height : Int
  // Diff/clear state for the live area: the last drawn surface (for row diffing)
  // or, once dropped, the footprint it left behind (for clearing). See
  // `FrameCache`.
  mut cache : FrameCache
}

///|
pub fn Viewport::new(height~ : Int) -> Viewport {
  let _ = height
  let size = { rows: DefaultTerminalRows, cols: DefaultTerminalCols }
  { top: 0, size, height: 0, cache: Fresh }
}

///|
fn visible_height(size : TerminalSize, surface : Surface) -> Int {
  normalized_height(size, surface.height())
}

///|
pub fn Viewport::cols(self : Viewport) -> Int {
  self.size.cols
}

///|
fn Viewport::bottom(self : Viewport) -> Int {
  bottom_of(top=self.top, height=self.height)
}

///|
fn Viewport::max_top(self : Viewport) -> Int {
  max_top_for(self.size, self.height)
}

///|
fn Viewport::set_size(self : Viewport, size : TerminalSize) -> Unit {
  let size = normalize_terminal_size(size)
  if size.rows != self.size.rows || size.cols != self.size.cols {
    // Terminal resize can reflow rows away from their old physical footprint.
    // Resize rebuilds from semantic rows, so the cached frame must be dropped.
    self.cache = self.cache.invalidate(live_top=self.top)
  }
  self.size = size
  if self.top > 0 && self.height > 0 {
    self.set_geometry(top=self.top, height=self.height)
  }
}

///|
fn Viewport::set_top(self : Viewport, top : Int) -> Unit {
  self.top = @clamp.int(top, min=1, max=self.max_top())
}

///|
fn Viewport::set_geometry(self : Viewport, top~ : Int, height~ : Int) -> Unit {
  self.height = normalized_height(self.size, height)
  self.top = normalized_top(self.size, self.height, top)
}

///|
async fn Viewport::initial_top(
  self : Viewport,
  tty : @tty.Tty,
  height~ : Int,
  timeout_ms~ : Int,
) -> Int {
  match tty.query_cursor_position(timeout_ms~) {
    Some(position) => normalized_top(self.size, height, position.row)
    None => max_top_for(self.size, height)
  }
}

///|
/// Where the live area should start on the next redraw for a new `height`.
///
/// Readline-style ownership: growth first consumes blank rows *below* the live
/// area, holding `top` fixed, and only pushes upward — scrolling committed text
/// into scrollback — once the taller area would overflow the screen bottom;
/// shrinking holds `top` too. `normalized_top` already encodes exactly this:
/// clamping the current top to `max_top_for` keeps it put while it fits and
/// raises it by just enough when it would not, so no extra growth handling is
/// needed.
fn Viewport::next_top(self : Viewport, height~ : Int) -> Int {
  normalized_top(self.size, height, self.top)
}

///|
pub fn Viewport::refresh_size(self : Viewport, tty : @tty.Tty) -> Unit {
  let size = try tty.window_size() catch {
    _ => { rows: DefaultTerminalRows, cols: DefaultTerminalCols }
  } noraise {
    size => { rows: size.rows, cols: size.cols }
  }
  self.set_size(size)
}

///|
async fn erase_cursor_row(tty : @tty.Tty) -> Unit {
  // `erase_line_all` clears the row but leaves the cursor column unchanged.
  //
  // Without the carriage return:
  //
  //   before: |old prompt text              |
  //                         ^
  //   clear:  |                             |
  //                         ^
  //   write:  |                   > new text|
  //
  // `\r` moves the cursor to column 1 first, so the next render is anchored at
  // the left edge:
  //
  //   after \r: |                             |
  //             ^
  //   write:    |> new text                   |
  tty.write("\r")
  tty.erase_line_all()
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
async fn write_span(tty : @tty.Tty, span : Span) -> Unit {
  span.style.apply(tty)
  tty.write(span.text)
  tty.reset_style()
}

///|
async fn draw_surface_line_at_cursor(tty : @tty.Tty, line : Line?) -> Unit {
  erase_cursor_row(tty)
  if line is Some(line) {
    // DECSTBM redraws full-width rows. If those rows are left as soft-wrapped
    // terminal lines, resizing can reflow old separators/prompts back into the
    // live viewport before the next draw clears them.
    tty.write(DisableAutoWrap)
    try {
      for span in line.spans {
        write_span(tty, span)
      }
    } catch {
      error => {
        tty.write(EnableAutoWrap)
        raise error
      }
    } noraise {
      _ => tty.write(EnableAutoWrap)
    }
  }
}

///|
async fn draw_surface_line_at(tty : @tty.Tty, row : Int, line : Line?) -> Unit {
  tty.set_cursor_position(row, 1)
  draw_surface_line_at_cursor(tty, line)
}

///|
/// Run `body` with the terminal's scroll region (DECSTBM margins) temporarily
/// restricted to rows `top..=bottom`, then restore the full-screen region.
///
/// Inside the region, line feeds and reverse-indexes scroll only those rows and
/// leave everything outside the margins fixed. This is the primitive every
/// scrollback trick below is built on. The margins are always reset, even if
/// `body` raises, so a failed write can never leave the terminal in a clipped
/// scroll region.
async fn with_scroll_region(
  tty : @tty.Tty,
  top : Int,
  bottom : Int,
  body : async () -> Unit,
) -> Unit {
  tty.set_top_bottom_margins(top, bottom)
  try body() catch {
    error => {
      tty.reset_top_bottom_margins()
      raise error
    }
  } noraise {
    _ => tty.reset_top_bottom_margins()
  }
}

///|
/// Make room for a taller live area by scrolling committed rows up into the
/// terminal's native scrollback.
///
/// With the region restricted to `1..=scrollback_bottom`, writing one newline at
/// its bottom row pushes the whole region up by one line — the top row leaves
/// the region into scrollback. Repeating `rows` times frees `rows` rows directly
/// above the new (higher) live-area top.
async fn scroll_scrollback_up_for_growth(
  tty : @tty.Tty,
  old_top~ : Int,
  new_top~ : Int,
) -> Unit {
  let rows = old_top - new_top
  let scrollback_bottom = old_top - 1
  if rows > 0 && scrollback_bottom >= 1 {
    with_scroll_region(tty, 1, scrollback_bottom, () => {
      tty.set_cursor_position(scrollback_bottom, 1)
      for _ in 0..<rows {
        tty.write("\r\n")
      }
    })
  }
}

///|
async fn Viewport::draw_placed_surface_rows(
  self : Viewport,
  tty : @tty.Tty,
  old_frame : Surface?,
  old_top~ : Int,
  old_height~ : Int,
  new_frame~ : Surface,
  new_top~ : Int,
) -> Unit {
  let new_height = new_frame.height()
  let old_content_unknown = (old_top > 0 && old_height > 0) && old_frame is None
  let (draw_top, draw_bottom) = redraw_span(
    old_top~,
    old_height~,
    new_top~,
    new_height~,
    screen_rows=self.size.rows,
    old_content_unknown~,
  )
  if draw_top <= draw_bottom {
    let mut rows_changed = false
    for row in draw_top..<=draw_bottom {
      let old_line = if old_frame is Some(frame) {
        frame.line_at_terminal_row(row~, top=old_top, height=old_height)
      } else {
        None
      }
      let new_line = new_frame.line_at_terminal_row(
        row~,
        top=new_top,
        height=new_height,
      )
      if old_content_unknown || !Line::same_optional(old_line, new_line) {
        if !rows_changed {
          tty.hide_cursor()
          rows_changed = true
        }
        draw_surface_line_at(tty, row, new_line)
      }
    }
    let cursor_changed = if old_frame is Some(frame) {
      !frame.same_terminal_cursor(new_frame, top=old_top, other_top=new_top)
    } else {
      true
    }
    if rows_changed {
      tty.show_cursor()
      tty.set_cursor_position(
        new_top + new_frame.cursor.row,
        1 + new_frame.cursor.col,
      )
    } else if cursor_changed {
      tty.set_cursor_position(
        new_top + new_frame.cursor.row,
        1 + new_frame.cursor.col,
      )
    }
  }
}

///|
async fn Viewport::draw_surface_rows(
  self : Viewport,
  tty : @tty.Tty,
  surface : Surface,
  timeout_ms~ : Int,
) -> Surface {
  let old_frame = self.cache.surface()
  let (old_top, old_height) = self.cache.footprint(live_top=self.top)
  // Readline-style composer ownership:
  //
  //   - The first redraw anchors at the current cursor position.
  //   - Growth uses blank space below first, then expands upward and scrolls
  //     committed output above the composer into terminal scrollback.
  //   - Shrink keeps `top` stable and clears rows released below the live area.
  let next_height = visible_height(self.size, surface)
  let new_top = if old_height == 0 {
    self.initial_top(tty, height=next_height, timeout_ms~)
  } else {
    self.next_top(height=next_height)
  }
  self.set_geometry(top=new_top, height=next_height)
  let surface = surface.with_max_rows(self.height)
  let new_top = self.top
  scroll_scrollback_up_for_growth(tty, old_top~, new_top~)
  self.draw_placed_surface_rows(
    tty,
    old_frame,
    old_top~,
    old_height~,
    new_frame=surface,
    new_top~,
  )
  self.cache = Drawn(surface)
  surface
}

///|
async fn place_cursor(tty : @tty.Tty, surface : Surface, top~ : Int) -> Unit {
  let cursor = surface.cursor
  tty.show_cursor()
  tty.set_cursor_position(top + cursor.row, 1 + cursor.col)
}

///|
/// Rebuild the DECSTBM screen after resize from semantic transcript rows.
///
/// The primary-screen scrollback is treated as a terminal cache here. Resize can
/// reflow that cache, so this path clears it, draws the live frame at the top,
/// then lets transcript insertion push it down until the screen is full.
pub async fn Viewport::replay_with_rows_before(
  self : Viewport,
  tty : @tty.Tty,
  rows_before : Array[Line],
  surface : Surface,
) -> Unit {
  tty.hide_cursor()
  tty.write(ClearScreenAndScrollback)
  tty.write(EnableAutoWrap)
  self.cache = Fresh
  let next_height = visible_height(self.size, surface)
  self.set_geometry(top=1, height=next_height)
  let surface = surface.with_max_rows(self.height)
  let bottom = self.bottom()
  for row in self.top..<=bottom {
    draw_surface_line_at(
      tty,
      row,
      surface.line_at_terminal_row(row~, top=self.top, height=self.height),
    )
  }
  if bottom < self.size.rows {
    for row in (bottom + 1)..<=self.size.rows {
      draw_surface_line_at(tty, row, None)
    }
  }
  self.cache = Drawn(surface)
  self.insert_before(tty, rows_before)
  place_cursor(tty, surface, top=self.top)
}

///|
pub async fn Viewport::draw(
  self : Viewport,
  tty : @tty.Tty,
  surface : Surface,
  timeout_ms~ : Int,
) -> Unit {
  ignore(self.draw_surface_rows(tty, surface, timeout_ms~))
}

///|
/// Open blank rows directly above the live area by scrolling it down, bounded by
/// the blank space below it so committed scrollback is never overwritten.
/// Returns the live-area top from before the shift.
///
/// With the region restricted to `top..=size.rows`, a reverse-index at the top
/// margin scrolls those rows down by one, inserting a blank row at `top`.
/// Repeating opens the requested space; the live area then sits `shift` rows
/// lower.
async fn Viewport::shift_down_for_insert(
  self : Viewport,
  tty : @tty.Tty,
  lines~ : Int,
) -> Int {
  let top = self.top
  let space = self.size.rows - self.bottom()
  let available = if space < 0 { 0 } else { space }
  let shift = if lines < available { lines } else { available }
  if shift > 0 {
    with_scroll_region(tty, top, self.size.rows, () => {
      tty.set_cursor_position(top, 1)
      for _ in 0..<shift {
        tty.reverse_index()
      }
    })
    self.set_top(top + shift)
  }
  top
}

///|
/// Insert rendered transcript rows above the viewport.
///
/// `cursor_row` controls where the first line feed starts. Normal append uses
/// the row above the old viewport so new blank space is filled. Resize replay
/// uses the row above the rebuilt viewport so transcript rows are bottom-aligned
/// before the live frame is redrawn.
async fn Viewport::insert_lines_before(
  self : Viewport,
  tty : @tty.Tty,
  lines : Array[Line],
  cursor_row~ : Int,
) -> Unit {
  let scrollback_bottom = self.top - 1
  if scrollback_bottom < 1 {
    for line in lines {
      draw_surface_line_at_cursor(tty, Some(line))
      tty.write("\r\n")
    }
  } else {
    // Draw the rows inside a `1..=scrollback_bottom` region so each `\r\n`
    // scrolls earlier transcript up into native scrollback as new rows arrive.
    with_scroll_region(tty, 1, scrollback_bottom, () => {
      let start = if cursor_row < 1 {
        if lines.get(0) is Some(line) {
          tty.set_cursor_position(1, 1)
          draw_surface_line_at_cursor(tty, Some(line))
          1
        } else {
          0
        }
      } else {
        tty.set_cursor_position(cursor_row, 1)
        0
      }
      for index in start..<lines.length() {
        tty.write("\r\n")
        draw_surface_line_at_cursor(tty, Some(lines[index]))
      }
    })
  }
}

///|
pub async fn Viewport::insert_before(
  self : Viewport,
  tty : @tty.Tty,
  lines : Array[Line],
) -> Unit {
  if self.top <= 0 || self.height <= 0 {
    self.cache = self.cache.invalidate(live_top=self.top)
    for line in lines {
      draw_surface_line_at_cursor(tty, Some(line))
      tty.write("\r\n")
    }
  } else {
    let old_top = self.shift_down_for_insert(tty, lines=lines.length())
    self.insert_lines_before(tty, lines, cursor_row=old_top - 1)
    if self.cache.surface() is Some(frame) {
      tty.show_cursor()
      tty.set_cursor_position(self.top + frame.cursor.row, 1 + frame.cursor.col)
    }
  }
}

///|
pub async fn Viewport::leave(self : Viewport, tty : @tty.Tty) -> Unit {
  tty.reset_top_bottom_margins()
  tty.reset_style()
  tty.write(EnableAutoWrap)
  tty.show_cursor()
  if self.top > 0 && self.height > 0 {
    tty.set_cursor_position(self.bottom(), 1)
    tty.write("\r\n")
  }
}
