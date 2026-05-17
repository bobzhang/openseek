///|
test "chat message constructor" {
  let user = @deepseek.ChatMessage(User, "hello")
  assert_eq(user.role.to_string(), "user")
  assert_eq(user.content, "hello")
  let assistant = @deepseek.ChatMessage(Assistant, "done")
  assert_eq(assistant.role.to_string(), "assistant")
  assert_eq(assistant.content, "done")
  let tool = @deepseek.ChatMessage(Tool("call_123"), "tool result")
  assert_eq(tool.role.to_string(), "tool")
  assert_eq(tool.content, "tool result")
}

///|
test "chat request encoding" {
  let body = ToJson::to_json(
    @deepseek.Conversation(
      V4Flash,
      [ChatMessage(User, "hello")],
      json_response=true,
    ),
  )
  let text = body.stringify()
  assert_true(text.contains("\"model\":\"deepseek-v4-flash\""))
  assert_true(text.contains("\"role\":\"user\""))
  assert_true(text.contains("\"response_format\""))
}

///|
test "native tool request encoding" {
  let tool = @deepseek.FunctionTool("shell", "Run a shell command.", {
    "type": "object",
    "properties": { "cmd": { "type": "string" } },
    "required": ["cmd"],
  })
  let body = ToJson::to_json(
    @deepseek.Conversation(V4Flash, [ChatMessage(User, "run tests")], tools=[
      tool,
    ]),
  )
  let text = body.stringify()
  assert_true(text.contains("\"tools\""))
  assert_true(text.contains("\"type\":\"function\""))
  assert_true(text.contains("\"name\":\"shell\""))
  assert_true(text.contains("\"required\""))
}

///|
test "assistant tool call roundtrip message encoding" {
  let call = @deepseek.ToolCall("call_123", "shell", "{\"cmd\":\"moon test\"}")
  let message = @deepseek.ChatMessage::assistant_tool_calls([call])
  let text = ToJson::to_json(message).stringify()
  assert_true(text.contains("\"role\":\"assistant\""))
  assert_true(text.contains("\"content\":null"))
  assert_true(text.contains("\"tool_calls\""))
  assert_true(
    text.contains("\"arguments\":\"{\\\"cmd\\\":\\\"moon test\\\"}\""),
  )
}

///|
test "model parsing" {
  assert_eq(
    @deepseek.Model::parse("deepseek-v4-flash").to_string(),
    "deepseek-v4-flash",
  )
  assert_eq(
    @deepseek.Model::parse("deepseek-v4-pro").to_string(),
    "deepseek-v4-pro",
  )
}
