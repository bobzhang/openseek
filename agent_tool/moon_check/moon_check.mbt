///|
/// Tool definition for `moon_check`: runs `moon check --output-json` directly,
/// optionally in `arguments.cwd`, and returns the real process exit code plus
/// merged stdout/stderr output.
///
/// ## Arguments
/// - `cwd` (string, optional): working directory. Empty means current process
///   directory.
/// - `path` (string, optional): one package/file path to pass to `moon check`.
/// - `paths` (array of strings, optional): additional package/file paths.
/// - `target` (string, optional): one of MoonBit's `moon check --target`
///   values.
/// - `warn_list` (string, optional): value for `--warn-list`.
/// - `deny_warn` (bool, optional): add `--deny-warn` when true.
/// - `fmt` (bool, optional): add `--fmt` when true.
/// - `explain` (bool, optional): add `--explain` when true.
///
/// ## Result
/// - `Respond(ToolOutput("cwd=...\ncommand=...\nexit=<code>\n<output>",
///   is_error=<code != 0>))` when `moon` runs.
/// - `Respond(ToolOutput("error running moon_check: ...", is_error=true))`
///   when launching the process raises.
/// - `Respond(ToolOutput("error: moon_check requires ...", is_error=true))`
///   for invalid arguments.
pub fn definition() -> @agent_tool.AgentToolDefinition {
  AgentToolDefinition(
    name="moon_check",
    description="Run moon check --output-json directly, optionally in arguments.cwd, and return exit code plus output.",
    schema=JsonSchema({
      "type": "object",
      "properties": {
        "cwd": { "type": "string" },
        "path": { "type": "string" },
        "paths": { "type": "array", "items": { "type": "string" } },
        "target": {
          "type": "string",
          "enum": ["wasm", "wasm-gc", "js", "native", "llvm", "all"],
        },
        "warn_list": { "type": "string" },
        "deny_warn": { "type": "boolean" },
        "fmt": { "type": "boolean" },
        "explain": { "type": "boolean" },
      },
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
        "error: moon_check requires \{message}",
        is_error=true,
      )
    }
  }
  moon_check(input) catch {
    error =>
      @agent_tool.ToolAction::respond(
        "error running moon_check: \{error}",
        is_error=true,
      )
  }
}

///|
fn command_args(input : @decode.MoonCheckInput) -> Array[String] {
  let args : Array[String] = ["check", "--output-json"]
  match input.target {
    Some(target) => {
      args.push("--target")
      args.push(target)
    }
    None => ()
  }
  match input.warn_list {
    Some(warn_list) => {
      args.push("--warn-list")
      args.push(warn_list)
    }
    None => ()
  }
  if input.deny_warn {
    args.push("--deny-warn")
  }
  if input.fmt {
    args.push("--fmt")
  }
  if input.explain {
    args.push("--explain")
  }
  for path in input.paths {
    args.push(path)
  }
  args
}

///|
async fn moon_check(input : @decode.MoonCheckInput) -> @agent_tool.ToolAction {
  let args = command_args(input)
  let (code, output) = match input.cwd {
    Some(cwd) => @process.collect_output_merged("moon", args, cwd~)
    None => @process.collect_output_merged("moon", args)
  }
  let cwd_text = match input.cwd {
    Some(cwd) => cwd
    None => "."
  }
  @agent_tool.ToolAction::respond(
    "cwd=\{cwd_text}\ncommand=moon \{args.join(" ")}\nexit=\{code}\n\{output.text()}",
    is_error=code != 0,
  )
}

///|
test "moon_check advertises expected schema" {
  let tool = definition()
  assert_eq(tool.name, "moon_check")
  let JsonSchema(schema) = tool.schema
  let text = schema.stringify()
  assert_true(text.contains("\"path\""))
  assert_true(text.contains("\"paths\""))
  assert_true(text.contains("\"target\""))
}

///|
test "moon_check builds direct moon command arguments" {
  let input = @decode.decode({
    "cwd": "/tmp",
    "paths": ["agent", "README.mbt.md"],
    "target": "native",
    "warn_list": "+unnecessary_annotation",
    "deny_warn": true,
    "fmt": true,
    "explain": true,
  })
  assert_eq(
    command_args(input).join("|"),
    "check|--output-json|--target|native|--warn-list|+unnecessary_annotation|--deny-warn|--fmt|--explain|agent|README.mbt.md",
  )
}

///|
test "moon_check parses path and paths together" {
  let input = @decode.decode({
    "path": "agent",
    "paths": ["agent_tool/read", "agent_tool/write"],
  })
  assert_eq(input.paths.join("|"), "agent|agent_tool/read|agent_tool/write")
}

///|
test "moon_check rejects invalid target" {
  let _ = @decode.decode({ "target": "browser" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.target"))
      return
    }
  }
  fail("invalid target parsed")
}

///|
async test "moon_check rejects non-object arguments" {
  let result = execute(Json::null())
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: moon_check requires object arguments")
  assert_true(output.is_error)
}

///|
async test "moon_check validates a real fixture project" {
  let project = copy_fixture_project("valid_project")
  let canonical = @fs.realpath(project)
  let result = execute({ "cwd": project })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  inspect(
    stable_moon_check_output(output.content, project, canonical),
    content=(
      #|cwd=<fixture>
      #|command=moon check --output-json
      #|exit=0
      #|Finished. moon: ran 2 tasks, now up to date
    ),
  )
}

///|
async test "moon_check reports diagnostics from a broken fixture project" {
  let project = copy_fixture_project("invalid_project")
  let canonical = @fs.realpath(project)
  let result = execute({ "cwd": project })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  inspect(
    stable_moon_check_output(output.content, project, canonical),
    content=(
      #|cwd=<fixture>
      #|command=moon check --output-json
      #|exit=255
      #|{"$message_type":"diagnostic","level":"error","error_code":4014,"path":"<fixture>/lib.mbt","loc":"3:3-3:15","message":"Expr Type Mismatch\n        has type : String\n        wanted   : Int"}
      #|Failed with 0 warnings, 1 errors.
      #|Error: failed when checking project
    ),
  )
}

///|
async fn copy_fixture_project(name : String) -> String {
  let target = @fs.tmpdir(prefix="openseek-moon-check-")
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
  let content = @fs.read_file(
    "agent_tool/moon_check/fixtures/\{fixture}/\{file}",
  ).text()
  @fs.write_file(target, content, create_mode=CreateOrTruncate)
}

///|
fn stable_moon_check_output(
  content : String,
  project : String,
  canonical : String,
) -> String {
  let normalized = content
    .replace_all(old=canonical, new="<fixture>")
    .replace_all(old=project, new="<fixture>")
  let stable_lines : Array[String] = []
  for line in normalized.split("\n") {
    if !line.has_prefix("failed: ") {
      stable_lines.push(line.to_owned())
    }
  }
  stable_lines.join("\n").trim().to_owned()
}
