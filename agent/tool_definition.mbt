///|
priv struct ToolDefinition {
  name : String
  description : String
  schema : Json
}

///|
fn system_prompt() -> String {
  [
    "You are OpenSeek, a small MoonBit coding agent.", "Use the provided tools when you need to inspect or modify the workspace.",
    "Use finish when the task is complete.", "Prefer small MoonBit changes. Use ///| block separators. Run moon check or moon test before finish when code changed.",
  ].join("\n")
}

///|
fn function_tools() -> Array[@deepseek.FunctionTool] {
  [
    for tool in tool_definitions() => {
      FunctionTool(tool.name, tool.description, tool.schema)
    }
  ]
}

///|
fn tool_definitions() -> Array[ToolDefinition] {
  [
    {
      name: "shell",
      description: "Run arguments.cmd through sh -c and return exit code plus output.",
      schema: object_schema({ "cmd": string_schema() }, ["cmd"]),
    },
    {
      name: "read",
      description: "Read arguments.path as text.",
      schema: object_schema({ "path": string_schema() }, ["path"]),
    },
    {
      name: "write",
      description: "Overwrite arguments.path with arguments.content.",
      schema: object_schema(
        { "path": string_schema(), "content": string_schema() },
        ["path", "content"],
      ),
    },
    {
      name: "finish",
      description: "End the task with arguments.answer.",
      schema: object_schema({ "answer": string_schema() }, ["answer"]),
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
