# Read Tool

`read` returns text from a file at `arguments.path`. By default it returns the
whole file when it fits within the output cap. For larger files, or when the
agent only needs a focused region, pass `start_line`, `max_lines`, or
`max_output_chars`.

## Arguments

| Name | Type | Required | Notes |
| ---- | ---- | -------- | ----- |
| `path` | string | yes | Filesystem path. Relative paths resolve against the agent process's current working directory. |
| `start_line` | number | no | 1-based first line to return. Defaults to `1`. |
| `max_lines` | number | no | Maximum number of lines to return. |
| `max_output_chars` | number | no | Maximum content chars to return. Defaults to `12000` and is capped at `50000`. |

## Action

The action is always `Respond(ToolOutput(...))` — the agent loop forwards
`ToolOutput.content` to the model as a tool-call response. `is_error` is
`false` on success and `true` for read failures, argument failures, or automatic
character truncation. The string body has one of these shapes:

- The file's text contents on uncapped whole-file success.
- A metadata header followed by `---` and the selected content for ranged reads
  or capped reads. The header includes line and character counts plus
  `truncated=true` when `max_output_chars` cut the selected content.
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
  assert_true(text.contains("\"start_line\""))
  assert_true(text.contains("\"max_lines\""))
  assert_true(text.contains("\"max_output_chars\""))
  assert_true(text.contains("\"required\""))
}
```

```moonbit check
///|
async test "read tool reads a workspace note through the registry" {
  let path = "/tmp/openseek-read-readme-task.txt"
  let content = "Task: summarize test failures\nStatus: investigating\n"
  @fs.write_file(path, content, create_mode=CreateOrTruncate)

  let tools = @agent_tool.Tools([@read.definition()])
  let call = @agent_tool.AgentToolCall(
    ToolCall(
      id="call_read_note",
      name="read",
      arguments=(
        #|{
        #|  "path": "/tmp/openseek-read-readme-task.txt"
        #|}
      ),
    ),
  )
  let result = @agent_tool.execute_tool_call(call, tools)
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, content)
  assert_false(output.is_error)
}
```

```moonbit check
///|
async test "read tool supports focused range reads" {
  let path = "/tmp/openseek-read-readme-range.txt"
  @fs.write_file(
    path,
    "alpha\nbeta\ngamma\ndelta",
    create_mode=CreateOrTruncate,
  )

  let tools = @agent_tool.Tools([@read.definition()])
  let call = @agent_tool.AgentToolCall(
    ToolCall(
      id="call_read_range",
      name="read",
      arguments=(
        #|{
        #|  "path": "/tmp/openseek-read-readme-range.txt",
        #|  "start_line": 2,
        #|  "max_lines": 2
        #|}
      ),
    ),
  )
  let result = @agent_tool.execute_tool_call(call, tools)
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.content.contains("start_line=2"))
  assert_true(output.content.contains("shown_lines=2"))
  assert_true(output.content.contains("beta\ngamma"))
  assert_false(output.is_error)
}
```
