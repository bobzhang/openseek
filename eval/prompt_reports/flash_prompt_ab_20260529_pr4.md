# Flash Prompt A/B, 2026-05-29

Model: `deepseek-v4-flash`

Run directory: `.moonagent/eval_runs/flash_prompt_ab_20260529_182600`

## Variants

- Baseline: `origin/main`, evaluated from a detached worktree.
- Candidate: PR prompt before the follow-up edits in this report.
- Patched smoke: same PR prompt after the first follow-up edits; stopped early
  at step 41 after clear non-convergence.

## File-Edit Harness

| Variant | Runs | Success | Marker present | Shell uses | Tool errors |
|---|---:|---:|---:|---:|---:|
| Baseline | 5 | 5 | 2 | 1 | 1 |
| Candidate | 5 | 5 | 4 | 0 | 0 |

The candidate prompt improved the lightweight file-edit harness. The
`compile_fix` case dropped from 7 steps with a shell fallback and one tool error
to 4 steps with no shell fallback and no tool error.

## TOML CLI Task

| Variant | Finished | Steps | Tool errors | `moon check` | `moon test` | Old argparse API hits | Custom error hits |
|---|---:|---:|---:|---:|---:|---:|---:|
| Baseline | yes | 80 | 10 | 11 | 4 | 1 | 1 |
| Candidate | yes | 143 | 44 | 22 | 5 | 0 | 3 |
| Patched smoke | no | 41 | 15 | 2 | 0 | 0 | 71 |

Independent probes:

- Baseline: `moon check --target native`, `moon test --target native`, file CLI
  JSON, stdin CLI JSON, and duplicate-key error all passed.
- Candidate: `moon check --target native`, `moon test --target native`, file CLI
  JSON, and stdin CLI JSON passed. Duplicate-key output was
  `error: duplicate key: 'key'}` with a stray brace.
- Patched smoke: stopped before a compilable solution because it was exploring
  custom error types and low-level syntax instead of converging.

## Trace Feedback

- The candidate removed the old `argparse` API failure mode
  (`@argparse.command`, `Matches.value`, etc.), which is a real improvement.
- It still used `@string.from_str` incorrectly as
  `@string.from_str[:Int](...)` and later fell back to `@string.parse_int`.
- It confused local package imports: the correct import for a `lib` package is
  the full package path such as `"user/toml/lib"`, called as `@lib.parse(...)`.
- It used `long="--stdin"` in `FlagArg`, which made `--stdin` fail until it
  discovered `FlagArg.long` should be `long="stdin"`.
- It printed `println(json)` first, producing MoonBit Debug/Show output rather
  than valid JSON, then fixed this to `json.stringify()`.
- It repeatedly converted `Result`-returning functions again, producing nested
  `Result` confusion.
- The patched smoke showed that vague error-handling facts can backfire:
  Flash over-indexed on custom non-error types (`type TomlError`) instead of
  MoonBit checked errors (`raise` / `suberror`).

## Prompt Changes From This Run

- Added local-package import and alias guidance.
- Made the typed `@string.from_str` idiom explicit and rejected type-application
  forms.
- Added `FlagArg.long` guidance: use `long="stdin"`, not `long="--stdin"`.
- Added JSON output guidance: use `json.stringify()` for CLI stdout and tests.
- Added `Json::number(n.to_double(), repr=text.to_owned())` guidance for integer
  JSON output.
- Corrected error guidance after review: do not encourage `Result[T, String]`
  for ordinary MoonBit parser/CLI flow. Explain checked errors as a function
  effect, use `fn main raise` for sync entry points that call raising functions,
  remember `async fn main` can already raise, and use `suberror` for clean
  user-facing parser errors. Keep tests direct: call raising functions normally
  and let the test fail if they raise.

## Conclusion

The current prompt improves simple file-edit behavior but does not make the
TOML parser task reliable yet. The best next prompt experiment should be smaller
and more opinionated: a compact parser workflow that says "build
`parse(input) -> Json raise` with checked errors first, then add CLI", rather
than more general MoonBit facts.
