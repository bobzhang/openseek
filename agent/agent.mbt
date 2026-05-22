///|
let default_max_steps : Int = 1000

///|
/// Runs the OpenSeek agent loop for a single task.
pub async fn run(
  api_key : String,
  model : @deepseek.Model,
  task : String,
  max_steps? : Int = default_max_steps,
) -> Unit {
  let client = @client.Client(
    api_key~,
    model~,
    thinking=Some(Enabled),
    reasoning_effort=Some(Max),
  )
  let tools = tool_definitions() catch {
    error => {
      let error_log = log.error()
      error_log <+ "agent setup failed: \{error}\n"
      return
    }
  }
  let messages : Array[@deepseek.ChatMessage] = [
    ChatMessage(System, content=system_prompt()),
    ChatMessage(User, content=task),
  ]
  for step in 0..<max_steps {
    log <+ "--- step \{step + 1} ---\n"
    let response = client.chat(messages, tools=tools.function_tools())
    if response.content != "" {
      log <+ "agent: \{response.content}\n"
    }
    print_usage(response.usage)
    if response.tool_calls.length() == 0 {
      log <+ "=== finished ===\n"
      log <+ "\{response.content}\n"
      return
    }
    let reasoning_content = match response.reasoning_content {
      "" => None
      content => Some(content)
    }
    let assistant_message : @deepseek.ChatMessage = ChatMessage(
      Assistant,
      content=response.content,
      tool_calls=response.tool_calls,
      reasoning_content?,
    )
    messages.push(assistant_message)
    for native_call in response.tool_calls {
      let tool_call = @agent_tool.AgentToolCall(native_call) catch {
        error => {
          let error_log = log.error()
          error_log <+ "tool: error: \{error}\n"
          messages.push(
            ChatMessage(Tool(native_call.id), content="error: \{error}"),
          )
          continue
        }
      }
      let result = @agent_tool.execute_tool_call(tool_call, tools)
      let output = match result {
        Control(Finish(answer)) => {
          log <+ "=== finished ===\n"
          log <+ "\{answer}\n"
          return
        }
        Control(Abort(reason)) => {
          let warn_log = log.warn()
          warn_log <+ "=== aborted ===\n"
          warn_log <+ "\{reason}\n"
          return
        }
        Respond(output) => output
      }
      let label = if output.is_error { "tool error" } else { "tool" }
      log <+ "\{label}: \{output.content}\n"
      messages.push(ChatMessage(Tool(native_call.id), content=output.content))
    }
  }
  let warn_log = log.warn()
  warn_log <+ "=== max steps exhausted ===\n"
}

///|
let log : @logger.Logger = @logger.stdout(min_level=INFO)

///|
async fn print_usage(usage : @deepseek.Usage) -> Unit {
  log <+
    "usage: prompt=\{usage.prompt_tokens} completion=\{usage.completion_tokens} cache_hit=\{usage.prompt_cache_hit_tokens} cache_miss=\{usage.prompt_cache_miss_tokens}\n"
}
