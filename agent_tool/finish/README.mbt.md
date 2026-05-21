# Finish Tool

`finish` ends the agent loop and returns `arguments.answer` as the final
result surfaced to the user. It is the only built-in tool whose result is a
`Finish` — every other tool produces a `Continue` and lets the loop keep
running.

## Arguments

| Name     | Type   | Required | Notes |
| -------- | ------ | -------- | ----- |
| `answer` | string | yes | Final answer text. Multiline strings are preserved as written. |

## Result

- `Finish(<answer>)` — stops the loop and uses the string as the final
  answer. The model sees a clean end-of-task signal.
- `Finish("")` — fallback when `answer` is missing, not a string, or the
  arguments are not a JSON object. This is intentionally lenient: a
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
