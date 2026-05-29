///|
fn prompt_entry(text : String) -> HistoryEntry {
  let composer = @composer.Model::new()
  HistoryEntry::new(text, composer.mode())
}

///|
fn shell_entry(text : String) -> HistoryEntry {
  let composer = @composer.Model::new()
  composer.insert_user_text("!" + text)
  HistoryEntry::new(composer.text(), composer.mode())
}

///|
fn recalled_text(entry : HistoryEntry?) -> String {
  match entry {
    Some(entry) => entry.text
    None => "<none>"
  }
}

///|
fn recalled_is_shell(entry : HistoryEntry?) -> Bool {
  match entry {
    Some(entry) => entry.mode.is_shell()
    None => false
  }
}

///|
fn recalled_is_input(entry : HistoryEntry?) -> Bool {
  match entry {
    Some(entry) => entry.mode.is_input()
    None => false
  }
}

///|
test "history recalls entries and restores draft" {
  let history = History::new()
  inspect(history.previous(prompt_entry("draft")) is None, content="true")
  history.push(prompt_entry("one"))
  history.push(prompt_entry("two"))
  let previous = history.previous(prompt_entry("draft"))
  inspect(recalled_text(previous), content="two")
  let previous = history.previous(prompt_entry("ignored"))
  inspect(recalled_text(previous), content="one")
  let previous = history.previous(prompt_entry("ignored"))
  inspect(recalled_text(previous), content="one")
  let next = history.next()
  inspect(recalled_text(next), content="two")
  let next = history.next()
  inspect(recalled_text(next), content="draft")
  inspect(history.next() is None, content="true")
}

///|
test "history skips empty and adjacent duplicate entries" {
  let history = History::new()
  history.push(prompt_entry(""))
  inspect(history.previous(prompt_entry("draft")) is None, content="true")
  history.push(prompt_entry("same"))
  history.push(prompt_entry("same"))
  let previous = history.previous(prompt_entry("draft"))
  inspect(recalled_text(previous), content="same")
  let previous = history.previous(prompt_entry("ignored"))
  inspect(recalled_text(previous), content="same")
}

///|
test "history distinguishes shell and prompt entries" {
  let history = History::new()
  history.push(prompt_entry("pwd"))
  history.push(shell_entry("pwd"))
  let previous = history.previous(prompt_entry("draft"))
  inspect(recalled_is_shell(previous), content="true")
  let previous = history.previous(prompt_entry("ignored"))
  inspect(recalled_is_input(previous), content="true")
}
