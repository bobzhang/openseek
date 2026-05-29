///|
async fn main {
  let matches = cli_command().parse(env=@env.get_env_vars())
  let api_key = value(matches, "api-key")
  let model = @deepseek.Model::parse(value(matches, "model"))
  let max_steps = max_steps(matches)
  let system_prompt_text = configured_system_prompt(matches, model)
  let task = values(matches, "task").join(" ")
  @agent.run(api_key, model, task, max_steps~, system_prompt_text~)
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
      OptionArg(
        "system-prompt-file",
        long="system-prompt-file",
        env="OPENSEEK_SYSTEM_PROMPT_FILE",
        default_values=[""],
        about="Read the complete system prompt from this file instead of the built-in prompt.",
      ),
      OptionArg(
        "system-prompt-addendum-file",
        long="system-prompt-addendum-file",
        env="OPENSEEK_SYSTEM_PROMPT_ADDENDUM_FILE",
        default_values=[""],
        about="Append this file to the selected system prompt for prompt experiments.",
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
async fn configured_system_prompt(
  matches : @argparse.Matches,
  model : @deepseek.Model,
) -> String {
  let base_path = value(matches, "system-prompt-file")
  let addendum_path = value(matches, "system-prompt-addendum-file")
  let base = if base_path == "" {
    @prompt.system_prompt_for_model(model)
  } else {
    @fs.read_file(base_path).text()
  }
  if addendum_path == "" {
    base
  } else {
    let addendum = @fs.read_file(addendum_path).text()
    (
      $|\{base}
      $|
      $|\{addendum}
    )
  }
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
    "OPENSEEK_SYSTEM_PROMPT_FILE": "/tmp/prompt-a.md",
    "OPENSEEK_SYSTEM_PROMPT_ADDENDUM_FILE": "/tmp/prompt-b.md",
  })
  assert_eq(value(parsed, "api-key"), "test-key")
  assert_eq(value(parsed, "model"), "deepseek-v4-pro")
  assert_eq(max_steps(parsed), 120)
  assert_eq(value(parsed, "system-prompt-file"), "/tmp/prompt-a.md")
  assert_eq(value(parsed, "system-prompt-addendum-file"), "/tmp/prompt-b.md")
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
async test "configured system prompt can replace and append files" {
  let dir = @fs.tmpdir(prefix="openseek-prompt-config-")
  let prompt_path = dir + "/prompt.md"
  let addendum_path = dir + "/addendum.md"
  @fs.write_file(prompt_path, "base prompt\n", create_mode=CreateOrTruncate)
  @fs.write_file(addendum_path, "addendum\n", create_mode=CreateOrTruncate)
  let parsed = cli_command().parse(
    argv=[
      "--system-prompt-file", prompt_path, "--system-prompt-addendum-file", addendum_path,
      "write", "MoonBit",
    ],
    env={ "DEEPSEEK": "test-key" },
  )
  assert_eq(
    configured_system_prompt(parsed, V4Flash),
    "base prompt\n\n\naddendum\n",
  )
  let _ = @fs.rmdir(dir, recursive=true) catch { _ => () }
}

///|
async test "configured system prompt defaults by model" {
  let parsed = cli_command().parse(argv=["write", "MoonBit"], env={
    "DEEPSEEK": "test-key",
  })
  assert_true(
    configured_system_prompt(parsed, V4Flash).contains("DeepSeek V4 Flash"),
  )
  assert_false(
    configured_system_prompt(parsed, V4Pro).contains("DeepSeek V4 Flash"),
  )
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
