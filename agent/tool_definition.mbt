///|
priv struct ToolDefinition {
  name : String
  description : String
  schema : Json
}

///|
fn system_prompt() -> String {
  [
    "You are OpenSeek, a small MoonBit coding agent.",
    "Reply with exactly one JSON tool call object and no markdown.",
    "Use this shape: {\"tool\":\"shell\",\"arguments\":{\"cmd\":\"moon check\"}}",
    "Use finish when the task is complete: {\"tool\":\"finish\",\"arguments\":{\"answer\":\"...\"}}",
    "",
    "Tools:",
    tools_prompt(),
    "",
    "Prefer small MoonBit changes. Use ///| block separators. Run moon check or moon test before finish when code changed.",
  ].join("\n")
}

///|
fn tools_prompt() -> String {
  tool_definitions()
  .map(fn(tool) {
    "- \{tool.name}: \{tool.description}\n  schema: \{tool.schema.stringify()}"
  })
  .join("\n")
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
  Json::object({
    "type": Json::string("object"),
    "properties": Json::object(properties),
    "required": Json::array(required.map(name => Json::string(name))),
  })
}

///|
fn string_schema() -> Json {
  Json::object({ "type": Json::string("string") })
}

///|
test "tool prompt includes json schemas" {
  let prompt = tools_prompt()
  assert_true(prompt.contains("shell"))
  assert_true(prompt.contains("\"required\""))
  assert_true(prompt.contains("\"cmd\""))
}
