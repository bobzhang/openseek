///|
fn ChatMessage::to_json(self : ChatMessage) -> Json {
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
fn Usage::from_json(json : Json) -> Usage {
  {
    prompt_tokens: field_int(json, "prompt_tokens"),
    completion_tokens: field_int(json, "completion_tokens"),
    total_tokens: field_int(json, "total_tokens"),
    prompt_cache_hit_tokens: field_int(json, "prompt_cache_hit_tokens"),
    prompt_cache_miss_tokens: field_int(json, "prompt_cache_miss_tokens"),
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
/// Encodes typed chat request values into the DeepSeek chat completions JSON
/// request body.
pub fn encode_chat_request(
  model : Model,
  messages : Array[ChatMessage],
  json_response? : Bool = false,
) -> Json {
  let fields : Map[String, Json] = Map([
    ("model", Json::string(model.to_string())),
    ("messages", Json::array(messages.map(message => message.to_json()))),
    ("stream", Json::boolean(false)),
  ])
  if json_response {
    fields.set("response_format", { "type": "json_object" })
  }
  Json::object(fields)
}

///|
test "request body can request json output" {
  let body = encode_chat_request(
    V4Flash,
    [ChatMessage(System, "json only"), ChatMessage(User, "ping")],
    json_response=true,
  )
  let text = body.stringify()
  assert_true(text.contains("\"response_format\""))
  assert_true(text.contains("\"json_object\""))
}

///|
test "tool messages include tool call id" {
  let body = encode_chat_request(
    V4Pro,
    [ChatMessage(Tool("call_123"), "tool result")],
    json_response=false,
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
  guard field(parsed, "choices") is Some(Array(choices)) else {
    fail("DeepSeek response is missing choices: \{text}")
  }
  guard choices.length() > 0 else {
    fail("DeepSeek response has empty choices: \{text}")
  }
  guard field(choices[0], "message") is Some(message) else {
    fail("DeepSeek response choice is missing message: \{text}")
  }
  guard field(message, "content") is Some(String(content)) else {
    fail("DeepSeek response message is missing content: \{text}")
  }
  let usage = match field(parsed, "usage") {
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

///|
fn field(json : Json, key : String) -> Json? {
  match json {
    Object(fields) => fields.get(key)
    _ => None
  }
}

///|
fn field_int(json : Json, key : String) -> Int {
  match field(json, key) {
    Some(Number(n, ..)) => n.to_int()
    _ => 0
  }
}
