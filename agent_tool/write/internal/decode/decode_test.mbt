///|
test "decode valid write input" {
  debug_inspect(
    decode({ "path": "/tmp/file.txt", "content": "hello" }),
    content=(
      #|{ path: "/tmp/file.txt", content: "hello" }
    ),
  )
}

///|
test "decode accepts empty content" {
  debug_inspect(
    decode({ "path": "/tmp/file.txt", "content": "" }),
    content=(
      #|{ path: "/tmp/file.txt", content: "" }
    ),
  )
}

///|
test "decode rejects missing content" {
  try decode({ "path": "/tmp/file.txt" }) catch {
    error => assert_true("\{error}".contains("arguments.content"))
  } noraise {
    _ => fail("missing content decoded")
  }
}

///|
test "decode rejects missing path" {
  try decode({ "content": "hello" }) catch {
    error => assert_true("\{error}".contains("arguments.path"))
  } noraise {
    _ => fail("missing path decoded")
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
