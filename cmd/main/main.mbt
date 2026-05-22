///|
async fn main {
  let matches = cli_command().parse(env=@env.get_env_vars())
  let api_key = value(matches, "api-key")
  let model = @deepseek.Model::parse(value(matches, "model"))
  let max_steps = max_steps(matches)
  let task = values(matches, "task").join(" ")
  @agent.run(api_key, model, task, max_steps~)
}

///|
fn cli_command() -> @argparse.Command {
  Command(
    "openseek",
    about="DeepSeek-backed MoonBit coding agent.",
    options=[
      OptionArg(
        "api-key",
        long="api-key",
        env="DEEPSEEK",
        required=true,
        about="DeepSeek API key.",
      ),
      OptionArg(
        "model",
        long="model",
        env="DEEPSEEK_MODEL",
        default_values=[@deepseek.V4Pro.to_string()],
        about="DeepSeek model: deepseek-v4-flash or deepseek-v4-pro.",
      ),
      OptionArg(
        "max-steps",
        long="max-steps",
        env="OPENSEEK_MAX_STEPS",
        default_values=["1000"],
        about="Maximum number of agent loop steps before stopping.",
      ),
    ],
    positionals=[
      PositionArg(
        "task",
        num_args=ValueRange(lower=1),
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
fn max_steps(matches : @argparse.Matches) -> Int raise {
  parse_positive_int(value(matches, "max-steps"), "--max-steps")
}

///|
fn parse_positive_int(input : String, label : String) -> Int raise {
  let parsed = @string.parse_int(input) catch {
    _ => fail("\{label} must be a positive integer, got: \{input}")
  }
  guard parsed > 0 else {
    fail("\{label} must be a positive integer, got: \{input}")
  }
  parsed
}

///|
test "cli parses env backed options and task" {
  let parsed = cli_command().parse(argv=["write", "MoonBit"], env={
    "DEEPSEEK": "test-key",
    "DEEPSEEK_MODEL": "deepseek-v4-pro",
    "OPENSEEK_MAX_STEPS": "120",
  })
  assert_eq(value(parsed, "api-key"), "test-key")
  assert_eq(value(parsed, "model"), "deepseek-v4-pro")
  assert_eq(max_steps(parsed), 120)
  assert_eq(values(parsed, "task").join(" "), "write MoonBit")
}

///|
test "cli defaults model and max steps" {
  let parsed = cli_command().parse(argv=["write", "MoonBit"], env={
    "DEEPSEEK": "test-key",
  })
  assert_eq(value(parsed, "model"), "deepseek-v4-pro")
  assert_eq(max_steps(parsed), 1000)
}

///|
test "cli parses max steps option" {
  let parsed = cli_command().parse(
    argv=["--max-steps", "25", "write", "MoonBit"],
    env={ "DEEPSEEK": "test-key" },
  )
  assert_eq(max_steps(parsed), 25)
}

///|
test "cli rejects invalid max steps" {
  let parsed = cli_command().parse(
    argv=["--max-steps", "0", "write", "MoonBit"],
    env={ "DEEPSEEK": "test-key" },
  )
  let _ = max_steps(parsed) catch {
    error => {
      assert_true("\{error}".contains("--max-steps must be a positive integer"))
      return
    }
  }
  fail("invalid max steps parsed")
}
