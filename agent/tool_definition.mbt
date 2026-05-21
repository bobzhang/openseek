///|
/// The agent's local tool registry: the four functions the agent advertises to
/// DeepSeek (`shell`, `read`, `write`, `finish`) along with their JSON schemas
/// and executors.
fn tool_definitions() -> Array[@agent_tool.AgentToolDefinition] {
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
  let tools = @agent_tool.Tools(tool_definitions())
  let function_tools = tools.function_tools()
  assert_eq(function_tools.length(), 4)
  let names = [ for t in function_tools => t.name ]
  assert_true(names.contains("shell"))
  assert_true(names.contains("read"))
  assert_true(names.contains("write"))
  assert_true(names.contains("finish"))
  for t in function_tools {
    let params = t.parameters.stringify()
    assert_true(params.contains("\"properties\""))
    assert_true(params.contains("\"required\""))
  }
}

///|
test "tool definitions are executable registry entries" {
  let tools = @agent_tool.Tools(tool_definitions())
  guard tools.find("finish") is Some(tool) else { fail("missing finish tool") }
  guard tool.execute is Sync(execute) else {
    fail("finish should use a synchronous executor")
  }
  let result = execute({ "answer": "done" })
  guard result is Finish(answer) else { fail("finish should produce Finish") }
  assert_eq(answer, "done")
}
