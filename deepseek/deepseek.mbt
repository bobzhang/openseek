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
pub impl Show for Model with to_string(self : Model) -> String {
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
pub impl Show for Role with to_string(self : Role) -> String {
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
pub struct Usage {
  prompt_tokens : Int
  completion_tokens : Int
  total_tokens : Int
  prompt_cache_hit_tokens : Int
  prompt_cache_miss_tokens : Int
}

///|
pub struct ChatResponse {
  content : String
  usage : Usage
}
