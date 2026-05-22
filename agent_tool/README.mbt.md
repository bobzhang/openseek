# Agent Tool

This package defines OpenSeek's local tool boundary: parsed tool calls, tool
definitions, executor wrappers, registries, typed output, and explicit
agent-loop control actions.

Concrete built-in tools live in subpackages:

- `agent_tool/read`
- `agent_tool/edit`
- `agent_tool/write`
- `agent_tool/shell`
- `agent_tool/finish`

## API Shape

- `AgentToolCall(@deepseek.ToolCall)`: parse DeepSeek's raw tool-call argument
  string into local JSON arguments.
- `AgentToolDefinition(name, description, schema, execute)`: define one local
  tool and its executor.
- `ToolExecutor`: wrap synchronous or asynchronous executors.
- `ToolOutput(content, is_error?)`: normal tool output sent back to the model.
- `ToolAction`: either `Respond(ToolOutput)` or `Control(AgentControl)`.
- `AgentControl`: loop-level control such as `Finish(answer)` or
  `Abort(reason)`.
- `Tools(definitions)`: name-indexed registry with duplicate-name validation.

Tool output errors are typed with `is_error=true`, but the output content is
still sent to the model so it can recover. Control actions are not sent back as
tool messages; the host loop handles them directly.

```moonbit check
///|
test "tool action helpers" {
  let response = @agent_tool.ToolAction::respond("ok")
  guard response is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "ok")
  assert_false(output.is_error)

  let failed = @agent_tool.ToolAction::respond("bad", is_error=true)
  guard failed is Respond(error_output) else { fail("expected Respond") }
  assert_eq(error_output.content, "bad")
  assert_true(error_output.is_error)

  let done = @agent_tool.ToolAction::finish("done")
  guard done is Control(Finish(answer)) else { fail("expected Finish") }
  assert_eq(answer, "done")
}
```
