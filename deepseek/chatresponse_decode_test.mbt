///|
fn decode_chat_response(text : String) -> @deepseek.ChatResponse raise {
  @json.from_json(@json.parse(text))
}

///|
fn chat_response_decode_fails(text : String) -> Bool {
  try decode_chat_response(text) catch {
    _ => true
  } noraise {
    _ => false
  }
}

///|
test "chat response decode keeps first choice and usage" {
  let response = decode_chat_response(
    (
      #|{"id":"resp_1","choices":[{"index":0,"message":{"role":"assistant","content":"first","reasoning_content":null,"tool_calls":null}},{"index":1,"message":{"content":"second"}}],"usage":{"prompt_tokens":2,"completion_tokens":3,"total_tokens":5},"ignored":true}
    ),
  )
  assert_eq(response.content, "first")
  assert_eq(response.reasoning_content, "")
  assert_eq(response.tool_calls.length(), 0)
  assert_eq(response.usage.prompt_tokens, 2)
  assert_eq(response.usage.completion_tokens, 3)
  assert_eq(response.usage.total_tokens, 5)
  assert_eq(response.usage.prompt_cache_hit_tokens, 0)
  assert_eq(response.usage.prompt_cache_miss_tokens, 0)
}

///|
test "chat response decode allows tool call without content or usage" {
  let response = decode_chat_response(
    (
      #|{"choices":[{"message":{"tool_calls":[{"id":"call_1","type":"function","function":{"name":"read","arguments":"{\"path\":\"moon.mod.json\"}"}}]}}]}
    ),
  )
  assert_eq(response.content, "")
  assert_eq(response.reasoning_content, "")
  assert_eq(response.tool_calls.length(), 1)
  assert_eq(response.tool_calls[0].id, "call_1")
  assert_eq(response.tool_calls[0].name, "read")
  assert_eq(response.tool_calls[0].arguments, "{\"path\":\"moon.mod.json\"}")
  assert_eq(response.usage.total_tokens, 0)
}

///|
test "chat response decode keeps multiple tool calls in order" {
  let response = decode_chat_response(
    (
      #|{"choices":[{"message":{"content":null,"tool_calls":[{"id":"call_1","type":"function","function":{"name":"read","arguments":"{\"path\":\"moon.mod.json\"}"}},{"id":"call_2","type":"function","function":{"name":"shell","arguments":"{\"cmd\":\"moon test deepseek\"}"}}]}}]}
    ),
  )
  assert_eq(response.content, "")
  assert_eq(response.tool_calls.length(), 2)
  assert_eq(response.tool_calls[0].id, "call_1")
  assert_eq(response.tool_calls[0].name, "read")
  assert_eq(response.tool_calls[1].id, "call_2")
  assert_eq(response.tool_calls[1].name, "shell")
  assert_eq(
    response.tool_calls[1].arguments,
    "{\"cmd\":\"moon test deepseek\"}",
  )
}

///|
test "chat response decode rejects missing content without tool calls" {
  assert_true(
    chat_response_decode_fails(
      (
        #|{"choices":[{"message":{"role":"assistant"}}]}
      ),
    ),
  )
}

///|
test "chat response decode rejects malformed message fields" {
  assert_true(
    chat_response_decode_fails(
      (
        #|{"choices":[{"message":{"content":1}}]}
      ),
    ),
  )
  assert_true(
    chat_response_decode_fails(
      (
        #|{"choices":[{"message":{"content":"ok","reasoning_content":1}}]}
      ),
    ),
  )
  assert_true(
    chat_response_decode_fails(
      (
        #|{"choices":[{"message":{"content":"ok","tool_calls":{}}}]}
      ),
    ),
  )
}

///|
test "chat response decode rejects malformed nested tool call" {
  assert_true(
    chat_response_decode_fails(
      (
        #|{"choices":[{"message":{"content":null,"tool_calls":[{"id":"call_1","type":"function","function":{"name":"read","arguments":{}}}]}}]}
      ),
    ),
  )
}

///|
test "chat response decode rejects malformed choices" {
  assert_true(
    chat_response_decode_fails(
      (
        #|{"choices":[]}
      ),
    ),
  )
}
