///|
let default_api_url : String = "https://api.deepseek.com/chat/completions"

///|
let default_model : String = "deepseek-v4-flash"

///|
pub struct Client {
  priv api_key : String
  model : String
  api_url : String
}

///|
pub fn Client::new(
  api_key : String,
  model? : String = default_model,
  api_url? : String = default_api_url,
) -> Client {
  { api_key, model, api_url }
}

///|
pub struct ChatMessage {
  role : String
  content : String
}

///|
pub fn ChatMessage::new(role : String, content : String) -> ChatMessage {
  { role, content }
}

///|
pub fn ChatMessage::system(content : String) -> ChatMessage {
  { role: "system", content }
}

///|
pub fn ChatMessage::user(content : String) -> ChatMessage {
  { role: "user", content }
}

///|
pub fn ChatMessage::assistant(content : String) -> ChatMessage {
  { role: "assistant", content }
}

///|
fn ChatMessage::to_json(self : ChatMessage) -> Json {
  { "role": self.role, "content": self.content }
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
  model : String,
  messages : Array[ChatMessage],
  json_response~ : Bool,
) -> Json {
  let fields : Map[String, Json] = Map([
    ("model", Json::string(model)),
    ("messages", Json::array(messages.map(message => message.to_json()))),
    ("stream", Json::boolean(false)),
  ])
  if json_response {
    fields.set("response_format", { "type": "json_object" })
  }
  Json::object(fields)
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
