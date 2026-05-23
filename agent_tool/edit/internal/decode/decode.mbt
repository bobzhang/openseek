///|
pub struct EditInput {
  path : String
  old_string : String
  new_string : String
  replace_all : Bool
}

///|
pub fn decode(arguments : Json) -> EditInput raise {
  match arguments {
    {
      "path": String(path),
      "old_string": String(old_string),
      "new_string": String(new_string),
      "replace_all": True,
      ..
    } => { path, old_string, new_string, replace_all: true }
    {
      "path": String(path),
      "old_string": String(old_string),
      "new_string": String(new_string),
      "replace_all": False,
      ..
    } => { path, old_string, new_string, replace_all: false }
    {
      "path": String(_),
      "old_string": String(_),
      "new_string": String(_),
      "replace_all": _,
      ..
    } => fail("arguments.replace_all to be a boolean")
    {
      "path": String(path),
      "old_string": String(old_string),
      "new_string": String(new_string),
      ..
    } => { path, old_string, new_string, replace_all: false }
    { "path": String(_), "old_string": String(_), .. } =>
      fail("arguments.new_string")
    { "path": String(_), .. } => fail("arguments.old_string")
    Object(_) => fail("arguments.path")
    _ => fail("object arguments")
  }
}

///|
test "decode valid edit input" {
  let input = decode({
    "path": "file.mbt",
    "old_string": "old",
    "new_string": "new",
  })
  assert_eq(input.path, "file.mbt")
  assert_eq(input.old_string, "old")
  assert_eq(input.new_string, "new")
  assert_false(input.replace_all)
}

///|
test "decode replace_all flag" {
  let input = decode({
    "path": "file.mbt",
    "old_string": "old",
    "new_string": "new",
    "replace_all": true,
  })
  assert_true(input.replace_all)
}

///|
test "decode rejects invalid replace_all" {
  let _ = decode({
    "path": "file.mbt",
    "old_string": "old",
    "new_string": "new",
    "replace_all": "yes",
  }) catch {
    error => {
      assert_true("\{error}".contains("arguments.replace_all"))
      return
    }
  }
  fail("invalid replace_all decoded")
}

///|
test "decode rejects missing required fields" {
  let _ = decode({ "path": "file.mbt" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.old_string"))
      return
    }
  }
  let _ = decode({ "path": "file.mbt", "old_string": "old" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.new_string"))
      return
    }
  }
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
