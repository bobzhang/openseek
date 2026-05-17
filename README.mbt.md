# bobzhang/openseek

OpenSeek is a small MoonBit foundation for a DeepSeek-backed coding agent.

## Packages

The `deepseek` subpackage exposes pure chat data and JSON helpers:

- `Model` and `Role`
- `ChatMessage(role, content)` with strongly typed `Role` values
- `encode_chat_request(...)` and `decode_chat_response(...)`

It has no HTTP dependency and is suitable for blackbox tests and portable
request/response handling.

The `deepseek/client` subpackage exposes the HTTP client:

- `Client(api_key, model?, api_url?)`
- `Client::chat(messages, json_response?)`

It depends on `moonbitlang/async/http` and is native-only.

The `agent` subpackage contains the OpenSeek agent loop and local tool
dispatch. It depends on `deepseek/client`, filesystem, and process APIs.

## Agent CLI

The `cmd/main` package is the CLI entry point. It parses arguments and runs the
agent package. The agent asks DeepSeek for one JSON action per turn and supports
four actions: `shell`, `read`, `write`, and `finish`.

```bash
export DEEPSEEK=sk-...
moon run cmd/main -- "inspect this project and finish with a short summary"
```

`DEEPSEEK_MODEL` is optional and defaults to `deepseek-v4-flash`.

See `deepseek/README.mbt.md` and `deepseek/client/README.mbt.md` for checked
API examples.
