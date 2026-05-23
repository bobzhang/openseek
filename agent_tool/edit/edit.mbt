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
    name="edit",
    description="Replace exact text in arguments.path with arguments.new_string.",
    schema=JsonSchema({
      "type": "object",
      "properties": {
        "path": { "type": "string" },
        "old_string": { "type": "string" },
        "new_string": { "type": "string" },
        "replace_all": { "type": "boolean" },
      },
      "required": ["path", "old_string", "new_string"],
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
        "error: edit requires \{message}",
        is_error=true,
      )
    }
  }
  edit_file(input)
}

///|
async fn edit_file(input : @decode.EditInput) -> @agent_tool.ToolAction {
  if input.old_string == "" {
    return @agent_tool.ToolAction::respond(
      "error editing \{input.path}: old_string must be non-empty",
      is_error=true,
    )
  }
  if input.old_string == input.new_string {
    return @agent_tool.ToolAction::respond(
      "error editing \{input.path}: old_string and new_string are identical",
      is_error=true,
    )
  }
  let content = @fs.read_file(input.path).text() catch {
    error =>
      return @agent_tool.ToolAction::respond(
        "error editing \{input.path}: error reading file: \{error}",
        is_error=true,
      )
  }
  let parts = content
    .split(input.old_string)
    .map(part => part.to_owned())
    .collect()
  let occurrences = parts.length() - 1
  if occurrences == 0 {
    return @agent_tool.ToolAction::respond(
      "error editing \{input.path}: old_string not found",
      is_error=true,
    )
  }
  if occurrences > 1 && !input.replace_all {
    return @agent_tool.ToolAction::respond(
      "error editing \{input.path}: old_string matched \{occurrences} times; set replace_all=true to replace all occurrences",
      is_error=true,
    )
  }
  let replacement_count = if input.replace_all { occurrences } else { 1 }
  let new_content = if input.replace_all {
    parts.join(input.new_string)
  } else {
    content.replace(old=input.old_string, new=input.new_string)
  }
  match manifest_write_error(input.path, new_content) {
    Some(message) =>
      return @agent_tool.ToolAction::respond(
        "error editing \{input.path}: \{message}",
        is_error=true,
      )
    None => ()
  }
  try {
    @fs.write_file(input.path, new_content, create_mode=CreateOrTruncate)
    @agent_tool.ToolAction::respond(
      "ok: replaced \{replacement_count} occurrence(s) in \{input.path}",
    )
  } catch {
    error =>
      @agent_tool.ToolAction::respond(
        "error editing \{input.path}: error writing file: \{error}",
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
