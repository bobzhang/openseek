///|
pub let default_max_output_chars : Int = 12000

///|
pub let hard_max_output_chars : Int = 50000

///|
pub struct MoonIdeInput {
  action : String
  cwd : String?
  query : String?
  path : String?
  loc : String?
  target : String?
  no_check : Bool
  max_output_chars : Int
}

///|
pub fn decode(arguments : Json) -> MoonIdeInput raise {
  match arguments {
    Object(fields) => parse_fields(fields)
    _ => fail("object arguments")
  }
}

///|
fn parse_fields(fields : Map[String, Json]) -> MoonIdeInput raise {
  let action = required_string(fields, "action")
  validate_action(action)
  let cwd = optional_string(fields, "cwd")
  let query = optional_string(fields, "query")
  let path = optional_string(fields, "path")
  let loc = optional_string(fields, "loc")
  let target = optional_string(fields, "target")
  match target {
    Some(value) => validate_target(value)
    None => ()
  }
  let no_check = optional_bool(fields, "no_check", default=false)
  let max_output_chars = optional_positive_int(
    fields, "max_output_chars", default_max_output_chars,
  )
  validate_required_fields(action, query, path, loc)
  {
    action,
    cwd,
    query,
    path,
    loc,
    target,
    no_check,
    max_output_chars: cap_max_output_chars(max_output_chars),
  }
}

///|
fn required_string(fields : Map[String, Json], name : String) -> String raise {
  match fields.get(name) {
    Some(String(value)) if value != "" => value
    Some(String(_)) | Some(Null) | None => fail("arguments.\{name}")
    _ => fail("arguments.\{name} to be a string")
  }
}

///|
fn optional_string(fields : Map[String, Json], name : String) -> String? raise {
  match fields.get(name) {
    Some(String(value)) if value != "" => Some(value)
    Some(String(_)) | Some(Null) | None => None
    _ => fail("arguments.\{name} to be a string")
  }
}

///|
fn optional_bool(
  fields : Map[String, Json],
  name : String,
  default~ : Bool,
) -> Bool raise {
  match fields.get(name) {
    Some(True) => true
    Some(False) => false
    Some(Null) | None => default
    _ => fail("arguments.\{name} to be a boolean")
  }
}

///|
fn optional_positive_int(
  fields : Map[String, Json],
  name : String,
  default : Int,
) -> Int raise {
  match fields.get(name) {
    Some(Number(value, ..)) => {
      let int_value = value.to_int()
      if int_value <= 0 {
        fail("arguments.\{name} to be a positive number")
      }
      int_value
    }
    Some(Null) | None => default
    _ => fail("arguments.\{name} to be a number")
  }
}

///|
fn cap_max_output_chars(value : Int) -> Int {
  if value > hard_max_output_chars {
    hard_max_output_chars
  } else {
    value
  }
}

///|
fn validate_action(action : String) -> Unit raise {
  let allowed = ["doc", "outline", "peek_def", "hover", "find_references"]
  if !allowed.contains(action) {
    fail(
      "arguments.action to be one of doc, outline, peek_def, hover, find_references",
    )
  }
}

///|
fn validate_target(target : String) -> Unit raise {
  let allowed = ["wasm", "wasm-gc", "js", "native", "llvm", "all"]
  if !allowed.contains(target) {
    fail("arguments.target to be one of wasm, wasm-gc, js, native, llvm, all")
  }
}

///|
fn validate_required_fields(
  action : String,
  query : String?,
  path : String?,
  loc : String?,
) -> Unit raise {
  match action {
    "doc" => if query is None { fail("arguments.query for action doc") }
    "outline" => if path is None { fail("arguments.path for action outline") }
    "peek_def" =>
      if query is None {
        fail("arguments.query for action peek_def")
      }
    "hover" => {
      if query is None {
        fail("arguments.query for action hover")
      }
      if loc is None {
        fail("arguments.loc for action hover")
      }
    }
    "find_references" =>
      if query is None {
        fail("arguments.query for action find_references")
      }
    _ => ()
  }
}

///|
test "decode doc action arguments" {
  let input = decode({
    "action": "doc",
    "cwd": "/tmp",
    "query": "String::replace_all",
    "no_check": true,
  })
  assert_eq(input.action, "doc")
  assert_true(input.cwd is Some("/tmp"))
  assert_true(input.query is Some("String::replace_all"))
  assert_true(input.no_check)
  assert_eq(input.max_output_chars, default_max_output_chars)
}

///|
test "decode loc-aware navigation arguments" {
  let input = decode({
    "action": "peek_def",
    "query": "render",
    "loc": "lib.mbt:14:8",
    "target": "native",
  })
  assert_eq(input.action, "peek_def")
  assert_true(input.loc is Some("lib.mbt:14:8"))
  assert_true(input.target is Some("native"))
}

///|
test "decode outline path" {
  let input = decode({
    "action": "outline",
    "path": "agent_tool/moon_ide",
    "max_output_chars": 42,
  })
  assert_eq(input.action, "outline")
  assert_true(input.path is Some("agent_tool/moon_ide"))
  assert_eq(input.max_output_chars, 42)
}

///|
test "decode caps oversized output limit" {
  let input = decode({
    "action": "doc",
    "query": "String",
    "max_output_chars": 999999,
  })
  assert_eq(input.max_output_chars, hard_max_output_chars)
}

///|
test "decode rejects invalid action" {
  let _ = decode({ "action": "rename", "query": "old_name" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.action"))
      return
    }
  }
  fail("invalid action decoded")
}

///|
test "decode rejects missing required fields" {
  let _ = decode({ "action": "hover", "query": "Widget" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.loc"))
      return
    }
  }
  fail("hover without loc decoded")
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
