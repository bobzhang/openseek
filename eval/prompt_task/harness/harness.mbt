///|
pub struct ProbeResult {
  passed : Bool
  reason : String
}

///|
pub struct ValidationResult {
  passed : Bool
  reason : String
  moon_check : Bool
  moon_test : Bool
  file_probe : Bool
  stdin_probe : Bool
  duplicate_probe : Bool
}

///|
pub struct TrialResult {
  index : Int
  prompt_label : String
  success : Bool
  reason : String
  workspace : String
  log_path : String
  exit_code : Int
  steps : Int
  tool_errors : Int
  finished : Bool
  validation : ValidationResult
  moon_check_uses : Int
  moon_test_uses : Int
  moon_run_e_mentions : Int
  moon_run_c_mentions : Int
  bad_run_e_mentions : Int
  from_str_mentions : Int
  parse_int_mentions : Int
  argparse_mentions : Int
  old_argparse_mentions : Int
  c_ffi_mentions : Int
  env_args_mentions : Int
  result_style_mentions : Int
  try_mentions : Int
  warnings : String
}

///|
pub struct EvalReport {
  model : String
  prompt_label : String
  task_file : String
  runs : Int
  concurrency : Int
  min_successes : Int
  successes : Int
  out_dir : String
  results : Array[TrialResult]
}

///|
pub async fn run_suite(config : Config) -> EvalReport {
  prepare_output_dir(config.out_dir)
  let task_template = @fs.read_file(config.task_file).text()
  let results = run_indexed_with_concurrency(config.runs, config.concurrency, index => {
    run_trial(config, task_template, index)
  })
  let report : EvalReport = {
    model: config.model.to_string(),
    prompt_label: config.prompt_label,
    task_file: config.task_file,
    runs: config.runs,
    concurrency: config.concurrency,
    min_successes: config.min_successes,
    successes: count_successes(results),
    out_dir: config.out_dir,
    results,
  }
  write_report_files(report)
  report
}

///|
async fn prepare_output_dir(out_dir : String) -> Unit {
  let _ = @fs.rmdir(out_dir, recursive=true) catch { _ => () }
  @fs.mkdir(out_dir + "/workspaces", recursive=true)
  @fs.mkdir(out_dir + "/logs", recursive=true)
}

///|
async fn[X] run_indexed_with_concurrency(
  count : Int,
  concurrency : Int,
  run : async (Int) -> X,
) -> Array[X] {
  let limit = @async.Semaphore(concurrency)
  @async.all(
    [
      for index in 0..<count => {
        () => {
          limit.acquire()
          defer limit.release()
          run(index)
        }
      }
    ],
  )
}

///|
async fn run_trial(
  config : Config,
  task_template : String,
  index : Int,
) -> TrialResult {
  let workspace = config.out_dir + "/workspaces/" + padded_index(index + 1)
  @fs.mkdir(workspace, recursive=true)
  let real_workspace = @fs.realpath(workspace)
  let task = task_template.replace_all(old="{{WORKSPACE}}", new=real_workspace)
  let args = [
    "run",
    "cmd/openseek",
    "--",
    "--max-steps",
    config.max_steps.to_string(),
    "--model",
    config.model.to_string(),
    "--log-format",
    "text",
  ]
  if config.system_prompt_file != "" {
    args.push("--system-prompt-file")
    args.push(config.system_prompt_file)
  }
  if config.system_prompt_addendum_file != "" {
    args.push("--system-prompt-addendum-file")
    args.push(config.system_prompt_addendum_file)
  }
  args.push(task)
  let (exit_code, output) = @process.collect_output_merged(
    "moon",
    args,
    extra_env={
      "DEEPSEEK": config.api_key,
      "DEEPSEEK_MODEL": config.model.to_string(),
      "OPENSEEK_MAX_STEPS": config.max_steps.to_string(),
    },
    inherit_env=true,
    cwd=config.repo_root,
  )
  let log_text = output.text()
  let log_path = config.out_dir + "/logs/" + padded_index(index + 1) + ".log"
  @fs.write_file(log_path, log_text, create_mode=CreateOrTruncate)
  let validation = validate_toml_workspace(real_workspace)
  evaluate_trial(
    config.prompt_label,
    index,
    real_workspace,
    log_path,
    exit_code,
    log_text,
    validation,
  )
}

///|
fn evaluate_trial(
  prompt_label : String,
  index : Int,
  workspace : String,
  log_path : String,
  exit_code : Int,
  log_text : String,
  validation : ValidationResult,
) -> TrialResult {
  let finished = log_text.contains("=== finished ===")
  let reasons : Array[String] = []
  if exit_code != 0 {
    reasons.push("agent process exited \{exit_code}")
  }
  if !finished {
    reasons.push("finish marker missing")
  }
  if !validation.passed {
    reasons.push(validation.reason)
  }
  let warnings : Array[String] = []
  let shell_uses = count_lines_containing_all(log_text, ["tool: exit="])
  if shell_uses > 0 {
    warnings.push("shell output observed \{shell_uses} time(s)")
  }
  let success = reasons.length() == 0
  {
    index: index + 1,
    prompt_label,
    success,
    reason: if success {
      "ok"
    } else {
      reasons.join("; ")
    },
    workspace,
    log_path,
    exit_code,
    steps: count_occurrences(log_text, "--- step "),
    tool_errors: count_occurrences(log_text, "tool error:"),
    finished,
    validation,
    moon_check_uses: count_lines_containing_all(log_text, ["command=moon check"]),
    moon_test_uses: count_lines_containing_all(log_text, ["command=moon test"]),
    moon_run_e_mentions: count_lines_containing_all(log_text, [
      "moon run", " -e",
    ]),
    moon_run_c_mentions: count_lines_containing_all(log_text, [
      "moon run", " -c",
    ]),
    bad_run_e_mentions: count_occurrences(
      log_text, "a value is required for `-e <SCRIPT>`",
    ),
    from_str_mentions: count_occurrences(log_text, "@string.from_str"),
    parse_int_mentions: count_occurrences(log_text, "@string.parse_int"),
    argparse_mentions: count_occurrences(log_text, "@argparse.parse") +
    count_occurrences(log_text, ".parse("),
    old_argparse_mentions: count_occurrences(log_text, "@argparse.command") +
    count_occurrences(log_text, "@argparse.flag") +
    count_occurrences(log_text, "@argparse.argument") +
    count_occurrences(log_text, ".is_present") +
    count_occurrences(log_text, ".value("),
    c_ffi_mentions: count_occurrences(log_text, "extern \"c\"") +
    count_occurrences(log_text, "native-stub"),
    env_args_mentions: count_occurrences(log_text, "@env.args"),
    result_style_mentions: count_occurrences(log_text, "Result[") +
    count_occurrences(log_text, "Ok(") +
    count_occurrences(log_text, "Err("),
    try_mentions: count_occurrences(log_text, "try?") +
    count_occurrences(log_text, "try!"),
    warnings: if warnings.length() == 0 {
      ""
    } else {
      warnings.join("; ")
    },
  }
}

///|
async fn validate_toml_workspace(workspace : String) -> ValidationResult {
  let check = run_command(workspace, ["moon", "check", "--target", "native"])
  let test_probe = run_command(workspace, ["moon", "test", "--target", "native"])
  let file_probe = run_file_probe(workspace)
  let stdin_probe = run_stdin_probe(workspace)
  let duplicate_probe = run_duplicate_probe(workspace)
  let failures : Array[String] = []
  if !check.passed {
    failures.push("moon check: " + check.reason)
  }
  if !test_probe.passed {
    failures.push("moon test: " + test_probe.reason)
  }
  if !file_probe.passed {
    failures.push("file probe: " + file_probe.reason)
  }
  if !stdin_probe.passed {
    failures.push("stdin probe: " + stdin_probe.reason)
  }
  if !duplicate_probe.passed {
    failures.push("duplicate probe: " + duplicate_probe.reason)
  }
  {
    passed: failures.length() == 0,
    reason: if failures.length() == 0 {
      "ok"
    } else {
      failures.join("; ")
    },
    moon_check: check.passed,
    moon_test: test_probe.passed,
    file_probe: file_probe.passed,
    stdin_probe: stdin_probe.passed,
    duplicate_probe: duplicate_probe.passed,
  }
}

///|
async fn run_command(
  workspace : String,
  command : Array[String],
) -> ProbeResult {
  let args = [ for i in 1..<command.length() => command[i] ]
  let (code, output) = @process.collect_output_merged(
    command[0],
    args,
    cwd=workspace,
  )
  if code == 0 {
    { passed: true, reason: "ok" }
  } else {
    { passed: false, reason: "exit \{code}: " + summarize(output.text()) }
  }
}

///|
async fn run_file_probe(workspace : String) -> ProbeResult {
  let path = workspace + "/.openseek-file-probe.toml"
  @fs.write_file(
    path,
    (
      #|[owner]
      #|name = "Alice"
      #|age = 30
      #|[database]
      #|host = "localhost"
      #|ports = [8000, 8001]
      #|
    ),
    create_mode=CreateOrTruncate,
  )
  let (code, stdout, stderr) = @process.collect_output(
    "moon",
    ["run", "--target", "native", "cmd/tomljson", "--", path],
    cwd=workspace,
  )
  json_stdout_probe(code, stdout.text(), stderr.text())
}

///|
async fn run_stdin_probe(workspace : String) -> ProbeResult {
  let path = workspace + "/.openseek-stdin-probe.toml"
  @fs.write_file(path, "a.b.c = 42\nx.y = true\n", create_mode=CreateOrTruncate)
  let (code, stdout, stderr) = @process.collect_output(
    "moon",
    ["run", "--target", "native", "cmd/tomljson", "--", "--stdin"],
    stdin=@process.redirect_from_file(path),
    cwd=workspace,
  )
  json_stdout_probe(code, stdout.text(), stderr.text())
}

///|
async fn run_duplicate_probe(workspace : String) -> ProbeResult {
  let path = workspace + "/.openseek-duplicate-probe.toml"
  @fs.write_file(path, "key = 1\nkey = 2\n", create_mode=CreateOrTruncate)
  let (code, stdout, stderr) = @process.collect_output(
    "moon",
    ["run", "--target", "native", "cmd/tomljson", "--", "--stdin"],
    stdin=@process.redirect_from_file(path),
    cwd=workspace,
  )
  let combined = stdout.text() + stderr.text()
  if combined.contains("RUNTIME ERROR") || combined.contains("panic") {
    return { passed: false, reason: "debug/panic output leaked" }
  }
  if !combined.contains("duplicate") && !combined.contains("Duplicate") {
    return {
      passed: false,
      reason: "missing duplicate-key message, exit \{code}: " +
      summarize(combined),
    }
  }
  { passed: true, reason: "ok" }
}

///|
fn json_stdout_probe(
  code : Int,
  stdout : String,
  stderr : String,
) -> ProbeResult {
  if code != 0 {
    return {
      passed: false,
      reason: "exit \{code}: " + summarize(stdout + stderr),
    }
  }
  let trimmed = stdout.trim().to_owned()
  let _ = @json.parse(trimmed) catch {
    error =>
      return {
        passed: false,
        reason: "stdout is not JSON: \{error}; stdout=" + summarize(stdout),
      }
  }
  { passed: true, reason: "ok" }
}

///|
fn count_successes(results : Array[TrialResult]) -> Int {
  let mut count = 0
  for result in results {
    if result.success {
      count += 1
    }
  }
  count
}

///|
fn count_occurrences(content : String, needle : String) -> Int {
  if needle == "" {
    return 0
  }
  let pieces = content.split(needle).collect()
  pieces.length() - 1
}

///|
fn count_lines_containing_all(content : String, needles : Array[String]) -> Int {
  let mut count = 0
  for piece in content.split("\n") {
    let line = piece.to_owned()
    let mut matched = true
    for needle in needles {
      if !line.contains(needle) {
        matched = false
      }
    }
    if matched {
      count += 1
    }
  }
  count
}

///|
fn summarize(text : String) -> String {
  let one_line = text
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\n", new=" ")
    .trim()
    .to_owned()
  if one_line.length() <= 240 {
    one_line
  } else {
    one_line.sub(start=0, end=240).to_owned() + "..."
  }
}

///|
fn padded_index(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}
