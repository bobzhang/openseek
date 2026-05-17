# DeepSeek Client

This package contains the effectful DeepSeek HTTP transport. It depends on the
pure `bobzhang/openseek/deepseek` package for models, roles, messages, JSON
encoding, and JSON decoding.

Use this package when you need to send chat requests to the real DeepSeek API.
The package depends on `moonbitlang/async/http` and is native-only.

## API Shape

- `Client(api_key, model?, api_url?)`: configure the API key, typed model, and
  optional endpoint override.
- `Client::chat(messages, json_response?)`: send typed chat messages and decode
  the response.

`Client` implements `Debug` with the API key redacted.

The blackbox test suite includes a real API smoke test when `DEEPSEEK` is set.
Without that environment variable, the smoke test is skipped.

```moonbit check
///|
test "construct DeepSeek client" {
  let client = @client.Client("test-key", model=V4Pro)
  inspect(client.model, content="deepseek-v4-pro")
  assert_eq(client.api_url, "https://api.deepseek.com/chat/completions")

  let message = @deepseek.ChatMessage(User, "ping")
  inspect(message.role, content="user")
  assert_eq(message.content, "ping")
}
```
