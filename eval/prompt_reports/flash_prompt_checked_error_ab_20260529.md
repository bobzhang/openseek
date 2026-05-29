# Flash Checked-Error Prompt A/B, 2026-05-29

Model: `deepseek-v4-flash`

Task template: `eval/prompt_tasks/toml_parser_cli.md`

Run directory:
`.moonagent/eval_runs/flash_prompt_ab_20260529_192334_checked_errors_v2`

## Variants

| Variant | Prompt | Outcome |
| --- | --- | --- |
| Baseline | `origin/main` from detached worktree | Finished and passed independent probes, but used C FFI, manual CLI parsing, and explicit error containers. |
| Candidate v2 | PR prompt before the final checked-error wording | Finished faster and used checked errors, `@argparse`, async IO, and `@string.from_str`. |
| Candidate v3 | Prompt with extra catch/error-test wording | Finished, but regressed versus v2: more steps, more tool errors, more error-container reasoning. |

## Log Metrics

Blank `rg -c` counts are zero.

| Variant | Steps | Finished | Tool errors | `moon check` | `moon test` | `from_str` | Old argparse API | Direct `argparse` parse | Legacy `try?`/`try!` | Success/failure container mentions |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Baseline | 153 | 1 | 33 | 14 | 2 | 21 | 1 | 0 | 6 | 32 |
| Candidate v2 | 112 | 1 | 26 | 10 | 3 | 1 | 0 | 14 | 0 | 19 |
| Candidate v3 | 139 | 1 | 42 | 15 | 8 | 0 | 0 | 0 | 2 | 43 |

Additional signals:

| Variant | Checked-error terms | String interpolation/probe errors | Bad `moon run -e` usage | `moon run -` stdin snippets |
| --- | ---: | ---: | ---: | ---: |
| Baseline | 24 | 5 | 2 | 4 |
| Candidate v2 | 30 | 65 | 4 | 23 |
| Candidate v3 | 5 | 0 | 0 | 16 |

## Independent Probe Results

Baseline passed:

- `moon check --target native`
- `moon test --target native`
- file-path CLI JSON probe
- stdin CLI JSON probe
- duplicate-key error probe

Candidate v2 passed the same probes and produced a better implementation shape:

- library API: `parse(source : String) -> Json raise`
- custom errors via `suberror`
- native CLI with `moonbitlang/async/fs`, `moonbitlang/async/stdio`, and
  `moonbitlang/core/argparse`
- numeric parsing with `let n : Int = @string.from_str(text)`

Candidate v3 also completed and passed success probes, but its final CLI used
manual `matches.flags.contains(...)` / `matches.values.contains(...)` access
instead of the expressive pattern-match guidance. It also used `catch` for CLI
errors and returned from `async fn main`, which gave clean output but still
showed that extra catch guidance pulled the model away from the intended direct
checked-error style.

## Trace Feedback

- The v2 prompt was the best of this run. It reduced steps from 153 to 112 and
  avoided the baseline's C FFI and manual `@env.args()` parser.
- The final v2 solution still needed many repairs around string interpolation,
  `moon run -e`, and one-off snippets. Those parts should stay concrete.
- The v3 checked-error expansion was too operational. It mentioned catch/testing
  details, and Flash responded by inventing explicit success/failure handling in
  tests, trying constructor matches from black-box tests, and searching for
  abort/exit APIs.
- The useful part of the checked-error explanation is conceptual: `raise` is a
  checked effect in the function signature, while the successful value remains
  the ordinary return type. That is the part to keep and expand.

## Prompt Decision

Keep the prompt additions that are low-risk and repeatedly useful:

- `moon run -e` requires the code as the next argument; use `moon run -` with
  stdin for multi-line snippets.
- `.mbtx`/`moon run -e` dependency probes may include an `import` block such as
  `moonbitlang/async@0.19.1`.
- string interpolation is `\{expr}`, including in `$|` multi-line strings.
- typed parsing should be `let n : Int = @string.from_str(text)`.
- CLI parsing should use `@argparse.parse(...)`.

Change the checked-error section after v3:

- Expand the benefit: checked errors keep parser APIs as `Json raise`, so
  success-path code and tests stay direct while failure remains visible in the
  signature.
- Remove detailed catch/error-unit-test guidance for Flash. It caused the model
  to overfit and introduce explicit error-container logic.
- Tell Flash to keep tests mostly on successful behavior and CLI acceptance
  probes unless exact error values are required.
- Remove `Result`, `Ok`, and `Err` from the prelude examples in the Flash prompt
  so the model is not primed toward explicit containers for parser control flow.

## Conclusion

The new prompt is an improvement over baseline, but the TOML task is not yet
fully reliable. Candidate v2 is the best observed variant in this run. The final
patch keeps v2's successful shape and expands MoonBit checked-error intuition
without teaching catch-heavy test patterns.
