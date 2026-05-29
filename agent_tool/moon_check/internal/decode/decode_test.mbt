///|
test "decode direct moon_check arguments" {
  debug_inspect(
    decode({
      "cwd": "/tmp",
      "path": "agent",
      "paths": ["README.mbt.md"],
      "target": "native",
      "warn_list": "+unnecessary_annotation",
      "deny_warn": true,
      "fmt": true,
      "explain": true,
    }),
    content=(
      #|{
      #|  cwd: Some("/tmp"),
      #|  paths: ["agent", "README.mbt.md"],
      #|  target: Some("native"),
      #|  warn_list: Some("+unnecessary_annotation"),
      #|  deny_warn: true,
      #|  fmt: true,
      #|  explain: true,
      #|}
    ),
  )
}

///|
test "decode path and paths together" {
  debug_inspect(
    decode({ "path": "agent", "paths": ["agent_tool/read", "agent_tool/write"] }),
    content=(
      #|{
      #|  cwd: None,
      #|  paths: ["agent", "agent_tool/read", "agent_tool/write"],
      #|  target: None,
      #|  warn_list: None,
      #|  deny_warn: false,
      #|  fmt: false,
      #|  explain: false,
      #|}
    ),
  )
}

///|
test "decode ignores empty optional strings and false flags" {
  debug_inspect(
    decode({
      "cwd": "",
      "path": "",
      "paths": ["", null],
      "deny_warn": false,
      "fmt": null,
    }),
    content=(
      #|{
      #|  cwd: None,
      #|  paths: [],
      #|  target: None,
      #|  warn_list: None,
      #|  deny_warn: false,
      #|  fmt: false,
      #|  explain: false,
      #|}
    ),
  )
}

///|
test "decode rejects invalid target" {
  try decode({ "target": "browser" }) catch {
    error => assert_true("\{error}".contains("arguments.target"))
  } noraise {
    _ => fail("invalid target decoded")
  }
}

///|
test "decode rejects invalid paths" {
  try decode({ "paths": [42] }) catch {
    error => assert_true("\{error}".contains("arguments.paths"))
  } noraise {
    _ => fail("invalid paths decoded")
  }
}

///|
test "decode rejects non-object arguments" {
  try decode(Json::null()) catch {
    error => assert_true("\{error}".contains("object arguments"))
  } noraise {
    _ => fail("non-object decoded")
  }
}
