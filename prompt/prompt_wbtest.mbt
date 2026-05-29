///|
test "system prompt includes moonbit guide" {
  let prompt = base_prompt()
  assert_true(prompt.contains("# Agent Workflow"))
  assert_true(prompt.contains("MoonBit Error Handling"))
  assert_true(prompt.contains("--warn-list +unnecessary_annotation"))
  assert_true(prompt.contains("moon run -e"))
  assert_false(prompt.contains("moon run -c"))
  assert_true(prompt.contains("Find `moon.mod` (module root)"))
  assert_false(prompt.contains("Find `moon.mod.json` (module root)"))
  assert_true(prompt.contains("Typical Module configuration (`moon.mod`)"))
  assert_false(
    prompt.contains("Typical Module configurations (`moon.mod.json`)"),
  )
  assert_true(prompt.contains("preferred_target = \"native\""))
  assert_false(prompt.contains("\"preferred-target\": \"native\""))
  assert_true(prompt.contains("cache-friendly"))
  assert_true(prompt.contains("moon_ide outline"))
  assert_true(prompt.contains("start_line"))
  assert_true(prompt.contains("flat like Go packages"))
  assert_true(prompt.contains("generated native/C entry path"))
  assert_true(prompt.contains("create `moon.mod`, not `moon.mod.json`"))
  assert_true(prompt.contains("After editing `moon.mod`, `moon.pkg`"))
  assert_true(prompt.contains("acceptance probes"))
  assert_true(prompt.contains("file arguments are read as files"))
  assert_true(prompt.contains("OpenSeek DeepSeek Addendum"))
}

///|
test "flash prompt includes flash addenda" {
  let prompt = flash_prompt()
  assert_true(prompt.contains("DeepSeek V4 Flash"))
  assert_true(prompt.contains("Do not emit JSON action plans"))
  assert_true(prompt.contains("moon run -e"))
  assert_true(prompt.contains("Do not use `moon run -c`"))
  assert_true(prompt.contains("Current MoonBit modules use `moon.mod`"))
  assert_true(prompt.contains("moon.mod.json` is legacy"))
  assert_true(prompt.contains("Do not import `moonbitlang/core`"))
  assert_true(prompt.contains("moonbitlang/core/argparse"))
  assert_true(prompt.contains("@argparse.parse(cli_command())"))
  assert_true(prompt.contains("@string.from_str"))
  assert_true(prompt.contains("@string.parse_int(text, base=...)"))
  assert_true(prompt.contains("moonbitlang/async/fs"))
  assert_true(prompt.contains("@stdio.stdin.read_all().text()"))
  assert_true(prompt.contains("@fs.read_file(config.input).text()"))
  assert_true(prompt.contains("Json::object(map)"))
  assert_true(prompt.contains("Json::boolean(b)"))
  assert_true(prompt.contains("Empty no-op expression is `()`"))
  assert_true(
    prompt.contains("Do not implement ordinary file/stdin IO with C FFI"),
  )
  assert_true(
    prompt.contains("moon run --target native cmd/tomljson -- /tmp/input.toml"),
  )
  assert_false(prompt.contains("Spec-driven Development"))
  assert_false(prompt.contains("proof_invariant"))
  assert_false(prompt.contains("Loop Invariants"))
}

///|
test "default prompt is selected per model" {
  assert_eq(system_prompt_for_model(V4Flash), flash_prompt())
  assert_true(system_prompt_for_model(V4Flash).contains("DeepSeek V4 Flash"))
  assert_false(system_prompt_for_model(V4Pro).contains("DeepSeek V4 Flash"))
}
