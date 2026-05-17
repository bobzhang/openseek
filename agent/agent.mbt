///|
let max_steps : Int = 20

///|
let system_prompt : String =
  #|You are OpenSeek, a small MoonBit coding agent.
  #|Reply with exactly one JSON object and no markdown:
  #|{"action":"shell","args":{"cmd":"moon check"}}
  #|{"action":"read","args":{"path":"moon.mod.json"}}
  #|{"action":"write","args":{"path":"file.mbt","content":"..."}}
  #|{"action":"finish","args":{"answer":"..."}}
  #|
  #|Tools:
  #|shell: run args.cmd through sh -c and receive exit code plus output.
  #|read: read args.path as text.
  #|write: overwrite args.path with args.content.
  #|finish: end the task with args.answer.
  #|
  #|Prefer small MoonBit changes. Use ///| block separators. Run moon check or
  #|moon test before finish when code changed.

///|
/// Runs the OpenSeek agent loop for a single task.
pub async fn run(
  api_key : String,
  model : @deepseek.Model,
  task : String,
) -> Unit {
  let client = @client.Client(api_key, model~)
  let messages : Array[@deepseek.ChatMessage] = [
    ChatMessage(System, system_prompt),
    ChatMessage(User, task),
  ]
  for step in 0..<max_steps {
    println("--- step \{step + 1} ---")
    let response = client.chat(messages, json_response=true)
    println("agent: \{response.content}")
    print_usage(response.usage)
    messages.push(ChatMessage(Assistant, response.content))
    let action_json = @json.parse(response.content) catch {
      _ => {
        messages.push(
          ChatMessage(
            User,
            "error: reply was not valid JSON. Reply with exactly one JSON object.",
          ),
        )
        continue
      }
    }
    guard field(action_json, "action") is Some(String(action)) else {
      messages.push(ChatMessage(User, "error: missing string field action"))
      continue
    }
    let args = match field(action_json, "args") {
      Some(args) => args
      None => Json::object(Map([]))
    }
    if action == "finish" {
      let answer = match field(args, "answer") {
        Some(String(answer)) => answer
        _ => ""
      }
      println("=== finished ===")
      println(answer)
      return
    }
    let result = dispatch(action, args)
    println("tool: \{result}")
    messages.push(ChatMessage(User, result))
  }
  println("=== max steps exhausted ===")
}

///|
async fn dispatch(action : String, args : Json) -> String {
  match action {
    "shell" => {
      guard field(args, "cmd") is Some(String(cmd)) else {
        return "error: shell requires args.cmd"
      }
      shell(cmd) catch {
        error => "error running shell: \{error}"
      }
    }
    "read" => {
      guard field(args, "path") is Some(String(path)) else {
        return "error: read requires args.path"
      }
      @fs.read_file(path).text() catch {
        error => "error reading \{path}: \{error}"
      }
    }
    "write" => {
      guard field(args, "path") is Some(String(path)) else {
        return "error: write requires args.path and args.content"
      }
      guard field(args, "content") is Some(String(content)) else {
        return "error: write requires args.path and args.content"
      }
      try {
        @fs.write_file(path, content, create_mode=CreateOrTruncate)
        "ok: wrote \{content.length()} chars to \{path}"
      } catch {
        error => "error writing \{path}: \{error}"
      }
    }
    other => "error: unknown action \{other}"
  }
}

///|
async fn shell(cmd : String) -> String {
  let (code, output) = @process.collect_output_merged("sh", ["-c", cmd])
  "exit=\{code}\n\{output.text()}"
}

///|
fn field(json : Json, key : String) -> Json? {
  match json {
    Object(fields) => fields.get(key)
    _ => None
  }
}

///|
fn print_usage(usage : @deepseek.Usage) -> Unit {
  println(
    "usage: prompt=\{usage.prompt_tokens} completion=\{usage.completion_tokens} cache_hit=\{usage.prompt_cache_hit_tokens} cache_miss=\{usage.prompt_cache_miss_tokens}",
  )
}
