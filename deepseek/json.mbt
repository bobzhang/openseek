///|
/// Encodes a `ChatMessage` as the DeepSeek chat completions wire object.
///
/// Assistant messages whose `content` is empty but carry tool calls are
/// encoded with JSON `content: null`, as the API requires.
pub fn encode_chat_message(message : ChatMessage) -> Json {
  let content = match message.role {
    Assistant if message.tool_calls.length() > 0 && message.content == "" =>
      Json::null()
    _ => Json::string(message.content)
  }
  let fields : Map[String, Json] = {
    "role": Json::string(message.role.to_string()),
    "content": content,
  }
  match message.role {
    Tool(tool_call_id) => fields.set("tool_call_id", Json::string(tool_call_id))
    _ => ()
  }
  if message.tool_calls.length() > 0 {
    fields.set(
      "tool_calls",
      Json::array([ for call in message.tool_calls => encode_tool_call(call) ]),
    )
  }
  match message.reasoning_content {
    Some(reasoning_content) =>
      fields.set("reasoning_content", Json::string(reasoning_content))
    None => ()
  }
  Json::object(fields)
}

///|
/// Encodes a `ToolDefinition` as a DeepSeek `tools[]` entry.
pub fn encode_tool_definition(tool : ToolDefinition) -> Json {
  let function_fields : Map[String, Json] = {
    "name": Json::string(tool.name),
    "description": Json::string(tool.description),
    "parameters": tool.parameters,
  }
  if tool.strict {
    function_fields.set("strict", Json::boolean(true))
  }
  Json::object({
    "type": Json::string("function"),
    "function": Json::object(function_fields),
  })
}

///|
/// Encodes a `ToolCall` as the DeepSeek assistant `tool_calls[]` entry.
pub fn encode_tool_call(call : ToolCall) -> Json {
  Json::object({
    "id": Json::string(call.id),
    "type": Json::string("function"),
    "function": Json::object({
      "name": Json::string(call.name),
      "arguments": Json::string(call.arguments),
    }),
  })
}

///|
/// Encodes a DeepSeek chat completions request body.
///
/// The request always asks for a JSON object response. `tools`, `thinking`,
/// and `reasoning_effort` are omitted when empty / `None`.
pub fn encode_chat_request(
  model : Model,
  messages : Array[ChatMessage],
  tools? : Array[ToolDefinition] = [],
  thinking? : ThinkingMode,
  reasoning_effort? : ReasoningEffort,
) -> Json {
  let fields : Array[(String, Json)] = [
    ("model", Json::string(model.to_string())),
    (
      "messages",
      Json::array([ for message in messages => encode_chat_message(message) ]),
    ),
    ("stream", Json::boolean(false)),
    ("response_format", Json::object({ "type": Json::string("json_object") })),
  ]
  if tools.length() > 0 {
    fields.push(
      (
        "tools",
        Json::array([ for tool in tools => encode_tool_definition(tool) ]),
      ),
    )
  }
  match thinking {
    Some(thinking) =>
      fields.push(
        (
          "thinking",
          Json::object({ "type": Json::string(thinking.to_string()) }),
        ),
      )
    None => ()
  }
  match reasoning_effort {
    Some(reasoning_effort) =>
      fields.push(
        ("reasoning_effort", Json::string(reasoning_effort.to_string())),
      )
    None => ()
  }
  Json::object(Map(fields))
}

///|
fn Usage::from_json(json : Json) -> Usage {
  {
    prompt_tokens: match json {
      { "prompt_tokens": Number(n, ..), .. } => n.to_int()
      _ => 0
    },
    completion_tokens: match json {
      { "completion_tokens": Number(n, ..), .. } => n.to_int()
      _ => 0
    },
    total_tokens: match json {
      { "total_tokens": Number(n, ..), .. } => n.to_int()
      _ => 0
    },
    prompt_cache_hit_tokens: match json {
      { "prompt_cache_hit_tokens": Number(n, ..), .. } => n.to_int()
      _ => 0
    },
    prompt_cache_miss_tokens: match json {
      { "prompt_cache_miss_tokens": Number(n, ..), .. } => n.to_int()
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
  let body = encode_chat_message(
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
  let body = encode_tool_definition(tool)
  let text = body.stringify()
  assert_true(text.contains("\"type\":\"function\""))
  assert_true(text.contains("\"name\":\"get_weather\""))
  assert_true(text.contains("\"strict\":true"))
}

///|
test "assistant tool call messages encode tool_calls" {
  let body = encode_chat_message(
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
  let body = encode_chat_message(
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
  match json {
    {
      "id": String(id),
      "function": { "name": String(name), "arguments": String(arguments), .. },
      ..
    } => ToolCall(id~, name~, arguments~)
    {
      "id": String(_),
      "function": { "name": String(_), "arguments": _, .. },
      ..
    } =>
      json_decode_error(
        path.add_key("function").add_key("arguments"),
        "ToolCall::from_json: expected function.arguments",
      )
    { "id": String(_), "function": { "name": String(_), .. }, .. } =>
      json_decode_error(
        path.add_key("function").add_key("arguments"),
        "ToolCall::from_json: expected function.arguments",
      )
    { "id": String(_), "function": { "name": _, .. }, .. } =>
      json_decode_error(
        path.add_key("function").add_key("name"),
        "ToolCall::from_json: expected function.name",
      )
    Object({ "id": String(_), "function": Object(_), .. }) =>
      json_decode_error(
        path.add_key("function").add_key("name"),
        "ToolCall::from_json: expected function.name",
      )
    Object({ "id": String(_), "function": _, .. }) =>
      json_decode_error(
        path.add_key("function"),
        "ToolCall::from_json: expected function object",
      )
    Object({ "id": String(_), .. }) =>
      json_decode_error(
        path.add_key("function"),
        "ToolCall::from_json: expected function object",
      )
    Object({ "id": _, .. }) =>
      json_decode_error(path.add_key("id"), "ToolCall::from_json: expected id")
    Object(_) =>
      json_decode_error(path.add_key("id"), "ToolCall::from_json: expected id")
    _ => json_decode_error(path, "ToolCall::from_json: expected object")
  }
}

///|
/// Decodes a DeepSeek chat completions JSON response envelope.
///
/// Missing usage information is represented as zero token counts.
pub impl FromJson for ChatResponse with from_json(
  json : Json,
  path : @json.JsonPath,
) -> ChatResponse {
  let message_path = path.add_key("choices").add_index(0).add_key("message")
  let (message_fields, usage_json) : (Map[String, Json], Json?) = match json {
    {
      "choices": [{ "message": Object(message_fields), .. }, ..],
      "usage": usage_json,
      ..
    } => (message_fields, Some(usage_json))
    { "choices": [{ "message": Object(message_fields), .. }, ..], .. } =>
      (message_fields, None)
    { "choices": [], .. } =>
      json_decode_error(
        path.add_key("choices"),
        "ChatResponse::from_json: empty choices",
      )
    { "choices": [Object({ "message": _, .. }), ..], .. } =>
      json_decode_error(
        message_path, "ChatResponse::from_json: expected message object",
      )
    { "choices": [Object(_), ..], .. } =>
      json_decode_error(
        message_path, "ChatResponse::from_json: expected message object",
      )
    { "choices": [_, ..], .. } =>
      json_decode_error(
        path.add_key("choices").add_index(0),
        "ChatResponse::from_json: expected choice object",
      )
    { "choices": _, .. } =>
      json_decode_error(
        path.add_key("choices"),
        "ChatResponse::from_json: expected choices array",
      )
    Object(_) =>
      json_decode_error(
        path.add_key("choices"),
        "ChatResponse::from_json: expected choices array",
      )
    _ =>
      json_decode_error(
        path, "ChatResponse::from_json: expected response object",
      )
  }
  let tool_calls = match message_fields {
    { "tool_calls": Array(raw_tool_calls), .. } => {
      let tool_call_results = [
        for index, tool_call in raw_tool_calls => {
          try? FromJson::from_json(
            tool_call,
            message_path.add_key("tool_calls").add_index(index),
          )
        }
      ]
      let decoded : Array[ToolCall] = []
      for result in tool_call_results {
        match result {
          Ok(tool_call) => decoded.push(tool_call)
          Err(error) => raise error
        }
      }
      decoded
    }
    { "tool_calls": Null, .. } => []
    { "tool_calls": _, .. } =>
      json_decode_error(
        message_path.add_key("tool_calls"),
        "ChatResponse::from_json: expected tool_calls array",
      )
    _ => []
  }
  let content = match message_fields {
    { "content": String(content), .. } => content
    { "content": Null, .. } => ""
    { "content": _, .. } =>
      json_decode_error(
        message_path.add_key("content"),
        "ChatResponse::from_json: expected message content",
      )
    _ if tool_calls.length() > 0 => ""
    _ =>
      json_decode_error(
        message_path.add_key("content"),
        "ChatResponse::from_json: expected message content",
      )
  }
  let reasoning_content = match message_fields {
    { "reasoning_content": String(reasoning_content), .. } => reasoning_content
    { "reasoning_content": Null, .. } => ""
    { "reasoning_content": _, .. } =>
      json_decode_error(
        message_path.add_key("reasoning_content"),
        "ChatResponse::from_json: expected reasoning_content string",
      )
    _ => ""
  }
  let usage = match usage_json {
    Some(usage) => FromJson::from_json(usage, path.add_key("usage"))
    None => Usage::empty()
  }
  { content, reasoning_content, tool_calls, usage }
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
