# DeepSeek Client

This package contains the effectful DeepSeek HTTP transport. It depends on the
pure `bobzhang/openseek/deepseek` package for models, roles, messages, JSON
encoding, and JSON decoding.

Use this package when you need to send chat requests to the real DeepSeek API.
The package depends on `moonbitlang/async/http` and is native-only.

## API Shape

- `Client(api_key~, model?, api_url?)`: configure the API key, typed model, and
  optional endpoint override.
- `Client::chat(messages, json_response?, tools?)`: send typed chat messages,
  optionally with native DeepSeek function tools, and decode the response.

`Client` implements `Debug` with the API key redacted.

## Request Behavior

`Client::chat` builds a `@deepseek.Conversation` with the client's configured
model and sends it to `api_url` as JSON. It always sends `stream=false`.

Use `json_response=true` only when the response should be a JSON object. Use
`tools=[...]` when the model should call native DeepSeek function tools. Tool
call results should be appended as `@deepseek.ChatMessage(Tool(call.id), text)`
before sending the next request.

HTTP status codes outside `200..<300` raise with the status code and response
body. Successful responses are decoded with `@deepseek.decode_chat_response`.

## Configuration

The default endpoint is `https://api.deepseek.com/chat/completions`, and the
default model is `deepseek-v4-flash`. Tests and examples use placeholder API
keys unless explicitly marked as real API smoke tests.

```moonbit check
///|
test "construct DeepSeek client" {
  let client = @client.Client(api_key="test-key", model=V4Pro)
  inspect(client.model, content="deepseek-v4-pro")
  assert_eq(client.api_url, "https://api.deepseek.com/chat/completions")

  let message = @deepseek.ChatMessage(User, "ping")
  inspect(message.role, content="user")
  assert_eq(message.content, "ping")
}
```

```moonbit check
///|
test "prepare tool-enabled client request values" {
  let client = @client.Client(api_key="test-key")
  let tool = @deepseek.FunctionTool("read", "Read a file.", {
    "type": "object",
    "properties": { "path": { "type": "string" } },
    "required": ["path"],
  })
  let messages = [@deepseek.ChatMessage(User, "read README.mbt.md")]
  let body = ToJson::to_json(
    @deepseek.Conversation(client.model, messages, tools=[tool]),
  ).stringify()

  assert_true(body.contains("\"model\":\"deepseek-v4-flash\""))
  assert_true(body.contains("\"tools\""))
  assert_true(body.contains("\"name\":\"read\""))
}
```

## Tests

Run the package tests with:

```bash
moon test deepseek/client
```

The blackbox test suite includes a real API smoke test when `DEEPSEEK` is set.
Without that environment variable, the smoke test prints a skip message and
returns successfully.
