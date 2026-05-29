///|
pub struct WriteInput {
  path : String
  content : String
} derive(Debug)

///|
pub fn decode(arguments : Json) -> WriteInput raise {
  match arguments {
    { "path": String(path), "content": String(content), .. } =>
      { path, content }
    { "path": String(_), .. } => fail("arguments.content")
    Object(_) => fail("arguments.path")
    _ => fail("object arguments")
  }
}
