///|
pub struct FinishInput {
  answer : String
} derive(Debug)

///|
pub fn decode(arguments : Json) -> FinishInput {
  let answer = match arguments {
    { "answer": String(answer), .. } => answer
    _ => ""
  }
  { answer, }
}
