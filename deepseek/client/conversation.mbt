///|
priv struct Conversation {
  model : @deepseek.Model
  messages : Array[@deepseek.ChatMessage]
  tools : Array[@deepseek.ToolDefinition]
  thinking : @deepseek.ThinkingMode?
  reasoning_effort : @deepseek.ReasoningEffort?
}

///|
fn Conversation::Conversation(
  model : @deepseek.Model,
  messages : Array[@deepseek.ChatMessage],
  tools? : Array[@deepseek.ToolDefinition] = [],
  thinking? : @deepseek.ThinkingMode? = None,
  reasoning_effort? : @deepseek.ReasoningEffort? = None,
) -> Conversation {
  { model, messages, tools, thinking, reasoning_effort }
}

///|
impl ToJson for Conversation with to_json(self : Conversation) -> Json {
  Json::object(
    Map(
      [
        ("model", Json::string(self.model.to_string())),
        ("messages", ToJson::to_json(self.messages)),
        ("stream", Json::boolean(false)),
        (
          "response_format",
          Json::object({ "type": Json::string("json_object") }),
        ),
        ..if self.tools.length() > 0 {
          [("tools", ToJson::to_json(self.tools))]
        } else {
          []
        },
        ..match self.thinking {
          Some(thinking) =>
            [
              (
                "thinking",
                Json::object({ "type": Json::string(thinking.to_string()) }),
              ),
            ]
          None => []
        },
        ..match self.reasoning_effort {
          Some(reasoning_effort) =>
            [("reasoning_effort", Json::string(reasoning_effort.to_string()))]
          None => []
        },
      ],
    ),
  )
}

///|
test "conversation always requests json output" {
  let body = ToJson::to_json(
    Conversation(V4Flash, [
      ChatMessage(System, content="json only"),
      ChatMessage(User, content="ping"),
    ]),
  )
  let text = body.stringify()
  assert_true(text.contains("\"response_format\""))
  assert_true(text.contains("\"json_object\""))
  guard body is { "response_format": { "type": String("json_object"), .. }, .. } else {
    fail("wrong response_format")
  }
}

///|
test "conversation encodes tool request body" {
  let tool = @deepseek.ToolDefinition("shell", "Run a shell command.", {
    "type": "object",
    "properties": { "cmd": { "type": "string" } },
    "required": ["cmd"],
  })
  let body = ToJson::to_json(
    Conversation(V4Flash, [ChatMessage(User, content="run tests")], tools=[tool]),
  )
  let text = body.stringify()
  assert_true(text.contains("\"model\":\"deepseek-v4-flash\""))
  assert_true(text.contains("\"messages\""))
  assert_true(text.contains("\"tools\""))
  assert_true(text.contains("\"type\":\"function\""))
  assert_true(text.contains("\"name\":\"shell\""))
  assert_true(text.contains("\"required\""))
}

///|
test "conversation encodes thinking controls" {
  let body = ToJson::to_json(
    Conversation(
      V4Pro,
      [ChatMessage(User, content="solve")],
      thinking=Some(Enabled),
      reasoning_effort=Some(Max),
    ),
  )
  let text = body.stringify()
  assert_true(text.contains("\"thinking\""))
  assert_true(text.contains("\"type\":\"enabled\""))
  assert_true(text.contains("\"reasoning_effort\":\"max\""))
}
