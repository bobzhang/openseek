///|
/// Tool definition for `moon_ide`: runs read-only `moon ide` semantic
/// navigation commands directly, optionally in `arguments.cwd`, and returns the
/// real process exit code plus merged stdout/stderr output.
///
/// ## Arguments
/// - `action` (string, required): one of `doc`, `outline`, `peek_def`,
///   `hover`, or `find_references`.
/// - `cwd` (string, optional): working directory. Empty means current process
///   directory.
/// - `query` (string, optional): required for `doc`, `peek_def`, `hover`, and
///   `find_references`.
/// - `path` (string, optional): required for `outline`.
/// - `loc` (string, optional): required for `hover`, optional for `peek_def`
///   and `find_references`; format is `path[:line[:col]]`.
/// - `target` (string, optional): one of MoonBit's `moon ide --target` values.
/// - `no_check` (bool, optional): defaults to false; when true, adds
///   `--no-check`.
/// - `max_output_chars` (number, optional): defaults to 12000 and is capped at
///   50000.
///
/// ## Result
/// - `Respond(ToolOutput("cwd=...\ncommand=...\nexit=<code>\n<output>",
///   is_error=<code != 0>))` when `moon ide` runs.
/// - `Respond(ToolOutput("error running moon_ide: ...", is_error=true))`
///   when launching the process raises.
/// - `Respond(ToolOutput("error: moon_ide requires ...", is_error=true))`
///   for invalid arguments.
pub fn definition() -> @agent_tool.AgentToolDefinition {
  AgentToolDefinition(
    "moon_ide",
    "Run read-only moon ide semantic navigation commands directly and return exit code plus output.",
    JsonSchema({
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "enum": ["doc", "outline", "peek_def", "hover", "find_references"],
        },
        "cwd": { "type": "string" },
        "query": { "type": "string" },
        "path": { "type": "string" },
        "loc": { "type": "string" },
        "target": {
          "type": "string",
          "enum": ["wasm", "wasm-gc", "js", "native", "llvm", "all"],
        },
        "no_check": { "type": "boolean" },
        "max_output_chars": { "type": "number" },
      },
      "required": ["action"],
    }),
    Async(execute),
  )
}

///|
let default_max_output_chars : Int = 12000

///|
let hard_max_output_chars : Int = 50000

///|
priv struct MoonIdeOptions {
  action : String
  cwd : String?
  query : String?
  path : String?
  loc : String?
  target : String?
  no_check : Bool
  max_output_chars : Int
}

///|
async fn execute(arguments : Json) -> @agent_tool.ToolAction {
  let options = match arguments {
    Object(fields) =>
      parse_options(fields) catch {
        error =>
          return @agent_tool.ToolAction::respond(
            "error: moon_ide requires \{error}",
            is_error=true,
          )
      }
    _ =>
      return @agent_tool.ToolAction::respond(
        "error: moon_ide requires object arguments",
        is_error=true,
      )
  }
  moon_ide(options) catch {
    error =>
      @agent_tool.ToolAction::respond(
        "error running moon_ide: \{error}",
        is_error=true,
      )
  }
}

///|
fn parse_options(fields : Map[String, Json]) -> MoonIdeOptions raise {
  let action = required_string(fields, "action")
  validate_action(action)
  let cwd = optional_string(fields, "cwd")
  let query = optional_string(fields, "query")
  let path = optional_string(fields, "path")
  let loc = optional_string(fields, "loc")
  let target = optional_string(fields, "target")
  match target {
    Some(value) => validate_target(value)
    None => ()
  }
  let no_check = optional_bool(fields, "no_check", default=false)
  let max_output_chars = optional_positive_int(
    fields, "max_output_chars", default_max_output_chars,
  )
  validate_required_fields(action, query, path, loc)
  {
    action,
    cwd,
    query,
    path,
    loc,
    target,
    no_check,
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
fn optional_string(fields : Map[String, Json], name : String) -> String? raise {
  match fields.get(name) {
    Some(String(value)) if value != "" => Some(value)
    Some(String(_)) | Some(Null) | None => None
    _ => fail("arguments.\{name} to be a string")
  }
}

///|
fn optional_bool(
  fields : Map[String, Json],
  name : String,
  default~ : Bool,
) -> Bool raise {
  match fields.get(name) {
    Some(True) => true
    Some(False) => false
    Some(Null) | None => default
    _ => fail("arguments.\{name} to be a boolean")
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
fn validate_action(action : String) -> Unit raise {
  let allowed = ["doc", "outline", "peek_def", "hover", "find_references"]
  if !allowed.contains(action) {
    fail(
      "arguments.action to be one of doc, outline, peek_def, hover, find_references",
    )
  }
}

///|
fn validate_target(target : String) -> Unit raise {
  let allowed = ["wasm", "wasm-gc", "js", "native", "llvm", "all"]
  if !allowed.contains(target) {
    fail("arguments.target to be one of wasm, wasm-gc, js, native, llvm, all")
  }
}

///|
fn validate_required_fields(
  action : String,
  query : String?,
  path : String?,
  loc : String?,
) -> Unit raise {
  match action {
    "doc" => if query is None { fail("arguments.query for action doc") }
    "outline" => if path is None { fail("arguments.path for action outline") }
    "peek_def" =>
      if query is None {
        fail("arguments.query for action peek_def")
      }
    "hover" => {
      if query is None {
        fail("arguments.query for action hover")
      }
      if loc is None {
        fail("arguments.loc for action hover")
      }
    }
    "find_references" =>
      if query is None {
        fail("arguments.query for action find_references")
      }
    _ => ()
  }
}

///|
fn MoonIdeOptions::command_args(self : MoonIdeOptions) -> Array[String] {
  let args : Array[String] = ["ide", self.command_action()]
  if self.no_check {
    args.push("--no-check")
  }
  match self.target {
    Some(target) => {
      args.push("--target")
      args.push(target)
    }
    None => ()
  }
  match self.loc {
    Some(loc) => {
      args.push("--loc")
      args.push(loc)
    }
    None => ()
  }
  match self.action {
    "outline" =>
      match self.path {
        Some(path) => args.push(path)
        None => ()
      }
    _ =>
      match self.query {
        Some(query) => args.push(query)
        None => ()
      }
  }
  args
}

///|
fn MoonIdeOptions::command_action(self : MoonIdeOptions) -> String {
  match self.action {
    "peek_def" => "peek-def"
    "find_references" => "find-references"
    other => other
  }
}

///|
async fn moon_ide(options : MoonIdeOptions) -> @agent_tool.ToolAction {
  let args = options.command_args()
  let (code, output) = match options.cwd {
    Some(cwd) => @process.collect_output_merged("moon", args, cwd~)
    None => @process.collect_output_merged("moon", args)
  }
  let cwd_text = match options.cwd {
    Some(cwd) => cwd
    None => "."
  }
  let body = output.text()
  let capped = cap_text(body, options.max_output_chars)
  let truncation = truncation_header(body, options.max_output_chars)
  @agent_tool.ToolAction::respond(
    "cwd=\{cwd_text}\ncommand=moon \{args.join(" ")}\nexit=\{code}\{truncation}\n\{capped}",
    is_error=code != 0,
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
fn truncation_header(content : String, max_chars : Int) -> String {
  if content.length() <= max_chars {
    ""
  } else {
    "\ntruncated=true\noutput_chars=\{content.length()}\nshown_chars=\{max_chars}"
  }
}

///|
test "moon_ide advertises expected schema" {
  let tool = definition()
  assert_eq(tool.name, "moon_ide")
  let JsonSchema(schema) = tool.schema
  let text = schema.stringify()
  assert_true(text.contains("\"doc\""))
  assert_true(text.contains("\"outline\""))
  assert_true(text.contains("\"peek_def\""))
  assert_true(text.contains("\"hover\""))
  assert_true(text.contains("\"find_references\""))
  assert_true(text.contains("\"max_output_chars\""))
}

///|
test "moon_ide builds direct doc command arguments" {
  let options : MoonIdeOptions = {
    action: "doc",
    cwd: Some("/tmp"),
    query: Some("String::replace_all"),
    path: None,
    loc: None,
    target: None,
    no_check: true,
    max_output_chars: default_max_output_chars,
  }
  assert_eq(
    options.command_args().join("|"),
    "ide|doc|--no-check|String::replace_all",
  )
}

///|
test "moon_ide builds loc-aware navigation command arguments" {
  let options : MoonIdeOptions = {
    action: "peek_def",
    cwd: None,
    query: Some("render"),
    path: None,
    loc: Some("lib.mbt:14:8"),
    target: Some("native"),
    no_check: false,
    max_output_chars: default_max_output_chars,
  }
  assert_eq(
    options.command_args().join("|"),
    "ide|peek-def|--target|native|--loc|lib.mbt:14:8|render",
  )
}

///|
test "moon_ide parses outline path" {
  let options = parse_options({
    "action": "outline",
    "path": "agent_tool/moon_ide",
    "max_output_chars": 42,
  })
  assert_eq(options.command_args().join("|"), "ide|outline|agent_tool/moon_ide")
  assert_eq(options.max_output_chars, 42)
}

///|
test "moon_ide caps oversized output limit" {
  let options = parse_options({
    "action": "doc",
    "query": "String",
    "max_output_chars": 999999,
  })
  assert_eq(options.max_output_chars, hard_max_output_chars)
}

///|
test "moon_ide rejects invalid action" {
  let _ = parse_options({ "action": "rename", "query": "old_name" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.action"))
      return
    }
  }
  fail("invalid action parsed")
}

///|
test "moon_ide rejects missing required fields" {
  let _ = parse_options({ "action": "hover", "query": "Widget" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.loc"))
      return
    }
  }
  fail("hover without loc parsed")
}

///|
test "moon_ide records truncation metadata" {
  assert_eq(cap_text("abcdef", 3), "abc")
  assert_eq(
    truncation_header("abcdef", 3),
    "\ntruncated=true\noutput_chars=6\nshown_chars=3",
  )
}

///|
async test "moon_ide rejects non-object arguments" {
  let result = execute(Json::null())
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: moon_ide requires object arguments")
  assert_true(output.is_error)
}

///|
async test "moon_ide looks up installed core documentation" {
  let result = execute({
    "action": "doc",
    "query": "String::replace_all",
    "max_output_chars": 2000,
    "no_check": true,
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  let stable = output.content.trim()
  assert_true(
    stable.contains("command=moon ide doc --no-check String::replace_all"),
  )
  assert_true(stable.contains("pub fn String::replace_all"))
  assert_true(stable.contains("Replaces all non-overlapping occurrences"))
}

///|
async test "moon_ide outlines a real fixture package" {
  let project = copy_fixture_project("simple_project")
  let canonical = @fs.realpath(project)
  let result = execute({
    "cwd": project,
    "action": "outline",
    "path": ".",
    "no_check": false,
  })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  inspect(
    stable_moon_ide_output(output.content, project, canonical).trim(),
    content=(
      #|cwd=<fixture>
      #|command=moon ide outline .
      #|exit=0
      #|lib.mbt:
      #| L02 | pub struct Widget {
      #|       ...
      #| L07 | pub fn Widget::new(name : String) -> Widget {
      #|       ...
      #| L12 | pub fn Widget::label(self : Widget) -> String {
      #|       ...
      #| L17 | pub fn render(widget : Widget) -> String {
      #|       ...
    ),
  )
}

///|
async test "moon_ide peeks a definition in a real fixture package" {
  let project = copy_fixture_project("simple_project")
  let canonical = @fs.realpath(project)
  let result = execute({
    "cwd": project,
    "action": "peek_def",
    "query": "render",
    "loc": "lib.mbt",
    "no_check": false,
  })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  let stable = stable_moon_ide_output(output.content, project, canonical)
  assert_true(stable.contains("cwd=<fixture>"))
  assert_true(stable.contains("command=moon ide peek-def --loc lib.mbt render"))
  assert_true(stable.contains("pub fn render(widget : Widget) -> String"))
}

///|
async test "moon_ide hovers a token in a real fixture package" {
  let project = copy_fixture_project("simple_project")
  let canonical = @fs.realpath(project)
  let result = execute({
    "cwd": project,
    "action": "hover",
    "query": "Widget",
    "loc": "lib.mbt:17:24",
    "no_check": false,
  })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  let stable = stable_moon_ide_output(output.content, project, canonical)
  assert_true(stable.contains("cwd=<fixture>"))
  assert_true(
    stable.contains("command=moon ide hover --loc lib.mbt:17:24 Widget"),
  )
  assert_true(stable.contains("struct Widget"))
}

///|
async test "moon_ide finds references in a real fixture package" {
  let project = copy_fixture_project("simple_project")
  let canonical = @fs.realpath(project)
  let result = execute({
    "cwd": project,
    "action": "find_references",
    "query": "Widget::label",
    "loc": "lib.mbt",
    "no_check": false,
  })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  let stable = stable_moon_ide_output(output.content, project, canonical)
  assert_true(stable.contains("cwd=<fixture>"))
  assert_true(
    stable.contains(
      "command=moon ide find-references --loc lib.mbt Widget::label",
    ),
  )
  assert_true(stable.contains("Found "))
  assert_true(stable.contains("widget.label()"))
}

///|
async fn copy_fixture_project(name : String) -> String {
  let target = @fs.tmpdir(prefix="openseek-moon-ide-")
  copy_fixture_file(name, "moon.mod.fixture", target + "/moon.mod")
  copy_fixture_file(name, "moon.pkg.fixture", target + "/moon.pkg")
  copy_fixture_file(name, "lib.mbt.fixture", target + "/lib.mbt")
  target
}

///|
async fn copy_fixture_file(
  fixture : String,
  file : String,
  target : String,
) -> Unit {
  let content = @fs.read_file("agent_tool/moon_ide/fixtures/\{fixture}/\{file}").text()
  @fs.write_file(target, content, create_mode=CreateOrTruncate)
}

///|
fn stable_moon_ide_output(
  content : String,
  project : String,
  canonical : String,
) -> String {
  content
  .replace_all(old=canonical, new="<fixture>")
  .replace_all(old=project, new="<fixture>")
}
