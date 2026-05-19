///|
/// DeepSeek chat model names accepted by the chat completions API.
pub(all) enum Model {
  V4Flash
  V4Pro
} derive(Eq, Debug)

///|
/// Returns the DeepSeek wire name for a chat model.
pub impl Show for Model with to_string(self : Model) -> String {
  match self {
    V4Flash => "deepseek-v4-flash"
    V4Pro => "deepseek-v4-pro"
  }
}

///|
/// Parses a DeepSeek wire model name into a typed model.
pub fn Model::parse(input : String) -> Model raise {
  match input {
    "deepseek-v4-flash" => V4Flash
    "deepseek-v4-pro" => V4Pro
    other => fail("unknown DeepSeek model: \{other}")
  }
}

///|
/// DeepSeek thinking mode request toggle.
pub(all) enum ThinkingMode {
  Enabled
  Disabled
} derive(Eq, Debug)

///|
/// Returns the DeepSeek wire name for a thinking mode toggle.
pub impl Show for ThinkingMode with to_string(self : ThinkingMode) -> String {
  match self {
    Enabled => "enabled"
    Disabled => "disabled"
  }
}

///|
/// DeepSeek reasoning effort for thinking mode.
pub(all) enum ReasoningEffort {
  High
  Max
} derive(Eq, Debug)

///|
/// Returns the DeepSeek wire name for a reasoning effort.
pub impl Show for ReasoningEffort with to_string(self : ReasoningEffort) -> String {
  match self {
    High => "high"
    Max => "max"
  }
}

///|
/// DeepSeek chat message roles.
///
/// `Tool(tool_call_id)` represents a tool response message and carries the
/// `tool_call_id` field required by the API.
pub(all) enum Role {
  System
  User
  Assistant
  Tool(String)
} derive(Eq, Debug)

///|
/// Returns the DeepSeek wire name for a chat message role.
pub impl Show for Role with to_string(self : Role) -> String {
  match self {
    System => "system"
    User => "user"
    Assistant => "assistant"
    Tool(_) => "tool"
  }
}

///|
/// A typed chat message.
///
/// Construct messages with `ChatMessage(User, "hello")`,
/// `ChatMessage(System, "...")`, or `ChatMessage(Tool("call_id"), "...")`.
pub struct ChatMessage {
  role : Role
  content : String
  tool_calls : Array[ToolCall]
  reasoning_content : String?
} derive(Debug)

///|
/// Constructs a typed chat message.
pub fn ChatMessage::ChatMessage(
  role : Role,
  content : String,
  tool_calls? : Array[ToolCall] = [],
  reasoning_content? : String,
) -> ChatMessage {
  { role, content, tool_calls, reasoning_content }
}

///|
/// A complete DeepSeek chat request conversation.
///
/// `json_response=true` requests a JSON object response format.
pub struct Conversation {
  model : Model
  messages : Array[ChatMessage]
  json_response : Bool
  tools : Array[ToolDefinition]
  thinking : ThinkingMode?
  reasoning_effort : ReasoningEffort?
} derive(Debug)

///|
/// Constructs a typed DeepSeek chat request conversation.
pub fn Conversation::Conversation(
  model : Model,
  messages : Array[ChatMessage],
  json_response? : Bool = false,
  tools? : Array[ToolDefinition] = [],
  thinking? : ThinkingMode? = None,
  reasoning_effort? : ReasoningEffort? = None,
) -> Conversation {
  { model, messages, json_response, tools, thinking, reasoning_effort }
}

///|
/// Token usage reported by DeepSeek chat responses.
pub struct Usage {
  prompt_tokens : Int
  completion_tokens : Int
  total_tokens : Int
  prompt_cache_hit_tokens : Int
  prompt_cache_miss_tokens : Int
} derive(Debug)

///|
/// Decoded DeepSeek chat response content and token usage.
pub struct ChatResponse {
  content : String
  reasoning_content : String
  tool_calls : Array[ToolCall]
  usage : Usage
} derive(Debug)
