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
