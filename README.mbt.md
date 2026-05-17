# bobzhang/openseek

OpenSeek is a small MoonBit foundation for a DeepSeek-backed coding agent.

The `deepseek` subpackage exposes a tiny DeepSeek chat client:

- `Client::new(api_key, model?, api_url?)`
- `Client::chat(messages, json_response?)`
- `ChatMessage::system`, `ChatMessage::user`, and `ChatMessage::assistant`

The first runnable agent lives in `cmd/main`. It asks DeepSeek for one JSON
action per turn and supports four actions: `shell`, `read`, `write`, and
`finish`.

```bash
export DEEPSEEK=sk-...
moon run cmd/main -- "inspect this project and finish with a short summary"
```

`DEEPSEEK_MODEL` is optional and defaults to `deepseek-v4-flash`.

See `deepseek/README.mbt.md` for a checked API example.
