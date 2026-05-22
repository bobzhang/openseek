///|
/// Tool definition for `shell`: runs `arguments.cmd` through `sh -c`,
/// optionally in `arguments.cwd`, and returns the exit code plus merged
/// stdout/stderr output.
///
/// ## Arguments
/// - `cmd` (string, required): shell command line passed to `sh -c`.
/// - `cwd` (string, optional): working directory the command runs in.
///   An empty string is treated the same as a missing field.
/// - `max_output_chars` (number, optional): defaults to 12000 and is capped at
///   50000. Truncated output is reported as a tool error even when the process
///   exits zero.
///
/// ## Result
/// - `Respond(ToolOutput("exit=<code>\n<output>", is_error=<code != 0>))`
///   when `sh -c` runs. Non-zero exit codes are typed as tool errors while
///   preserving the full output for the model.
/// - `Respond(ToolOutput("error running shell: ...", is_error=true))` when
///   launching the process raises.
/// - `Respond(ToolOutput("error: shell requires ...", is_error=true))` for
///   invalid arguments.
pub fn definition() -> @agent_tool.AgentToolDefinition {
  AgentToolDefinition(
    "shell",
    "Run arguments.cmd through sh -c, optionally in arguments.cwd, and return exit code plus output.",
    JsonSchema({
      "type": "object",
      "properties": {
        "cmd": { "type": "string" },
        "cwd": { "type": "string" },
        "max_output_chars": { "type": "number" },
      },
      "required": ["cmd"],
    }),
    Async(execute),
  )
}

///|
let default_max_output_chars : Int = 12000

///|
let hard_max_output_chars : Int = 50000

///|
priv struct ShellOptions {
  cmd : String
  cwd : String?
  max_output_chars : Int
}

///|
async fn execute(arguments : Json) -> @agent_tool.ToolAction {
  let options = match arguments {
    Object(fields) =>
      parse_options(fields) catch {
        error =>
          return @agent_tool.ToolAction::respond(
            "error: shell requires \{error}",
            is_error=true,
          )
      }
    _ =>
      return @agent_tool.ToolAction::respond(
        "error: shell requires object arguments",
        is_error=true,
      )
  }
  shell(options) catch {
    error =>
      @agent_tool.ToolAction::respond(
        "error running shell: \{error}",
        is_error=true,
      )
  }
}

///|
fn parse_options(fields : Map[String, Json]) -> ShellOptions raise {
  let cmd = required_string(fields, "cmd")
  let cwd = optional_string(fields, "cwd")
  let max_output_chars = optional_positive_int(
    fields, "max_output_chars", default_max_output_chars,
  )
  { cmd, cwd, max_output_chars: cap_max_output_chars(max_output_chars) }
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
fn optional_string(fields : Map[String, Json], name : String) -> String? raise {
  match fields.get(name) {
    Some(String(value)) if value != "" => Some(value)
    Some(String(_)) | Some(Null) | None => None
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
fn cap_max_output_chars(value : Int) -> Int {
  if value > hard_max_output_chars {
    hard_max_output_chars
  } else {
    value
  }
}

///|
async fn shell(options : ShellOptions) -> @agent_tool.ToolAction {
  let (code, output) = match options.cwd {
    Some(cwd) => @process.collect_output_merged("sh", ["-c", options.cmd], cwd~)
    None => @process.collect_output_merged("sh", ["-c", options.cmd])
  }
  let body = output.text()
  let capped = cap_text(body, options.max_output_chars)
  let truncation = truncation_header(body, options.max_output_chars)
  @agent_tool.ToolAction::respond(
    "exit=\{code}\{truncation}\n\{capped}",
    is_error=code != 0 || is_truncated(body, options.max_output_chars),
  )
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
fn is_truncated(content : String, max_chars : Int) -> Bool {
  content.length() > max_chars
}

///|
fn truncation_header(content : String, max_chars : Int) -> String {
  if is_truncated(content, max_chars) {
    "\ntruncated=true\noutput_chars=\{content.length()}\nshown_chars=\{max_chars}"
  } else {
    ""
  }
}

///|
test "shell parses and caps output limit" {
  let options = parse_options({
    "cmd": "echo hello",
    "cwd": "/tmp",
    "max_output_chars": 999999,
  })
  assert_eq(options.cmd, "echo hello")
  assert_true(options.cwd is Some("/tmp"))
  assert_eq(options.max_output_chars, hard_max_output_chars)
}

///|
test "shell records truncation metadata" {
  assert_eq(cap_text("abcdef", 3), "abc")
  assert_true(is_truncated("abcdef", 3))
  assert_eq(
    truncation_header("abcdef", 3),
    "\ntruncated=true\noutput_chars=6\nshown_chars=3",
  )
}

///|
async test "shell runs cmd and returns exit code plus output" {
  let result = execute({ "cmd": "echo hello" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  assert_true(output.content.contains("exit=0"))
  assert_true(output.content.contains("hello"))
}

///|
async test "shell propagates non-zero exit codes" {
  let result = execute({ "cmd": "exit 7" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_true(output.content.contains("exit=7"))
}

///|
async test "shell honors cwd when non-empty" {
  let result = execute({ "cmd": "pwd", "cwd": "/tmp" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  assert_true(output.content.contains("exit=0"))
  assert_true(output.content.contains("/tmp"))
}

///|
async test "shell treats empty cwd as missing" {
  let result = execute({ "cmd": "echo cwdless", "cwd": "" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  assert_true(output.content.contains("exit=0"))
  assert_true(output.content.contains("cwdless"))
}

///|
async test "shell truncates oversized output and marks it as error" {
  let result = execute({ "cmd": "printf abcdef", "max_output_chars": 3 })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_true(output.content.contains("exit=0"))
  assert_true(output.content.contains("truncated=true"))
  assert_true(output.content.contains("shown_chars=3"))
  assert_true(output.content.contains("\nabc"))
  assert_false(output.content.contains("abcdef"))
}

///|
async test "shell merges stderr into the captured output" {
  let result = execute({ "cmd": "echo oops 1>&2" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  assert_true(output.content.contains("oops"))
}

///|
async test "shell rejects missing cmd" {
  let result = execute({ "cwd": "/tmp" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_true(output.content.contains("error: shell requires"))
  assert_true(output.content.contains("arguments.cmd"))
}

///|
async test "shell rejects non-object arguments" {
  let result = execute(Json::null())
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_eq(output.content, "error: shell requires object arguments")
}
