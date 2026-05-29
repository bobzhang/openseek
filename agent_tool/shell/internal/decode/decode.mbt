///|
pub let default_max_output_chars : Int = 12000

///|
pub let hard_max_output_chars : Int = 50000

///|
pub struct ShellInput {
  cmd : String
  cwd : String?
  max_output_chars : Int
} derive(Debug)

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
