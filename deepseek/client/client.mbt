///|
let default_api_url : String = "https://api.deepseek.com/chat/completions"

///|
let default_model : @deepseek.Model = @deepseek.V4Flash

///|
/// HTTP client for the DeepSeek chat completions API.
pub struct Client {
  priv api_key : String
  model : @deepseek.Model
  api_url : String
}

///|
pub impl Debug for Client with to_repr(self : Client) -> Repr {
  Repr::record({
    "api_key": Repr::string("<redacted>"),
    "model": to_repr(self.model),
    "api_url": to_repr(self.api_url),
  })
}

///|
/// Constructs a DeepSeek HTTP client.
///
/// `model` defaults to `deepseek-v4-flash`; `api_url` defaults to the DeepSeek
/// chat completions endpoint.
pub fn Client::Client(
  api_key : String,
  model? : @deepseek.Model = default_model,
  api_url? : String = default_api_url,
) -> Client {
  { api_key, model, api_url }
}

///|
/// Sends typed chat messages to DeepSeek and decodes the response.
///
/// Set `json_response=true` to request a JSON object response format.
pub async fn Client::chat(
  self : Client,
  messages : Array[@deepseek.ChatMessage],
  json_response? : Bool = false,
) -> @deepseek.ChatResponse {
  let body = @deepseek.encode_chat_request(self.model, messages, json_response~)
  let (resp, data) = @http.post(self.api_url, body, headers={
    "Content-Type": "application/json",
    "Authorization": "Bearer " + self.api_key,
  })
  let text = data.text()
  guard resp.code >= 200 && resp.code < 300 else {
    fail("DeepSeek API error \{resp.code}: \{text}")
  }
  @deepseek.decode_chat_response(text)
}
