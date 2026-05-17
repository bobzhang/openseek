///|
async test "realworld DeepSeek API smoke test" {
  guard @env.get_env_var("DEEPSEEK") is Some(api_key) && api_key != "" else {
    return
  }

  let client = @client.Client(api_key)
  let response = client.chat(json_response=true) <| [
      ChatMessage(
        System,
        (
          #|Reply with exactly this JSON object and no markdown: {"answer":"pong"}
        ),
      ),
      ChatMessage(User, "ping"),
    ]
  // It may fail in theory, but in practice it should always work.
  debug_inspect(
    response.content,
    content=(
      #|"{\"answer\":\"pong\"}"
    ),
  )
  assert_true(response.content.contains("pong"))
  assert_true(response.usage.total_tokens > 0)
}
