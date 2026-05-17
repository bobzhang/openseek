///|
pub impl ToJson for ChatMessage with to_json(self : ChatMessage) -> Json {
  let fields : Map[String, Json] = {
    "role": self.role.to_string(),
    "content": self.content,
  }
  match self.role {
    Tool(tool_call_id) => fields.set("tool_call_id", Json::string(tool_call_id))
    _ => ()
  }
  Json::object(fields)
}

///|
pub impl ToJson for Conversation with to_json(self : Conversation) -> Json {
  Json::object(
    Map(
      [
        ("model", Json::string(self.model.to_string())),
        ("messages", ToJson::to_json(self.messages)),
        ("stream", Json::boolean(false)),
        ..if self.json_response {
          [
            (
              "response_format",
              Json::object({ "type": Json::string("json_object") }),
            ),
          ]
        } else {
          []
        },
      ],
    ),
  )
}

///|
fn Usage::from_json(json : Json) -> Usage {
  let fields = match json {
    Object(fields) => fields
    _ => Map([])
  }
  {
    prompt_tokens: match fields.get("prompt_tokens") {
      Some(Number(n, ..)) => n.to_int()
      _ => 0
    },
    completion_tokens: match fields.get("completion_tokens") {
      Some(Number(n, ..)) => n.to_int()
      _ => 0
    },
    total_tokens: match fields.get("total_tokens") {
      Some(Number(n, ..)) => n.to_int()
      _ => 0
    },
    prompt_cache_hit_tokens: match fields.get("prompt_cache_hit_tokens") {
      Some(Number(n, ..)) => n.to_int()
      _ => 0
    },
    prompt_cache_miss_tokens: match fields.get("prompt_cache_miss_tokens") {
      Some(Number(n, ..)) => n.to_int()
      _ => 0
    },
  }
}

///|
fn Usage::empty() -> Usage {
  {
    prompt_tokens: 0,
    completion_tokens: 0,
    total_tokens: 0,
    prompt_cache_hit_tokens: 0,
    prompt_cache_miss_tokens: 0,
  }
}

///|
test "request body can request json output" {
  let body = ToJson::to_json(
    Conversation(
      V4Flash,
      [ChatMessage(System, "json only"), ChatMessage(User, "ping")],
      json_response=true,
    ),
  )
  let text = body.stringify()
  assert_true(text.contains("\"response_format\""))
  assert_true(text.contains("\"json_object\""))
  guard body is Object(body_fields) else {
    fail("request body is not an object")
  }
  guard body_fields.get("response_format") is Some(Object(format)) else {
    fail("missing response_format")
  }
  guard format.get("type") is Some(String("json_object")) else {
    fail("wrong response_format")
  }
}

///|
test "conversation encodes chat request body" {
  let body = ToJson::to_json(
    Conversation(V4Flash, [ChatMessage(User, "hello")], json_response=true),
  )
  let text = body.stringify()
  assert_true(text.contains("\"model\":\"deepseek-v4-flash\""))
  assert_true(text.contains("\"messages\""))
  assert_true(text.contains("\"response_format\""))
}

///|
test "tool messages include tool call id" {
  let body = ToJson::to_json(
    Conversation(
      V4Pro,
      [ChatMessage(Tool("call_123"), "tool result")],
      json_response=false,
    ),
  )
  let text = body.stringify()
  assert_true(text.contains("\"role\":\"tool\""))
  assert_true(text.contains("\"tool_call_id\":\"call_123\""))
}

///|
/// Decodes a DeepSeek chat completions JSON response body.
///
/// Missing usage information is represented as zero token counts.
pub fn decode_chat_response(text : String) -> ChatResponse raise {
  let parsed = @json.parse(text)
  guard parsed is Object(parsed_fields) else {
    fail("DeepSeek response is missing choices: \{text}")
  }
  guard parsed_fields.get("choices") is Some(Array(choices)) else {
    fail("DeepSeek response is missing choices: \{text}")
  }
  guard choices.length() > 0 else {
    fail("DeepSeek response has empty choices: \{text}")
  }
  guard choices[0] is Object(choice_fields) else {
    fail("DeepSeek response choice is missing message: \{text}")
  }
  guard choice_fields.get("message") is Some(message) else {
    fail("DeepSeek response choice is missing message: \{text}")
  }
  guard message is Object(message_fields) else {
    fail("DeepSeek response message is missing content: \{text}")
  }
  guard message_fields.get("content") is Some(String(content)) else {
    fail("DeepSeek response message is missing content: \{text}")
  }
  let usage = match parsed_fields.get("usage") {
    Some(usage) => Usage::from_json(usage)
    None => Usage::empty()
  }
  { content, usage }
}

///|
test "parse chat response extracts content and usage" {
  let response = decode_chat_response(
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
