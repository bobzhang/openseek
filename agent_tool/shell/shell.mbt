///|
/// Tool definition for `shell`: runs `arguments.cmd` through `sh -c`,
/// optionally in `arguments.cwd`, and returns the exit code plus merged
/// stdout/stderr output.
///
/// ## Arguments
/// - `cmd` (string, required): shell command line passed to `sh -c`.
/// - `cwd` (string, optional): working directory the command runs in.
///   An empty string is treated the same as a missing field.
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
      "properties": { "cmd": { "type": "string" }, "cwd": { "type": "string" } },
      "required": ["cmd"],
    }),
    Async(execute),
  )
}

///|
async fn execute(arguments : Json) -> @agent_tool.ToolAction {
  match arguments {
    { "cmd": String(cmd), "cwd": String(cwd), .. } if cwd != "" =>
      shell(cmd, Some(cwd)) catch {
        error =>
          @agent_tool.ToolAction::respond(
            "error running shell: \{error}",
            is_error=true,
          )
      }
    { "cmd": String(cmd), .. } =>
      shell(cmd, None) catch {
        error =>
          @agent_tool.ToolAction::respond(
            "error running shell: \{error}",
            is_error=true,
          )
      }
    Object(_) =>
      @agent_tool.ToolAction::respond(
        "error: shell requires arguments.cmd",
        is_error=true,
      )
    _ =>
      @agent_tool.ToolAction::respond(
        "error: shell requires object arguments",
        is_error=true,
      )
  }
}

///|
async fn shell(cmd : String, cwd : String?) -> @agent_tool.ToolAction {
  let (code, output) = match cwd {
    Some(cwd) => @process.collect_output_merged("sh", ["-c", cmd], cwd~)
    None => @process.collect_output_merged("sh", ["-c", cmd])
  }
  @agent_tool.ToolAction::respond(
    "exit=\{code}\n\{output.text()}",
    is_error=code != 0,
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
  assert_eq(output.content, "error: shell requires arguments.cmd")
}

///|
async test "shell rejects non-object arguments" {
  let result = execute(Json::null())
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_eq(output.content, "error: shell requires object arguments")
}
