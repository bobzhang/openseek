///|
async fn run_edit(arguments : Json) -> @agent_tool.ToolAction {
  match @edit.definition().execute {
    Async(execute) => execute(arguments)
    Sync(_) => fail("edit tool should be async")
  }
}

///|
async test "edit replaces a unique exact match" {
  let path = "/tmp/openseek-edit-unique.txt"
  @fs.write_file(path, "alpha\nbeta\ngamma\n", create_mode=CreateOrTruncate)
  let result = run_edit({
    "path": path,
    "old_string": "beta",
    "new_string": "delta",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "ok: replaced 1 occurrence(s) in \{path}")
  assert_false(output.is_error)
  assert_eq(@fs.read_file(path).text(), "alpha\ndelta\ngamma\n")
}

///|
async test "edit preserves surrounding multiline content" {
  let path = "/tmp/openseek-edit-multiline.txt"
  @fs.write_file(
    path,
    "fn main {\n  println(\"old\")\n}\n",
    create_mode=CreateOrTruncate,
  )
  let result = run_edit({
    "path": path,
    "old_string": "  println(\"old\")",
    "new_string": "  println(\"new\")",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_false(output.is_error)
  assert_eq(@fs.read_file(path).text(), "fn main {\n  println(\"new\")\n}\n")
}

///|
async test "edit rejects missing old_string" {
  let result = run_edit({ "path": "/tmp/openseek-edit-noop.txt" })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: edit requires arguments.old_string")
  assert_true(output.is_error)
}

///|
async test "edit rejects missing new_string" {
  let result = run_edit({
    "path": "/tmp/openseek-edit-noop.txt",
    "old_string": "x",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: edit requires arguments.new_string")
  assert_true(output.is_error)
}

///|
async test "edit rejects non-object arguments" {
  let result = run_edit(Json::null())
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error: edit requires object arguments")
  assert_true(output.is_error)
}

///|
async test "edit rejects empty old_string" {
  let path = "/tmp/openseek-edit-empty-old.txt"
  @fs.write_file(path, "content", create_mode=CreateOrTruncate)
  let result = run_edit({
    "path": path,
    "old_string": "",
    "new_string": "replacement",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(
    output.content,
    "error editing \{path}: old_string must be non-empty",
  )
  assert_true(output.is_error)
}

///|
async test "edit rejects identical replacement" {
  let path = "/tmp/openseek-edit-identical.txt"
  @fs.write_file(path, "content", create_mode=CreateOrTruncate)
  let result = run_edit({
    "path": path,
    "old_string": "content",
    "new_string": "content",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(
    output.content,
    "error editing \{path}: old_string and new_string are identical",
  )
  assert_true(output.is_error)
}

///|
async test "edit rejects suspicious moon.pkg rewrite" {
  let dir = @fs.tmpdir(prefix="openseek-edit-manifest-")
  let path = dir + "/moon.pkg"
  @fs.write_file(
    path,
    "warnings = \"+unnecessary_annotation\"",
    create_mode=CreateOrTruncate,
  )
  let result = run_edit({
    "path": path,
    "old_string": "warnings = \"+unnecessary_annotation\"",
    "new_string": "x",
  })
  let read_back = @fs.read_file(path).text()
  let _ = @fs.rmdir(dir, recursive=true) catch { _ => () }
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.is_error)
  assert_true(output.content.contains("moon.pkg content is suspiciously small"))
  assert_eq(read_back, "warnings = \"+unnecessary_annotation\"")
}

///|
async test "edit rejects missing match" {
  let path = "/tmp/openseek-edit-missing.txt"
  @fs.write_file(path, "alpha", create_mode=CreateOrTruncate)
  let result = run_edit({
    "path": path,
    "old_string": "beta",
    "new_string": "gamma",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "error editing \{path}: old_string not found")
  assert_true(output.is_error)
}

///|
async test "edit rejects ambiguous match without replace_all" {
  let path = "/tmp/openseek-edit-ambiguous.txt"
  @fs.write_file(path, "alpha beta beta", create_mode=CreateOrTruncate)
  let result = run_edit({
    "path": path,
    "old_string": "beta",
    "new_string": "delta",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(
    output.content,
    "error editing \{path}: old_string matched 2 times; set replace_all=true to replace all occurrences",
  )
  assert_true(output.is_error)
  assert_eq(@fs.read_file(path).text(), "alpha beta beta")
}

///|
async test "edit replace_all updates every match" {
  let path = "/tmp/openseek-edit-replace-all.txt"
  @fs.write_file(path, "alpha beta beta", create_mode=CreateOrTruncate)
  let result = run_edit({
    "path": path,
    "old_string": "beta",
    "new_string": "delta",
    "replace_all": true,
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(output.content, "ok: replaced 2 occurrence(s) in \{path}")
  assert_false(output.is_error)
  assert_eq(@fs.read_file(path).text(), "alpha delta delta")
}

///|
async test "edit rejects non-boolean replace_all" {
  let path = "/tmp/openseek-edit-bad-replace-all.txt"
  @fs.write_file(path, "alpha", create_mode=CreateOrTruncate)
  let result = run_edit({
    "path": path,
    "old_string": "alpha",
    "new_string": "beta",
    "replace_all": "yes",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_eq(
    output.content,
    "error: edit requires arguments.replace_all to be a boolean",
  )
  assert_true(output.is_error)
}

///|
async test "edit surfaces read errors" {
  let result = run_edit({
    "path": "/tmp/openseek-edit-does-not-exist.txt",
    "old_string": "x",
    "new_string": "y",
  })
  guard result is Respond(output) else { fail("expected Respond") }
  assert_true(output.content.contains("error editing"))
  assert_true(output.content.contains("error reading file"))
  assert_true(output.is_error)
}
