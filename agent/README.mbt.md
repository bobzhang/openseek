# OpenSeek Agent

This package contains the native-only agent loop for `bobzhang/openseek`. It
owns the system prompt, local tool schemas, native DeepSeek tool-call handling,
and dispatch for workspace operations.

The package depends on:

- `bobzhang/openseek/deepseek` for typed models, messages, roles, and tool
  definitions.
- `bobzhang/openseek/deepseek/client` for HTTP chat requests.
- `moonbitlang/async/fs` and `moonbitlang/async/process` for local tool
  execution.

## API Shape

- `run(api_key, model, task)`: run the agent loop for one natural-language task.

`run` creates a DeepSeek client, starts a conversation with a system prompt and
user task, sends native function tool definitions on each turn, executes any
returned tool calls, and sends tool results back with `Tool(call.id)` messages.
The loop stops when the model answers directly, calls the `finish` tool, or the
step limit is reached.

## Tools

The agent exposes four local tools to DeepSeek:

- `shell`: runs `arguments.cmd` through `sh -c` and returns exit code plus
  merged output.
- `read`: reads `arguments.path` as text.
- `write`: overwrites `arguments.path` with `arguments.content`.
- `finish`: ends the task with `arguments.answer`.

Tool-call arguments are parsed from DeepSeek's raw JSON argument string and then
validated by the dispatcher before execution.

## Operational Notes

This package is intended for trusted local automation. The `shell` tool can run
arbitrary commands, and the `write` tool can overwrite files visible to the
process. Use the CLI package when invoking it as an application.

Run the package tests with:

```bash
moon test agent
```
