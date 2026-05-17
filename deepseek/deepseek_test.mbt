///|
test "chat message constructors" {
  let user = @deepseek.ChatMessage::user("hello")
  assert_eq(user.role, "user")
  assert_eq(user.content, "hello")
  let assistant = @deepseek.ChatMessage::assistant("done")
  assert_eq(assistant.role, "assistant")
  assert_eq(assistant.content, "done")
}

///|
test "client defaults" {
  let client = @deepseek.Client::new("test-key")
  assert_eq(client.model, "deepseek-v4-flash")
  assert_eq(client.api_url, "https://api.deepseek.com/chat/completions")
}
