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
- `ChatMessage::assistant_tool_calls(tool_calls)`: build the assistant message
  that must be sent back after DeepSeek requests native tool calls.
- `FunctionTool(name, description, parameters, strict?)`: a native DeepSeek
  function tool definition with a JSON Schema parameters object.
- `ToolCall(id, name, arguments)`: a decoded function call request from the
  model; `arguments` is the raw JSON string from the API.
- `Conversation(model, messages, json_response?, tools?)`: one typed chat
  request with `ToJson` for DeepSeek request body encoding.
- `Usage` and `ChatResponse`: decoded response values with `Debug`; responses
  include `tool_calls`.
- `decode_chat_response(text)`: decode a DeepSeek chat response body.

## Native Tool Calls

DeepSeek tool calling uses the same flow described in the
[official API docs](https://api-docs.deepseek.com/guides/tool_calls): send
`tools` with a chat request, read `response.tool_calls`, append the assistant
tool-call message, execute each local function, then append
`ChatMessage(Tool(call.id), result)` before the next request.

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
test "encode native tool call values" {
  let tool = @deepseek.FunctionTool("read", "Read a file.", {
    "type": "object",
    "properties": { "path": { "type": "string" } },
    "required": ["path"],
  })
  let conversation = @deepseek.Conversation(
    V4Flash,
    [ChatMessage(User, "read README.mbt.md")],
    tools=[tool],
  )
  let body = ToJson::to_json(conversation).stringify()
  assert_true(body.contains("\"tools\""))
  assert_true(body.contains("\"type\":\"function\""))

  let call = @deepseek.ToolCall(
    "call_1", "read", "{\"path\":\"README.mbt.md\"}",
  )
  let message = @deepseek.ChatMessage::assistant_tool_calls([call])
  assert_true(ToJson::to_json(message).stringify().contains("\"tool_calls\""))
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

```moonbit check
///|
test "decode native tool call values" {
  let response = @deepseek.decode_chat_response(
    (
      #|{"choices":[{"message":{"content":null,"tool_calls":[{"id":"call_1","type":"function","function":{"name":"read","arguments":"{\"path\":\"README.mbt.md\"}"}}]}}]}
    ),
  )
  assert_eq(response.tool_calls.length(), 1)
  assert_eq(response.tool_calls[0].id, "call_1")
  assert_eq(response.tool_calls[0].name, "read")
}
```
