///|
/// Agent-local executable form of a native `@deepseek.ToolCall`.
///
/// `@deepseek.ToolCall` is the protocol value returned by the API: it keeps the
/// DeepSeek `id` and raw JSON argument string so the assistant tool-call message
/// and later `Tool(id)` result message can preserve the wire format. Once the
/// agent is ready to dispatch a local tool, `AgentToolCall` keeps only the tool
/// name and parsed `Json` arguments. The original id stays on the native call
/// used by the conversation loop when it appends the tool result message.
priv struct AgentToolCall {
  /// Local tool name selected by DeepSeek, such as `shell`, `read`, `write`, or
  /// `finish`.
  name : String
  /// Parsed JSON arguments for the selected local tool. Dispatchers validate the
  /// required fields for each tool before execution.
  arguments : Json
}

///|
fn AgentToolCall::AgentToolCall(
  call : @deepseek.ToolCall,
) -> AgentToolCall raise {
  let arguments = @json.parse(call.arguments) catch {
    _ => fail("\{call.name} arguments are not valid JSON")
  }
  { name: call.name, arguments }
}

///|
test "parse native tool call arguments" {
  let call = AgentToolCall(
    ToolCall(id="call_123", name="shell", arguments="{\"cmd\":\"moon check\"}"),
  )
  assert_eq(call.name, "shell")
  guard call.arguments is { "cmd": String(cmd), .. } else {
    fail("missing cmd")
  }
  assert_eq(cmd, "moon check")
}

///|
test "reject invalid native tool call arguments" {
  let _ = AgentToolCall(ToolCall(id="call_123", name="shell", arguments="{")) catch {
    error => {
      assert_true("\{error}".contains("shell arguments are not valid JSON"))
      return
    }
  }
  fail("invalid arguments parsed")
}
