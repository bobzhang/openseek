///|
fn Ui::composer_surface(self : Ui) -> @surface.Surface {
  @render.composer_surface(
    self.composer,
    activity=self.activity,
    queued_inputs=self.queued_inputs,
    status=self.status,
    notice=self.notice,
    cols=self.viewport.cols(),
  )
}

///|
async fn Ui::redraw_frame(self : Ui) -> Unit {
  self.viewport.redraw(self.tty, self.composer_surface())
}

///|
async fn Ui::redraw(self : Self) -> Unit {
  self.viewport.refresh_size(self.tty)
  self.redraw_frame()
}

///|
/// Lay out one transcript item, prefixed with a blank separator row so items
/// are visually spaced apart (matching the Codex TUI). The separator is plain,
/// outside any item background block.
fn Ui::item_rows(self : Self, doc : @doc.Doc) -> Array[@surface.Line] {
  let rows : Array[@surface.Line] = [@surface.Line::new([])]
  for row in doc.layout(width=self.viewport.cols()) {
    rows.push(row)
  }
  rows
}

///|
fn Ui::transcript_rows(self : Self) -> Array[@surface.Line] {
  let rows : Array[@surface.Line] = []
  for doc in self.transcript {
    for row in self.item_rows(doc) {
      rows.push(row)
    }
  }
  rows
}

///|
async fn Ui::redraw_after_resize(self : Self) -> Unit {
  self.viewport.refresh_size(self.tty)
  self.viewport.replay_with_rows_before(
    self.tty,
    self.transcript_rows(),
    self.composer_surface(),
  )
}

///|
/// Anchor and draw the first frame. The viewport's `enter` queries the terminal
/// cursor, so this must run before the tty reader starts (see `with_entered`).
async fn Ui::enter(self : Self) -> Unit {
  self.viewport.refresh_size(self.tty)
  self.viewport.enter(
    self.tty,
    self.composer_surface(),
    timeout_ms=self.config.esc_timeout_ms,
  )
  self.entered = true
}

///|
/// Append a styled `Doc` to the permanent transcript: insert its rows into the
/// terminal scrollback above the live area, then redraw the live frame. Runs on
/// the command queue so it serializes with other redraws.
pub async fn Ui::append_transcript(self : Self, doc : @doc.Doc) -> Unit {
  self.commands.wait(() => {
    self.transcript.push(doc)
    self.viewport.refresh_size(self.tty)
    self.viewport.insert_before(self.tty, self.item_rows(doc))
    self.redraw_frame()
  })
}

///|
/// Project a semantic `TranscriptItem` to a `Doc` and append it to the
/// transcript via `append_transcript`.
pub async fn Ui::append_item(self : Self, item : TranscriptItem) -> Unit {
  self.append_transcript(@doc.ToDoc::to_doc(item))
}

///|
/// Set or clear the transient activity label shown above the composer. `Some`
/// shows a busy/progress line that never enters the transcript; `None` hides it.
/// Redraws the live frame.
pub async fn Ui::set_activity(self : Self, activity : @doc.Text?) -> Unit {
  self.commands.wait(() => {
    self.activity = activity
    self.redraw()
  })
}

///|
/// Replace the list of queued inputs shown in the live area (copied defensively)
/// and redraw the frame.
pub async fn Ui::set_queued_inputs(self : Self, inputs : Array[Input]) -> Unit {
  self.commands.wait(() => {
    self.queued_inputs = inputs.copy()
    self.redraw()
  })
}

///|
/// Set the persistent status line below the composer and redraw. Transient input
/// notices may temporarily override its display until the next input event.
pub async fn Ui::set_status(self : Self, status : @doc.Text) -> Unit {
  self.commands.wait(() => {
    self.status = status
    self.redraw()
  })
}

///|
async fn Ui::leave(self : Self) -> Unit {
  guard self.entered else { return }
  self.entered = false
  self.viewport.refresh_size(self.tty)
  self.viewport.leave(self.tty)
}
