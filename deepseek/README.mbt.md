# DeepSeek API

This package provides the small DeepSeek chat client used by OpenSeek.

```moonbit check
///|
test "construct chat request values" {
  let client = @deepseek.Client::new("test-key")
  assert_eq(client.model, "deepseek-v4-flash")
  assert_eq(client.api_url, "https://api.deepseek.com/chat/completions")

  let message = @deepseek.ChatMessage::user("write a MoonBit test")
  assert_eq(message.role, "user")
  assert_eq(message.content, "write a MoonBit test")
}
```
