///|
priv struct AgentToolCall {
  name : String
  arguments : Json
}

///|
fn AgentToolCall::from_deepseek(
  call : @deepseek.ToolCall,
) -> Result[AgentToolCall, String] {
  let arguments = @json.parse(call.arguments) catch {
    _ => return Err("\{call.name} arguments are not valid JSON")
  }
  Ok({ name: call.name, arguments })
}

///|
fn required_string_argument(
  arguments : Json,
  tool_name : String,
  key : String,
) -> Result[String, String] {
  guard arguments is Object(fields) else {
    return Err("\{tool_name} requires object arguments")
  }
  match fields.get(key) {
    Some(String(value)) => Ok(value)
    _ => Err("\{tool_name} requires arguments.\{key}")
  }
}

///|
test "parse native tool call arguments" {
  let parsed = AgentToolCall::from_deepseek(
    ToolCall("call_123", "shell", "{\"cmd\":\"moon check\"}"),
  )
  guard parsed is Ok(call) else { fail("tool call did not parse") }
  assert_eq(call.name, "shell")
  guard required_string_argument(call.arguments, "shell", "cmd") is Ok(cmd) else {
    fail("missing cmd")
  }
  assert_eq(cmd, "moon check")
}

///|
test "reject invalid native tool call arguments" {
  let parsed = AgentToolCall::from_deepseek(ToolCall("call_123", "shell", "{"))
  guard parsed is Err(error) else { fail("invalid arguments parsed") }
  assert_true(error.contains("shell arguments are not valid JSON"))
}
