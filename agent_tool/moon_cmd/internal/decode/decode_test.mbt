///|
test "decode direct moon command arguments" {
  debug_inspect(
    decode({
      "command": "run",
      "cwd": "/tmp",
      "target": "native",
      "args": ["--quiet"],
      "path": "cmd/main",
      "program_args": ["input.toml", "--pretty"],
      "stdin": "input",
    }),
    content=(
      #|{
      #|  command: "run",
      #|  cwd: Some("/tmp"),
      #|  target: Some("native"),
      #|  args: ["--quiet"],
      #|  paths: ["cmd/main"],
      #|  program_args: ["input.toml", "--pretty"],
      #|  stdin: Some("input"),
      #|  test_update_kind: None,
      #|  test_update_reason: None,
      #|  max_output_chars: 12000,
      #|}
    ),
  )
}

///|
test "decode singular and plural argument fields" {
  debug_inspect(
    decode({
      "command": "test",
      "arg": "--filter",
      "args": ["parser::*", "--quiet"],
      "path": "toml",
      "paths": ["README.mbt.md"],
    }),
    content=(
      #|{
      #|  command: "test",
      #|  cwd: None,
      #|  target: None,
      #|  args: ["--filter", "parser::*", "--quiet"],
      #|  paths: ["toml", "README.mbt.md"],
      #|  program_args: [],
      #|  stdin: None,
      #|  test_update_kind: None,
      #|  test_update_reason: None,
      #|  max_output_chars: 12000,
      #|}
    ),
  )
}

///|
test "decode rejects invalid command" {
  try decode({ "command": "new" }) catch {
    error => assert_true("\{error}".contains("arguments.command"))
  } noraise {
    _ => fail("invalid command decoded")
  }
}

///|
test "decode rejects program args outside run" {
  try decode({ "command": "test", "program_args": ["ignored"] }) catch {
    error => assert_true("\{error}".contains("arguments.program_args"))
  } noraise {
    _ => fail("invalid program args decoded")
  }
}

///|
test "decode rejects stdin outside run" {
  try decode({ "command": "test", "stdin": "input" }) catch {
    error => assert_true("\{error}".contains("arguments.stdin"))
  } noraise {
    _ => fail("invalid stdin decoded")
  }
}

///|
test "decode rejects target for fmt" {
  try decode({ "command": "fmt", "target": "native" }) catch {
    error => assert_true("\{error}".contains("arguments.target"))
  } noraise {
    _ => fail("invalid fmt target decoded")
  }
}

///|
test "decode rejects moon test update without classification" {
  try decode({ "command": "test", "arg": "--update" }) catch {
    error => assert_true("\{error}".contains("arguments.test_update_kind"))
  } noraise {
    _ => fail("unclassified test update decoded")
  }
}

///|
test "decode rejects moon test update without reason" {
  try
    decode({
      "command": "test",
      "arg": "--update",
      "test_update_kind": "stale_snapshot",
    })
  catch {
    error => assert_true("\{error}".contains("arguments.test_update_reason"))
  } noraise {
    _ => fail("unexplained test update decoded")
  }
}

///|
test "decode accepts classified moon test update" {
  debug_inspect(
    decode({
      "command": "test",
      "arg": "--update",
      "test_update_kind": "stale_snapshot",
      "test_update_reason": "plain moon test only reported snapshot diffs",
    }),
    content=(
      #|{
      #|  command: "test",
      #|  cwd: None,
      #|  target: None,
      #|  args: ["--update"],
      #|  paths: [],
      #|  program_args: [],
      #|  stdin: None,
      #|  test_update_kind: Some("stale_snapshot"),
      #|  test_update_reason: Some("plain moon test only reported snapshot diffs"),
      #|  max_output_chars: 12000,
      #|}
    ),
  )
}

///|
test "decode parses and caps output limit" {
  debug_inspect(
    decode({ "command": "check", "max_output_chars": 999999 }),
    content=(
      #|{
      #|  command: "check",
      #|  cwd: None,
      #|  target: None,
      #|  args: [],
      #|  paths: [],
      #|  program_args: [],
      #|  stdin: None,
      #|  test_update_kind: None,
      #|  test_update_reason: None,
      #|  max_output_chars: 50000,
      #|}
    ),
  )
}

///|
test "decode rejects non-object arguments" {
  try decode(Json::null()) catch {
    error => assert_true("\{error}".contains("object arguments"))
  } noraise {
    _ => fail("non-object decoded")
  }
}
