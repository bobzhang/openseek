///|
test "decode valid shell input" {
  debug_inspect(
    decode({ "cmd": "echo hello", "cwd": "/tmp", "max_output_chars": 999999 }),
    content=(
      #|{ cmd: "echo hello", cwd: Some("/tmp"), max_output_chars: 50000 }
    ),
  )
}

///|
test "decode treats empty cwd as absent" {
  debug_inspect(
    decode({ "cmd": "pwd", "cwd": "" }),
    content=(
      #|{ cmd: "pwd", cwd: None, max_output_chars: 12000 }
    ),
  )
}

///|
test "decode rejects missing command" {
  try decode({ "cwd": "/tmp" }) catch {
    error => assert_true("\{error}".contains("arguments.cmd"))
  } noraise {
    _ => fail("missing command decoded")
  }
}

///|
test "decode rejects invalid output cap" {
  try decode({ "cmd": "echo hello", "max_output_chars": 0 }) catch {
    error =>
      assert_true(
        "\{error}".contains(
          "arguments.max_output_chars to be a positive number",
        ),
      )
  } noraise {
    _ => fail("invalid output cap decoded")
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
