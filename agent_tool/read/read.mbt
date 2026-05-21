///|
/// Tool definition for `read`: returns the contents of `arguments.path` as
/// text.
///
/// ## Arguments
/// - `path` (string, required): filesystem path to read.
///
/// ## Result
/// - `Continue(<file contents>)` on success.
/// - `Continue("error reading <path>: <error>")` if the read fails (missing
///   file, permission denied, invalid UTF-8, etc.).
/// - `Continue("error: read requires arguments.path")` if the payload is an
///   object missing `path`.
/// - `Continue("error: read requires object arguments")` if the payload is
///   not a JSON object.
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
async fn execute(arguments : Json) -> @agent_tool.ToolResult {
  match arguments {
    { "path": String(path), .. } =>
      Continue(
        @fs.read_file(path).text() catch {
          error => "error reading \{path}: \{error}"
        },
      )
    Object(_) => Continue("error: read requires arguments.path")
    _ => Continue("error: read requires object arguments")
  }
}

///|
async test "read returns file contents" {
  let path = "/tmp/openseek-read-test.txt"
  @fs.write_file(path, "hello read", create_mode=CreateOrTruncate)
  let result = execute({ "path": path })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, "hello read")
}

///|
async test "read returns empty string for an empty file" {
  let path = "/tmp/openseek-read-empty.txt"
  @fs.write_file(path, "", create_mode=CreateOrTruncate)
  let result = execute({ "path": path })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, "")
}

///|
async test "read preserves multiline content" {
  let path = "/tmp/openseek-read-multiline.txt"
  let content = "line one\nline two\nline three\n"
  @fs.write_file(path, content, create_mode=CreateOrTruncate)
  let result = execute({ "path": path })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, content)
}

///|
async test "read surfaces filesystem errors" {
  let result = execute({ "path": "/tmp/openseek-does-not-exist" })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_true(output.contains("error reading"))
}

///|
async test "read rejects missing path" {
  let result = execute({})
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, "error: read requires arguments.path")
}

///|
async test "read rejects non-object arguments" {
  let result = execute(Json::null())
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, "error: read requires object arguments")
}
