///|
async fn main {
  let matches = cli_command().parse(env=@env.get_env_vars())
  let api_key = value(matches, "api-key")
  let model = @deepseek.Model::parse(value(matches, "model"))
  let task = values(matches, "task").join(" ")
  @agent.run(api_key, model, task)
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
        default_values=[@deepseek.V4Flash.to_string()],
        about="DeepSeek model: deepseek-v4-flash or deepseek-v4-pro.",
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
test "cli parses env backed options and task" {
  let parsed = cli_command().parse(argv=["write", "MoonBit"], env={
    "DEEPSEEK": "test-key",
    "DEEPSEEK_MODEL": "deepseek-v4-pro",
  })
  assert_eq(value(parsed, "api-key"), "test-key")
  assert_eq(value(parsed, "model"), "deepseek-v4-pro")
  assert_eq(values(parsed, "task").join(" "), "write MoonBit")
}
