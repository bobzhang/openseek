///|
test "decode valid edit input" {
  debug_inspect(
    decode({ "path": "file.mbt", "old_string": "old", "new_string": "new" }),
    content=(
      #|{
      #|  path: "file.mbt",
      #|  old_string: "old",
      #|  new_string: "new",
      #|  replace_all: false,
      #|}
    ),
  )
}

///|
test "decode replace_all flag" {
  debug_inspect(
    decode({
      "path": "file.mbt",
      "old_string": "old",
      "new_string": "new",
      "replace_all": true,
    }),
    content=(
      #|{
      #|  path: "file.mbt",
      #|  old_string: "old",
      #|  new_string: "new",
      #|  replace_all: true,
      #|}
    ),
  )
}

///|
test "decode rejects invalid replace_all" {
  try
    decode({
      "path": "file.mbt",
      "old_string": "old",
      "new_string": "new",
      "replace_all": "yes",
    })
  catch {
    error => assert_true("\{error}".contains("arguments.replace_all"))
  } noraise {
    _ => fail("invalid replace_all decoded")
  }
}

///|
test "decode rejects missing required fields" {
  try decode({ "path": "file.mbt" }) catch {
    error => assert_true("\{error}".contains("arguments.old_string"))
  } noraise {
    _ => fail("missing old_string decoded")
  }
  try decode({ "path": "file.mbt", "old_string": "old" }) catch {
    error => assert_true("\{error}".contains("arguments.new_string"))
  } noraise {
    _ => fail("missing new_string decoded")
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
