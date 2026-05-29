///|
priv struct HistoryEntry {
  text : String
  mode : @composer.Mode
}

///|
priv struct History {
  entries : Array[HistoryEntry]
  // Cursor is in the inclusive range [0, entries.length()].
  // entries.length() means the user is editing the fresh, not-yet-submitted
  // draft rather than a stored history entry.
  mut cursor : Int
  mut draft : HistoryEntry?
}

///|
fn HistoryEntry::new(text : String, mode : @composer.Mode) -> HistoryEntry {
  { text, mode }
}

///|
fn HistoryEntry::same_as(self : HistoryEntry, other : HistoryEntry) -> Bool {
  self.text == other.text && self.mode == other.mode
}

///|
fn History::new() -> History {
  { entries: [], cursor: 0, draft: None }
}

///|
fn History::reset_navigation(self : History) -> Unit {
  self.cursor = self.entries.length()
  self.draft = None
}

///|
fn History::push(self : History, entry : HistoryEntry) -> Unit {
  if entry.text.length() > 0 {
    if self.entries.last() is Some(last) {
      if !last.same_as(entry) {
        self.entries.push(entry)
      }
    } else {
      self.entries.push(entry)
    }
  }
  self.reset_navigation()
}

///|
fn History::previous(self : History, current : HistoryEntry) -> HistoryEntry? {
  if self.entries.length() == 0 {
    return None
  }
  if self.cursor == self.entries.length() {
    self.draft = Some(current)
  }
  if self.cursor > 0 {
    self.cursor -= 1
  }
  self.entries.get(self.cursor)
}

///|
fn History::next(self : History) -> HistoryEntry? {
  if self.cursor >= self.entries.length() {
    return None
  }
  self.cursor += 1
  if self.cursor == self.entries.length() {
    self.draft
  } else {
    self.entries.get(self.cursor)
  }
}
