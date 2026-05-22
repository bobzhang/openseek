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
