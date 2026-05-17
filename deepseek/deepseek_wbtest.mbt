///|
test "request body can request json output" {
  let body = request_body(
    "deepseek-v4-flash",
    [ChatMessage::system("json only"), ChatMessage::user("ping")],
    json_response=true,
  )
  let text = body.stringify()
  assert_true(text.contains("\"response_format\""))
  assert_true(text.contains("\"json_object\""))
}

///|
test "parse chat response extracts content and usage" {
  let response = parse_chat_response(
    (
      #|{"choices":[{"message":{"content":"{\"action\":\"finish\",\"args\":{\"answer\":\"ok\"}}"}}],"usage":{"prompt_tokens":10,"completion_tokens":4,"total_tokens":14,"prompt_cache_hit_tokens":7,"prompt_cache_miss_tokens":3}}
    ),
  )
  assert_eq(
    response.content,
    "{\"action\":\"finish\",\"args\":{\"answer\":\"ok\"}}",
  )
  assert_eq(response.usage.prompt_tokens, 10)
  assert_eq(response.usage.completion_tokens, 4)
  assert_eq(response.usage.prompt_cache_hit_tokens, 7)
  assert_eq(response.usage.prompt_cache_miss_tokens, 3)
}
