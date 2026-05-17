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
    let response = client.chat(messages, tools=function_tools())
    if response.content != "" {
      println("agent: \{response.content}")
    }
    print_usage(response.usage)
    if response.tool_calls.length() == 0 {
      println("=== finished ===")
      println(response.content)
      return
    }
    messages.push(
      @deepseek.ChatMessage::assistant_tool_calls(response.tool_calls),
    )
    for native_call in response.tool_calls {
      let tool_call = match AgentToolCall::from_deepseek(native_call) {
        Ok(tool_call) => tool_call
        Err(error) => {
          println("tool: error: \{error}")
          messages.push(ChatMessage(Tool(native_call.id), "error: \{error}"))
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
      messages.push(ChatMessage(Tool(native_call.id), result.output))
    }
  }
  println("=== max steps exhausted ===")
}

///|
fn print_usage(usage : @deepseek.Usage) -> Unit {
  println(
    "usage: prompt=\{usage.prompt_tokens} completion=\{usage.completion_tokens} cache_hit=\{usage.prompt_cache_hit_tokens} cache_miss=\{usage.prompt_cache_miss_tokens}",
  )
}
