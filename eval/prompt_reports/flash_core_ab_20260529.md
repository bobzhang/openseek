# Flash Core Prompt A/B 2026-05-29

Task template: `eval/prompt_tasks/toml_parser_cli.md`

Run directory: `.moonagent/eval_runs/prompt_ab_flash_core_20260529_154655`

Model: `deepseek-v4-flash`

Max steps per run: 160

## Variants

| Variant | System prompt | Outcome |
| --- | --- | --- |
| `flash_full` | `prompt/flash_prompt.md` before compaction | Rejected. Step 1 returned action-shaped JSON/noop instead of using tools. |
| `flash_core` | `eval/prompts/flash_core_prompt.md` | Finished at step 160. Library and stdin CLI worked, but file path CLI failed independently with `Error: empty input`. |
| `flash_core_v2` | `eval/prompts/flash_core_prompt_v2.md` | Finished at step 110. Passed independent file, stdin, and duplicate-key probes. |

## Log Metrics

| Variant | Steps | Finished | Tool errors | Shell outputs | Writes | Edits | Check | Test | Info | Fmt | Build | Run | `run -e` | `run -c` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `flash_full` | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| `flash_core` | 160 | 1 | 50 | 23 | 36 | 6 | 11 | 9 | 2 | 1 | 0 | 42 | 13 | 0 |
| `flash_core_v2` | 110 | 1 | 20 | 43 | 19 | 1 | 10 | 2 | 3 | 2 | 1 | 5 | 0 | 0 |

## Independent Validation

`flash_core`:

- `moon check --target native` passed.
- `moon test --target native` passed.
- Stdin CLI probe produced valid JSON.
- File path CLI probe failed with `Error: empty input`.

`flash_core_v2`:

- `moon check --target native` passed with 7 warnings from deprecated `assert_eq`
  use on `Json` in tests.
- `moon test --target native` passed: 13/13 tests.
- File path CLI probe:
  `moon run --target native cmd/tomljson -- /tmp/openseek_eval_file.toml`
  produced valid nested JSON.
- Stdin CLI probe:
  `printf 'a.b.c = 42\nx.y = true\n' | moon run --target native cmd/tomljson -- --stdin`
  produced valid nested JSON.
- Duplicate-key probe produced a clean error:
  `Error: duplicate key "key"`.

## Prompt Lessons

- The previous full Flash prompt is too large/noisy for this model in this
  harness; it failed the tool protocol immediately.
- Compact tool-protocol guidance is necessary but not sufficient. The first core
  prompt could work through compiler feedback but invented C FFI for ordinary
  file IO and missed the file-argument requirement.
- The v2 prompt's exact async `@fs`/`@stdio` CLI pattern fixed the file-input
  gap and reduced steps from 160 to 110.
- The v2 run still showed avoidable recovery work around `moonbitlang/core`
  imports and dependency resolution, so the promoted production prompt adds:
  "do not import `moonbitlang/core`" and "run `moon update` after adding new
  dependencies if unresolved".

## Decision

Promote the compact Flash prompt shape. `prompt/flash_prompt.md` was replaced
with a production version based on `flash_core_v2` plus the post-run fixes
above, and `prompt/generated_flash_prompt.mbt` was regenerated.
