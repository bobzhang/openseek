# Moon Ide Tool

`moon_ide` runs read-only `moon ide` semantic navigation commands directly.
It is intended for API discovery and codebase navigation before editing:
documentation lookup, package/file outline, definition lookup, hover, and
reference search.

The tool runs fresh IDE analysis by default. Set `no_check` to `true` when the
workspace already has current IDE artifacts and speed matters more than a fresh
check.

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
