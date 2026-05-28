# Eval Report

`bobzhang/openseek/eval/report` provides the small report primitive shared by
local harnesses. It renders a title, summary metrics, dynamic table columns,
rows, and optional log links to both Markdown and JSON.

It is intentionally simple: individual harnesses still own their domain result
types, then convert to `Report` at the output boundary.

## API Shape

- `Metric(name~, value~)`: a string metric used in summaries or rows.
- `ReportRow(index~, name~, success~, reason?, warnings?, metrics?, log_path?)`:
  one case/tool row.
- `Report(title~, summary?, metric_columns?, rows?)`: the renderable report.
- `Report::markdown()`: Markdown table plus optional log section.
- `Report::to_json()`: JSON representation for automated inspection.
- `Report::write_files(out_dir)`: writes `report.md` and `report.json`.
- `write_files(out_dir, markdown, json)`: shared writer for harnesses that keep
  their own richer JSON schema but reuse the Markdown renderer.

## Example

```moonbit check
///|
test "render a tiny report" {
  let report = @report.Report(
    title="Tool Harness",
    summary=[Metric(name="passed", value="true")],
    metric_columns=["Mode"],
    rows=[
      ReportRow(index=1, name="read", success=true, metrics=[
        Metric(name="Mode", value="filesystem"),
      ]),
    ],
  )
  let markdown = report.markdown()
  assert_true(markdown.contains("# Tool Harness"))
  assert_true(
    markdown.contains("| # | Case | Result | Mode | Reason | Warnings |"),
  )
  assert_true(markdown.contains("| 1 | `read` | pass | filesystem | ok |  |"))
}
```
