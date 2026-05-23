///|
/// Tool definition for `finish`: ends the agent loop with `arguments.answer`
/// as the final response surfaced to the user.
///
/// ## Arguments
/// - `answer` (string, required): the final answer text.
///
/// ## Result
/// - `Control(Finish(<answer>))` — stops the loop and returns the string.
///   Missing or non-string `answer` produces `Control(Finish(""))`.
///
/// `finish` is the only built-in tool whose action is not `Respond`. The loop
/// always stops after `finish` runs, regardless of what comes back.
pub fn definition() -> @agent_tool.AgentToolDefinition {
  AgentToolDefinition(
    name="finish",
    description="End the task with arguments.answer.",
    schema=JsonSchema({
      "type": "object",
      "properties": { "answer": { "type": "string" } },
      "required": ["answer"],
    }),
    execute=Sync(execute),
  )
}

///|
fn execute(arguments : Json) -> @agent_tool.ToolAction {
  finish(@decode.decode(arguments))
}

///|
fn finish(input : @decode.FinishInput) -> @agent_tool.ToolAction {
  @agent_tool.ToolAction::finish(input.answer)
}

///|
test "finish returns Finish with the answer" {
  let result = execute({ "answer": "all done" })
  guard result is Control(Finish(answer)) else { fail("expected Finish") }
  assert_eq(answer, "all done")
}

///|
test "finish preserves multiline answers" {
  let result = execute({ "answer": "line one\nline two" })
  guard result is Control(Finish(answer)) else { fail("expected Finish") }
  assert_eq(answer, "line one\nline two")
}

///|
test "finish ignores extra fields on the payload" {
  let result = execute({ "answer": "done", "extra": "ignored" })
  guard result is Control(Finish(answer)) else { fail("expected Finish") }
  assert_eq(answer, "done")
}

///|
test "finish returns empty Finish when answer is missing" {
  let result = execute({})
  guard result is Control(Finish(answer)) else { fail("expected Finish") }
  assert_eq(answer, "")
}

///|
test "finish returns empty Finish when answer is non-string" {
  let result = execute({ "answer": 42 })
  guard result is Control(Finish(answer)) else { fail("expected Finish") }
  assert_eq(answer, "")
}

///|
test "finish returns empty Finish on non-object arguments" {
  let result = execute(Json::null())
  guard result is Control(Finish(answer)) else { fail("expected Finish") }
  assert_eq(answer, "")
}
