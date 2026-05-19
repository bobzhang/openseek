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
test "chat message constructor keeps labeled fields" {
  let call = @deepseek.ToolCall(
    id="call_123",
    name="shell",
    arguments="{\"cmd\":\"moon test\"}",
  )
  let message = @deepseek.ChatMessage(
    Assistant,
    "",
    tool_calls=[call],
    reasoning_content="run tests first",
  )
  assert_eq(message.tool_calls.length(), 1)
  assert_true(message.reasoning_content is Some("run tests first"))
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
  let tool = @deepseek.ToolDefinition("shell", "Run a shell command.", {
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
  let call = @deepseek.ToolCall(
    id="call_123",
    name="shell",
    arguments="{\"cmd\":\"moon test\"}",
  )
  let message = @deepseek.ChatMessage(
    Assistant,
    "",
    tool_calls=[call],
    reasoning_content="run tests first",
  )
  let text = ToJson::to_json(message).stringify()
  assert_true(text.contains("\"role\":\"assistant\""))
  assert_true(text.contains("\"content\":null"))
  assert_true(text.contains("\"tool_calls\""))
  assert_true(text.contains("\"reasoning_content\":\"run tests first\""))
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

///|
test "thinking controls stringify" {
  let enabled : @deepseek.ThinkingMode = Enabled
  let disabled : @deepseek.ThinkingMode = Disabled
  let high : @deepseek.ReasoningEffort = High
  let max : @deepseek.ReasoningEffort = Max
  assert_eq(enabled.to_string(), "enabled")
  assert_eq(disabled.to_string(), "disabled")
  assert_eq(high.to_string(), "high")
  assert_eq(max.to_string(), "max")
}
