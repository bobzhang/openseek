///|
pub struct MoonCheckInput {
  cwd : String?
  paths : Array[String]
  target : String?
  warn_list : String?
  deny_warn : Bool
  fmt : Bool
  explain : Bool
} derive(Debug)

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
