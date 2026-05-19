///|
priv struct AgentToolDefinition {
  name : String
  description : String
  schema : Json
  execute : ToolExecutor
}

///|
priv enum ToolExecutor {
  Async(async (Json) -> ToolResult)
  Sync((Json) -> ToolResult)
}

///|
async fn ToolExecutor::run(self : ToolExecutor, arguments : Json) -> ToolResult {
  match self {
    Async(execute) => execute(arguments)
    Sync(execute) => execute(arguments)
  }
}

///|
fn function_tools() -> Array[@deepseek.ToolDefinition] {
  [
    for tool in tool_definitions() => {
      ToolDefinition(tool.name, tool.description, tool.schema)
    }
  ]
}

///|
fn find_tool(name : String) -> AgentToolDefinition? {
  for tool in tool_definitions() {
    if tool.name == name {
      return Some(tool)
    }
  }
  None
}

///|
fn tool_definitions() -> Array[AgentToolDefinition] {
  [
    {
      name: "shell",
      description: "Run arguments.cmd through sh -c, optionally in arguments.cwd, and return exit code plus output.",
      schema: object_schema(
        { "cmd": string_schema(), "cwd": string_schema() },
        ["cmd"],
      ),
      execute: Async(execute_shell),
    },
    {
      name: "read",
      description: "Read arguments.path as text.",
      schema: object_schema({ "path": string_schema() }, ["path"]),
      execute: Async(execute_read),
    },
    {
      name: "write",
      description: "Overwrite arguments.path with arguments.content.",
      schema: object_schema(
        { "path": string_schema(), "content": string_schema() },
        ["path", "content"],
      ),
      execute: Async(execute_write),
    },
    {
      name: "finish",
      description: "End the task with arguments.answer.",
      schema: object_schema({ "answer": string_schema() }, ["answer"]),
      execute: Sync(execute_finish),
    },
  ]
}

///|
fn object_schema(
  properties : Map[String, Json],
  required : Array[String],
) -> Json {
  {
    "type": "object",
    "properties": Json::object(properties),
    "required": [
      for name in required => name
    ],
  }
}

///|
fn string_schema() -> Json {
  { "type": "string" }
}

///|
test "function tools include json schemas" {
  let tools = function_tools()
  assert_eq(tools.length(), 4)
  let text = ToJson::to_json(tools).stringify()
  assert_true(text.contains("\"type\":\"function\""))
  assert_true(text.contains("\"name\":\"shell\""))
  assert_true(text.contains("\"required\""))
  assert_true(text.contains("\"cmd\""))
}

///|
test "tool definitions are executable registry entries" {
  guard find_tool("finish") is Some(tool) else { fail("missing finish tool") }
  guard tool.execute is Sync(execute) else {
    fail("finish should use a synchronous executor")
  }
  let result = execute({ "answer": "done" })
  assert_eq(result.output, "done")
  assert_true(result.finished)
}
