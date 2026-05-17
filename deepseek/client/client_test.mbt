///|
test "client defaults" {
  let client = @client.Client("test-key")
  inspect(client.model, content="deepseek-v4-flash")
  assert_eq(client.api_url, "https://api.deepseek.com/chat/completions")
}

///|
test "client debug redacts api key" {
  let client = @client.Client("test-key")
  let rendered = to_repr(client).to_string()
  assert_true(rendered.contains("<redacted>"))
  assert_false(rendered.contains("test-key"))
}
