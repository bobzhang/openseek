///|
test "chat message constructor" {
  let user = @deepseek.ChatMessage(@deepseek.User, "hello")
  assert_eq(user.role.to_string(), "user")
  assert_eq(user.content, "hello")
  let assistant = @deepseek.ChatMessage(@deepseek.Assistant, "done")
  assert_eq(assistant.role.to_string(), "assistant")
  assert_eq(assistant.content, "done")
  let tool = @deepseek.ChatMessage(@deepseek.Tool("call_123"), "tool result")
  assert_eq(tool.role.to_string(), "tool")
  assert_eq(tool.content, "tool result")
}

///|
test "chat request encoding" {
  let body = @deepseek.encode_chat_request(
    @deepseek.V4Flash,
    [@deepseek.ChatMessage(@deepseek.User, "hello")],
    json_response=true,
  )
  let text = body.stringify()
  assert_true(text.contains("\"model\":\"deepseek-v4-flash\""))
  assert_true(text.contains("\"role\":\"user\""))
  assert_true(text.contains("\"response_format\""))
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
