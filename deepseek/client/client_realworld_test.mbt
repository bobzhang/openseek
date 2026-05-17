///|
async test "realworld DeepSeek API smoke test" {
  match @env.get_env_var("DEEPSEEK") {
    Some(api_key) if api_key != "" => {
      let client = @client.Client(api_key)
      let response = client.chat(
        [
          ChatMessage(
            System,
            "Reply with exactly this JSON object and no markdown: {\"answer\":\"pong\"}",
          ),
          ChatMessage(User, "ping"),
        ],
        json_response=true,
      )
      assert_true(response.content.contains("pong"))
      assert_true(response.usage.total_tokens > 0)
    }
    _ => ()
  }
}
