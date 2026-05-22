# Edit Tool

`edit` replaces exact text in `arguments.path`. It is intended for targeted
code changes where overwriting the whole file would be unnecessarily broad.

## Arguments

| Name          | Type    | Required | Notes |
| ------------- | ------- | -------- | ----- |
| `path`        | string  | yes | Filesystem path. Relative paths resolve against the agent process's current working directory. |
| `old_string`  | string  | yes | Exact text to replace. Empty strings are rejected. |
| `new_string`  | string  | yes | Replacement text. It must differ from `old_string`. |
| `replace_all` | boolean | no  | Defaults to `false`. When false, `old_string` must occur exactly once. |

## Action

The action is always `Respond(ToolOutput(...))` — the agent loop forwards
`ToolOutput.content` to the model as a tool-call response. `is_error` is
`false` on success and `true` for edit or argument failures. The string body
has one of these shapes:

- `"ok: replaced <n> occurrence(s) in <path>"` on success.
- `"error editing <path>: old_string not found"` — no exact match was found.
- `"error editing <path>: old_string matched <n> times; set replace_all=true to replace all occurrences"` — the edit was ambiguous.
- `"error editing <path>: <error>"` — reading or writing failed.
- `"error: edit requires arguments.<field>"` — payload was an object but missed a required field.
- `"error: edit requires object arguments"` — payload was not a JSON object.

## Example

```moonbit check
///|
test "edit tool advertises the expected schema" {
  let tool = @edit.definition()
  assert_eq(tool.name, "edit")
  let JsonSchema(schema) = tool.schema
  let text = schema.stringify()
  assert_true(text.contains("\"path\""))
  assert_true(text.contains("\"old_string\""))
  assert_true(text.contains("\"new_string\""))
  assert_true(text.contains("\"replace_all\""))
  assert_true(text.contains("\"required\""))
}
```

```moonbit check
///|
async test "edit tool applies a focused code change through the registry" {
  let path = "/tmp/openseek-edit-readme-example.mbt"
  @fs.write_file(
    path,
    "fn greet() -> String {\n  \"hello\"\n}\n",
    create_mode=CreateOrTruncate,
  )

  let tools = @agent_tool.Tools([@edit.definition()])
  let call = @agent_tool.AgentToolCall(
    ToolCall(
      id="call_edit_greeting",
      name="edit",
      arguments=(
        #|{
        #|  "path": "/tmp/openseek-edit-readme-example.mbt",
        #|  "old_string": "  \"hello\"",
        #|  "new_string": "  \"hello, MoonBit\""
        #|}
      ),
    ),
  )
  let result = @agent_tool.execute_tool_call(call, tools)
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "ok: replaced 1 occurrence(s) in \{path}")
  assert_false(output.is_error)
  assert_eq(
    @fs.read_file(path).text(),
    "fn greet() -> String {\n  \"hello, MoonBit\"\n}\n",
  )
}
```
