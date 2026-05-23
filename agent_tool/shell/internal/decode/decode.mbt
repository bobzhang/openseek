///|
pub let default_max_output_chars : Int = 12000

///|
pub let hard_max_output_chars : Int = 50000

///|
pub struct ShellInput {
  cmd : String
  cwd : String?
  max_output_chars : Int
}

///|
pub fn decode(arguments : Json) -> ShellInput raise {
  match arguments {
    Object(fields) => parse_fields(fields)
    _ => fail("object arguments")
  }
}

///|
fn parse_fields(fields : Map[String, Json]) -> ShellInput raise {
  let cmd = required_string(fields, "cmd")
  let cwd = optional_string(fields, "cwd")
  let max_output_chars = optional_positive_int(
    fields, "max_output_chars", default_max_output_chars,
  )
  { cmd, cwd, max_output_chars: cap_max_output_chars(max_output_chars) }
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
test "decode valid shell input" {
  let input = decode({
    "cmd": "echo hello",
    "cwd": "/tmp",
    "max_output_chars": 999999,
  })
  assert_eq(input.cmd, "echo hello")
  assert_true(input.cwd is Some("/tmp"))
  assert_eq(input.max_output_chars, hard_max_output_chars)
}

///|
test "decode treats empty cwd as absent" {
  let input = decode({ "cmd": "pwd", "cwd": "" })
  assert_true(input.cwd is None)
}

///|
test "decode rejects missing command" {
  let _ = decode({ "cwd": "/tmp" }) catch {
    error => {
      assert_true("\{error}".contains("arguments.cmd"))
      return
    }
  }
  fail("missing command decoded")
}

///|
test "decode rejects invalid output cap" {
  let _ = decode({ "cmd": "echo hello", "max_output_chars": 0 }) catch {
    error => {
      assert_true(
        "\{error}".contains(
          "arguments.max_output_chars to be a positive number",
        ),
      )
      return
    }
  }
  fail("invalid output cap decoded")
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
