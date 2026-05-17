///|
let max_steps : Int = 20

///|
/// Runs the OpenSeek agent loop for a single task.
pub async fn run(
  api_key : String,
  model : @deepseek.Model,
  task : String,
) -> Unit {
  let client = @client.Client(api_key~, model~)
  let messages : Array[@deepseek.ChatMessage] = [
    ChatMessage(System, system_prompt()),
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
            "error: reply was not valid JSON. Reply with exactly one JSON tool call object.",
          ),
        )
        continue
      }
    }
    let tool_call = match ToolCall::from_json(action_json) {
      Ok(tool_call) => tool_call
      Err(error) => {
        messages.push(ChatMessage(User, "error: \{error}"))
        continue
      }
    }
    let result = execute_tool_call(tool_call)
    if result.finished {
      println("=== finished ===")
      println(result.output)
      return
    }
    println("tool: \{result.output}")
    messages.push(ChatMessage(User, result.output))
  }
  println("=== max steps exhausted ===")
}

///|
fn print_usage(usage : @deepseek.Usage) -> Unit {
  println(
    "usage: prompt=\{usage.prompt_tokens} completion=\{usage.completion_tokens} cache_hit=\{usage.prompt_cache_hit_tokens} cache_miss=\{usage.prompt_cache_miss_tokens}",
  )
}
