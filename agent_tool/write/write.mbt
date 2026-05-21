///|
/// Tool definition for `write`: overwrites `arguments.path` with
/// `arguments.content`. Existing files are truncated; missing parent
/// directories are not created.
///
/// ## Arguments
/// - `path` (string, required): filesystem path to write.
/// - `content` (string, required): text to write. The file is truncated
///   before writing.
///
/// ## Result
/// - `Respond(ToolOutput("ok: wrote <n> chars to <path>"))` on success.
/// - `Respond(ToolOutput("error writing <path>: <error>", is_error=true))`
///   if the write fails.
/// - `Respond(ToolOutput("error: write requires ...", is_error=true))` for
///   invalid arguments.
pub fn definition() -> @agent_tool.AgentToolDefinition {
  AgentToolDefinition(
    "write",
    "Overwrite arguments.path with arguments.content.",
    JsonSchema({
      "type": "object",
      "properties": {
        "path": { "type": "string" },
        "content": { "type": "string" },
      },
      "required": ["path", "content"],
    }),
    Async(execute),
  )
}

///|
async fn execute(arguments : Json) -> @agent_tool.ToolAction {
  let (path, content) = match arguments {
    { "path": String(path), "content": String(content), .. } => (path, content)
    { "path": String(_), .. } =>
      return @agent_tool.ToolAction::respond(
        "error: write requires arguments.content",
        is_error=true,
      )
    Object(_) =>
      return @agent_tool.ToolAction::respond(
        "error: write requires arguments.path",
        is_error=true,
      )
    _ =>
      return @agent_tool.ToolAction::respond(
        "error: write requires object arguments",
        is_error=true,
      )
  }
  try {
    @fs.write_file(path, content, create_mode=CreateOrTruncate)
    @agent_tool.ToolAction::respond(
      "ok: wrote \{content.length()} chars to \{path}",
    )
  } catch {
    error =>
      @agent_tool.ToolAction::respond(
        "error writing \{path}: \{error}",
        is_error=true,
      )
  }
}

///|
async test "write creates a file with the given content" {
  let path = "/tmp/openseek-write-test.txt"
  let result = execute({ "path": path, "content": "hello write" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "ok: wrote 11 chars to \{path}")
  assert_false(output.is_error)
  let read_back = @fs.read_file(path).text()
  assert_eq(read_back, "hello write")
}

///|
async test "write truncates existing files" {
  let path = "/tmp/openseek-write-truncate.txt"
  @fs.write_file(path, "long original content", create_mode=CreateOrTruncate)
  let result = execute({ "path": path, "content": "short" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "ok: wrote 5 chars to \{path}")
  assert_false(output.is_error)
  let read_back = @fs.read_file(path).text()
  assert_eq(read_back, "short")
}

///|
async test "write accepts empty content" {
  let path = "/tmp/openseek-write-empty.txt"
  @fs.write_file(path, "previous", create_mode=CreateOrTruncate)
  let result = execute({ "path": path, "content": "" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "ok: wrote 0 chars to \{path}")
  assert_false(output.is_error)
  let read_back = @fs.read_file(path).text()
  assert_eq(read_back, "")
}

///|
async test "write surfaces filesystem errors" {
  let result = execute({
    "path": "/tmp/openseek-missing-dir/does-not-exist.txt",
    "content": "x",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.content.contains("error writing"))
  assert_true(output.is_error)
}

///|
async test "write rejects missing content" {
  let result = execute({ "path": "/tmp/openseek-noop.txt" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: write requires arguments.content")
  assert_true(output.is_error)
}

///|
async test "write rejects missing path" {
  let result = execute({ "content": "stuff" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: write requires arguments.path")
  assert_true(output.is_error)
}

///|
async test "write rejects non-object arguments" {
  let result = execute(Json::null())
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: write requires object arguments")
  assert_true(output.is_error)
}
