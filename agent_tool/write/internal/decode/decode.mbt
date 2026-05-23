///|
pub struct WriteInput {
  path : String
  content : String
}

///|
pub fn decode(arguments : Json) -> WriteInput raise {
  match arguments {
    { "path": String(path), "content": String(content), .. } =>
      { path, content }
    { "path": String(_), .. } => fail("arguments.content")
    Object(_) => fail("arguments.path")
    _ => fail("object arguments")
  }
}

///|
test "decode valid write input" {
  let input = decode({ "path": "/tmp/file.txt", "content": "hello" })
  assert_eq(input.path, "/tmp/file.txt")
  assert_eq(input.content, "hello")
}

///|
test "decode accepts empty content" {
  let input = decode({ "path": "/tmp/file.txt", "content": "" })
  assert_eq(input.content, "")
}

///|
test "decode rejects missing content" {
  let _ = decode({ "path": "/tmp/file.txt" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.content"))
      return
    }
  }
  fail("missing content decoded")
}

///|
test "decode rejects missing path" {
  let _ = decode({ "content": "hello" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.path"))
      return
    }
  }
  fail("missing path decoded")
}

///|
test "decode rejects non-object arguments" {
  let _ = decode(Json::null()) catch {
    error => {
      assert_true("\{error}".contains("object arguments"))
      return
    }
  }
  fail("non-object decoded")
}
