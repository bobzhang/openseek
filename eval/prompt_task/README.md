# Prompt Task Eval

This harness runs a MoonBit prompt task through the real OpenSeek agent with
isolated workspaces, per-trial logs, independent validation probes, and bounded
parallelism.

The default task is `eval/prompt_tasks/toml_parser_cli.md`. The runner replaces
`{{WORKSPACE}}` in the task template with each trial workspace path, starts the
agent, then independently validates the final TOML project with:

- `moon check --target native`
- `moon test --target native`
- file-input `cmd/tomljson` JSON probe
- stdin `cmd/tomljson` JSON probe
- duplicate-key invalid-input probe with no panic/debug stack

Run five Flash TOML trials concurrently:

```bash
moon run eval/prompt_task/cmd/main -- \
  --api-key "$DEEPSEEK" \
  --model deepseek-v4-flash \
  --runs 5 \
  --concurrency 5 \
  --min-successes 5 \
  --max-steps 160 \
  --prompt-label flash-current \
  --out .moonagent/eval_runs/toml_flash_current_5x
```

Run an A/B comparison by using different output directories and prompt labels:

```bash
moon run eval/prompt_task/cmd/main -- \
  --api-key "$DEEPSEEK" \
  --model deepseek-v4-flash \
  --runs 5 \
  --concurrency 5 \
  --min-successes 5 \
  --max-steps 160 \
  --prompt-label flash-candidate \
  --system-prompt-file prompt/flash_prompt.md \
  --out .moonagent/eval_runs/toml_flash_candidate_5x
```

The report records success rate, steps, tool errors, validation pass/fail,
prompt-sensitive log counters, and paths to each raw log.
