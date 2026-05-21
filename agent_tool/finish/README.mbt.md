# Finish Tool

`finish` ends the agent loop and returns `arguments.answer` as the final
result surfaced to the user. It is the only built-in tool whose result is a
`Control(Finish(...))` action — every other built-in tool produces
`Respond(ToolOutput(...))` and lets the loop keep running.

## Arguments

| Name     | Type   | Required | Notes |
| -------- | ------ | -------- | ----- |
| `answer` | string | yes | Final answer text. Multiline strings are preserved as written. |

## Action

- `Control(Finish(<answer>))` — stops the loop and uses the string as the
  final answer. The model sees a clean end-of-task signal.
- `Control(Finish(""))` — fallback when `answer` is missing, not a string,
  or the arguments are not a JSON object. This is intentionally lenient: a
  malformed `finish` call still ends the loop, just with no answer text.

## Example

```moonbit check
///|
test "finish tool advertises the expected schema" {
  let tool = @finish.definition()
  assert_eq(tool.name, "finish")
  let JsonSchema(schema) = tool.schema
  let text = schema.stringify()
  assert_true(text.contains("\"answer\""))
  assert_true(text.contains("\"required\""))
}
```

```moonbit check
///|
async test "finish tool returns the final agent answer through the registry" {
  let tools = @agent_tool.Tools([@finish.definition()])
  let call = @agent_tool.AgentToolCall(
    ToolCall(
      id="call_finish_answer",
      name="finish",
      arguments=(
        #|{
        #|  "answer": "Updated tests and ran moon test."
        #|}
      ),
    ),
  )
  let result = @agent_tool.execute_tool_call(call, tools)
  guard result is Control(Finish(answer)) else { fail("expected Finish") }
  assert_eq(answer, "Updated tests and ran moon test.")
}
```
