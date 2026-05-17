# DeepSeek API

This package provides the small DeepSeek chat client used by OpenSeek.
The blackbox test suite includes a real API smoke test when `DEEPSEEK` is set.

```moonbit check
///|
test "construct chat request values" {
  let client = @deepseek.Client("test-key")
  inspect(client.model, content="deepseek-v4-flash")
  assert_eq(client.api_url, "https://api.deepseek.com/chat/completions")

  let message = @deepseek.ChatMessage(@deepseek.User, "write a MoonBit test")
  inspect(message.role, content="user")
  assert_eq(message.content, "write a MoonBit test")
}
```
