# DeepSeek Chat Data

This pure package provides strongly typed DeepSeek chat data and JSON
encoding/decoding. Use it when constructing requests, parsing responses, or
testing DeepSeek chat behavior without network access.

The HTTP client lives in `bobzhang/openseek/deepseek/client`.

## API Shape

- `Model`: current DeepSeek chat model names, with `Show` for wire strings and
  `Debug` for inspection.
- `ThinkingMode` and `ReasoningEffort`: typed controls for DeepSeek V4 thinking
  mode (`enabled`/`disabled`) and effort (`high`/`max`).
- `Role`: `System`, `User`, `Assistant`, and `Tool(tool_call_id)`, with `Show`
  for wire strings and `Debug` for inspection.
- `ChatMessage(role, content, tool_calls?, reasoning_content?)`: one typed chat
  message constructor with `ToJson` for DeepSeek wire encoding. Use `Assistant`
  with `tool_calls` for the assistant message that must be sent back after
  DeepSeek requests native tool calls.
- `ToolDefinition(name, description, parameters, strict?)`: a native DeepSeek
  function tool definition with a JSON Schema parameters object.
- `ToolCall(id~, name~, arguments~)`: a decoded function call request from the
  model; `arguments` is the raw JSON string from the API.
- `Conversation(model, messages, json_response?, tools?, thinking?,
  reasoning_effort?)`: one typed chat request with `ToJson` for DeepSeek
  request body encoding.
- `Usage` and `ChatResponse`: decoded response values with `Debug`; responses
  include `reasoning_content` and `tool_calls`.
- `decode_chat_response(text)`: decode a DeepSeek chat response body.

## Native Tool Calls

DeepSeek tool calling uses the same flow described in the
[official API docs](https://api-docs.deepseek.com/guides/tool_calls): send
`tools` with a chat request, read `response.tool_calls`, append the assistant
tool-call message, execute each local function, then append
`ChatMessage(Tool(call.id), result)` before the next request.

### `ToolDefinition` vs `ToolCall`

`ToolDefinition` and `ToolCall` are opposite sides of the same protocol step:

| Type | Direction | Meaning |
| --- | --- | --- |
| `ToolDefinition` | Your code sends it to DeepSeek in `Conversation.tools`. | A tool definition: name, description, and JSON Schema for arguments. It advertises a function the model may request later. |
| `ToolCall` | DeepSeek returns it in `ChatResponse.tool_calls`. | A concrete tool invocation request: generated call id, function name, and raw JSON argument string. |

The usual sequence is:

1. Define available tools with `ToolDefinition(...)`.
2. Send them in `Conversation(..., tools=[...])` or `Client::chat(..., tools=[...])`.
3. Decode DeepSeek's response into `ToolCall` values.
4. Append `ChatMessage(Assistant, "", tool_calls=response.tool_calls)` so the
   conversation records the model's requested calls.
5. Execute each local function after parsing `ToolCall.arguments`.
6. Append each result as `ChatMessage(Tool(call.id), result)`.

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
    thinking=Some(Enabled),
    reasoning_effort=Some(High),
  )
  let body = ToJson::to_json(conversation)
  assert_true(body.stringify().contains("\"json_object\""))
  assert_true(body.stringify().contains("\"messages\""))
  assert_true(body.stringify().contains("\"reasoning_effort\":\"high\""))
}
```

```moonbit check
///|
test "encode native tool call values" {
  let tool = @deepseek.ToolDefinition("read", "Read a file.", {
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
    id="call_1",
    name="read",
    arguments="{\"path\":\"README.mbt.md\"}",
  )
  let message = @deepseek.ChatMessage(Assistant, "", tool_calls=[call])
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
