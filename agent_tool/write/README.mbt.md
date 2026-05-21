# Write Tool

`write` overwrites `arguments.path` with `arguments.content`. Existing files
are truncated; missing parent directories are **not** created — the agent
should `shell` a `mkdir -p` first when it needs nested directories.

## Arguments

| Name      | Type   | Required | Notes |
| --------- | ------ | -------- | ----- |
| `path`    | string | yes | Filesystem path. Relative paths resolve against the agent process's current working directory. |
| `content` | string | yes | Full file body. Empty strings are accepted and produce a zero-byte file. |

## Action

The action is always `Respond(ToolOutput(...))` — the agent loop forwards
`ToolOutput.content` to the model as a tool-call response. `is_error` is
`false` on success and `true` for write or argument failures. The string body
has one of these shapes:

- `"ok: wrote <n> chars to <path>"` on success — `n` is the character count
  of the written content.
- `"error writing <path>: <error>"` — the write failed. Common causes:
  permission denied, missing parent directory, read-only filesystem.
- `"error: write requires arguments.content"` — payload had `path` but no
  `content` (or `content` was not a string).
- `"error: write requires arguments.path"` — payload was an object missing
  `path`.
- `"error: write requires object arguments"` — payload was not a JSON object.

## Example

```moonbit check
///|
test "write tool advertises the expected schema" {
  let tool = @write.definition()
  assert_eq(tool.name, "write")
  let JsonSchema(schema) = tool.schema
  let text = schema.stringify()
  assert_true(text.contains("\"path\""))
  assert_true(text.contains("\"content\""))
  assert_true(text.contains("\"required\""))
}
```
