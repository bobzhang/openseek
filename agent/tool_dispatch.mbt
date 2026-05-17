///|
priv struct ToolResult {
  output : String
  finished : Bool
}

///|
async fn execute_tool_call(call : ToolCall) -> ToolResult {
  match call.name {
    "shell" => execute_shell(call.arguments)
    "read" => execute_read(call.arguments)
    "write" => execute_write(call.arguments)
    "finish" => execute_finish(call.arguments)
    other => continue_result("error: unknown tool \{other}")
  }
}

///|
async fn execute_shell(arguments : Json) -> ToolResult {
  match required_string_argument(arguments, "shell", "cmd") {
    Ok(cmd) =>
      continue_result(
        shell(cmd) catch {
          error => "error running shell: \{error}"
        },
      )
    Err(error) => continue_result("error: \{error}")
  }
}

///|
async fn execute_read(arguments : Json) -> ToolResult {
  match required_string_argument(arguments, "read", "path") {
    Ok(path) =>
      continue_result(
        @fs.read_file(path).text() catch {
          error => "error reading \{path}: \{error}"
        },
      )
    Err(error) => continue_result("error: \{error}")
  }
}

///|
async fn execute_write(arguments : Json) -> ToolResult {
  let path = match required_string_argument(arguments, "write", "path") {
    Ok(path) => path
    Err(error) => return continue_result("error: \{error}")
  }
  let content = match required_string_argument(arguments, "write", "content") {
    Ok(content) => content
    Err(error) => return continue_result("error: \{error}")
  }
  try {
    @fs.write_file(path, content, create_mode=CreateOrTruncate)
    continue_result("ok: wrote \{content.length()} chars to \{path}")
  } catch {
    error => continue_result("error writing \{path}: \{error}")
  }
}

///|
fn execute_finish(arguments : Json) -> ToolResult {
  let answer = match required_string_argument(arguments, "finish", "answer") {
    Ok(answer) => answer
    Err(_) => ""
  }
  { output: answer, finished: true }
}

///|
fn continue_result(output : String) -> ToolResult {
  { output, finished: false }
}

///|
async fn shell(cmd : String) -> String {
  let (code, output) = @process.collect_output_merged("sh", ["-c", cmd])
  "exit=\{code}\n\{output.text()}"
}
