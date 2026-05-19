///|
pub impl ToJson for ChatMessage with to_json(self : ChatMessage) -> Json {
  let content = match self.role {
    Assistant if self.tool_calls.length() > 0 && self.content == "" =>
      Json::null()
    _ => Json::string(self.content)
  }
  let fields : Map[String, Json] = {
    "role": Json::string(self.role.to_string()),
    "content": content,
  }
  match self.role {
    Tool(tool_call_id) => fields.set("tool_call_id", Json::string(tool_call_id))
    _ => ()
  }
  if self.tool_calls.length() > 0 {
    fields.set("tool_calls", ToJson::to_json(self.tool_calls))
  }
  match self.reasoning_content {
    Some(reasoning_content) =>
      fields.set("reasoning_content", Json::string(reasoning_content))
    None => ()
  }
  Json::object(fields)
}

///|
pub impl ToJson for ToolDefinition with to_json(self : ToolDefinition) -> Json {
  let function_fields : Map[String, Json] = {
    "name": Json::string(self.name),
    "description": Json::string(self.description),
    "parameters": self.parameters,
  }
  if self.strict {
    function_fields.set("strict", Json::boolean(true))
  }
  Json::object({
    "type": Json::string("function"),
    "function": Json::object(function_fields),
  })
}

///|
pub impl ToJson for ToolCall with to_json(self : ToolCall) -> Json {
  Json::object({
    "id": Json::string(self.id),
    "type": Json::string("function"),
    "function": Json::object({
      "name": Json::string(self.name),
      "arguments": Json::string(self.arguments),
    }),
  })
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
test "tool messages include tool call id" {
  let body = ToJson::to_json(
    ChatMessage(Tool("call_123"), content="tool result"),
  )
  let text = body.stringify()
  assert_true(text.contains("\"role\":\"tool\""))
  assert_true(text.contains("\"tool_call_id\":\"call_123\""))
}

///|
test "tool definitions encode as native DeepSeek tools" {
  let tool = ToolDefinition(
    "get_weather",
    "Get weather for a location.",
    {
      "type": "object",
      "properties": { "location": { "type": "string" } },
      "required": ["location"],
    },
    strict=true,
  )
  let body = ToJson::to_json(tool)
  let text = body.stringify()
  assert_true(text.contains("\"type\":\"function\""))
  assert_true(text.contains("\"name\":\"get_weather\""))
  assert_true(text.contains("\"strict\":true"))
}

///|
test "assistant tool call messages encode tool_calls" {
  let body = ToJson::to_json(
    ChatMessage(
      Assistant,
      content="",
      tool_calls=[
        ToolCall(
          id="call_123",
          name="get_weather",
          arguments="{\"location\":\"Hangzhou\"}",
        ),
      ],
      reasoning_content="checked available tools",
    ),
  )
  let text = body.stringify()
  assert_true(text.contains("\"role\":\"assistant\""))
  assert_true(text.contains("\"content\":null"))
  assert_true(text.contains("\"tool_calls\""))
  assert_true(text.contains("\"id\":\"call_123\""))
  assert_true(
    text.contains("\"reasoning_content\":\"checked available tools\""),
  )
}

///|
test "assistant tool call messages preserve content when present" {
  let body = ToJson::to_json(
    ChatMessage(Assistant, content="I will check that now.", tool_calls=[
      ToolCall(
        id="call_123",
        name="get_weather",
        arguments="{\"location\":\"Hangzhou\"}",
      ),
    ]),
  )
  let text = body.stringify()
  assert_true(text.contains("\"content\":\"I will check that now.\""))
  assert_true(text.contains("\"tool_calls\""))
}

///|
fn[T] json_decode_error(
  path : @json.JsonPath,
  message : String,
) -> T raise @json.JsonDecodeError {
  raise JsonDecodeError((path, message))
}

///|
pub impl FromJson for Usage with from_json(json : Json, _path : @json.JsonPath) -> Usage {
  Usage::from_json(json)
}

///|
pub impl FromJson for ToolCall with from_json(
  json : Json,
  path : @json.JsonPath,
) -> ToolCall {
  guard json is Object(fields) else {
    json_decode_error(path, "ToolCall::from_json: expected object")
  }
  guard fields.get("id") is Some(String(id)) else {
    json_decode_error(path.add_key("id"), "ToolCall::from_json: expected id")
  }
  guard fields.get("function") is Some(Object(function_fields)) else {
    json_decode_error(
      path.add_key("function"),
      "ToolCall::from_json: expected function object",
    )
  }
  guard function_fields.get("name") is Some(String(name)) else {
    json_decode_error(
      path.add_key("function").add_key("name"),
      "ToolCall::from_json: expected function.name",
    )
  }
  guard function_fields.get("arguments") is Some(String(arguments)) else {
    json_decode_error(
      path.add_key("function").add_key("arguments"),
      "ToolCall::from_json: expected function.arguments",
    )
  }
  ToolCall(id~, name~, arguments~)
}

///|
/// Decodes a DeepSeek chat completions JSON response envelope.
///
/// Missing usage information is represented as zero token counts.
pub impl FromJson for ChatResponse with from_json(
  json : Json,
  path : @json.JsonPath,
) -> ChatResponse {
  guard json is Object(parsed_fields) else {
    json_decode_error(path, "ChatResponse::from_json: expected response object")
  }
  let choices_path = path.add_key("choices")
  guard parsed_fields.get("choices") is Some(Array(choices)) else {
    json_decode_error(
      choices_path, "ChatResponse::from_json: expected choices array",
    )
  }
  guard choices.length() > 0 else {
    json_decode_error(choices_path, "ChatResponse::from_json: empty choices")
  }
  let choice_path = choices_path.add_index(0)
  guard choices[0] is Object(choice_fields) else {
    json_decode_error(
      choice_path, "ChatResponse::from_json: expected choice object",
    )
  }
  let message_path = choice_path.add_key("message")
  guard choice_fields.get("message") is Some(Object(message_fields)) else {
    json_decode_error(
      message_path, "ChatResponse::from_json: expected message object",
    )
  }
  let tool_calls = decode_tool_calls(message_fields, message_path)
  let content = match message_fields.get("content") {
    Some(String(content)) => content
    Some(Null) => ""
    None if tool_calls.length() > 0 => ""
    _ =>
      json_decode_error(
        message_path.add_key("content"),
        "ChatResponse::from_json: expected message content",
      )
  }
  let reasoning_content = match message_fields.get("reasoning_content") {
    Some(String(reasoning_content)) => reasoning_content
    Some(Null) | None => ""
    _ =>
      json_decode_error(
        message_path.add_key("reasoning_content"),
        "ChatResponse::from_json: expected reasoning_content string",
      )
  }
  let usage = match parsed_fields.get("usage") {
    Some(usage) => FromJson::from_json(usage, path.add_key("usage"))
    None => Usage::empty()
  }
  { content, reasoning_content, tool_calls, usage }
}

///|
fn decode_tool_calls(
  message_fields : Map[String, Json],
  message_path : @json.JsonPath,
) -> Array[ToolCall] raise @json.JsonDecodeError {
  match message_fields.get("tool_calls") {
    Some(Array(tool_calls)) => {
      let decoded : Array[ToolCall] = []
      for index, tool_call in tool_calls {
        decoded.push(
          FromJson::from_json(
            tool_call,
            message_path.add_key("tool_calls").add_index(index),
          ),
        )
      }
      decoded
    }
    Some(Null) | None => []
    _ =>
      json_decode_error(
        message_path.add_key("tool_calls"),
        "ChatResponse::from_json: expected tool_calls array",
      )
  }
}

///|
test "parse chat response extracts content and usage" {
  let response : ChatResponse = @json.from_json(
    @json.parse(
      (
        #|{"choices":[{"message":{"content":"{\"action\":\"finish\",\"args\":{\"answer\":\"ok\"}}"}}],"usage":{"prompt_tokens":10,"completion_tokens":4,"total_tokens":14,"prompt_cache_hit_tokens":7,"prompt_cache_miss_tokens":3}}
      ),
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
  assert_eq(response.tool_calls.length(), 0)
  assert_eq(response.reasoning_content, "")
}

///|
test "parse chat response extracts native tool calls" {
  let response : ChatResponse = @json.from_json(
    @json.parse(
      (
        #|{"choices":[{"finish_reason":"tool_calls","message":{"content":null,"reasoning_content":"need current weather","role":"assistant","tool_calls":[{"id":"call_123","type":"function","function":{"name":"get_weather","arguments":"{\"location\":\"Hangzhou\"}"}}]}}],"usage":{"total_tokens":20}}
      ),
    ),
  )
  assert_eq(response.content, "")
  assert_eq(response.reasoning_content, "need current weather")
  assert_eq(response.tool_calls.length(), 1)
  assert_eq(response.tool_calls[0].id, "call_123")
  assert_eq(response.tool_calls[0].name, "get_weather")
  assert_eq(response.tool_calls[0].arguments, "{\"location\":\"Hangzhou\"}")
  assert_eq(response.usage.total_tokens, 20)
}
