# Shell Tool

`shell` runs a command line through `sh -c` and returns the exit code together
with the merged stdout/stderr output. It is the agent's escape hatch for
running build commands, tests, package managers, version-control operations,
and any other workspace task the other built-in tools don't cover.

## Design Rationale

`shell` is the general escape hatch because an agent occasionally needs a real
workspace command that is not worth modeling as a dedicated tool. It uses
`sh -c` to match developer command-line ergonomics: pipelines, redirects,
environment variables, and existing scripts all work without inventing a custom
argument schema for every possible operation.

stdout and stderr are merged so diagnostics appear in the same order a terminal
would show them. Output is capped because commands can accidentally emit
generated artifacts, dependency listings, or compiler invocations large enough
to damage the model context. Truncation is treated as a tool error so the agent
knows it did not receive the full command output.

## API Style

Use `cwd` whenever the command is workspace-relative, and keep commands
specific:

```json
{
  "cmd": "git status --short",
  "cwd": "/Users/dii/git/openseek"
}
```

Prefer dedicated tools when they encode useful policy. For MoonBit compiler
diagnostics, use `moon_check`; for MoonBit test/run/info/fmt/build validation,
use `moon_cmd`. Use `shell` for everything else or for commands that need shell
features such as pipes.

## Arguments

| Name | Type   | Required | Notes |
| ---- | ------ | -------- | ----- |
| `cmd` | string | yes | Passed as the single argument to `sh -c`. |
| `cwd` | string | no  | Working directory. An empty string is treated as missing. |
| `max_output_chars` | number | no | Defaults to 12000, capped at 50000. Truncated output is a tool error. |

## Action

The action is always `Respond(ToolOutput(...))` — the agent loop forwards
`ToolOutput.content` to the model as a tool-call response and never finishes
from a `shell` invocation. `is_error` is `true` for launch failures, invalid
arguments, non-zero shell exit codes, and output truncation. The string body
has one of these shapes:

- `"exit=<code>\n<stdout/stderr merged>"` — normal completion.
- `"exit=<code>\ntruncated=true\noutput_chars=<n>\nshown_chars=<n>\n<output-prefix>"` —
  the process completed but output was capped before sending it to the model.
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
  assert_true(text.contains("\"max_output_chars\""))
  assert_true(text.contains("\"required\""))
}
```

```moonbit check
///|
async test "shell tool runs a project-style command through the registry" {
  let tools = @agent_tool.Tools([@shell.definition()])
  let call = @agent_tool.AgentToolCall(
    ToolCall(
      id="call_shell_count",
      name="shell",
      arguments=(
        #|{
        #|  "cmd": "printf 'alpha beta' | wc -w",
        #|  "cwd": "/tmp"
        #|}
      ),
    ),
  )
  let result = @agent_tool.execute_tool_call(call, tools)
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  assert_true(output.content.contains("exit=0"))
  assert_true(output.content.contains("2"))
}
```
