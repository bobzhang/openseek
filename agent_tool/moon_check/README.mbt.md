# Moon Check Tool

`moon_check` runs `moon check --output-json` directly and returns the real exit
code with merged stdout/stderr output. It is a focused validation tool for
MoonBit work: use it when the agent needs compiler feedback without going
through `sh -c`.

## Design Rationale

`moon_check` exists separately from `shell` and `moon_cmd` because compiler
diagnostics are the tightest feedback loop in MoonBit work. It always runs
`moon check --output-json`, which gives the agent structured locations and
messages without depending on a shell pipeline or a human-readable formatter.

The schema is intentionally narrow. It accepts MoonBit check options that affect
diagnostics, but it does not expose unrelated `moon` subcommands. That narrow
shape nudges the agent to check early and often while keeping compile feedback
separate from tests, CLI runs, formatting, and interface generation.

## API Style

Use `moon_check` after each meaningful code batch, especially after creating or
editing a package file:

```json
{
  "cwd": "/tmp/example_project",
  "path": "src/parser",
  "target": "native"
}
```

Use `warn_list` or `deny_warn` when the task requires stricter cleanup. Use
`moon_cmd` for `moon test`, `moon run`, `moon info`, `moon fmt`, or
user-facing command validation.

## Arguments

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| `cwd` | string | no | Working directory. Empty is treated as missing. |
| `path` | string | no | One package/file path passed to `moon check`. |
| `paths` | string array | no | Additional package/file paths. |
| `target` | string | no | `wasm`, `wasm-gc`, `js`, `native`, `llvm`, or `all`. |
| `warn_list` | string | no | Value passed to `--warn-list`. |
| `deny_warn` | boolean | no | Adds `--deny-warn` when true. |
| `fmt` | boolean | no | Adds `--fmt` when true. |
| `explain` | boolean | no | Adds `--explain` when true. |

## Action

The action is always `Respond(ToolOutput(...))`. `is_error` is true when the
direct `moon` process exits non-zero, when argument validation fails, or when
the process cannot be launched. The string body has one of these shapes:

- `"cwd=<cwd>\ncommand=moon check --output-json ...\nexit=<code>\n<output>"`.
- `"error running moon_check: <error>"`.
- `"error: moon_check requires <field description>"`.

## Example

```moonbit check
///|
test "moon_check tool advertises the expected schema" {
  let tool = @moon_check.definition()
  assert_eq(tool.name, "moon_check")
  let JsonSchema(schema) = tool.schema
  let text = schema.stringify()
  assert_true(text.contains("\"path\""))
  assert_true(text.contains("\"target\""))
}
```

Process execution is intentionally not exercised from doc tests: running
`moon check` against the active package from inside `moon test` can contend with
the active build. The real-world unit tests copy fixture projects into `/tmp`
and run `moon_check` there, covering both a valid project and a broken project
that emits compiler diagnostics.
