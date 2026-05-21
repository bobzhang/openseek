# Read Tool

`read` returns the contents of a file at `arguments.path` as text. The whole
file is read into memory; there is no streaming or range support.

## Arguments

| Name   | Type   | Required | Notes |
| ------ | ------ | -------- | ----- |
| `path` | string | yes | Filesystem path. Relative paths resolve against the agent process's current working directory. |

## Action

The action is always `Respond(ToolOutput(...))` — the agent loop forwards
`ToolOutput.content` to the model as a tool-call response. `is_error` is
`false` on success and `true` for read or argument failures. The string body
has one of these shapes:

- The file's text contents on success.
- `"error reading <path>: <error>"` — the read failed. Common causes: the
  file is missing, the agent doesn't have read permissions, or the bytes
  aren't valid UTF-8.
- `"error: read requires arguments.path"` — payload was an object but had no
  `path` field.
- `"error: read requires object arguments"` — payload was not a JSON object.

## Example

```moonbit check
///|
test "read tool advertises the expected schema" {
  let tool = @read.definition()
  assert_eq(tool.name, "read")
  let JsonSchema(schema) = tool.schema
  let text = schema.stringify()
  assert_true(text.contains("\"path\""))
  assert_true(text.contains("\"required\""))
}
```
