///|
async test "realworld DeepSeek API smoke test" {
  match @env.get_env_var("DEEPSEEK") {
    Some(api_key) if api_key != "" => {
      let client = @deepseek.Client(api_key)
      let response = client.chat(
        [
          @deepseek.ChatMessage(
            @deepseek.System,
            "Reply with exactly this JSON object and no markdown: {\"answer\":\"pong\"}",
          ),
          @deepseek.ChatMessage(@deepseek.User, "ping"),
        ],
        json_response=true,
      )
      assert_true(response.content.contains("pong"))
      assert_true(response.usage.total_tokens > 0)
    }
    _ => ()
  }
}
