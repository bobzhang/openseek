# OpenSeek CLI

This package is the native-only command-line entry point for OpenSeek. It parses
arguments with `moonbitlang/core/argparse`, reads defaults from environment
variables, and calls `bobzhang/openseek/agent.run`.

## Command

```bash
moon run cmd/main -- [--api-key sk-...] [--model deepseek-v4-flash] "task text"
```

`--api-key` can also be supplied with `DEEPSEEK`. `--model` can also be supplied
with `DEEPSEEK_MODEL`; it defaults to `deepseek-v4-flash`.

## Examples

```bash
export DEEPSEEK=sk-...
moon run cmd/main -- "run moon test and summarize the result"
```

```bash
DEEPSEEK_MODEL=deepseek-v4-pro moon run cmd/main -- "inspect the package docs"
```

## Package Boundary

This package should stay thin: argument parsing, environment-backed defaults,
model parsing, and delegation to `@agent.run`. The agent package owns the prompt,
tool definitions, and execution loop.

Run the package tests with:

```bash
moon test cmd/main
```
