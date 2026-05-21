///|
/// Agent-local executable form of a native `@deepseek.ToolCall`.
///
/// `@deepseek.ToolCall` is the protocol value returned by the API: it keeps the
/// DeepSeek `id` and raw JSON argument string so the assistant tool-call message
/// and later `Tool(id)` result message can preserve the wire format. Once the
/// agent is ready to dispatch a local tool, `AgentToolCall` keeps only the tool
/// name and parsed `Json` arguments. The original id stays on the native call
/// used by the conversation loop when it appends the tool result message.
pub struct AgentToolCall {
  /// Local tool name selected by DeepSeek, such as `shell`, `read`, `write`, or
  /// `finish`.
  name : String
  /// Parsed JSON arguments for the selected local tool. Dispatchers validate the
  /// required fields for each tool before execution.
  arguments : Json
}

///|
/// Parses a `@deepseek.ToolCall` into an `AgentToolCall`. Raises when the raw
/// arguments string is not valid JSON.
pub fn AgentToolCall::AgentToolCall(
  call : @deepseek.ToolCall,
) -> AgentToolCall raise {
  let arguments = @json.parse(call.arguments) catch {
    _ => fail("\{call.name} arguments are not valid JSON")
  }
  { name: call.name, arguments }
}

///|
/// A locally registered tool: the name and JSON Schema sent to DeepSeek, plus a
/// callable executor that runs when DeepSeek requests this tool.
pub(all) struct AgentToolDefinition {
  name : String
  description : String
  schema : Json
  execute : ToolExecutor
}

///|
/// Wraps a tool executor as either an async or synchronous function. The
/// framework runs both uniformly through `ToolExecutor::run`.
pub(all) enum ToolExecutor {
  Async(async (Json) -> ToolResult)
  Sync((Json) -> ToolResult)
}

///|
pub async fn ToolExecutor::run(
  self : ToolExecutor,
  arguments : Json,
) -> ToolResult {
  match self {
    Async(execute) => execute(arguments)
    Sync(execute) => execute(arguments)
  }
}

///|
/// The outcome of running a tool. The agent loop branches on this.
pub(all) enum ToolResult {
  /// Append the string as a `Tool(id)` chat message and keep looping. Tool-
  /// reported errors use this variant too — the model sees the error text
  /// and decides what to do next.
  Continue(String)
  /// Stop the loop and treat the string as the final answer to surface to
  /// the user.
  Finish(String)
}

///|
/// Encodes a registry of local tool definitions as the DeepSeek `tools[]`
/// payload the chat completions API expects.
pub fn function_tools(
  registry : Array[AgentToolDefinition],
) -> Array[@deepseek.ToolDefinition] {
  [
    for tool in registry => {
      ToolDefinition(tool.name, tool.description, tool.schema)
    }
  ]
}

///|
/// Returns the registered definition whose name matches `name`, or `None`.
pub fn find_tool(
  registry : Array[AgentToolDefinition],
  name : String,
) -> AgentToolDefinition? {
  for tool in registry {
    if tool.name == name {
      return Some(tool)
    }
  }
  None
}

///|
/// Dispatches a parsed tool call against `registry`. Returns a continue-result
/// with an `error: unknown tool` message when no definition matches.
pub async fn execute_tool_call(
  call : AgentToolCall,
  registry : Array[AgentToolDefinition],
) -> ToolResult {
  match find_tool(registry, call.name) {
    Some(tool) => tool.execute.run(call.arguments)
    None => Continue("error: unknown tool \{call.name}")
  }
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

///|
test "function_tools converts agent registry to deepseek tool definitions" {
  let registry : Array[AgentToolDefinition] = [
    {
      name: "echo",
      description: "Echo the input.",
      schema: { "type": "object" },
      execute: Sync(_args => Continue("ok")),
    },
  ]
  let tools = function_tools(registry)
  assert_eq(tools.length(), 1)
  assert_eq(tools[0].name, "echo")
}

///|
async test "execute_tool_call reports unknown tool" {
  let call = AgentToolCall(ToolCall(id="call_1", name="ghost", arguments="{}"))
  let result = execute_tool_call(call, [])
  guard result is Continue(output) else {
    fail("unknown tool should produce Continue")
  }
  assert_eq(output, "error: unknown tool ghost")
}

///|
async test "execute_tool_call dispatches to registered executor" {
  let registry : Array[AgentToolDefinition] = [
    {
      name: "echo",
      description: "Echo.",
      schema: { "type": "object" },
      execute: Sync(args => {
        match args {
          { "value": String(v), .. } => Continue(v)
          _ => Continue("no value")
        }
      }),
    },
  ]
  let call = AgentToolCall(
    ToolCall(id="call_1", name="echo", arguments="{\"value\":\"hi\"}"),
  )
  let result = execute_tool_call(call, registry)
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, "hi")
}
