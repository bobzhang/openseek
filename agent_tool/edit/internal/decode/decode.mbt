///|
pub struct EditInput {
  path : String
  old_string : String
  new_string : String
  replace_all : Bool
} derive(Debug)

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
