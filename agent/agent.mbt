///|
let default_max_steps : Int = 1000

///|
pub(all) enum LogFormat {
  Text
  Jsonl
}

///|
pub fn LogFormat::to_string(self : LogFormat) -> String {
  match self {
    Text => "text"
    Jsonl => "jsonl"
  }
}

///|
pub fn LogFormat::parse(input : String) -> LogFormat raise {
  match input {
    "text" => Text
    "jsonl" => Jsonl
    _ => fail("log format must be text or jsonl, got: \{input}")
  }
}

///|
/// Returns the base built-in system prompt.
pub fn default_system_prompt() -> String {
  @prompt.system_prompt_for_model(V4Pro)
}

///|
/// Returns the default system prompt for a DeepSeek model.
pub fn default_system_prompt_for_model(model : @deepseek.Model) -> String {
  @prompt.system_prompt_for_model(model)
}

///|
/// Runs the OpenSeek agent loop for a single task.
pub async fn run(
  api_key : String,
  model : @deepseek.Model,
  task : String,
  max_steps? : Int = default_max_steps,
  system_prompt_text? : String = default_system_prompt_for_model(model),
  log_format? : LogFormat = Jsonl,
) -> Unit {
  let log = AgentLog(log_format)
  let client = @client.Client(
    api_key~,
    model~,
    thinking=Some(Enabled),
    reasoning_effort=Some(Max),
  )
  let tools = tool_definitions() catch {
    error => {
      log.agent_setup_failed("\{error}")
      return
    }
  }
  let messages : Array[@deepseek.ChatMessage] = [
    ChatMessage(System, content=system_prompt_text),
    ChatMessage(User, content=task),
  ]
  for step in 0..<max_steps {
    log.step(step + 1)
    let response = client.chat(messages, tools=tools.function_tools())
    if response.content != "" {
      log.agent_content(response.content)
    }
    log.usage(response.usage)
    if response.tool_calls.length() == 0 {
      log.finish(response.content)
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
          log.tool_decode_error("\{error}")
          messages.push(
            ChatMessage(Tool(native_call.id), content="error: \{error}"),
          )
          continue
        }
      }
      let result = @agent_tool.execute_tool_call(tool_call, tools)
      let output = match result {
        Control(Finish(answer)) => {
          log.finish(answer)
          return
        }
        Control(Abort(reason)) => {
          log.abort(reason)
          return
        }
        Respond(output) => output
      }
      log.tool_output(output.is_error, output.content)
      messages.push(ChatMessage(Tool(native_call.id), content=output.content))
    }
  }
  log.max_steps_exhausted()
}

///|
priv struct AgentLog {
  format : LogFormat
  logger : @logger.Logger
}

///|
fn AgentLog::AgentLog(format : LogFormat) -> AgentLog {
  { format, logger: @logger.stdout(min_level=INFO) }
}

///|
async fn AgentLog::agent_setup_failed(
  self : AgentLog,
  message : String,
) -> Unit {
  match self.format {
    Text => {
      let logger = self.logger.error()
      logger <+ "agent setup failed: \{message}\n"
    }
    Jsonl =>
      self.jsonl(ERROR, "agent_setup_failed", [
        ("message", Json::string(message)),
      ])
  }
}

///|
async fn AgentLog::step(self : AgentLog, step : Int) -> Unit {
  match self.format {
    Text => {
      let logger = self.logger
      logger <+ "--- step \{step} ---\n"
    }
    Jsonl => self.jsonl(INFO, "step", [("step", int_json(step))])
  }
}

///|
async fn AgentLog::agent_content(self : AgentLog, content : String) -> Unit {
  match self.format {
    Text => {
      let logger = self.logger
      logger <+ "agent: \{content}\n"
    }
    Jsonl => self.jsonl(INFO, "assistant", [("content", Json::string(content))])
  }
}

///|
async fn AgentLog::usage(self : AgentLog, usage : @deepseek.Usage) -> Unit {
  match self.format {
    Text => {
      let logger = self.logger
      logger <+
        "usage: prompt=\{usage.prompt_tokens} completion=\{usage.completion_tokens} cache_hit=\{usage.prompt_cache_hit_tokens} cache_miss=\{usage.prompt_cache_miss_tokens}\n"
    }
    Jsonl =>
      self.jsonl(INFO, "usage", [
        ("prompt_tokens", int_json(usage.prompt_tokens)),
        ("completion_tokens", int_json(usage.completion_tokens)),
        ("total_tokens", int_json(usage.total_tokens)),
        ("prompt_cache_hit_tokens", int_json(usage.prompt_cache_hit_tokens)),
        ("prompt_cache_miss_tokens", int_json(usage.prompt_cache_miss_tokens)),
      ])
  }
}

///|
async fn AgentLog::finish(self : AgentLog, answer : String) -> Unit {
  match self.format {
    Text => {
      let logger = self.logger
      logger <+ "=== finished ===\n"
      logger <+ "\{answer}\n"
    }
    Jsonl => self.jsonl(INFO, "finish", [("answer", Json::string(answer))])
  }
}

///|
async fn AgentLog::tool_decode_error(self : AgentLog, message : String) -> Unit {
  match self.format {
    Text => {
      let logger = self.logger.error()
      logger <+ "tool: error: \{message}\n"
    }
    Jsonl =>
      self.jsonl(ERROR, "tool_error", [("message", Json::string(message))])
  }
}

///|
async fn AgentLog::abort(self : AgentLog, reason : String) -> Unit {
  match self.format {
    Text => {
      let logger = self.logger.warn()
      logger <+ "=== aborted ===\n"
      logger <+ "\{reason}\n"
    }
    Jsonl => self.jsonl(WARN, "abort", [("reason", Json::string(reason))])
  }
}

///|
async fn AgentLog::tool_output(
  self : AgentLog,
  is_error : Bool,
  content : String,
) -> Unit {
  match self.format {
    Text => {
      let label = if is_error { "tool error" } else { "tool" }
      let logger = self.logger
      logger <+ "\{label}: \{content}\n"
    }
    Jsonl => {
      let level : @logger.Level = if is_error { ERROR } else { INFO }
      self.jsonl(level, "tool", [
        ("is_error", Json::boolean(is_error)),
        ("content", Json::string(content)),
      ])
    }
  }
}

///|
async fn AgentLog::max_steps_exhausted(self : AgentLog) -> Unit {
  match self.format {
    Text => {
      let logger = self.logger.warn()
      logger <+ "=== max steps exhausted ===\n"
    }
    Jsonl => self.jsonl(WARN, "max_steps_exhausted", [])
  }
}

///|
async fn AgentLog::jsonl(
  self : AgentLog,
  level : @logger.Level,
  event : String,
  fields : Array[(String, Json)],
) -> Unit {
  guard self.logger.enabled(level) else { return }
  let record = Json::object(
    Map(
      [
        ("level", Json::string(level.label())),
        ("event", Json::string(event)),
        ..fields,
      ],
    ),
  )
  self.logger.at(level).write_string(record.stringify() + "\n")
}

///|
fn int_json(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}
