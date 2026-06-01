# OpenSeek Real-World CLI

This page is both documentation and an executable cram test for the native CLI.
It exercises the real DeepSeek API, so it requires MoonBit nightly because
`moon cram` is currently nightly-only.

Moon Cram runs the examples in an isolated work directory. To call the real API,
put the key in that work directory before running the document:

```bash
work_dir="$(mktemp -d)"
printf 'export DEEPSEEK=%q\n' "$DEEPSEEK" > "$work_dir/.deepseek_env"
moon cram test --work-directory "$work_dir" tests/cram/realworld.md
```

When `.deepseek_env` is absent or does not define `DEEPSEEK`, the examples take
a documented skip path instead of calling the API.

## Cram Setup

The test runner puts `openseek.exe` on `PATH`. These setup commands locate the
checkout, name the fixture directory, and load the optional API key.

```mooncram
$ openseek_cli="$(command -v openseek.exe)"
```

```mooncram
$ repo_root="${openseek_cli%/_build/native/*/build/cmd/openseek/openseek.exe}"
```

```mooncram
$ fixtures="$repo_root/tests/cram/fixtures"
```

```mooncram
$ if [ -f .deepseek_env ]; then . ./.deepseek_env; fi
```

```mooncram
$ if [ -n "${DEEPSEEK:-}" ]; then
>   printf 'DeepSeek credentials: configured\n'
> else
>   printf 'DeepSeek credentials: not configured\n'
> fi
DeepSeek credentials: (configured|not configured) (re)
```

## V4 Pro Smoke Test

The CLI reads the API key from `DEEPSEEK`, uses `DEEPSEEK_MODEL`, and completes
a small task through the real agent loop. JSONL is the default log format, so
the output can be saved with `tee` and queried with `jq`.

```mooncram
$ if [ -n "${DEEPSEEK:-}" ]; then
>   DEEPSEEK_MODEL=deepseek-v4-pro OPENSEEK_MAX_STEPS=4 \
>     openseek.exe "$(cat "$fixtures/pro-task.txt")" | tee pro.jsonl >/dev/null
> else
>   printf '{"event":"skip","reason":"DEEPSEEK is not configured"}\n' > pro.jsonl
> fi
```

The JSONL log stays in the cram work directory, so it can be inspected in
another shell session while the run is still fresh on disk.

```mooncram
$ jq -r 'select(.event == "step" or .event == "skip") | .reason // "step=\(.step)"' pro.jsonl | head -n 1
(step=1|DEEPSEEK is not configured) (re)
```

```mooncram
$ jq -r 'select(.event == "usage" or .event == "skip") | .reason // "prompt_tokens=\(.prompt_tokens)"' pro.jsonl | head -n 1
(prompt_tokens=[1-9][0-9]*|DEEPSEEK is not configured) (re)
```

```mooncram
$ jq -r 'select(.event == "finish" or .event == "skip") | .answer // .reason' pro.jsonl | tail -n 1
(.*OPENSEEK_CRAM_PRO_OK.*|DEEPSEEK is not configured) (re)
```

## Prompt File Override

The prompt override path is also covered end to end: the CLI reads a local
system prompt file, still authenticates with `DEEPSEEK`, and reaches a final
answer.

```mooncram
$ if [ -n "${DEEPSEEK:-}" ]; then
>   openseek.exe --model deepseek-v4-pro --max-steps 4 \
>     --system-prompt-file "$fixtures/prompt-system.md" \
>     "$(cat "$fixtures/prompt-task.txt")" | tee prompt-file.jsonl >/dev/null
> else
>   printf '{"event":"skip","reason":"DEEPSEEK is not configured"}\n' > prompt-file.jsonl
> fi
```

```mooncram
$ jq -r 'select(.event == "step" or .event == "skip") | .reason // "step=\(.step)"' prompt-file.jsonl | head -n 1
(step=1|DEEPSEEK is not configured) (re)
```

```mooncram
$ jq -r 'select(.event == "finish" or .event == "skip") | .answer // .reason' prompt-file.jsonl | tail -n 1
(.*OPENSEEK_CRAM_PROMPT_FILE_OK.*|DEEPSEEK is not configured) (re)
```
