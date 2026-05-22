# Moon Cmd Tool

`moon_cmd` runs selected `moon` subcommands directly without going through
`sh -c`. It is intended for end-to-end validation: run tests, execute CLIs,
refresh package interfaces, and verify README commands with the same argument
shape users will run.

For raw compiler diagnostics, keep using `moon_check`; it always runs
`moon check --output-json` and has a narrow schema that nudges the model toward
structured compiler feedback. Use `moon_cmd` when the important behavior is the
actual command line and process result.

## Arguments

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| `command` | string | yes | `check`, `test`, `run`, `info`, `fmt`, or `build`. |
| `cwd` | string | no | Working directory. Empty is treated as missing. |
| `target` | string | no | `wasm`, `wasm-gc`, `js`, `native`, `llvm`, or `all`. Not accepted for `fmt`. |
| `arg` | string | no | One extra moon argument, such as `--update` or `--output-json`. |
| `args` | string array | no | Additional moon arguments placed after common flags. |
| `path` | string | no | One package/file path or main package. |
| `paths` | string array | no | Additional package/file paths. |
| `program_args` | string array | no | Arguments after `--`; only valid with `command = "run"`. |

## Action

The action is always `Respond(ToolOutput(...))`. `is_error` is true when the
direct `moon` process exits non-zero, when argument validation fails, or when
the process cannot be launched. The string body has one of these shapes:

- `"cwd=<cwd>\ncommand=moon <subcommand> ...\nexit=<code>\n<output>"`.
- `"error running moon_cmd: <error>"`.
- `"error: moon_cmd requires <field description>"`.

## Example

```moonbit check
///|
test "moon_cmd tool advertises run validation fields" {
  let tool = @moon_cmd.definition()
  assert_eq(tool.name, "moon_cmd")
  let JsonSchema(schema) = tool.schema
  let text = schema.stringify()
  assert_true(text.contains("\"command\""))
  assert_true(text.contains("\"program_args\""))
}
```

Process execution is covered by fixture tests that copy a native-only CLI
project into `/tmp`, then verify a failing default-target invocation, a passing
explicit `--target native` CLI run, snapshot output from `moon test`, and a
failing test reported as a tool error.
