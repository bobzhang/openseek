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
async fn main {
  let matches = cli_command().parse(env=@env.get_env_vars())
  let api_key = value(matches, "api-key")
  let model = @deepseek.Model::parse(value(matches, "model"))
  let task = values(matches, "task").join(" ")
  let client = @deepseek.Client(api_key, model~)
  let messages : Array[@deepseek.ChatMessage] = [
    @deepseek.ChatMessage::system(system_prompt),
    @deepseek.ChatMessage::user(task),
  ]
  for step in 0..<max_steps {
    println("--- step \{step + 1} ---")
    let response = client.chat(messages, json_response=true)
    println("agent: \{response.content}")
    print_usage(response.usage)
    messages.push(@deepseek.ChatMessage::assistant(response.content))
    let action_json = @json.parse(response.content) catch {
      _ => {
        messages.push(
          @deepseek.ChatMessage::user(
            "error: reply was not valid JSON. Reply with exactly one JSON object.",
          ),
        )
        continue
      }
    }
    guard field(action_json, "action") is Some(String(action)) else {
      messages.push(
        @deepseek.ChatMessage::user("error: missing string field action"),
      )
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
    messages.push(@deepseek.ChatMessage::user(result))
  }
  println("=== max steps exhausted ===")
}

///|
fn cli_command() -> @argparse.Command {
  @argparse.Command(
    "openseek",
    about="DeepSeek-backed MoonBit coding agent.",
    options=[
      @argparse.OptionArg(
        "api-key",
        long="api-key",
        env="DEEPSEEK",
        required=true,
        about="DeepSeek API key.",
      ),
      @argparse.OptionArg(
        "model",
        long="model",
        env="DEEPSEEK_MODEL",
        default_values=[@deepseek.V4Flash.to_string()],
        about="DeepSeek model: deepseek-v4-flash or deepseek-v4-pro.",
      ),
    ],
    positionals=[
      @argparse.PositionArg(
        "task",
        num_args=@argparse.ValueRange(lower=1),
        allow_hyphen_values=true,
        about="Task description.",
      ),
    ],
  )
}

///|
fn value(matches : @argparse.Matches, name : String) -> String raise {
  match matches.values.get(name) {
    Some([value]) => value
    Some(values) if values.length() > 0 => values[0]
    _ => fail("missing parsed argument: \{name}")
  }
}

///|
fn values(matches : @argparse.Matches, name : String) -> Array[String] raise {
  match matches.values.get(name) {
    Some(values) => values
    None => fail("missing parsed argument: \{name}")
  }
}

///|
test "cli parses env backed options and task" {
  let parsed = cli_command().parse(argv=["write", "MoonBit"], env={
    "DEEPSEEK": "test-key",
    "DEEPSEEK_MODEL": "deepseek-v4-pro",
  })
  assert_eq(value(parsed, "api-key"), "test-key")
  assert_eq(value(parsed, "model"), "deepseek-v4-pro")
  assert_eq(values(parsed, "task").join(" "), "write MoonBit")
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
