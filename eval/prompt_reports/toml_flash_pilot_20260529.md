# TOML Flash Prompt Pilot 2026-05-29

Task template: `eval/prompt_tasks/toml_parser_cli.md`

Run directory: `.moonagent/eval_runs/prompt_ab_toml_20260529_142732`

Model: `deepseek-v4-flash`

Max steps per run: 160

## Variants

| Variant | Addendum | Outcome |
| --- | --- | --- |
| `builtin` | none | Hit max steps, but final workspace independently compiled and passed tests. |
| `probe_discipline` | `eval/prompts/moonbit_probe_discipline.md` | Finished and produced the best behavioral trace. |
| `cli_contract` | `eval/prompts/moonbit_cli_contract.md` | Finished, compiled, and passed tests, but used shell heavily and left warnings. |
| `validation_loop` | `eval/prompts/moonbit_validation_loop.md` | Rejected: step 1 emitted action-shaped JSON instead of tool calls. |
| `parser_workflow` | `eval/prompts/moonbit_parser_workflow.md` | Rejected: step 1 emitted a direct JSON object instead of tool calls. |

## Log Metrics

| Variant | Steps | Finished | Maxed | Tool errors | `moon_cmd` | Shell outputs | Writes | Edits | Check | Test | Info | Fmt | Run | `run -e` | `run -c` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `builtin` | 160 | 0 | 1 | 35 | 42 | 52 | 41 | 4 | 21 | 4 | 1 | 1 | 9 | 1 | 0 |
| `probe_discipline` | 156 | 1 | 0 | 26 | 65 | 30 | 23 | 15 | 12 | 10 | 3 | 3 | 4 | 0 | 0 |
| `cli_contract` | 153 | 1 | 0 | 29 | 38 | 57 | 20 | 18 | 14 | 5 | 2 | 3 | 9 | 0 | 0 |
| `validation_loop` | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| `parser_workflow` | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

## Independent Validation

For `builtin`, `probe_discipline`, and `cli_contract`:

- `moon check --target native` passed.
- `moon test --target native` passed.
- Absolute-path file CLI probe produced valid JSON.
- `--stdin` CLI probe produced valid JSON.
- Duplicate-key CLI probe produced a useful error message but exited with code
  0. This is a dirty failure contract for all three substantial variants.

Additional notes:

- `cli_contract` kept deprecated `derive(Show)` warnings.
- `builtin` hit the step cap and should not be treated as a clean success even
  though the final workspace was usable.
- `probe_discipline` had the lowest shell-output count among substantial runs
  and the most structured MoonBit command use.

## Token/Cache Signals

| Variant | Usage lines | Prompt tokens | Completion tokens | Cache hit | Cache miss |
| --- | ---: | ---: | ---: | ---: | ---: |
| `builtin` | 160 | 13,599,740 | 54,812 | 13,521,152 | 78,588 |
| `probe_discipline` | 156 | 17,538,169 | 58,921 | 17,414,912 | 123,257 |
| `cli_contract` | 153 | 10,162,156 | 47,521 | 10,089,344 | 72,812 |
| `validation_loop` | 1 | 16,362 | 188 | 8,704 | 7,658 |
| `parser_workflow` | 1 | 16,331 | 67 | 14,464 | 1,867 |

## Conclusion

`moonbit_probe_discipline` is the only candidate worth carrying forward from
this pilot. It improved the behavior trace versus built-in by finishing,
reducing shell use, and leaning more on structured MoonBit commands. It did not
increase `moon run -e` use in this task, so the addendum should be judged more
as a general validation-discipline improvement than a proven one-line probe
improvement.

`moonbit_cli_contract` is promising for final validation wording but too noisy
as a standalone addendum. It should be combined with a stronger "use native tool
calls, not shell or JSON action plans" guard before another run.

`moonbit_validation_loop` and `moonbit_parser_workflow` should not be promoted
as written. Both caused immediate non-tool JSON responses, which is a hard
agent-protocol failure.

Next prompt/tool work:

- Add a short tool-call protocol guard: do not emit JSON action plans; call the
  provided native tools.
- Strengthen routing away from shell for MoonBit commands.
- Add an acceptance helper that asserts CLI exit codes, JSON validity,
  stdout/stderr cleanliness, file mode, and stdin mode.
- Repeat TOML with at least three runs for `builtin` and
  `probe_discipline`, then test a combined `probe + CLI contract + tool-call
  guard` candidate.
