///|
/// Tool definition for `moon_cmd`: runs selected `moon` subcommands directly,
/// optionally in `arguments.cwd`, and returns the real process exit code plus
/// merged stdout/stderr output.
///
/// ## Arguments
/// - `command` (string, required): one of `check`, `test`, `run`, `info`,
///   `fmt`, or `build`.
/// - `cwd` (string, optional): working directory. Empty means current process
///   directory.
/// - `target` (string, optional): one of MoonBit's `--target` values. `fmt`
///   does not accept targets.
/// - `arg` (string, optional): one extra moon argument before positional paths.
/// - `args` (array of strings, optional): more moon arguments before paths.
/// - `path` (string, optional): one package/file/main path.
/// - `paths` (array of strings, optional): additional package/file/main paths.
/// - `program_args` (array of strings, optional): arguments after `--`; only
///   valid for `run`.
/// - `stdin` (string, optional): text sent to process stdin; only valid for
///   `run`.
/// - `test_update_kind` (string, optional): required when running
///   `moon test --update`; use `stale_snapshot` or
///   `intentional_output_change`.
/// - `test_update_reason` (string, optional): required when running
///   `moon test --update`; summarize the prior failure review.
/// - `max_output_chars` (number, optional): defaults to 12000 and is capped at
///   50000. Truncated output is reported as a tool error even when the process
///   exits zero.
///
/// ## Result
/// - `Respond(ToolOutput("cwd=...\ncommand=...\nexit=<code>\n<output>",
///   is_error=<code != 0>))` when `moon` runs.
/// - `Respond(ToolOutput("error running moon_cmd: ...", is_error=true))`
///   when launching the process raises.
/// - `Respond(ToolOutput("error: moon_cmd requires ...", is_error=true))`
///   for invalid arguments.
pub fn definition() -> @agent_tool.AgentToolDefinition {
  AgentToolDefinition(
    "moon_cmd",
    "Run selected moon subcommands directly, optionally in arguments.cwd, and return exit code plus output.",
    JsonSchema({
      "type": "object",
      "properties": {
        "command": {
          "type": "string",
          "enum": ["check", "test", "run", "info", "fmt", "build"],
        },
        "cwd": { "type": "string" },
        "target": {
          "type": "string",
          "enum": ["wasm", "wasm-gc", "js", "native", "llvm", "all"],
        },
        "arg": { "type": "string" },
        "args": { "type": "array", "items": { "type": "string" } },
        "path": { "type": "string" },
        "paths": { "type": "array", "items": { "type": "string" } },
        "program_args": { "type": "array", "items": { "type": "string" } },
        "stdin": { "type": "string" },
        "test_update_kind": {
          "type": "string",
          "enum": ["stale_snapshot", "intentional_output_change"],
        },
        "test_update_reason": { "type": "string" },
        "max_output_chars": { "type": "number" },
      },
      "required": ["command"],
    }),
    Async(execute),
  )
}

///|
let default_max_output_chars : Int = 12000

///|
let hard_max_output_chars : Int = 50000

///|
priv struct MoonCommandOptions {
  command : String
  cwd : String?
  target : String?
  args : Array[String]
  paths : Array[String]
  program_args : Array[String]
  stdin : String?
  test_update_kind : String?
  test_update_reason : String?
  max_output_chars : Int
}

///|
async fn execute(arguments : Json) -> @agent_tool.ToolAction {
  let options = match arguments {
    Object(fields) =>
      parse_options(fields) catch {
        error =>
          return @agent_tool.ToolAction::respond(
            "error: moon_cmd requires \{error}",
            is_error=true,
          )
      }
    _ =>
      return @agent_tool.ToolAction::respond(
        "error: moon_cmd requires object arguments",
        is_error=true,
      )
  }
  moon_cmd(options) catch {
    error =>
      @agent_tool.ToolAction::respond(
        "error running moon_cmd: \{error}",
        is_error=true,
      )
  }
}

///|
fn parse_options(fields : Map[String, Json]) -> MoonCommandOptions raise {
  let command = required_string(fields, "command")
  validate_command(command)
  let cwd = optional_string(fields, "cwd")
  let target = optional_string(fields, "target")
  match target {
    Some(value) => {
      validate_target(value)
      validate_target_supported(command)
    }
    None => ()
  }
  let args = parse_arg_list(fields)
  let paths = parse_paths(fields)
  let program_args = optional_string_array(fields, "program_args")
  if program_args.length() > 0 && command != "run" {
    fail("arguments.program_args only with command run")
  }
  let stdin = optional_string(fields, "stdin")
  if stdin is Some(_) && command != "run" {
    fail("arguments.stdin only with command run")
  }
  let test_update_kind = optional_string(fields, "test_update_kind")
  let test_update_reason = optional_string(fields, "test_update_reason")
  let max_output_chars = optional_positive_int(
    fields, "max_output_chars", default_max_output_chars,
  )
  validate_test_update_guard(
    command, args, test_update_kind, test_update_reason,
  )
  {
    command,
    cwd,
    target,
    args,
    paths,
    program_args,
    stdin,
    test_update_kind,
    test_update_reason,
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
fn parse_arg_list(fields : Map[String, Json]) -> Array[String] raise {
  let args : Array[String] = []
  match fields.get("arg") {
    Some(String(arg)) if arg != "" => args.push(arg)
    Some(String(_)) | Some(Null) | None => ()
    _ => fail("arguments.arg to be a string")
  }
  for arg in optional_string_array(fields, "args") {
    args.push(arg)
  }
  args
}

///|
fn parse_paths(fields : Map[String, Json]) -> Array[String] raise {
  let paths : Array[String] = []
  match fields.get("path") {
    Some(String(path)) if path != "" => paths.push(path)
    Some(String(_)) | Some(Null) | None => ()
    _ => fail("arguments.path to be a string")
  }
  for path in optional_string_array(fields, "paths") {
    paths.push(path)
  }
  paths
}

///|
fn optional_string_array(
  fields : Map[String, Json],
  name : String,
) -> Array[String] raise {
  let values : Array[String] = []
  match fields.get(name) {
    Some(Array(items)) =>
      for item in items {
        match item {
          String(value) if value != "" => values.push(value)
          String(_) | Null => ()
          _ => fail("arguments.\{name} to be an array of strings")
        }
      }
    Some(Null) | None => ()
    _ => fail("arguments.\{name} to be an array of strings")
  }
  values
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
fn validate_command(command : String) -> Unit raise {
  let allowed = ["check", "test", "run", "info", "fmt", "build"]
  if !allowed.contains(command) {
    fail("arguments.command to be one of check, test, run, info, fmt, build")
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
fn validate_target_supported(command : String) -> Unit raise {
  if command == "fmt" {
    fail("arguments.target is not supported for command fmt")
  }
}

///|
fn validate_test_update_guard(
  command : String,
  args : Array[String],
  kind : String?,
  reason : String?,
) -> Unit raise {
  guard uses_test_update(command, args) else { return }
  match kind {
    Some("stale_snapshot") | Some("intentional_output_change") => ()
    Some(_) =>
      fail(
        "arguments.test_update_kind to be stale_snapshot or intentional_output_change for moon test --update",
      )
    None =>
      fail(
        "arguments.test_update_kind for moon test --update after reviewing a plain moon test failure; do not use --update for behavior bugs",
      )
  }
  match reason {
    Some(_) => ()
    None =>
      fail(
        "arguments.test_update_reason for moon test --update after reviewing a plain moon test failure",
      )
  }
}

///|
fn uses_test_update(command : String, args : Array[String]) -> Bool {
  if command != "test" {
    return false
  }
  for arg in args {
    if arg == "--update" || arg == "-u" {
      return true
    }
  }
  false
}

///|
fn MoonCommandOptions::command_args(self : MoonCommandOptions) -> Array[String] {
  let args : Array[String] = [self.command]
  match self.target {
    Some(target) => {
      args.push("--target")
      args.push(target)
    }
    None => ()
  }
  for arg in self.args {
    args.push(arg)
  }
  for path in self.paths {
    args.push(path)
  }
  if self.program_args.length() > 0 {
    args.push("--")
    for arg in self.program_args {
      args.push(arg)
    }
  }
  args
}

///|
async fn moon_cmd(options : MoonCommandOptions) -> @agent_tool.ToolAction {
  let args = options.command_args()
  let (code, output) = collect_moon_output(args, options.cwd, options.stdin)
  let cwd_text = match options.cwd {
    Some(cwd) => cwd
    None => "."
  }
  let update_review = match
    (options.test_update_kind, options.test_update_reason) {
    (Some(kind), Some(reason)) => "\nsnapshot_update=\{kind}: \{reason}"
    _ => ""
  }
  let stdin_review = match options.stdin {
    Some(input) => "\nstdin_chars=\{input.length()}"
    None => ""
  }
  let body = output.text()
  let capped = cap_text(body, options.max_output_chars)
  let truncation = truncation_header(body, options.max_output_chars)
  @agent_tool.ToolAction::respond(
    "cwd=\{cwd_text}\ncommand=moon \{args.join(" ")}\{update_review}\{stdin_review}\nexit=\{code}\{truncation}\n\{capped}",
    is_error=code != 0 || is_truncated(body, options.max_output_chars),
  )
}

///|
async fn collect_moon_output(
  args : Array[String],
  cwd : String?,
  stdin : String?,
) -> (Int, &@io.Data) {
  match stdin {
    None =>
      match cwd {
        Some(cwd) => @process.collect_output_merged("moon", args, cwd~)
        None => @process.collect_output_merged("moon", args)
      }
    Some(input) => {
      let dir = @fs.tmpdir(prefix="openseek-moon-cmd-stdin-")
      let input_path = dir + "/stdin"
      @fs.write_file(input_path, input, create_mode=CreateOrTruncate)
      let process_input = @process.redirect_from_file(input_path)
      let result = match cwd {
        Some(cwd) =>
          @process.collect_output_merged("moon", args, stdin=process_input, cwd~)
        None => @process.collect_output_merged("moon", args, stdin=process_input)
      }
      let _ = @fs.rmdir(dir, recursive=true) catch { _ => () }
      result
    }
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
test "moon_cmd advertises expected schema" {
  let tool = definition()
  assert_eq(tool.name, "moon_cmd")
  let JsonSchema(schema) = tool.schema
  let text = schema.stringify()
  assert_true(text.contains("\"command\""))
  assert_true(text.contains("\"program_args\""))
  assert_true(text.contains("\"stdin\""))
  assert_true(text.contains("\"target\""))
  assert_true(text.contains("\"test_update_kind\""))
  assert_true(text.contains("\"max_output_chars\""))
}

///|
test "moon_cmd builds direct moon command arguments" {
  let options : MoonCommandOptions = {
    command: "run",
    cwd: Some("/tmp"),
    target: Some("native"),
    args: ["--quiet"],
    paths: ["cmd/main"],
    program_args: ["input.toml", "--pretty"],
    stdin: None,
    test_update_kind: None,
    test_update_reason: None,
    max_output_chars: default_max_output_chars,
  }
  assert_eq(
    options.command_args().join("|"),
    "run|--target|native|--quiet|cmd/main|--|input.toml|--pretty",
  )
}

///|
test "moon_cmd parses singular and plural argument fields" {
  let options = parse_options({
    "command": "test",
    "arg": "--filter",
    "args": ["parser::*", "--quiet"],
    "path": "toml",
    "paths": ["README.mbt.md"],
  })
  assert_eq(
    options.command_args().join("|"),
    "test|--filter|parser::*|--quiet|toml|README.mbt.md",
  )
}

///|
test "moon_cmd rejects invalid command" {
  let _ = parse_options({ "command": "new" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.command"))
      return
    }
  }
  fail("invalid command parsed")
}

///|
test "moon_cmd rejects program args outside run" {
  let _ = parse_options({ "command": "test", "program_args": ["ignored"] }) catch {
    error => {
      assert_true("\{error}".contains("arguments.program_args"))
      return
    }
  }
  fail("invalid program args parsed")
}

///|
test "moon_cmd rejects stdin outside run" {
  let _ = parse_options({ "command": "test", "stdin": "input" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.stdin"))
      return
    }
  }
  fail("invalid stdin parsed")
}

///|
test "moon_cmd rejects target for fmt" {
  let _ = parse_options({ "command": "fmt", "target": "native" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.target"))
      return
    }
  }
  fail("invalid fmt target parsed")
}

///|
test "moon_cmd rejects moon test update without classification" {
  let _ = parse_options({ "command": "test", "arg": "--update" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.test_update_kind"))
      return
    }
  }
  fail("unclassified test update parsed")
}

///|
test "moon_cmd rejects moon test update without reason" {
  let _ = parse_options({
    "command": "test",
    "arg": "--update",
    "test_update_kind": "stale_snapshot",
  }) catch {
    error => {
      assert_true("\{error}".contains("arguments.test_update_reason"))
      return
    }
  }
  fail("unexplained test update parsed")
}

///|
test "moon_cmd accepts classified moon test update" {
  let options = parse_options({
    "command": "test",
    "arg": "--update",
    "test_update_kind": "stale_snapshot",
    "test_update_reason": "plain moon test only reported snapshot diffs",
  })
  assert_eq(options.command_args().join("|"), "test|--update")
  assert_true(options.test_update_kind is Some("stale_snapshot"))
}

///|
test "moon_cmd parses and caps output limit" {
  let options = parse_options({ "command": "check", "max_output_chars": 999999 })
  assert_eq(options.max_output_chars, hard_max_output_chars)
}

///|
test "moon_cmd records truncation metadata" {
  assert_eq(cap_text("abcdef", 3), "abc")
  assert_true(is_truncated("abcdef", 3))
  assert_eq(
    truncation_header("abcdef", 3),
    "\ntruncated=true\noutput_chars=6\nshown_chars=3",
  )
}

///|
async test "moon_cmd rejects non-object arguments" {
  let result = execute(Json::null())
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: moon_cmd requires object arguments")
  assert_true(output.is_error)
}

///|
async test "moon_cmd rejects unclassified test update before process launch" {
  let result = execute({ "command": "test", "arg": "--update" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_true(output.content.contains("arguments.test_update_kind"))
}

///|
async test "moon_cmd validates a native fixture CLI when target is explicit" {
  let project = copy_fixture_project("native_cli_project")
  let canonical = @fs.realpath(project)
  let result = execute({
    "cwd": project,
    "command": "run",
    "target": "native",
    "path": "cmd/main",
    "program_args": ["input.toml"],
  })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  let stable = stable_moon_cmd_output(output.content, project, canonical)
  assert_true(stable.contains("cwd=<fixture>"))
  assert_true(
    stable.contains("command=moon run --target native cmd/main -- input.toml"),
  )
  assert_true(stable.contains("exit=0"))
  assert_true(stable.contains("moon-cmd-ok"))
}

///|
async test "moon_cmd passes stdin to native fixture CLI" {
  let project = copy_fixture_project("native_cli_project")
  let canonical = @fs.realpath(project)
  let result = execute({
    "cwd": project,
    "command": "run",
    "target": "native",
    "path": "cmd/main",
    "program_args": ["--stdin"],
    "stdin": "hello\n",
  })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  let stable = stable_moon_cmd_output(output.content, project, canonical)
  assert_true(stable.contains("cwd=<fixture>"))
  assert_true(
    stable.contains("command=moon run --target native cmd/main -- --stdin"),
  )
  assert_true(stable.contains("stdin_chars=6"))
  assert_true(stable.contains("exit=0"))
  assert_true(stable.contains("stdin:hello"))
}

///|
async test "moon_cmd truncates oversized successful output as a tool error" {
  let project = copy_fixture_project("native_cli_project")
  let canonical = @fs.realpath(project)
  let result = execute({
    "cwd": project,
    "command": "run",
    "target": "native",
    "path": "cmd/main",
    "program_args": ["input.toml"],
    "max_output_chars": 10,
  })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  let stable = stable_moon_cmd_output(output.content, project, canonical)
  assert_true(stable.contains("cwd=<fixture>"))
  assert_true(
    stable.contains("command=moon run --target native cmd/main -- input.toml"),
  )
  assert_true(stable.contains("exit=0"))
  assert_true(stable.contains("truncated=true"))
  assert_true(stable.contains("shown_chars=10"))
}

///|
async test "moon_cmd catches default-target failure for native-only CLI" {
  let project = copy_fixture_project("native_cli_project")
  let canonical = @fs.realpath(project)
  let result = execute({
    "cwd": project,
    "command": "run",
    "path": "cmd/main",
    "program_args": ["input.toml"],
  })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  let stable = stable_moon_cmd_output(output.content, project, canonical)
  assert_true(stable.contains("cwd=<fixture>"))
  assert_true(stable.contains("command=moon run cmd/main -- input.toml"))
  assert_true(stable.contains("Package"))
  assert_true(stable.contains("does not support target backend"))
}

///|
async test "moon_cmd snapshots native fixture test output" {
  let project = copy_fixture_project("native_cli_project")
  let canonical = @fs.realpath(project)
  let result = execute({
    "cwd": project,
    "command": "test",
    "target": "native",
    "path": "cmd/main",
  })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  inspect(
    stable_moon_cmd_output(output.content, project, canonical).trim(),
    content=(
      #|cwd=<fixture>
      #|command=moon test --target native cmd/main
      #|exit=0
      #|Total tests: 1, passed: 1, failed: 0.
    ),
  )
}

///|
async test "moon_cmd reports failing fixture tests as tool errors" {
  let project = copy_fixture_project("native_cli_project")
  let canonical = @fs.realpath(project)
  @fs.write_file(
    project + "/cmd/main/main_wbtest.mbt",
    (
      #|///|
      #|test "intentional failure" {
      #|  assert_eq(1, 2)
      #|}
    ),
    create_mode=CreateOrTruncate,
  )
  let result = execute({
    "cwd": project,
    "command": "test",
    "target": "native",
    "path": "cmd/main",
  })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  let stable = stable_moon_cmd_output(output.content, project, canonical)
  assert_true(stable.contains("cwd=<fixture>"))
  assert_true(stable.contains("command=moon test --target native cmd/main"))
  assert_true(stable.contains("exit="))
  assert_true(stable.contains("intentional failure"))
  assert_true(stable.contains("failed:"))
}

///|
async fn copy_fixture_project(name : String) -> String {
  let target = @fs.tmpdir(prefix="openseek-moon-cmd-")
  @fs.mkdir(target + "/cmd/main", recursive=true)
  copy_fixture_file(name, "moon.mod.fixture", target + "/moon.mod")
  copy_fixture_file(name, "main.mbt.fixture", target + "/cmd/main/main.mbt")
  copy_fixture_file(
    name,
    "main_wbtest.mbt.fixture",
    target + "/cmd/main/main_wbtest.mbt",
  )
  copy_fixture_file(name, "moon.pkg.fixture", target + "/cmd/main/moon.pkg")
  target
}

///|
async fn copy_fixture_file(
  fixture : String,
  file : String,
  target : String,
) -> Unit {
  let content = @fs.read_file("agent_tool/moon_cmd/fixtures/\{fixture}/\{file}").text()
  @fs.write_file(target, content, create_mode=CreateOrTruncate)
}

///|
fn stable_moon_cmd_output(
  content : String,
  project : String,
  canonical : String,
) -> String {
  content
  .replace_all(old=canonical, new="<fixture>")
  .replace_all(old=project, new="<fixture>")
  .replace_all(old="Using cached moonbitlang/async@0.19.1\n", new="")
}
