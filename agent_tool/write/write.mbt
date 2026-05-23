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
    name="write",
    description="Overwrite arguments.path with arguments.content.",
    schema=JsonSchema({
      "type": "object",
      "properties": {
        "path": { "type": "string" },
        "content": { "type": "string" },
      },
      "required": ["path", "content"],
    }),
    execute=Async(execute),
  )
}

///|
async fn execute(arguments : Json) -> @agent_tool.ToolAction {
  let input = @decode.decode(arguments) catch {
    error => {
      let message = @tool_error.failure_message("\{error}")
      return @agent_tool.ToolAction::respond(
        "error: write requires \{message}",
        is_error=true,
      )
    }
  }
  write_file(input)
}

///|
async fn write_file(input : @decode.WriteInput) -> @agent_tool.ToolAction {
  try {
    match manifest_write_error(input.path, input.content) {
      Some(message) =>
        return @agent_tool.ToolAction::respond(
          "error writing \{input.path}: \{message}",
          is_error=true,
        )
      None => ()
    }
    @fs.write_file(input.path, input.content, create_mode=CreateOrTruncate)
    @agent_tool.ToolAction::respond(
      "ok: wrote \{input.content.length()} chars to \{input.path}",
    )
  } catch {
    error =>
      @agent_tool.ToolAction::respond(
        "error writing \{input.path}: \{error}",
        is_error=true,
      )
  }
}

///|
async fn manifest_write_error(path : String, content : String) -> String? {
  let trimmed = content.trim().to_owned()
  if is_moon_mod_json_path(path) && !@fs.exists(path) {
    return Some(
      "moon.mod.json is legacy; create moon.mod for new MoonBit projects",
    )
  }
  if is_moon_mod_path(path) {
    if trimmed == "" {
      return Some("moon.mod must not be empty")
    }
    if trimmed.has_prefix("{") || trimmed.contains("\"name\"") {
      return Some("moon.mod uses current text syntax, not JSON")
    }
    if !trimmed.contains("name =") {
      return Some("moon.mod should include a module `name = ...` entry")
    }
  }
  if is_moon_pkg_path(path) {
    if trimmed.length() < 8 {
      return Some("moon.pkg content is suspiciously small")
    }
    if trimmed.has_prefix("{") {
      return Some("moon.pkg uses current text syntax, not JSON")
    }
  }
  None
}

///|
fn is_moon_mod_path(path : String) -> Bool {
  path == "moon.mod" || path.has_suffix("/moon.mod")
}

///|
fn is_moon_mod_json_path(path : String) -> Bool {
  path == "moon.mod.json" || path.has_suffix("/moon.mod.json")
}

///|
fn is_moon_pkg_path(path : String) -> Bool {
  path == "moon.pkg" || path.has_suffix("/moon.pkg")
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
async test "write rejects new legacy moon.mod.json" {
  let dir = @fs.tmpdir(prefix="openseek-write-manifest-")
  let path = dir + "/moon.mod.json"
  let result = execute({ "path": path, "content": "{\"name\":\"legacy\"}" })
  let _ = @fs.rmdir(dir, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_true(output.content.contains("moon.mod.json is legacy"))
}

///|
async test "write rejects json style moon.mod" {
  let dir = @fs.tmpdir(prefix="openseek-write-manifest-")
  let path = dir + "/moon.mod"
  let result = execute({ "path": path, "content": "{\"name\":\"bad\"}" })
  let _ = @fs.rmdir(dir, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_true(output.content.contains("moon.mod uses current text syntax"))
}

///|
async test "write rejects suspiciously tiny moon.pkg" {
  let dir = @fs.tmpdir(prefix="openseek-write-manifest-")
  let path = dir + "/moon.pkg"
  let result = execute({ "path": path, "content": "x" })
  let _ = @fs.rmdir(dir, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_true(output.content.contains("moon.pkg content is suspiciously small"))
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
