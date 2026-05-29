///|
test "model starts at end and keeps cursor visible" {
  let model = Model::from_text("a\nb\nc")
  let point = model.cursor_point()
  inspect(point.line, content="2")
  inspect(point.grapheme_column, content="1")
  inspect(point.display_column, content="1")
  inspect(model.visible_text_rows(), content="3")
  inspect(model.view_start, content="0")
  inspect(model.cursor_row(), content="2")
}

///|
test "model up down moves cursor and visible line window" {
  let model = Model::from_text("one\ntwo\nthree")
  inspect(model.cursor_point().line, content="2")
  inspect(model.view_start, content="0")
  model.move_vertical(-1)
  inspect(model.cursor_point().line, content="1")
  inspect(model.cursor_point().display_column, content="3")
  inspect(model.view_start, content="0")
  model.move_vertical(-1)
  inspect(model.cursor_point().line, content="0")
  inspect(model.cursor_point().display_column, content="3")
  inspect(model.view_start, content="0")
  model.move_vertical(1)
  inspect(model.cursor_point().line, content="1")
  inspect(model.view_start, content="0")
  model.move_vertical(1)
  inspect(model.cursor_point().line, content="2")
  inspect(model.view_start, content="0")
}

///|
test "model scrolls visible window after max rows" {
  let model = Model::from_text("a\nb\nc\nd\ne")
  inspect(model.visible_text_rows(), content="4")
  inspect(model.view_start, content="1")
  inspect(model.cursor_row(), content="3")
  model.move_vertical(-3)
  inspect(model.cursor_point().line, content="1")
  inspect(model.view_start, content="1")
  model.move_vertical(-1)
  inspect(model.cursor_point().line, content="0")
  inspect(model.view_start, content="0")
}

///|
test "model inserts and deletes at cursor" {
  let inserted = Model::from_text("ab")
  inserted.move_left()
  inserted.insert("X")
  inspect(inserted.text, content="aXb")
  inspect(inserted.cursor, content="2")
  let deleted_before = Model::from_text("a👨‍👩‍👧‍👦b")
  deleted_before.move_left()
  deleted_before.delete_before()
  inspect(deleted_before.text, content="ab")
  inspect(deleted_before.cursor_point().display_column, content="1")
  let deleted_after = Model::from_text("ab")
  deleted_after.move_home()
  deleted_after.delete_after()
  inspect(deleted_after.text, content="b")
  inspect(deleted_after.cursor, content="0")
}

///|
test "model shell mode keeps marker out of text" {
  let shell = Model::new()
  shell.insert_user_text("!echo hi")
  assert_true(shell.mode().is_shell())
  inspect(shell.text, content="echo hi")
  inspect(shell.cursor, content="7")
  let normal = Model::new()
  normal.insert_user_text("!")
  normal.delete_before()
  assert_true(normal.mode().is_input())
  inspect(normal.text, content="")
}

///|
test "model home end moves within logical line" {
  let model = Model::from_text("ab\ncd")
  model.move_home()
  inspect(model.cursor_point().line, content="1")
  inspect(model.cursor_point().display_column, content="0")
  model.move_end()
  inspect(model.cursor_point().line, content="1")
  inspect(model.cursor_point().display_column, content="2")
}

///|
test "model kills before and after cursor within logical line" {
  let before = Model::from_text("ab\ncd")
  before.kill_before()
  inspect(before.text, content="ab\n")
  inspect(before.cursor_point().line, content="1")
  inspect(before.cursor_point().display_column, content="0")
  let after = Model::from_text("ab\ncd")
  after.move_home()
  after.kill_after()
  inspect(after.text, content="ab\n")
  inspect(after.cursor_point().line, content="1")
  inspect(after.cursor_point().display_column, content="0")
}

///|
test "model kill keeps shell mode active" {
  let shell = Model::new()
  shell.insert_user_text("!pwd")
  shell.kill_before()
  assert_true(shell.mode().is_shell())
  inspect(shell.text, content="")
}

///|
test "input prefix marks only the first logical input line" {
  inspect(Model::new().input_prefix(0), content="> ")
  let shell = Model::new()
  shell.insert_user_text("!")
  inspect(shell.input_prefix(0), content="! ")
  inspect(Model::new().input_prefix(1), content="  ")
  inspect(
    Model::from_text("a\nb\nc", max_text_rows=2).input_prefix(0),
    content="  ",
  )
}

///|
test "input cursor offset accounts for prompt and display width" {
  inspect(Model::new().cursor_offset(80), content="2")
  inspect(Model::from_text("abc").cursor_offset(80), content="5")
  inspect(Model::from_text("你好").cursor_offset(80), content="6")
  let moved_left = Model::from_text("abc")
  moved_left.move_left()
  inspect(moved_left.cursor_offset(80), content="4")
  inspect(Model::from_text("a\nb").cursor_offset(80), content="3")
  inspect(Model::from_text("abcdef").cursor_offset(5), content="5")
  let shell = Model::new()
  shell.insert_user_text("!abc")
  inspect(shell.cursor_offset(80), content="5")
}

///|
test "model replace restores text mode and cursor" {
  let shell = Model::new()
  shell.insert_user_text("!pwd")
  let model = Model::from_text("draft")
  model.replace(shell.text(), mode=shell.mode())
  inspect(model.text(), content="pwd")
  assert_true(model.mode().is_shell())
  inspect(model.cursor, content="3")
  inspect(model.input_prefix(0), content="! ")
}

///|
test "model reports cursor vertical history boundaries" {
  let model = Model::from_text("one\ntwo")
  assert_false(model.cursor_at_first_line())
  assert_true(model.cursor_at_last_line())
  model.move_home()
  assert_false(model.cursor_at_first_line())
  assert_true(model.cursor_at_last_line())
  model.move_vertical(-1)
  assert_true(model.cursor_at_first_line())
  assert_false(model.cursor_at_last_line())
}
