///|
/// Tool definition for `finish`: ends the agent loop with `arguments.answer`
/// as the final response surfaced to the user.
///
/// ## Arguments
/// - `answer` (string, required): the final answer text.
///
/// ## Result
/// - `Finish(<answer>)` — stops the loop and returns the string. Missing or
///   non-string `answer` produces `Finish("")`.
///
/// `finish` is the only built-in tool whose result is not a `Continue`. The
/// loop always stops after `finish` runs, regardless of what comes back.
pub fn definition() -> @agent_tool.AgentToolDefinition {
  AgentToolDefinition(
    "finish",
    "End the task with arguments.answer.",
    JsonSchema({
      "type": "object",
      "properties": { "answer": { "type": "string" } },
      "required": ["answer"],
    }),
    Sync(execute),
  )
}

///|
fn execute(arguments : Json) -> @agent_tool.ToolResult {
  let answer = match arguments {
    { "answer": String(answer), .. } => answer
    _ => ""
  }
  Finish(answer)
}

///|
test "finish returns Finish with the answer" {
  let result = execute({ "answer": "all done" })
  guard result is Finish(answer) else { fail("expected Finish") }
  assert_eq(answer, "all done")
}

///|
test "finish preserves multiline answers" {
  let result = execute({ "answer": "line one\nline two" })
  guard result is Finish(answer) else { fail("expected Finish") }
  assert_eq(answer, "line one\nline two")
}

///|
test "finish ignores extra fields on the payload" {
  let result = execute({ "answer": "done", "extra": "ignored" })
  guard result is Finish(answer) else { fail("expected Finish") }
  assert_eq(answer, "done")
}

///|
test "finish returns empty Finish when answer is missing" {
  let result = execute({})
  guard result is Finish(answer) else { fail("expected Finish") }
  assert_eq(answer, "")
}

///|
test "finish returns empty Finish when answer is non-string" {
  let result = execute({ "answer": 42 })
  guard result is Finish(answer) else { fail("expected Finish") }
  assert_eq(answer, "")
}

///|
test "finish returns empty Finish on non-object arguments" {
  let result = execute(Json::null())
  guard result is Finish(answer) else { fail("expected Finish") }
  assert_eq(answer, "")
}
