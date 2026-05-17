# bobzhang/openseek

OpenSeek is a small MoonBit foundation for a DeepSeek-backed coding agent. The
module is split into pure data, HTTP transport, agent orchestration, and a CLI
entry point so request encoding can be tested without network access.

## Packages

| Package | Purpose | Docs |
| --- | --- | --- |
| `bobzhang/openseek` | Root package and module overview. | `README.mbt.md` |
| `bobzhang/openseek/deepseek` | Pure DeepSeek chat data, JSON encoding, and response decoding. | `deepseek/README.mbt.md` |
| `bobzhang/openseek/deepseek/client` | Native-only HTTP transport for DeepSeek chat completions. | `deepseek/client/README.mbt.md` |
| `bobzhang/openseek/agent` | Native-only OpenSeek agent loop and local tool dispatch. | `agent/README.mbt.md` |
| `bobzhang/openseek/cmd/main` | Native-only command-line entry point. | `cmd/main/README.md` |

The `deepseek` subpackage is pure and exposes chat data plus JSON helpers:

- `Model` and `Role`
- `ChatMessage(role, content)` with strongly typed `Role` values
- `FunctionTool(name, description, parameters, strict?)` for native tool calls
- `Conversation(model, messages, json_response?, tools?)` with `ToJson` request encoding
- `decode_chat_response(...)`

It has no HTTP dependency and is suitable for blackbox tests and portable
request/response handling.

The `deepseek/client` subpackage exposes the HTTP client:

- `Client(api_key~, model?, api_url?)`
- `Client::chat(messages, json_response?, tools?)`

It depends on `moonbitlang/async/http` and is native-only.

The `agent` subpackage contains the OpenSeek agent loop, native DeepSeek
tool-call handling, and local tool dispatch. It depends on `deepseek/client`,
filesystem, and process APIs.

## Agent CLI

The `cmd/main` package is the CLI entry point. It parses arguments and runs the
agent package. The agent sends DeepSeek native function tools and supports four
local tools: `shell`, `read`, `write`, and `finish`.

```bash
export DEEPSEEK=sk-...
moon run cmd/main -- "inspect this project and finish with a short summary"
```

`DEEPSEEK_MODEL` is optional and defaults to `deepseek-v4-flash`.

See each package README for API boundaries, examples, and package-specific test
notes.
