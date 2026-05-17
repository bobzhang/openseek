# DeepSeek Chat Data

This pure package provides strongly typed DeepSeek chat data and JSON
encoding/decoding. Use it when constructing requests, parsing responses, or
testing DeepSeek chat behavior without network access.

The HTTP client lives in `bobzhang/openseek/deepseek/client`.

## API Shape

- `Model`: current DeepSeek chat model names, with `Show` for wire strings and
  `Debug` for inspection.
- `Role`: `System`, `User`, `Assistant`, and `Tool(tool_call_id)`, with `Show`
  for wire strings and `Debug` for inspection.
- `ChatMessage(role, content)`: one typed chat message constructor with
  `ToJson` for DeepSeek wire encoding.
- `Conversation(model, messages, json_response?)`: one typed chat request with
  `ToJson` for DeepSeek request body encoding.
- `Usage` and `ChatResponse`: decoded response values with `Debug`.
- `decode_chat_response(text)`: decode a DeepSeek chat response body.

```moonbit check
///|
test "encode chat request values" {
  let message = @deepseek.ChatMessage(User, "write a MoonBit test")
  let model : @deepseek.Model = V4Flash
  inspect(model, content="deepseek-v4-flash")
  inspect(message.role, content="user")
  assert_eq(message.content, "write a MoonBit test")
  assert_true(
    ToJson::to_json(message).stringify().contains("\"role\":\"user\""),
  )

  let conversation = @deepseek.Conversation(
    model,
    [message],
    json_response=true,
  )
  let body = ToJson::to_json(conversation)
  assert_true(body.stringify().contains("\"json_object\""))
  assert_true(body.stringify().contains("\"messages\""))
}
```

```moonbit check
///|
test "decode chat response values" {
  let response = @deepseek.decode_chat_response(
    (
      #|{"choices":[{"message":{"content":"ok"}}]}
    ),
  )
  assert_eq(response.content, "ok")
  assert_eq(response.usage.total_tokens, 0)
}
```
