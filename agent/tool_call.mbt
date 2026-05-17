///|
priv struct ToolCall {
  name : String
  arguments : Json
}

///|
fn ToolCall::from_json(json : Json) -> Result[ToolCall, String] {
  guard json is Object(fields) else {
    return Err("tool call must be a JSON object")
  }
  guard fields.get("tool") is Some(String(name)) else {
    return Err("tool call is missing string field tool")
  }
  let arguments = match fields.get("arguments") {
    Some(arguments) => arguments
    None => Json::object(Map([]))
  }
  Ok({ name, arguments })
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
test "parse tool call json" {
  let call_json = @json.parse(
    (
      #|{"tool":"shell","arguments":{"cmd":"moon check"}}
    ),
  )
  let parsed = ToolCall::from_json(call_json)
  guard parsed is Ok(call) else { fail("tool call did not parse") }
  assert_eq(call.name, "shell")
  guard required_string_argument(call.arguments, "shell", "cmd") is Ok(cmd) else {
    fail("missing cmd")
  }
  assert_eq(cmd, "moon check")
}
