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
      },
      "required": ["command"],
    }),
    Async(execute),
  )
}

///|
priv struct MoonCommandOptions {
  command : String
  cwd : String?
  target : String?
  args : Array[String]
  paths : Array[String]
  program_args : Array[String]
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
  { command, cwd, target, args, paths, program_args }
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
  let (code, output) = match options.cwd {
    Some(cwd) => @process.collect_output_merged("moon", args, cwd~)
    None => @process.collect_output_merged("moon", args)
  }
  let cwd_text = match options.cwd {
    Some(cwd) => cwd
    None => "."
  }
  @agent_tool.ToolAction::respond(
    "cwd=\{cwd_text}\ncommand=moon \{args.join(" ")}\nexit=\{code}\n\{output.text()}",
    is_error=code != 0,
  )
}

///|
test "moon_cmd advertises expected schema" {
  let tool = definition()
  assert_eq(tool.name, "moon_cmd")
  let JsonSchema(schema) = tool.schema
  let text = schema.stringify()
  assert_true(text.contains("\"command\""))
  assert_true(text.contains("\"program_args\""))
  assert_true(text.contains("\"target\""))
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
    "arg": "--update",
    "args": ["--filter", "parser::*"],
    "path": "toml",
    "paths": ["README.mbt.md"],
  })
  assert_eq(
    options.command_args().join("|"),
    "test|--update|--filter|parser::*|toml|README.mbt.md",
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
async test "moon_cmd rejects non-object arguments" {
  let result = execute(Json::null())
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: moon_cmd requires object arguments")
  assert_true(output.is_error)
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
}
