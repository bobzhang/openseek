# Shell Tool

`shell` runs a command line through `sh -c` and returns the exit code together
with the merged stdout/stderr output. It is the agent's escape hatch for
running build commands, tests, package managers, version-control operations,
and any other workspace task the other built-in tools don't cover.

## Arguments

| Name | Type   | Required | Notes |
| ---- | ------ | -------- | ----- |
| `cmd` | string | yes | Passed as the single argument to `sh -c`. |
| `cwd` | string | no  | Working directory. An empty string is treated as missing. |

## Result

The result is always a `Continue` — the agent loop forwards the output to the
model as a tool-call response and never finishes from a `shell` invocation.
The string body has one of these shapes:

- `"exit=<code>\n<stdout/stderr merged>"` — normal completion.
- `"error running shell: <error>"` — `sh -c` failed to launch (rare; usually
  a process subsystem error).
- `"error: shell requires arguments.cmd"` — payload was an object but had no
  `cmd` field.
- `"error: shell requires object arguments"` — payload was not a JSON object.

`stderr` is merged into `stdout` via `@process.collect_output_merged` so the
model sees the same interleaving a developer would see in a terminal.

## Example

```moonbit check
///|
test "shell tool advertises the expected schema" {
  let tool = @shell.definition()
  assert_eq(tool.name, "shell")
  let JsonSchema(schema) = tool.schema
  let text = schema.stringify()
  assert_true(text.contains("\"cmd\""))
  assert_true(text.contains("\"required\""))
}
```
