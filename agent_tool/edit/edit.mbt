///|
/// Tool definition for `edit`: replaces exact text in `arguments.path`.
///
/// ## Arguments
/// - `path` (string, required): filesystem path to edit.
/// - `old_string` (string, required): exact text to replace. It must be
///   non-empty.
/// - `new_string` (string, required): replacement text. It must differ from
///   `old_string`.
/// - `replace_all` (bool, optional): replace every occurrence. Defaults to
///   `false`; when false, `old_string` must occur exactly once.
///
/// ## Result
/// - `Respond(ToolOutput("ok: replaced <n> occurrence(s) in <path>"))` on
///   success.
/// - `Respond(ToolOutput("error editing <path>: ...", is_error=true))` for
///   filesystem failures, empty/no-op edits, missing matches, or ambiguous
///   matches.
/// - `Respond(ToolOutput("error: edit requires ...", is_error=true))` for
///   invalid arguments.
pub fn definition() -> @agent_tool.AgentToolDefinition {
  AgentToolDefinition(
    "edit",
    "Replace exact text in arguments.path with arguments.new_string.",
    JsonSchema({
      "type": "object",
      "properties": {
        "path": { "type": "string" },
        "old_string": { "type": "string" },
        "new_string": { "type": "string" },
        "replace_all": { "type": "boolean" },
      },
      "required": ["path", "old_string", "new_string"],
    }),
    Async(execute),
  )
}

///|
async fn execute(arguments : Json) -> @agent_tool.ToolAction {
  match arguments {
    {
      "path": String(path),
      "old_string": String(old_string),
      "new_string": String(new_string),
      "replace_all": True,
      ..
    } => edit_file(path, old_string, new_string, true)
    {
      "path": String(path),
      "old_string": String(old_string),
      "new_string": String(new_string),
      "replace_all": False,
      ..
    } => edit_file(path, old_string, new_string, false)
    {
      "path": String(_),
      "old_string": String(_),
      "new_string": String(_),
      "replace_all": _,
      ..
    } =>
      @agent_tool.ToolAction::respond(
        "error: edit requires arguments.replace_all to be a boolean",
        is_error=true,
      )
    {
      "path": String(path),
      "old_string": String(old_string),
      "new_string": String(new_string),
      ..
    } => edit_file(path, old_string, new_string, false)
    { "path": String(_), "old_string": String(_), .. } =>
      @agent_tool.ToolAction::respond(
        "error: edit requires arguments.new_string",
        is_error=true,
      )
    { "path": String(_), .. } =>
      @agent_tool.ToolAction::respond(
        "error: edit requires arguments.old_string",
        is_error=true,
      )
    Object(_) =>
      @agent_tool.ToolAction::respond(
        "error: edit requires arguments.path",
        is_error=true,
      )
    _ =>
      @agent_tool.ToolAction::respond(
        "error: edit requires object arguments",
        is_error=true,
      )
  }
}

///|
async fn edit_file(
  path : String,
  old_string : String,
  new_string : String,
  replace_all : Bool,
) -> @agent_tool.ToolAction {
  if old_string == "" {
    return @agent_tool.ToolAction::respond(
      "error editing \{path}: old_string must be non-empty",
      is_error=true,
    )
  }
  if old_string == new_string {
    return @agent_tool.ToolAction::respond(
      "error editing \{path}: old_string and new_string are identical",
      is_error=true,
    )
  }
  let content = @fs.read_file(path).text() catch {
    error =>
      return @agent_tool.ToolAction::respond(
        "error editing \{path}: error reading file: \{error}",
        is_error=true,
      )
  }
  let parts = content.split(old_string).map(part => part.to_owned()).collect()
  let occurrences = parts.length() - 1
  if occurrences == 0 {
    return @agent_tool.ToolAction::respond(
      "error editing \{path}: old_string not found",
      is_error=true,
    )
  }
  if occurrences > 1 && !replace_all {
    return @agent_tool.ToolAction::respond(
      "error editing \{path}: old_string matched \{occurrences} times; set replace_all=true to replace all occurrences",
      is_error=true,
    )
  }
  let replacement_count = if replace_all { occurrences } else { 1 }
  let new_content = if replace_all {
    parts.join(new_string)
  } else {
    content.replace(old=old_string, new=new_string)
  }
  try {
    @fs.write_file(path, new_content, create_mode=CreateOrTruncate)
    @agent_tool.ToolAction::respond(
      "ok: replaced \{replacement_count} occurrence(s) in \{path}",
    )
  } catch {
    error =>
      @agent_tool.ToolAction::respond(
        "error editing \{path}: error writing file: \{error}",
        is_error=true,
      )
  }
}

///|
async test "edit replaces a unique exact match" {
  let path = "/tmp/openseek-edit-unique.txt"
  @fs.write_file(path, "alpha\nbeta\ngamma\n", create_mode=CreateOrTruncate)
  let result = execute({
    "path": path,
    "old_string": "beta",
    "new_string": "delta",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "ok: replaced 1 occurrence(s) in \{path}")
  assert_false(output.is_error)
  assert_eq(@fs.read_file(path).text(), "alpha\ndelta\ngamma\n")
}

///|
async test "edit preserves surrounding multiline content" {
  let path = "/tmp/openseek-edit-multiline.txt"
  @fs.write_file(
    path,
    "fn main {\n  println(\"old\")\n}\n",
    create_mode=CreateOrTruncate,
  )
  let result = execute({
    "path": path,
    "old_string": "  println(\"old\")",
    "new_string": "  println(\"new\")",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  assert_eq(@fs.read_file(path).text(), "fn main {\n  println(\"new\")\n}\n")
}

///|
async test "edit rejects missing old_string" {
  let result = execute({ "path": "/tmp/openseek-edit-noop.txt" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: edit requires arguments.old_string")
  assert_true(output.is_error)
}

///|
async test "edit rejects missing new_string" {
  let result = execute({
    "path": "/tmp/openseek-edit-noop.txt",
    "old_string": "x",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: edit requires arguments.new_string")
  assert_true(output.is_error)
}

///|
async test "edit rejects non-object arguments" {
  let result = execute(Json::null())
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: edit requires object arguments")
  assert_true(output.is_error)
}

///|
async test "edit rejects empty old_string" {
  let path = "/tmp/openseek-edit-empty-old.txt"
  @fs.write_file(path, "content", create_mode=CreateOrTruncate)
  let result = execute({
    "path": path,
    "old_string": "",
    "new_string": "replacement",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(
    output.content,
    "error editing \{path}: old_string must be non-empty",
  )
  assert_true(output.is_error)
}

///|
async test "edit rejects identical replacement" {
  let path = "/tmp/openseek-edit-identical.txt"
  @fs.write_file(path, "content", create_mode=CreateOrTruncate)
  let result = execute({
    "path": path,
    "old_string": "content",
    "new_string": "content",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(
    output.content,
    "error editing \{path}: old_string and new_string are identical",
  )
  assert_true(output.is_error)
}

///|
async test "edit rejects missing match" {
  let path = "/tmp/openseek-edit-missing.txt"
  @fs.write_file(path, "alpha", create_mode=CreateOrTruncate)
  let result = execute({
    "path": path,
    "old_string": "beta",
    "new_string": "gamma",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error editing \{path}: old_string not found")
  assert_true(output.is_error)
}

///|
async test "edit rejects ambiguous match without replace_all" {
  let path = "/tmp/openseek-edit-ambiguous.txt"
  @fs.write_file(path, "alpha beta beta", create_mode=CreateOrTruncate)
  let result = execute({
    "path": path,
    "old_string": "beta",
    "new_string": "delta",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(
    output.content,
    "error editing \{path}: old_string matched 2 times; set replace_all=true to replace all occurrences",
  )
  assert_true(output.is_error)
  assert_eq(@fs.read_file(path).text(), "alpha beta beta")
}

///|
async test "edit replace_all updates every match" {
  let path = "/tmp/openseek-edit-replace-all.txt"
  @fs.write_file(path, "alpha beta beta", create_mode=CreateOrTruncate)
  let result = execute({
    "path": path,
    "old_string": "beta",
    "new_string": "delta",
    "replace_all": true,
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "ok: replaced 2 occurrence(s) in \{path}")
  assert_false(output.is_error)
  assert_eq(@fs.read_file(path).text(), "alpha delta delta")
}

///|
async test "edit rejects non-boolean replace_all" {
  let path = "/tmp/openseek-edit-bad-replace-all.txt"
  @fs.write_file(path, "alpha", create_mode=CreateOrTruncate)
  let result = execute({
    "path": path,
    "old_string": "alpha",
    "new_string": "beta",
    "replace_all": "yes",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(
    output.content,
    "error: edit requires arguments.replace_all to be a boolean",
  )
  assert_true(output.is_error)
}

///|
async test "edit surfaces read errors" {
  let result = execute({
    "path": "/tmp/openseek-edit-does-not-exist.txt",
    "old_string": "x",
    "new_string": "y",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.content.contains("error editing"))
  assert_true(output.content.contains("error reading file"))
  assert_true(output.is_error)
}
