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
/// - `Continue("exit=<code>\n<output>")` on success — exit code from `sh -c`
///   followed by merged stdout/stderr.
/// - `Continue("error running shell: ...")` when launching the process raises.
/// - `Continue("error: shell requires arguments.cmd")` if `cmd` is missing
///   from an otherwise object-shaped payload.
/// - `Continue("error: shell requires object arguments")` if the payload is
///   not a JSON object.
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
async fn execute(arguments : Json) -> @agent_tool.ToolResult {
  match arguments {
    { "cmd": String(cmd), "cwd": String(cwd), .. } if cwd != "" =>
      Continue(
        shell(cmd, Some(cwd)) catch {
          error => "error running shell: \{error}"
        },
      )
    { "cmd": String(cmd), .. } =>
      Continue(
        shell(cmd, None) catch {
          error => "error running shell: \{error}"
        },
      )
    Object(_) => Continue("error: shell requires arguments.cmd")
    _ => Continue("error: shell requires object arguments")
  }
}

///|
async fn shell(cmd : String, cwd : String?) -> String {
  let (code, output) = match cwd {
    Some(cwd) => @process.collect_output_merged("sh", ["-c", cmd], cwd~)
    None => @process.collect_output_merged("sh", ["-c", cmd])
  }
  "exit=\{code}\n\{output.text()}"
}

///|
async test "shell runs cmd and returns exit code plus output" {
  let result = execute({ "cmd": "echo hello" })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_true(output.contains("exit=0"))
  assert_true(output.contains("hello"))
}

///|
async test "shell propagates non-zero exit codes" {
  let result = execute({ "cmd": "exit 7" })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_true(output.contains("exit=7"))
}

///|
async test "shell honors cwd when non-empty" {
  let result = execute({ "cmd": "pwd", "cwd": "/tmp" })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_true(output.contains("exit=0"))
  assert_true(output.contains("/tmp"))
}

///|
async test "shell treats empty cwd as missing" {
  let result = execute({ "cmd": "echo cwdless", "cwd": "" })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_true(output.contains("exit=0"))
  assert_true(output.contains("cwdless"))
}

///|
async test "shell merges stderr into the captured output" {
  let result = execute({ "cmd": "echo oops 1>&2" })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_true(output.contains("oops"))
}

///|
async test "shell rejects missing cmd" {
  let result = execute({ "cwd": "/tmp" })
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, "error: shell requires arguments.cmd")
}

///|
async test "shell rejects non-object arguments" {
  let result = execute(Json::null())
  guard result is Continue(output) else { fail("expected Continue") }
  assert_eq(output, "error: shell requires object arguments")
}
