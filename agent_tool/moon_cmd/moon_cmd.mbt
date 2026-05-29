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
    name="moon_cmd",
    description="Run selected moon subcommands directly, optionally in arguments.cwd, and return exit code plus output.",
    schema=JsonSchema({
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
    execute=Async(execute),
  )
}

///|
async fn execute(arguments : Json) -> @agent_tool.ToolAction {
  let input = @decode.decode(arguments) catch {
    error => {
      let message = @tool_error.failure_message("\{error}")
      return @agent_tool.ToolAction::respond(
        "error: moon_cmd requires \{message}",
        is_error=true,
      )
    }
  }
  moon_cmd(input) catch {
    error =>
      @agent_tool.ToolAction::respond(
        "error running moon_cmd: \{error}",
        is_error=true,
      )
  }
}

///|
fn command_args(input : @decode.MoonCommandInput) -> Array[String] {
  let args : Array[String] = [input.command]
  match input.target {
    Some(target) => {
      args.push("--target")
      args.push(target)
    }
    None => ()
  }
  for arg in input.args {
    args.push(arg)
  }
  for path in input.paths {
    args.push(path)
  }
  if input.program_args.length() > 0 {
    args.push("--")
    for arg in input.program_args {
      args.push(arg)
    }
  }
  args
}

///|
async fn moon_cmd(input : @decode.MoonCommandInput) -> @agent_tool.ToolAction {
  let args = command_args(input)
  let (code, output) = collect_moon_output(args, input.cwd, input.stdin)
  let cwd_text = match input.cwd {
    Some(cwd) => cwd
    None => "."
  }
  let update_review = match (input.test_update_kind, input.test_update_reason) {
    (Some(kind), Some(reason)) => "\nsnapshot_update=\{kind}: \{reason}"
    _ => ""
  }
  let stdin_review = match input.stdin {
    Some(input) => "\nstdin_chars=\{input.length()}"
    None => ""
  }
  let body = output.text()
  let capped = cap_text(body, input.max_output_chars)
  let truncation = truncation_header(body, input.max_output_chars)
  @agent_tool.ToolAction::respond(
    "cwd=\{cwd_text}\ncommand=moon \{args.join(" ")}\{update_review}\{stdin_review}\nexit=\{code}\{truncation}\n\{capped}",
    is_error=code != 0 || is_truncated(body, input.max_output_chars),
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
          @process.collect_output_merged(
            "moon",
            args,
            stdin=process_input,
            cwd~,
          )
        None =>
          @process.collect_output_merged("moon", args, stdin=process_input)
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
  let input = @decode.decode({
    "command": "run",
    "cwd": "/tmp",
    "target": "native",
    "args": ["--quiet"],
    "path": "cmd/main",
    "program_args": ["input.toml", "--pretty"],
  })
  assert_eq(
    command_args(input).join("|"),
    "run|--target|native|--quiet|cmd/main|--|input.toml|--pretty",
  )
}

///|
test "moon_cmd parses singular and plural argument fields" {
  let input = @decode.decode({
    "command": "test",
    "arg": "--filter",
    "args": ["parser::*", "--quiet"],
    "path": "toml",
    "paths": ["README.mbt.md"],
  })
  assert_eq(
    command_args(input).join("|"),
    "test|--filter|parser::*|--quiet|toml|README.mbt.md",
  )
}

///|
test "moon_cmd rejects invalid command" {
  let _ = @decode.decode({ "command": "new" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.command"))
      return
    }
  }
  fail("invalid command parsed")
}

///|
test "moon_cmd rejects program args outside run" {
  let _ = @decode.decode({ "command": "test", "program_args": ["ignored"] }) catch {
    error => {
      assert_true("\{error}".contains("arguments.program_args"))
      return
    }
  }
  fail("invalid program args parsed")
}

///|
test "moon_cmd rejects stdin outside run" {
  let _ = @decode.decode({ "command": "test", "stdin": "input" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.stdin"))
      return
    }
  }
  fail("invalid stdin parsed")
}

///|
test "moon_cmd rejects target for fmt" {
  let _ = @decode.decode({ "command": "fmt", "target": "native" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.target"))
      return
    }
  }
  fail("invalid fmt target parsed")
}

///|
test "moon_cmd rejects moon test update without classification" {
  let _ = @decode.decode({ "command": "test", "arg": "--update" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.test_update_kind"))
      return
    }
  }
  fail("unclassified test update parsed")
}

///|
test "moon_cmd rejects moon test update without reason" {
  let _ = @decode.decode({
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
  let input = @decode.decode({
    "command": "test",
    "arg": "--update",
    "test_update_kind": "stale_snapshot",
    "test_update_reason": "plain moon test only reported snapshot diffs",
  })
  assert_eq(command_args(input).join("|"), "test|--update")
  assert_true(input.test_update_kind is Some("stale_snapshot"))
}

///|
test "moon_cmd parses and caps output limit" {
  let input = @decode.decode({ "command": "check", "max_output_chars": 999999 })
  assert_eq(input.max_output_chars, @decode.hard_max_output_chars)
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
async test "moon_cmd runs a virtual filesystem native CLI fixture" {
  let project = @fs.tmpdir(prefix="openseek-moon-cmd-vfs-")
  @vfs.FileSystem({
    "moon.mod": (
      #|name = "openseek/moon_cmd_vfs_fixture"
      #|
      #|version = "0.1.0"
      #|
      #|preferred_target = "native"
      #|
    ),
    "cmd/main/moon.pkg": (
      #|import {
      #|  "moonbitlang/core/env"
      #|}
      #|
      #|supported_targets = "+native"
      #|
      #|options(
      #|  "is-main": true,
      #|)
      #|
    ),
    "cmd/main/main.mbt": (
      #|///|
      #|fn main {
      #|  if has_probe_arg() {
      #|    println("moon-cmd-vfs-probe")
      #|  } else {
      #|    println("moon-cmd-vfs-missing")
      #|  }
      #|}
      #|
      #|///|
      #|fn has_probe_arg() -> Bool {
      #|  for arg in @env.args() {
      #|    if arg == "--probe" {
      #|      return true
      #|    }
      #|  }
      #|  false
      #|}
      #|
    ),
    "cmd/main/main_wbtest.mbt": (
      #|///|
      #|test "probe helper default" {
      #|  assert_false(has_probe_arg())
      #|}
      #|
    ),
  }).write_to(project)
  let canonical = @fs.realpath(project)
  let result = execute({
    "cwd": project,
    "command": "run",
    "target": "native",
    "path": "cmd/main",
    "program_args": ["--probe"],
  })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  inspect(
    stable_moon_cmd_output(output.content, project, canonical).trim(),
    content=(
      #|cwd=<fixture>
      #|command=moon run --target native cmd/main -- --probe
      #|exit=0
      #|moon-cmd-vfs-probe
    ),
  )
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
  .replace_all(old="Downloading moonbitlang/async@0.19.1\n", new="")
}
