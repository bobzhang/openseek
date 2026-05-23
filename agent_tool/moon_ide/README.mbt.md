# Moon Ide Tool

`moon_ide` runs read-only `moon ide` semantic navigation commands directly.
It is intended for API discovery and codebase navigation before editing:
documentation lookup, package/file outline, definition lookup, hover, and
reference search.

The tool runs fresh IDE analysis by default. Set `no_check` to `true` when the
workspace already has current IDE artifacts and speed matters more than a fresh
check.

## Design Rationale

`moon_ide` gives the agent read-only semantic discovery before it edits. MoonBit
packages are flat compilation units, so symbol ownership is not always obvious
from file names alone. IDE queries let the agent inspect documentation,
definitions, hovers, outlines, and references using the compiler's view of the
project instead of guessing from text search.

The tool is intentionally read-only. Renames and edits should remain separate
operations so code mutation stays visible in `edit` or `write` calls. Fresh
analysis is the default because stale IDE artifacts can mislead the agent;
`no_check=true` is available only when the caller knows the workspace is already
current.

## API Style

Use `doc` to discover APIs before writing code:

```json
{
  "action": "doc",
  "cwd": "/tmp/example_project",
  "query": "String::replace_all"
}
```

Use file-oriented actions with `path` or `loc` when navigating generated code:

```json
{
  "action": "outline",
  "cwd": "/tmp/example_project",
  "path": "src/parser.mbt"
}
```

Prefer `moon_ide` before broad source reads when a semantic query can answer the
question directly.

## Arguments

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| `action` | string | yes | `doc`, `outline`, `peek_def`, `hover`, or `find_references`. |
| `cwd` | string | no | Working directory. Empty is treated as missing. |
| `query` | string | for `doc`, `peek_def`, `hover`, `find_references` | Symbol, token, or doc query. |
| `path` | string | for `outline` | File or package directory to outline. |
| `loc` | string | for `hover`, optional for `peek_def`/`find_references` | `path[:line[:col]]`, using 1-based line and column. |
| `target` | string | no | `wasm`, `wasm-gc`, `js`, `native`, `llvm`, or `all`. |
| `no_check` | boolean | no | Defaults to `false`; when true, passes `--no-check`. |
| `max_output_chars` | number | no | Defaults to 12000, capped at 50000. |

## Action

The action is always `Respond(ToolOutput(...))`. `is_error` is true when the
direct `moon ide` process exits non-zero, when argument validation fails, or
when the process cannot be launched. The string body has one of these shapes:

- `"cwd=<cwd>\ncommand=moon ide <action> ...\nexit=<code>\n<output>"`.
- `"cwd=<cwd>\ncommand=moon ide <action> ...\nexit=<code>\ntruncated=true\noutput_chars=<n>\nshown_chars=<n>\n<output-prefix>"`.
- `"error running moon_ide: <error>"`.
- `"error: moon_ide requires <field description>"`.

## Example

```moonbit check
///|
test "moon_ide tool advertises semantic navigation fields" {
  let tool = @moon_ide.definition()
  assert_eq(tool.name, "moon_ide")
  let JsonSchema(schema) = tool.schema
  let text = schema.stringify()
  assert_true(text.contains("\"peek_def\""))
  assert_true(text.contains("\"find_references\""))
  assert_true(text.contains("\"max_output_chars\""))
}
```

Process execution is covered by real-world tests that copy a MoonBit fixture
project into `/tmp`, then run `moon ide outline`, `peek-def`, `hover`, and
`find-references`. A separate doc lookup test queries the installed core
documentation for `String::replace_all`.
