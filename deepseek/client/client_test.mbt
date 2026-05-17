///|
test "client defaults" {
  let client = @client.Client(api_key="test-key")
  inspect(client.model, content="deepseek-v4-flash")
  assert_eq(client.api_url, "https://api.deepseek.com/chat/completions")
}

///|
test "client debug redacts api key" {
  let client = @client.Client(api_key="test-key")
  debug_inspect(
    client,
    content=(
      #|{
      #|  api_key: ...,
      #|  model: V4Flash,
      #|  api_url: "https://api.deepseek.com/chat/completions",
      #|}
    ),
  )
}
