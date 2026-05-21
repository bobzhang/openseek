///|
/// Tool definition for `read`: returns the contents of `arguments.path` as
/// text.
///
/// ## Arguments
/// - `path` (string, required): filesystem path to read.
///
/// ## Result
/// - `Respond(ToolOutput(<file contents>))` on success.
/// - `Respond(ToolOutput("error reading <path>: <error>", is_error=true))`
///   if the read fails (missing file, permission denied, invalid UTF-8, etc.).
/// - `Respond(ToolOutput("error: read requires ...", is_error=true))` for
///   invalid arguments.
pub fn definition() -> @agent_tool.AgentToolDefinition {
  AgentToolDefinition(
    "read",
    "Read arguments.path as text.",
    JsonSchema({
      "type": "object",
      "properties": { "path": { "type": "string" } },
      "required": ["path"],
    }),
    Async(execute),
  )
}

///|
async fn execute(arguments : Json) -> @agent_tool.ToolAction {
  match arguments {
    { "path": String(path), .. } =>
      @agent_tool.ToolAction::respond(@fs.read_file(path).text()) catch {
        error =>
          @agent_tool.ToolAction::respond(
            "error reading \{path}: \{error}",
            is_error=true,
          )
      }
    Object(_) =>
      @agent_tool.ToolAction::respond(
        "error: read requires arguments.path",
        is_error=true,
      )
    _ =>
      @agent_tool.ToolAction::respond(
        "error: read requires object arguments",
        is_error=true,
      )
  }
}

///|
async test "read returns file contents" {
  let path = "/tmp/openseek-read-test.txt"
  @fs.write_file(path, "hello read", create_mode=CreateOrTruncate)
  let result = execute({ "path": path })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "hello read")
  assert_false(output.is_error)
}

///|
async test "read returns empty string for an empty file" {
  let path = "/tmp/openseek-read-empty.txt"
  @fs.write_file(path, "", create_mode=CreateOrTruncate)
  let result = execute({ "path": path })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "")
  assert_false(output.is_error)
}

///|
async test "read preserves multiline content" {
  let path = "/tmp/openseek-read-multiline.txt"
  let content = "line one\nline two\nline three\n"
  @fs.write_file(path, content, create_mode=CreateOrTruncate)
  let result = execute({ "path": path })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, content)
  assert_false(output.is_error)
}

///|
async test "read surfaces filesystem errors" {
  let result = execute({ "path": "/tmp/openseek-does-not-exist" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.content.contains("error reading"))
  assert_true(output.is_error)
}

///|
async test "read rejects missing path" {
  let result = execute({})
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: read requires arguments.path")
  assert_true(output.is_error)
}

///|
async test "read rejects non-object arguments" {
  let result = execute(Json::null())
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: read requires object arguments")
  assert_true(output.is_error)
}
