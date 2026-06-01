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
/// A rectangular block of terminal rows: 1-based start row `top` and row count
/// `height` (so `bottom = top + height - 1`).
///
/// Used for the live area's current placement — which additionally satisfies the
/// viewport invariant `1 <= height <= size.rows` and `1 <= top <= max_top` — and
/// for a previous frame's footprint (see `FrameCache`), which is the same shape
/// but may predate a resize.
priv struct Geometry {
  top : Int
  height : Int
}

///|
/// Bottom-most row the live area occupies (`top + height - 1`).
fn Geometry::bottom(self : Geometry) -> Int {
  self.top + self.height - 1
}

///|
struct Viewport {
  mut size : @layout.TerminalSize
  // The live area's placement, or `None` before it has been drawn. Matching
  // readline's model, output can be written before the input area exists; the
  // first redraw anchors the area at the current terminal cursor and sets this.
  mut geometry : Geometry?
  // Diff/clear state for the live area: the last drawn surface (for row diffing)
  // or, once dropped, the footprint it left behind (for clearing). See
  // `FrameCache`.
  mut cache : FrameCache
}

///|
pub fn Viewport::new(height~ : Int) -> Viewport {
  let _ = height
  { size: @layout.TerminalSize::default(), geometry: None, cache: Fresh }
}

///|
/// The live area's start row, or 0 before it has been placed.
fn Viewport::top(self : Viewport) -> Int {
  match self.geometry {
    Some(g) => g.top
    None => 0
  }
}

///|
/// The live area's height in rows, or 0 before it has been placed.
fn Viewport::height(self : Viewport) -> Int {
  match self.geometry {
    Some(g) => g.height
    None => 0
  }
}

///|
pub fn Viewport::cols(self : Viewport) -> Int {
  self.size.cols()
}

///|
fn Viewport::bottom(self : Viewport) -> Int {
  match self.geometry {
    Some(g) => g.bottom()
    None => 0
  }
}

///|
fn Viewport::set_size(self : Viewport, size : @layout.TerminalSize) -> Unit {
  if size.rows() != self.size.rows() || size.cols() != self.size.cols() {
    // Terminal resize can reflow rows away from their old physical footprint.
    // Resize rebuilds from semantic rows, so the cached frame must be dropped.
    self.cache = self.cache.invalidate(live_top=self.top())
  }
  self.size = size
  // Re-clamp an already-placed live area against the new dimensions so it stays
  // on screen; before the first draw there is nothing to place.
  if self.geometry is Some(g) {
    self.set_geometry(top=g.top, height=g.height)
  }
}

///|
fn Viewport::set_geometry(self : Viewport, top~ : Int, height~ : Int) -> Unit {
  let height = clamp_height(self.size, height)
  let top = clamp_top(self.size, height, top)
  self.geometry = Some({ top, height })
}

///|
pub fn Viewport::refresh_size(self : Viewport, tty : @tty.Tty) -> Unit {
  let size = try tty.window_size() catch {
    _ => @layout.TerminalSize::default()
  } noraise {
    size => @layout.TerminalSize::new(rows=size.rows, cols=size.cols)
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
async fn apply_style(tty : @tty.Tty, style : @surface.Style) -> Unit {
  if style.foreground() != Default {
    tty.set_foreground(style.foreground())
  }
  if style.background() != Default {
    tty.set_background(style.background())
  }
  if style.underline() {
    tty.underline()
  }
}

///|
async fn write_span(tty : @tty.Tty, span : @surface.Span) -> Unit {
  apply_style(tty, span.style())
  tty.write(span.text())
  tty.reset_style()
}

///|
async fn draw_surface_line_at_cursor(
  tty : @tty.Tty,
  line : @surface.Line?,
) -> Unit {
  erase_cursor_row(tty)
  if line is Some(line) {
    // DECSTBM redraws full-width rows. If those rows are left as soft-wrapped
    // terminal lines, resizing can reflow old separators/prompts back into the
    // live viewport before the next draw clears them.
    tty.write(DisableAutoWrap)
    try {
      for span in line.spans() {
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
async fn draw_surface_line_at(
  tty : @tty.Tty,
  row : Int,
  line : @surface.Line?,
) -> Unit {
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
  old : Geometry,
  new_top~ : Int,
) -> Unit {
  // old:                                     new:
  //
  // +------------+                           +------------+
  // | scrollback |                           | scrollback |
  // | scrollback |                           | scrollback |
  // | scrollback |                           +------------+
  // | scrollback |                new top -> +------------+
  // +------------+ <- scrollback_bottom      | composer   |
  // +------------+ <- old.top                | composer   |
  // | composer   |                           | composer   |
  // +------------+                           +------------+
  //
  // Here we need to make rooms for 2 rows. Since top is 1-based line number from the top
  // of the terminal, we can obtain the number of rows to make by old.top - new_top.
  //
  let rows = old.top - new_top
  let scrollback_bottom = old.top - 1
  if rows > 0 && scrollback_bottom >= 1 {
    with_scroll_region(tty, 1, scrollback_bottom, () => {
      tty.set_cursor_position(scrollback_bottom, 1)
      tty.write("\r\n".repeat(rows))
    })
  }
}

///|
/// Paint the first frame: draw every row of the new area (there is nothing on
/// screen yet to diff against) and place the cursor. The area comes straight
/// from `set_geometry`, so it already fits the screen — no span clamping needed.
async fn enter_placed_surface_rows(
  tty : @tty.Tty,
  new_frame~ : @surface.Surface,
  new_top~ : Int,
) -> Unit {
  let new_height = new_frame.height()
  guard new_height > 0 else { return }
  tty.hide_cursor()
  for row in new_top..<(new_top + new_height) {
    draw_surface_line_at(
      tty,
      row,
      line_at_terminal_row(new_frame, row~, top=new_top, height=new_height),
    )
  }
  place_cursor(tty, new_frame, top=new_top)
}

///|
/// Redraw over a previous frame: repaint only the rows that changed within the
/// union of the old and new footprints, then move the cursor. `old_frame` is the
/// cached surface to diff against, or `None` — a dropped cache (`old_content_
/// unknown`) — which forces a full repaint of the span.
async fn Viewport::redraw_placed_surface_rows(
  self : Viewport,
  tty : @tty.Tty,
  old_frame : @surface.Surface?,
  old : Geometry,
  new_frame~ : @surface.Surface,
  new_top~ : Int,
) -> Unit {
  let new_height = new_frame.height()
  let old_content_unknown = old_frame is None
  let (draw_top, draw_bottom) = calculate_redraw_span(
    old,
    { top: new_top, height: new_height },
    screen_rows=self.size.rows(),
    old_content_unknown~,
  )
  guard draw_top <= draw_bottom else { return }
  let mut rows_changed = false
  for row in draw_top..<=draw_bottom {
    let old_line = if old_frame is Some(frame) {
      line_at_terminal_row(frame, row~, top=old.top, height=old.height)
    } else {
      None
    }
    let new_line = line_at_terminal_row(
      new_frame,
      row~,
      top=new_top,
      height=new_height,
    )
    if old_content_unknown || old_line != new_line {
      if !rows_changed {
        tty.hide_cursor()
        rows_changed = true
      }
      draw_surface_line_at(tty, row, new_line)
    }
  }
  let cursor_changed = if old_frame is Some(frame) {
    !same_terminal_cursor(frame, new_frame, top=old.top, other_top=new_top)
  } else {
    true
  }
  if rows_changed {
    place_cursor(tty, new_frame, top=new_top)
  } else if cursor_changed {
    tty.set_cursor_position(
      new_top + new_frame.cursor().row(),
      1 + new_frame.cursor().col(),
    )
  }
}

///|
async fn place_cursor(
  tty : @tty.Tty,
  surface : @surface.Surface,
  top~ : Int,
) -> Unit {
  let cursor = surface.cursor()
  tty.show_cursor()
  tty.set_cursor_position(top + cursor.row(), 1 + cursor.col())
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
  rows_before : Array[@surface.Line],
  surface : @surface.Surface,
) -> Unit {
  tty.hide_cursor()
  tty.write(ClearScreenAndScrollback)
  tty.write(EnableAutoWrap)
  self.cache = Fresh
  // `set_geometry` clamps the height to the screen itself.
  self.set_geometry(top=1, height=surface.height())
  let surface = surface.with_max_rows(self.height())
  let bottom = self.bottom()
  for row in self.top()..<=bottom {
    draw_surface_line_at(
      tty,
      row,
      line_at_terminal_row(surface, row~, top=self.top(), height=self.height()),
    )
  }
  if bottom < self.size.rows() {
    for row in (bottom + 1)..<=self.size.rows() {
      draw_surface_line_at(tty, row, None)
    }
  }
  self.cache = Drawn(surface)
  self.insert_before(tty, rows_before)
  place_cursor(tty, surface, top=self.top())
}

///|
/// Draw `surface` as the live area for the first time, anchoring it at the
/// terminal cursor.
///
/// Anchor at the row the cursor currently sits on — where the shell left it when
/// the app started — so committed output above stays put. When the cursor is
/// near the bottom (say row 23 of 24 while the area needs 7 rows) it leaves too
/// little room beneath it, so `clamp_top` raises `top` to `calculate_max_top`
/// (here 18). When the cursor position can't be queried, assume the worst case
/// (no room below) and start at `calculate_max_top`. The cursor query is the one
/// blocking read, hence `timeout_ms`.
pub async fn Viewport::enter(
  self : Viewport,
  tty : @tty.Tty,
  surface : @surface.Surface,
  timeout_ms~ : Int,
) -> Unit {
  let height = clamp_height(self.size, surface.height())
  let top = if tty.query_cursor_position(timeout_ms~) is Some(position) {
    clamp_top(self.size, height, position.row)
  } else {
    calculate_max_top(self.size, height)
  }
  self.set_geometry(top~, height~)
  let surface = surface.with_max_rows(self.height())
  enter_placed_surface_rows(tty, new_frame=surface, new_top=self.top())
  self.cache = Drawn(surface)
}

///|
/// Redraw `surface` in place over the previous frame, holding the previous `top`.
///
/// Readline-style ownership: growth uses the blank rows below first and only
/// pushes upward once the taller area would overflow the screen bottom;
/// shrinking holds `top` too. Clamping the old top to `calculate_max_top` is
/// exactly that — it keeps `top` put while the area fits and raises it by just
/// enough when it would not. A no-op before `enter` has placed the area.
pub async fn Viewport::redraw(
  self : Viewport,
  tty : @tty.Tty,
  surface : @surface.Surface,
) -> Unit {
  // The previous frame (for diffing) and its footprint (for clearing vacated
  // rows) must be read before set_geometry moves the live area.
  let old_frame = self.cache.surface()
  guard self.cache.footprint(live_top=self.top()) is Some(old) else { return }
  let height = clamp_height(self.size, surface.height())
  let top = clamp_top(self.size, height, self.top())
  self.set_geometry(top~, height~)
  let surface = surface.with_max_rows(self.height())
  let new_top = self.top()
  scroll_scrollback_up_for_growth(tty, old, new_top~)
  self.redraw_placed_surface_rows(
    tty,
    old_frame,
    old,
    new_frame=surface,
    new_top~,
  )
  self.cache = Drawn(surface)
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
  let top = self.top()
  let space = self.size.rows() - self.bottom()
  let available = if space < 0 { 0 } else { space }
  let shift = if lines < available { lines } else { available }
  if shift > 0 {
    with_scroll_region(tty, top, self.size.rows(), () => {
      tty.set_cursor_position(top, 1)
      for _ in 0..<shift {
        tty.reverse_index()
      }
    })
    self.set_geometry(top=top + shift, height=self.height())
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
  lines : Array[@surface.Line],
  cursor_row~ : Int,
) -> Unit {
  let scrollback_bottom = self.top() - 1
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
  lines : Array[@surface.Line],
) -> Unit {
  if self.geometry is None {
    self.cache = self.cache.invalidate(live_top=self.top())
    for line in lines {
      draw_surface_line_at_cursor(tty, Some(line))
      tty.write("\r\n")
    }
  } else {
    let old_top = self.shift_down_for_insert(tty, lines=lines.length())
    self.insert_lines_before(tty, lines, cursor_row=old_top - 1)
    if self.cache.surface() is Some(frame) {
      tty.show_cursor()
      tty.set_cursor_position(
        self.top() + frame.cursor().row(),
        1 + frame.cursor().col(),
      )
    }
  }
}

///|
pub async fn Viewport::leave(self : Viewport, tty : @tty.Tty) -> Unit {
  tty.reset_top_bottom_margins()
  tty.reset_style()
  tty.write(EnableAutoWrap)
  tty.show_cursor()
  if self.geometry is Some(_) {
    tty.set_cursor_position(self.bottom(), 1)
    tty.write("\r\n")
  }
}
