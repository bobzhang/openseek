///|
pub let default_max_output_chars : Int = 12000

///|
pub let hard_max_output_chars : Int = 50000

///|
pub struct ReadInput {
  path : String
  start_line : Int
  max_lines : Int?
  max_output_chars : Int
}

///|
pub fn decode(arguments : Json) -> ReadInput raise {
  match arguments {
    Object(fields) => parse_fields(fields)
    _ => fail("object arguments")
  }
}

///|
fn parse_fields(fields : Map[String, Json]) -> ReadInput raise {
  let path = required_string(fields, "path")
  let start_line = optional_positive_int(fields, "start_line", 1)
  let max_lines = optional_positive_int_option(fields, "max_lines")
  let max_output_chars = optional_positive_int(
    fields, "max_output_chars", default_max_output_chars,
  )
  {
    path,
    start_line,
    max_lines,
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
fn optional_positive_int_option(
  fields : Map[String, Json],
  name : String,
) -> Int? raise {
  match fields.get(name) {
    Some(Number(value, ..)) => {
      let int_value = value.to_int()
      if int_value <= 0 {
        fail("arguments.\{name} to be a positive number")
      }
      Some(int_value)
    }
    Some(Null) | None => None
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
test "decode valid read input" {
  let input = decode({
    "path": "file.mbt",
    "start_line": 3,
    "max_lines": 4,
    "max_output_chars": 999999,
  })
  assert_eq(input.path, "file.mbt")
  assert_eq(input.start_line, 3)
  guard input.max_lines is Some(max_lines) else { fail("missing max_lines") }
  assert_eq(max_lines, 4)
  assert_eq(input.max_output_chars, hard_max_output_chars)
}

///|
test "decode defaults optional limits" {
  let input = decode({ "path": "file.mbt" })
  assert_eq(input.start_line, 1)
  assert_true(input.max_lines is None)
  assert_eq(input.max_output_chars, default_max_output_chars)
}

///|
test "decode rejects missing path" {
  let _ = decode({}) catch {
    error => {
      assert_true("\{error}".contains("arguments.path"))
      return
    }
  }
  fail("missing path decoded")
}

///|
test "decode rejects invalid limits" {
  let _ = decode({ "path": "file.mbt", "max_lines": 0 }) catch {
    error => {
      assert_true(
        "\{error}".contains("arguments.max_lines to be a positive number"),
      )
      return
    }
  }
  fail("invalid max_lines decoded")
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
