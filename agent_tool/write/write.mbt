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
/// - `Continue("ok: wrote <n> chars to <path>")` on success — `n` is the
///   character count of the written content.
/// - `Continue("error writing <path>: <error>")` if the write fails
///   (permission denied, missing parent directory, etc.).
/// - `Continue("error: write requires arguments.content")` if `path` is
///   present but `content` is missing or not a string.
/// - `Continue("error: write requires arguments.path")` if `path` is missing
///   from an object-shaped payload.
/// - `Continue("error: write requires object arguments")` if the payload is
///   not a JSON object.
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
async fn execute(arguments : Json) -> @agent_tool.ToolResult {
  let (path, content) = match arguments {
    { "path": String(path), "content": String(content), .. } => (path, content)
    { "path": String(_), .. } =>
      return Continue("error: write requires arguments.content")
    Object(_) => return Continue("error: write requires arguments.path")
    _ => return Continue("error: write requires object arguments")
  }
  try {
    @fs.write_file(path, content, create_mode=CreateOrTruncate)
    Continue("ok: wrote \{content.length()} chars to \{path}")
  } catch {
    error => Continue("error writing \{path}: \{error}")
  }
}

///|
async test "write creates a file with the given content" {
  let path = "/tmp/openseek-write-test.txt"
  let result = execute({ "path": path, "content": "hello write" })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, "ok: wrote 11 chars to \{path}")
  let read_back = @fs.read_file(path).text()
  assert_eq(read_back, "hello write")
}

///|
async test "write truncates existing files" {
  let path = "/tmp/openseek-write-truncate.txt"
  @fs.write_file(path, "long original content", create_mode=CreateOrTruncate)
  let result = execute({ "path": path, "content": "short" })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, "ok: wrote 5 chars to \{path}")
  let read_back = @fs.read_file(path).text()
  assert_eq(read_back, "short")
}

///|
async test "write accepts empty content" {
  let path = "/tmp/openseek-write-empty.txt"
  @fs.write_file(path, "previous", create_mode=CreateOrTruncate)
  let result = execute({ "path": path, "content": "" })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, "ok: wrote 0 chars to \{path}")
  let read_back = @fs.read_file(path).text()
  assert_eq(read_back, "")
}

///|
async test "write surfaces filesystem errors" {
  let result = execute({
    "path": "/tmp/openseek-missing-dir/does-not-exist.txt",
    "content": "x",
  })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_true(output.contains("error writing"))
}

///|
async test "write rejects missing content" {
  let result = execute({ "path": "/tmp/openseek-noop.txt" })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, "error: write requires arguments.content")
}

///|
async test "write rejects missing path" {
  let result = execute({ "content": "stuff" })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, "error: write requires arguments.path")
}

///|
async test "write rejects non-object arguments" {
  let result = execute(Json::null())
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, "error: write requires object arguments")
}
