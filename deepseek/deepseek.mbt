///|
let default_api_url : String = "https://api.deepseek.com/chat/completions"

///|
let default_model : Model = V4Flash

///|
pub(all) enum Model {
  V4Flash
  V4Pro
} derive(Eq)

///|
pub fn Model::to_string(self : Model) -> String {
  match self {
    V4Flash => "deepseek-v4-flash"
    V4Pro => "deepseek-v4-pro"
  }
}

///|
pub fn Model::parse(input : String) -> Model raise {
  match input {
    "deepseek-v4-flash" => V4Flash
    "deepseek-v4-pro" => V4Pro
    other => fail("unknown DeepSeek model: \{other}")
  }
}

///|
pub(all) enum Role {
  System
  User
  Assistant
  Tool(String)
} derive(Eq)

///|
pub fn Role::to_string(self : Role) -> String {
  match self {
    System => "system"
    User => "user"
    Assistant => "assistant"
    Tool(_) => "tool"
  }
}

///|
pub struct Client {
  priv api_key : String
  model : Model
  api_url : String
}

///|
pub fn Client::Client(
  api_key : String,
  model? : Model = default_model,
  api_url? : String = default_api_url,
) -> Client {
  { api_key, model, api_url }
}

///|
pub struct ChatMessage {
  role : Role
  content : String
}

///|
pub fn ChatMessage::ChatMessage(role : Role, content : String) -> ChatMessage {
  { role, content }
}

///|
pub fn ChatMessage::system(content : String) -> ChatMessage {
  ChatMessage(System, content)
}

///|
pub fn ChatMessage::user(content : String) -> ChatMessage {
  ChatMessage(User, content)
}

///|
pub fn ChatMessage::assistant(content : String) -> ChatMessage {
  ChatMessage(Assistant, content)
}

///|
pub fn ChatMessage::tool(
  tool_call_id : String,
  content : String,
) -> ChatMessage {
  ChatMessage(Tool(tool_call_id), content)
}

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
pub struct Usage {
  prompt_tokens : Int
  completion_tokens : Int
  total_tokens : Int
  prompt_cache_hit_tokens : Int
  prompt_cache_miss_tokens : Int
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
pub struct ChatResponse {
  content : String
  usage : Usage
}

///|
pub async fn Client::chat(
  self : Client,
  messages : Array[ChatMessage],
  json_response? : Bool = false,
) -> ChatResponse {
  let body = request_body(self.model, messages, json_response~)
  let (resp, data) = @http.post(self.api_url, body, headers={
    "Content-Type": "application/json",
    "Authorization": "Bearer " + self.api_key,
  })
  let text = data.text()
  guard resp.code >= 200 && resp.code < 300 else {
    fail("DeepSeek API error \{resp.code}: \{text}")
  }
  parse_chat_response(text)
}

///|
fn request_body(
  model : Model,
  messages : Array[ChatMessage],
  json_response~ : Bool,
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
  let body = request_body(
    V4Flash,
    [ChatMessage::system("json only"), ChatMessage::user("ping")],
    json_response=true,
  )
  let text = body.stringify()
  assert_true(text.contains("\"response_format\""))
  assert_true(text.contains("\"json_object\""))
}

///|
test "tool messages include tool call id" {
  let body = request_body(
    V4Pro,
    [ChatMessage::tool("call_123", "tool result")],
    json_response=false,
  )
  let text = body.stringify()
  assert_true(text.contains("\"role\":\"tool\""))
  assert_true(text.contains("\"tool_call_id\":\"call_123\""))
}

///|
fn parse_chat_response(text : String) -> ChatResponse raise {
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
