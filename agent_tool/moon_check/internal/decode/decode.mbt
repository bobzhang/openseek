///|
pub struct MoonCheckInput {
  cwd : String?
  paths : Array[String]
  target : String?
  warn_list : String?
  deny_warn : Bool
  fmt : Bool
  explain : Bool
}

///|
pub fn decode(arguments : Json) -> MoonCheckInput raise {
  match arguments {
    Object(fields) => parse_fields(fields)
    _ => fail("object arguments")
  }
}

///|
fn parse_fields(fields : Map[String, Json]) -> MoonCheckInput raise {
  let cwd = optional_string(fields, "cwd")
  let target = optional_string(fields, "target")
  match target {
    Some(value) => validate_target(value)
    None => ()
  }
  let warn_list = optional_string(fields, "warn_list")
  let paths = parse_paths(fields)
  {
    cwd,
    paths,
    target,
    warn_list,
    deny_warn: optional_bool(fields, "deny_warn"),
    fmt: optional_bool(fields, "fmt"),
    explain: optional_bool(fields, "explain"),
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
fn optional_bool(fields : Map[String, Json], name : String) -> Bool raise {
  match fields.get(name) {
    Some(True) => true
    Some(False) | Some(Null) | None => false
    _ => fail("arguments.\{name} to be a boolean")
  }
}

///|
fn parse_paths(fields : Map[String, Json]) -> Array[String] raise {
  let paths : Array[String] = []
  match fields.get("path") {
    Some(String(path)) if path != "" => paths.push(path)
    Some(String(_)) | Some(Null) | None => ()
    _ => fail("arguments.path to be a string")
  }
  match fields.get("paths") {
    Some(Array(values)) =>
      for value in values {
        match value {
          String(path) if path != "" => paths.push(path)
          String(_) | Null => ()
          _ => fail("arguments.paths to be an array of strings")
        }
      }
    Some(Null) | None => ()
    _ => fail("arguments.paths to be an array of strings")
  }
  paths
}

///|
fn validate_target(target : String) -> Unit raise {
  let allowed = ["wasm", "wasm-gc", "js", "native", "llvm", "all"]
  if !allowed.contains(target) {
    fail("arguments.target to be one of wasm, wasm-gc, js, native, llvm, all")
  }
}

///|
test "decode direct moon_check arguments" {
  let input = decode({
    "cwd": "/tmp",
    "path": "agent",
    "paths": ["README.mbt.md"],
    "target": "native",
    "warn_list": "+unnecessary_annotation",
    "deny_warn": true,
    "fmt": true,
    "explain": true,
  })
  assert_true(input.cwd is Some("/tmp"))
  assert_eq(input.paths.join("|"), "agent|README.mbt.md")
  assert_true(input.target is Some("native"))
  assert_true(input.warn_list is Some("+unnecessary_annotation"))
  assert_true(input.deny_warn)
  assert_true(input.fmt)
  assert_true(input.explain)
}

///|
test "decode path and paths together" {
  let input = decode({
    "path": "agent",
    "paths": ["agent_tool/read", "agent_tool/write"],
  })
  assert_eq(input.paths.join("|"), "agent|agent_tool/read|agent_tool/write")
}

///|
test "decode ignores empty optional strings and false flags" {
  let input = decode({
    "cwd": "",
    "path": "",
    "paths": ["", null],
    "deny_warn": false,
    "fmt": null,
  })
  assert_true(input.cwd is None)
  assert_eq(input.paths.length(), 0)
  assert_false(input.deny_warn)
  assert_false(input.fmt)
  assert_false(input.explain)
}

///|
test "decode rejects invalid target" {
  let _ = decode({ "target": "browser" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.target"))
      return
    }
  }
  fail("invalid target decoded")
}

///|
test "decode rejects invalid paths" {
  let _ = decode({ "paths": [42] }) catch {
    error => {
      assert_true("\{error}".contains("arguments.paths"))
      return
    }
  }
  fail("invalid paths decoded")
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
