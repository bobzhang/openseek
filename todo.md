# OpenSeek Evaluation TODO

## DeepSeek V4 Pro TOML Parser Run

- Status: failed/incomplete as of 2026-05-22 11:17 CST.
- Task: use the OpenSeek agent with `deepseek-v4-pro` reasoning mode to create a MoonBit TOML parser plus CLI that dumps parsed TOML as JSON.
- Model setting: `DEEPSEEK_MODEL=deepseek-v4-pro`; OpenSeek defaults used reasoning mode with max reasoning effort.
- Log: `.moonagent/eval_runs/results/openseek_toml_cli_d4pro_reasoning.log`
- Log size: 2,283 lines / 99,169 bytes.
- Output workspace: `.moonagent/eval_runs/toml_cli_task`
- Result: the run stopped at step 60 with `=== max steps exhausted ===`.
- Validation: `moon check` in the generated workspace fails with 111 errors and 22 warnings.
- Missing deliverables: no CLI package, no README, no tests, no `moon info` output, and no passing `moon test`.

## DeepSeek V4 Pro TOML Parser Retry

- Status: stopped/incomplete as of 2026-05-22 12:35 CST after the run stalled at step 45.
- Task: same TOML parser plus JSON-dump CLI task, using `--max-steps 1000`.
- Log: `.moonagent/eval_runs/results/openseek_toml_cli_d4pro_reasoning_retry.log`
- Log size: 1,451 lines / 80,528 bytes.
- Output workspace: `.moonagent/eval_runs/toml_cli_task_retry`
- Result: log streaming worked; step output appeared immediately in `tee`.
- Progress: the retry scaffolded module, TOML package, and CLI package by step 2, then generated `types.mbt`, `scanner.mbt`, and `parser.mbt`.
- Validation: final manual `moon check` in the generated workspace fails with 59 errors and 12 warnings.
- Missing deliverables: no CLI source, no README, no tests, no `moon info` output, and no passing `moon test`.

## DeepSeek V4 Pro TOML Parser V3

- Status: succeeded as of 2026-05-22 15:16 CST.
- Task: same TOML parser plus JSON-dump CLI task, using `--max-steps 1000`.
- Log: `.moonagent/eval_runs/results/openseek_toml_cli_d4pro_reasoning_v3.log`
- Log size: 4,715 lines / 159,001 bytes.
- Output workspace: `.moonagent/eval_runs/toml_cli_task_v3`
- Result: the agent finished successfully at step 109 with parser package, native CLI package, README, public tests, whitebox tests, generated interface, and passing validation.
- Validation: independent `moon check` and `moon test` in the generated workspace passed with 32 tests.
- CLI smoke: `moon run --target native cmd/main -- /tmp/openseek-toml-v3-smoke.toml` produced `{"title":"Smoke","owner":{"name":"Moon","ports":[8000,8001]}}`.
- Performance improvement over earlier runs: the agent recovered from manifest and API mistakes, discovered current `Json` and async filesystem APIs before finalizing code, used `moon_check` repeatedly, and reached a clean parser package by the mid-run before adding CLI/tests/docs.
- Remaining issue: the README says `moon run cmd/main -- <file.toml>`, but the package is native-only and the module does not set `preferred_target = "native"`, so the documented command fails unless the user passes `--target native`.

## Agent Performance Improvements To Investigate

- Done: stream logs per step through async stdio instead of relying on buffered `println`. During this run the log stayed at 0 bytes for several minutes, then flushed in large chunks, which made live supervision difficult.
- Add a task checklist inside the agent loop and force early coverage of required deliverables: package scaffold, minimal parser, CLI, README, tests, then richer TOML features.
- Run `moon check` after each generated file or small batch. The first check happened after several large files existed, so the agent had to triage 141 errors at once.
- Prefer replacing or deleting stale files when attempting a rewrite. The agent created `lexer2.mbt` but left the original broken `lexer.mbt` in the same package, so both compiled and errors compounded.
- Strengthen MoonBit syntax guidance for generated code: current error propagation syntax, method declarations, enum derives for equality, labeled parameters, suberror constructors, range loops, string APIs, and `Char?` handling.
- Parse `moon check --output-json` diagnostics and group root causes before editing. The raw compiler output was too large and led to scattered one-off edits.
- Add step-budget guardrails. If the CLI and tests do not exist by a threshold such as step 25, the agent should switch from feature expansion to a minimal compiling slice.
- Encourage an initial spike with tiny executable examples for unfamiliar APIs before writing large parser files.
- When an evaluation allows local references, surface nearby working examples such as `.moonagent/toml_parser_demo*` before implementing from scratch.
- Do not hide validation failures behind successful shell exits. In the retry, one check-like command returned `exit=0` while printing compiler failures, which led the loop to continue from a false success signal.
- Keep module/package manifests and dependency assumptions under validation. The retry repeatedly mis-modeled `@json.Json`, `String::split`, suberror constructor labels, and `@string`/`@strconv` parsing APIs.
- Done: add `moon_cmd` for direct `moon test`, `moon run`, `moon info`, `moon fmt`, and `moon build` validation without shell status masking.
- Add native CLI ergonomics checks in agent policy: when a package has `supported_targets = ["native"]`, either set module `preferred_target = "native"` or validate README commands with `moon_cmd` and explicit `--target native`.
- Reduce token-heavy file reads during eval: prefer package docs, focused ranges, or summaries over dumping full dependency sources and generated files into the log.
