///|
fn Ui::composer_surface(self : Ui) -> @surface.Surface {
  render_composer_surface(
    self.composer,
    self.activity,
    self.queued_inputs,
    self.status,
    self.notice,
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
pub async fn Ui::append_transcript(self : Self, doc : @doc.Doc) -> Unit {
  self.commands.wait(() => {
    self.transcript.push(doc)
    self.viewport.refresh_size(self.tty)
    self.viewport.insert_before(self.tty, self.item_rows(doc))
    self.redraw_frame()
  })
}

///|
pub async fn Ui::append_item(self : Self, item : TranscriptItem) -> Unit {
  self.append_transcript(item.to_doc())
}

///|
pub async fn Ui::set_activity(self : Self, activity : @doc.Text?) -> Unit {
  self.commands.wait(() => {
    self.activity = activity
    self.redraw()
  })
}

///|
pub async fn Ui::set_queued_inputs(self : Self, inputs : Array[Input]) -> Unit {
  self.commands.wait(() => {
    self.queued_inputs = inputs.copy()
    self.redraw()
  })
}

///|
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
