///|
priv struct ToolResult {
  output : String
  finished : Bool
}

///|
async fn execute_tool_call(call : AgentToolCall) -> ToolResult {
  match find_tool(call.name) {
    Some(tool) => tool.execute.run(call.arguments)
    None => continue_result("error: unknown tool \{call.name}")
  }
}

///|
async fn execute_shell(arguments : Json) -> ToolResult {
  match arguments {
    { "cmd": String(cmd), "cwd": String(cwd), .. } if cwd != "" =>
      continue_result(
        shell(cmd, Some(cwd)) catch {
          error => "error running shell: \{error}"
        },
      )
    { "cmd": String(cmd), .. } =>
      continue_result(
        shell(cmd, None) catch {
          error => "error running shell: \{error}"
        },
      )
    Object(_) => continue_result("error: shell requires arguments.cmd")
    _ => continue_result("error: shell requires object arguments")
  }
}

///|
async fn execute_read(arguments : Json) -> ToolResult {
  match arguments {
    { "path": String(path), .. } =>
      continue_result(
        @fs.read_file(path).text() catch {
          error => "error reading \{path}: \{error}"
        },
      )
    Object(_) => continue_result("error: read requires arguments.path")
    _ => continue_result("error: read requires object arguments")
  }
}

///|
async fn execute_write(arguments : Json) -> ToolResult {
  let (path, content) = match arguments {
    { "path": String(path), "content": String(content), .. } => (path, content)
    { "path": String(_), .. } =>
      return continue_result("error: write requires arguments.content")
    Object(_) => return continue_result("error: write requires arguments.path")
    _ => return continue_result("error: write requires object arguments")
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
  let answer = match arguments {
    { "answer": String(answer), .. } => answer
    _ => ""
  }
  { output: answer, finished: true }
}

///|
fn continue_result(output : String) -> ToolResult {
  { output, finished: false }
}

///|
async fn shell(cmd : String, cwd : String?) -> String {
  let (code, output) = match cwd {
    Some(cwd) => @process.collect_output_merged("sh", ["-c", cmd], cwd~)
    None => @process.collect_output_merged("sh", ["-c", cmd])
  }
  "exit=\{code}\n\{output.text()}"
}
