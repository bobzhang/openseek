///|
test "chat message constructors" {
  let user = @deepseek.ChatMessage::user("hello")
  assert_eq(user.role.to_string(), "user")
  assert_eq(user.content, "hello")
  let assistant = @deepseek.ChatMessage::assistant("done")
  assert_eq(assistant.role.to_string(), "assistant")
  assert_eq(assistant.content, "done")
  let generic = @deepseek.ChatMessage(@deepseek.User, "typed")
  assert_eq(generic.role.to_string(), "user")
  assert_eq(generic.content, "typed")
}

///|
test "client defaults" {
  let client = @deepseek.Client("test-key")
  assert_eq(client.model.to_string(), "deepseek-v4-flash")
  assert_eq(client.api_url, "https://api.deepseek.com/chat/completions")
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
