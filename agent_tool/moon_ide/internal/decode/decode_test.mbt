///|
test "decode doc action arguments" {
  debug_inspect(
    decode({
      "action": "doc",
      "cwd": "/tmp",
      "query": "String::replace_all",
      "no_check": true,
    }),
    content=(
      #|{
      #|  action: "doc",
      #|  cwd: Some("/tmp"),
      #|  query: Some("String::replace_all"),
      #|  path: None,
      #|  loc: None,
      #|  target: None,
      #|  no_check: true,
      #|  max_output_chars: 12000,
      #|}
    ),
  )
}

///|
test "decode loc-aware navigation arguments" {
  debug_inspect(
    decode({
      "action": "peek_def",
      "query": "render",
      "loc": "lib.mbt:14:8",
      "target": "native",
    }),
    content=(
      #|{
      #|  action: "peek_def",
      #|  cwd: None,
      #|  query: Some("render"),
      #|  path: None,
      #|  loc: Some("lib.mbt:14:8"),
      #|  target: Some("native"),
      #|  no_check: false,
      #|  max_output_chars: 12000,
      #|}
    ),
  )
}

///|
test "decode outline path" {
  debug_inspect(
    decode({
      "action": "outline",
      "path": "agent_tool/moon_ide",
      "max_output_chars": 42,
    }),
    content=(
      #|{
      #|  action: "outline",
      #|  cwd: None,
      #|  query: None,
      #|  path: Some("agent_tool/moon_ide"),
      #|  loc: None,
      #|  target: None,
      #|  no_check: false,
      #|  max_output_chars: 42,
      #|}
    ),
  )
}

///|
test "decode caps oversized output limit" {
  debug_inspect(
    decode({ "action": "doc", "query": "String", "max_output_chars": 999999 }),
    content=(
      #|{
      #|  action: "doc",
      #|  cwd: None,
      #|  query: Some("String"),
      #|  path: None,
      #|  loc: None,
      #|  target: None,
      #|  no_check: false,
      #|  max_output_chars: 50000,
      #|}
    ),
  )
}

///|
test "decode rejects invalid action" {
  try decode({ "action": "rename", "query": "old_name" }) catch {
    error => assert_true("\{error}".contains("arguments.action"))
  } noraise {
    _ => fail("invalid action decoded")
  }
}

///|
test "decode rejects missing required fields" {
  try decode({ "action": "hover", "query": "Widget" }) catch {
    error => assert_true("\{error}".contains("arguments.loc"))
  } noraise {
    _ => fail("hover without loc decoded")
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
