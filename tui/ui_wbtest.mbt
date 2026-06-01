///|
test "submitted input marks prompt and shell command" {
  let input = @composer.Model::new()
  let shell = @composer.Model::new()
  shell.insert_user_text("!")
  assert_true(submitted_input("hello", input.mode()) == Prompt("hello"))
  assert_true(submitted_input("pwd ", shell.mode()) == Command("pwd"))
  assert_true(submitted_input("", shell.mode()) == Command(""))
}

///|
test "queued inputs render numbered prompt and shell previews" {
  let rows = render_queued_inputs([Prompt("first"), Command("pwd")], cols=40)
  inspect(
    rows.map(line => line.text()).join("|"),
    content="queued follow-up inputs:|  1. > first|  2. $ pwd",
  )
}

///|
test "queued input previews are copied by value" {
  let queued = [Prompt("first")]
  let copied = queued.copy()
  queued.push(Prompt("second"))
  inspect(copied.length(), content="1")
}

///|
test "input doc renders prompt prefixes" {
  inspect(
    Prompt("hello\nworld")
    .to_doc()
    .layout(width=20)
    .map(line => line.text())
    .join("|"),
    content="> hello|  world",
  )
  inspect(
    Command("pwd").to_doc().layout(width=20).map(line => line.text()).join("|"),
    content="$ pwd",
  )
}

///|
test "transcript response renders bullet and continuation prefix" {
  inspect(
    Response("hello\nworld")
    .to_doc()
    .layout(width=20)
    .map(line => line.text())
    .join("|"),
    content="• hello|  world",
  )
}

///|
test "transcript tool call renders detail texts without caller-side joining" {
  inspect(
    TranscriptItem::ToolCall(
      ToolCall::ToolCall(@doc.Text::plain("Ran moon test"), status=Completed, details=[
        @doc.Text::plain("one"),
        @doc.Text::plain("two\nthree"),
      ]),
    )
    .to_doc()
    .layout(width=40)
    .map(line => line.text())
    .join("|"),
    content="• Ran moon test|  └ one|    two|    three",
  )
}
