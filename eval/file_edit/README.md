# File Edit Eval

This harness measures whether a model can use OpenSeek's file-editing tools
reliably. The case definitions live in `eval/file_edit/cases`; the reusable
runner, deterministic oracles, and report writer live in `eval/file_edit/harness`;
the `eval/file_edit/cmd/main` package is only the CLI wrapper around that
harness. Case fixtures use `bobzhang/openseek/testkit/filesystem`, and report
output is rendered through `bobzhang/openseek/eval/report`, so both fixture and
report code can be reused by other mock tests and harnesses.

To see the harness without calling DeepSeek, run the dry-run oracle test:

```bash
moon test eval/file_edit/harness --filter "dry run exact replacement oracle"
```

The default baseline is cheap Flash:

```bash
moon run eval/file_edit/cmd/main -- \
  --api-key "$DEEPSEEK" \
  --model deepseek-v4-flash \
  --runs 10 \
  --min-successes 8 \
  --max-steps 200 \
  --out .moonagent/eval_runs/file_edit_flash
```

The eval is intentionally not part of ordinary `moon test`: it calls the real
DeepSeek API and is nondeterministic. Use it as a manual or scheduled baseline.

## Pass Criteria

A trial passes only when:

- expected files match exactly,
- protected files remain unchanged,
- case-specific validation passes,
- the agent did not use the shell tool,
- the final log contains the requested `file-edit-eval:<case>` marker.

The report records successes, steps, tool errors, shell uses, edit successes,
write successes, log paths, and final failure reasons.
