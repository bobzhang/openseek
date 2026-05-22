///|
/// The agent's local tool registry. Each tool lives in its own subpackage of
/// `agent_tool` and exposes a `definition()` constructor; this function bundles
/// them into the `Tools` value the loop dispatches against. Raises if two
/// definitions share a name.
fn tool_definitions() -> @agent_tool.Tools raise {
  Tools([
    @shell.definition(),
    @read.definition(),
    @edit.definition(),
    @write.definition(),
    @finish.definition(),
  ])
}

///|
test "agent registers the expected tool names" {
  let tools = tool_definitions()
  let function_tools = tools.function_tools()
  assert_eq(function_tools.length(), 5)
  let names = [ for t in function_tools => t.name ]
  assert_true(names.contains("shell"))
  assert_true(names.contains("read"))
  assert_true(names.contains("edit"))
  assert_true(names.contains("write"))
  assert_true(names.contains("finish"))
}
