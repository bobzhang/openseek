///|
test "cli defaults to flash baseline" {
  let matches = cli_command().parse(argv=["--api-key", "test-key"])
  let config = config_from_matches(matches)
  assert_eq(config.api_key, "test-key")
  assert_eq(config.model.to_string(), "deepseek-v4-flash")
  assert_eq(config.runs, 10)
  assert_eq(config.concurrency, 1)
  assert_eq(config.min_successes, 8)
  assert_eq(config.max_steps, 200)
  assert_eq(config.prompt_label, "builtin")
  assert_eq(config.system_prompt_file, "")
  assert_eq(config.system_prompt_addendum_file, "")
}

///|
test "cli parses concurrency option" {
  let matches = cli_command().parse(argv=[
    "--api-key", "test-key", "--runs", "5", "--min-successes", "5", "--concurrency",
    "5",
  ])
  let config = config_from_matches(matches)
  assert_eq(config.runs, 5)
  assert_eq(config.concurrency, 5)
}

///|
test "cli parses prompt experiment options" {
  let matches = cli_command().parse(argv=[
    "--api-key", "test-key", "--prompt-label", "run-e-addendum", "--system-prompt-file",
    "prompts/base.md", "--system-prompt-addendum-file", "prompts/run-e.md",
  ])
  let config = config_from_matches(matches)
  assert_eq(config.prompt_label, "run-e-addendum")
  assert_eq(config.system_prompt_file, "prompts/base.md")
  assert_eq(config.system_prompt_addendum_file, "prompts/run-e.md")
}

///|
test "cli rejects impossible threshold" {
  let matches = cli_command().parse(argv=[
    "--api-key", "test-key", "--runs", "3", "--min-successes", "4",
  ])
  let _ = config_from_matches(matches) catch {
    error => {
      assert_true("\{error}".contains("--min-successes must be <= --runs"))
      return
    }
  }
  fail("impossible threshold parsed")
}
