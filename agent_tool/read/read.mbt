///|
/// Tool definition for `read`: returns text from `arguments.path`, optionally
/// restricted to a line range and capped to avoid flooding the agent context.
///
/// ## Arguments
/// - `path` (string, required): filesystem path to read.
/// - `start_line` (number, optional): 1-based first line to return. Defaults
///   to 1.
/// - `max_lines` (number, optional): maximum number of lines to return.
/// - `max_output_chars` (number, optional): maximum returned content chars.
///   Defaults to 12000 and is capped at 50000.
///
/// ## Result
/// - `Respond(ToolOutput(<file contents>))` on success for uncapped whole-file
///   reads.
/// - `Respond(ToolOutput(<metadata header + content>))` for ranged reads or
///   capped reads.
/// - `Respond(ToolOutput("error reading <path>: <error>", is_error=true))`
///   if the read fails (missing file, permission denied, invalid UTF-8, etc.).
/// - `Respond(ToolOutput("error: read requires ...", is_error=true))` for
///   invalid arguments.
pub fn definition() -> @agent_tool.AgentToolDefinition {
  AgentToolDefinition(
    "read",
    "Read arguments.path as text. Supports optional start_line, max_lines, and max_output_chars for focused reads.",
    JsonSchema({
      "type": "object",
      "properties": {
        "path": { "type": "string" },
        "start_line": { "type": "number" },
        "max_lines": { "type": "number" },
        "max_output_chars": { "type": "number" },
      },
      "required": ["path"],
    }),
    Async(execute),
  )
}

///|
async fn execute(arguments : Json) -> @agent_tool.ToolAction {
  match arguments {
    Object(fields) => {
      let options = parse_options(fields) catch {
        error =>
          return @agent_tool.ToolAction::respond(
            "error: read requires \{error}",
            is_error=true,
          )
      }
      read_file(options)
    }
    _ =>
      @agent_tool.ToolAction::respond(
        "error: read requires object arguments",
        is_error=true,
      )
  }
}

///|
let default_max_output_chars : Int = 12000

///|
let hard_max_output_chars : Int = 50000

///|
priv struct ReadOptions {
  path : String
  start_line : Int
  max_lines : Int?
  max_output_chars : Int
}

///|
priv struct ReadSelection {
  content : String
  start_line : Int
  end_line : Int
  total_lines : Int
  shown_lines : Int
  line_limited : Bool
}

///|
fn parse_options(fields : Map[String, Json]) -> ReadOptions raise {
  let path = required_string(fields, "path")
  let start_line = optional_positive_int(fields, "start_line", 1)
  let max_lines = optional_positive_int_option(fields, "max_lines")
  let max_output_chars = optional_positive_int(
    fields, "max_output_chars", default_max_output_chars,
  )
  {
    path,
    start_line,
    max_lines,
    max_output_chars: cap_max_output_chars(max_output_chars),
  }
}

///|
fn required_string(fields : Map[String, Json], name : String) -> String raise {
  match fields.get(name) {
    Some(String(value)) if value != "" => value
    Some(String(_)) | Some(Null) | None => fail("arguments.\{name}")
    _ => fail("arguments.\{name} to be a string")
  }
}

///|
fn optional_positive_int(
  fields : Map[String, Json],
  name : String,
  default : Int,
) -> Int raise {
  match fields.get(name) {
    Some(Number(value, ..)) => {
      let int_value = value.to_int()
      if int_value <= 0 {
        fail("arguments.\{name} to be a positive number")
      }
      int_value
    }
    Some(Null) | None => default
    _ => fail("arguments.\{name} to be a number")
  }
}

///|
fn optional_positive_int_option(
  fields : Map[String, Json],
  name : String,
) -> Int? raise {
  match fields.get(name) {
    Some(Number(value, ..)) => {
      let int_value = value.to_int()
      if int_value <= 0 {
        fail("arguments.\{name} to be a positive number")
      }
      Some(int_value)
    }
    Some(Null) | None => None
    _ => fail("arguments.\{name} to be a number")
  }
}

///|
fn cap_max_output_chars(value : Int) -> Int {
  if value > hard_max_output_chars {
    hard_max_output_chars
  } else {
    value
  }
}

///|
async fn read_file(options : ReadOptions) -> @agent_tool.ToolAction {
  let content = @fs.read_file(options.path).text() catch {
    error =>
      return @agent_tool.ToolAction::respond(
        "error reading \{options.path}: \{error}",
        is_error=true,
      )
  }
  let selection = select_lines(content, options.start_line, options.max_lines)
  let capped = cap_text(selection.content, options.max_output_chars)
  let char_truncated = selection.content.length() > options.max_output_chars
  let include_header = options.start_line != 1 ||
    options.max_lines is Some(_) ||
    char_truncated
  let output = if include_header {
    read_header(options.path, content, selection, capped, char_truncated) +
    capped
  } else {
    capped
  }
  @agent_tool.ToolAction::respond(output, is_error=char_truncated)
}

///|
fn select_lines(
  content : String,
  start_line : Int,
  max_lines : Int?,
) -> ReadSelection {
  let lines : Array[String] = content
    .split("\n")
    .map(line => line.to_owned())
    .collect()
  let total_lines = lines.length()
  let start_index = start_line - 1
  let requested_lines = match max_lines {
    Some(count) => count
    None => total_lines - start_index
  }
  let end_exclusive = clamp_end(start_index + requested_lines, total_lines)
  let selected : Array[String] = []
  if start_index < total_lines {
    for i in start_index..<end_exclusive {
      selected.push(lines[i])
    }
  }
  let shown_lines = selected.length()
  let end_line = if shown_lines == 0 {
    start_line - 1
  } else {
    start_line + shown_lines - 1
  }
  let line_limited = match max_lines {
    Some(_) => end_exclusive < total_lines
    None => false
  }
  {
    content: selected.join("\n"),
    start_line,
    end_line,
    total_lines,
    shown_lines,
    line_limited,
  }
}

///|
fn clamp_end(value : Int, total : Int) -> Int {
  if value < 0 {
    0
  } else if value > total {
    total
  } else {
    value
  }
}

///|
fn cap_text(content : String, max_chars : Int) -> String {
  if content.length() <= max_chars {
    content
  } else {
    content[:max_chars].to_owned()
  }
}

///|
fn read_header(
  path : String,
  original : String,
  selection : ReadSelection,
  capped : String,
  char_truncated : Bool,
) -> String {
  [
    "path=\{path}",
    "start_line=\{selection.start_line}",
    "end_line=\{selection.end_line}",
    "total_lines=\{selection.total_lines}",
    "shown_lines=\{selection.shown_lines}",
    "file_chars=\{original.length()}",
    "selected_chars=\{selection.content.length()}",
    "shown_chars=\{capped.length()}",
    "line_limited=\{selection.line_limited}",
    "truncated=\{char_truncated}",
    "---",
    "",
  ].join("\n")
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
async test "read returns a requested line range with metadata" {
  let path = "/tmp/openseek-read-range.txt"
  let content = "line one\nline two\nline three\nline four"
  @fs.write_file(path, content, create_mode=CreateOrTruncate)
  let result = execute({ "path": path, "start_line": 2, "max_lines": 2 })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  inspect(
    output.content,
    content=(
      #|path=/tmp/openseek-read-range.txt
      #|start_line=2
      #|end_line=3
      #|total_lines=4
      #|shown_lines=2
      #|file_chars=38
      #|selected_chars=19
      #|shown_chars=19
      #|line_limited=true
      #|truncated=false
      #|---
      #|line two
      #|line three
    ),
  )
}

///|
async test "read caps oversized output and marks it as an error" {
  let path = "/tmp/openseek-read-capped.txt"
  @fs.write_file(path, "abcdef", create_mode=CreateOrTruncate)
  let result = execute({ "path": path, "max_output_chars": 3 })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  inspect(
    output.content,
    content=(
      #|path=/tmp/openseek-read-capped.txt
      #|start_line=1
      #|end_line=1
      #|total_lines=1
      #|shown_lines=1
      #|file_chars=6
      #|selected_chars=6
      #|shown_chars=3
      #|line_limited=false
      #|truncated=true
      #|---
      #|abc
    ),
  )
}

///|
test "read parses and caps optional limits" {
  let options = parse_options({
    "path": "file.mbt",
    "start_line": 3,
    "max_lines": 4,
    "max_output_chars": 999999,
  })
  assert_eq(options.path, "file.mbt")
  assert_eq(options.start_line, 3)
  guard options.max_lines is Some(max_lines) else { fail("missing max_lines") }
  assert_eq(max_lines, 4)
  assert_eq(options.max_output_chars, hard_max_output_chars)
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
  assert_true(output.content.contains("error: read requires"))
  assert_true(output.content.contains("arguments.path"))
  assert_true(output.is_error)
}

///|
async test "read rejects invalid limits" {
  let result = execute({ "path": "/tmp/openseek-read-test.txt", "max_lines": 0 })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.content.contains("error: read requires"))
  assert_true(
    output.content.contains("arguments.max_lines to be a positive number"),
  )
  assert_true(output.is_error)
}

///|
async test "read rejects non-object arguments" {
  let result = execute(Json::null())
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: read requires object arguments")
  assert_true(output.is_error)
}
