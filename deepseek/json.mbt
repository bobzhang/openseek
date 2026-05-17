///|
pub impl ToJson for ChatMessage with to_json(self : ChatMessage) -> Json {
  let content = match self.role {
    Assistant if self.tool_calls.length() > 0 => Json::null()
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
  Json::object(fields)
}

///|
pub impl ToJson for FunctionTool with to_json(self : FunctionTool) -> Json {
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
pub impl ToJson for Conversation with to_json(self : Conversation) -> Json {
  Json::object(
    Map(
      [
        ("model", Json::string(self.model.to_string())),
        ("messages", ToJson::to_json(self.messages)),
        ("stream", Json::boolean(false)),
        ..if self.tools.length() > 0 {
          [("tools", ToJson::to_json(self.tools))]
        } else {
          []
        },
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
test "function tools encode as native DeepSeek tools" {
  let tool = FunctionTool(
    "get_weather",
    "Get weather for a location.",
    {
      "type": "object",
      "properties": { "location": { "type": "string" } },
      "required": ["location"],
    },
    strict=true,
  )
  let body = ToJson::to_json(
    Conversation(V4Pro, [ChatMessage(User, "weather")], tools=[tool]),
  )
  let text = body.stringify()
  assert_true(text.contains("\"tools\""))
  assert_true(text.contains("\"type\":\"function\""))
  assert_true(text.contains("\"name\":\"get_weather\""))
  assert_true(text.contains("\"strict\":true"))
}

///|
test "assistant tool call messages encode tool_calls" {
  let body = ToJson::to_json(
    ChatMessage::assistant_tool_calls([
      ToolCall("call_123", "get_weather", "{\"location\":\"Hangzhou\"}"),
    ]),
  )
  let text = body.stringify()
  assert_true(text.contains("\"role\":\"assistant\""))
  assert_true(text.contains("\"content\":null"))
  assert_true(text.contains("\"tool_calls\""))
  assert_true(text.contains("\"id\":\"call_123\""))
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
  let tool_calls = decode_tool_calls(message_fields, text)
  let content = match message_fields.get("content") {
    Some(String(content)) => content
    Some(Null) => ""
    None if tool_calls.length() > 0 => ""
    _ => fail("DeepSeek response message is missing content: \{text}")
  }
  let usage = match parsed_fields.get("usage") {
    Some(usage) => Usage::from_json(usage)
    None => Usage::empty()
  }
  { content, tool_calls, usage }
}

///|
fn decode_tool_calls(
  message_fields : Map[String, Json],
  text : String,
) -> Array[ToolCall] raise {
  match message_fields.get("tool_calls") {
    Some(Array(tool_calls)) => {
      let decoded : Array[ToolCall] = []
      for tool_call in tool_calls {
        decoded.push(ToolCall::from_json(tool_call, text))
      }
      decoded
    }
    Some(Null) | None => []
    _ => fail("DeepSeek response message has invalid tool_calls: \{text}")
  }
}

///|
fn ToolCall::from_json(json : Json, text : String) -> ToolCall raise {
  guard json is Object(fields) else {
    fail("DeepSeek tool call is not an object: \{text}")
  }
  guard fields.get("id") is Some(String(id)) else {
    fail("DeepSeek tool call is missing id: \{text}")
  }
  guard fields.get("function") is Some(Object(function_fields)) else {
    fail("DeepSeek tool call is missing function: \{text}")
  }
  guard function_fields.get("name") is Some(String(name)) else {
    fail("DeepSeek tool call is missing function.name: \{text}")
  }
  guard function_fields.get("arguments") is Some(String(arguments)) else {
    fail("DeepSeek tool call is missing function.arguments: \{text}")
  }
  ToolCall(id, name, arguments)
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
  assert_eq(response.tool_calls.length(), 0)
}

///|
test "parse chat response extracts native tool calls" {
  let response = decode_chat_response(
    (
      #|{"choices":[{"finish_reason":"tool_calls","message":{"content":null,"role":"assistant","tool_calls":[{"id":"call_123","type":"function","function":{"name":"get_weather","arguments":"{\"location\":\"Hangzhou\"}"}}]}}],"usage":{"total_tokens":20}}
    ),
  )
  assert_eq(response.content, "")
  assert_eq(response.tool_calls.length(), 1)
  assert_eq(response.tool_calls[0].id, "call_123")
  assert_eq(response.tool_calls[0].name, "get_weather")
  assert_eq(response.tool_calls[0].arguments, "{\"location\":\"Hangzhou\"}")
  assert_eq(response.usage.total_tokens, 20)
}
