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
    name="shell",
    description="Run arguments.cmd through sh -c, optionally in arguments.cwd, and return exit code plus output.",
    schema=JsonSchema({
      "type": "object",
      "properties": {
        "cmd": { "type": "string" },
        "cwd": { "type": "string" },
        "max_output_chars": { "type": "number" },
      },
      "required": ["cmd"],
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
        "error: shell requires \{message}",
        is_error=true,
      )
    }
  }
  match moonbit_command_policy_error(input.cmd) {
    Some(message) =>
      return @agent_tool.ToolAction::respond(message, is_error=true)
    None => ()
  }
  shell(input) catch {
    error =>
      @agent_tool.ToolAction::respond(
        "error running shell: \{error}",
        is_error=true,
      )
  }
}

///|
fn moonbit_command_policy_error(cmd : String) -> String? {
  let words = shell_words(cmd)
  let command_index = first_command_word_index(words)
  match command_index {
    None => None
    Some(index) => {
      let first = words[index]
      if first == "moon_cmd" {
        return Some(
          "error: moon_cmd is a tool, not a shell command; call the moon_cmd tool directly",
        )
      }
      if first == "moon" && index + 1 < words.length() {
        let subcommand = words[index + 1]
        if guarded_moon_subcommands().contains(subcommand) {
          return Some(
            "error: shell blocked `moon \{subcommand}`; use the moon_cmd tool so MoonBit commands keep structured args, output caps, and guardrails",
          )
        }
      }
      if contains_guarded_moon_fragment(cmd) {
        Some(
          "error: shell blocked an embedded MoonBit command; use cwd plus moon_cmd instead of `cd ... && moon ...`",
        )
      } else {
        None
      }
    }
  }
}

///|
fn guarded_moon_subcommands() -> Array[String] {
  ["check", "test", "run", "info", "fmt", "build"]
}

///|
fn shell_words(cmd : String) -> Array[String] {
  let words : Array[String] = []
  for piece in cmd.split(" ") {
    let word = clean_shell_word(piece.to_owned())
    if word != "" {
      words.push(word)
    }
  }
  words
}

///|
fn clean_shell_word(word : String) -> String {
  word.trim(chars="\t\r\n ").to_owned().trim(chars=";&|()").to_owned()
}

///|
fn first_command_word_index(words : Array[String]) -> Int? {
  for index, word in words {
    if !looks_like_env_assignment(word) {
      return Some(index)
    }
  }
  None
}

///|
fn looks_like_env_assignment(word : String) -> Bool {
  if word.contains("/") || word.contains("-") {
    return false
  }
  let parts = word.split("=").map(part => part.to_owned()).collect()
  parts.length() == 2 && parts[0] != "" && parts[1] != ""
}

///|
fn contains_guarded_moon_fragment(cmd : String) -> Bool {
  let probes = ["&& moon ", "; moon ", "\nmoon "]
  for probe in probes {
    for subcommand in guarded_moon_subcommands() {
      if cmd.contains(probe + subcommand) {
        return true
      }
    }
  }
  false
}

///|
async fn shell(input : @decode.ShellInput) -> @agent_tool.ToolAction {
  if input.cwd is Some(cwd) {
    let exists = @fs.exists(cwd)
    if !exists {
      return @agent_tool.ToolAction::respond(
        "error: cwd does not exist: \{cwd}",
        is_error=true,
      )
    }
    let kind = @fs.kind(cwd)
    if kind != Directory {
      return @agent_tool.ToolAction::respond(
        "error: cwd is not a directory: \{cwd}",
        is_error=true,
      )
    }
  }
  let (code, output) = match input.cwd {
    Some(cwd) => @process.collect_output_merged("sh", ["-c", input.cmd], cwd~)
    None => @process.collect_output_merged("sh", ["-c", input.cmd])
  }
  let body = output.text()
  let capped = cap_text(body, input.max_output_chars)
  let truncation = truncation_header(body, input.max_output_chars)
  @agent_tool.ToolAction::respond(
    "exit=\{code}\{truncation}\n\{capped}",
    is_error=code != 0 || is_truncated(body, input.max_output_chars),
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
  let input = @decode.decode({
    "cmd": "echo hello",
    "cwd": "/tmp",
    "max_output_chars": 999999,
  })
  assert_eq(input.cmd, "echo hello")
  assert_true(input.cwd is Some("/tmp"))
  assert_eq(input.max_output_chars, @decode.hard_max_output_chars)
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
async test "shell reads a virtual filesystem fixture from cwd" {
  let project = @fs.tmpdir(prefix="openseek-shell-vfs-")
  @vfs.FileSystem({
    "data/input.txt": (
      #|shell-vfs
      #|
    ),
  }).write_to(project)
  let result = execute({ "cmd": "cat data/input.txt", "cwd": project })
  let _ = @fs.rmdir(project, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  inspect(
    output.content.trim(),
    content=(
      #|exit=0
      #|shell-vfs
    ),
  )
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
test "shell detects moon command policy errors" {
  assert_true(moonbit_command_policy_error("moon test") is Some(_))
  assert_true(
    moonbit_command_policy_error("DEEPSEEK_MODEL=x moon run cmd/main")
    is Some(_),
  )
  assert_true(moonbit_command_policy_error("cd demo && moon check") is Some(_))
  assert_true(moonbit_command_policy_error("moon --version") is None)
  assert_true(moonbit_command_policy_error("git status --short") is None)
}

///|
async test "shell rejects moon run and points to moon_cmd" {
  let result = execute({ "cmd": "moon run --target native cmd/main -- .a" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_true(output.content.contains("shell blocked `moon run`"))
  assert_true(output.content.contains("moon_cmd"))
}

///|
async test "shell rejects moon_cmd as a shell command" {
  let result = execute({ "cmd": "moon_cmd run cmd/main" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_true(output.content.contains("moon_cmd is a tool"))
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

///|
async test "shell rejects non-existent cwd" {
  let result = execute({ "cmd": "echo hello", "cwd": "/nonexistent/path/xyz" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_true(output.content.contains("cwd does not exist"))
}

///|
async test "shell rejects cwd that is a file not a directory" {
  // Use a path that is known to exist and be a file-like entity
  let result = execute({ "cmd": "echo hello", "cwd": "/dev/null" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_true(output.content.contains("cwd is not a directory"))
}
