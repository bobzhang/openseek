///|
pub struct FinishInput {
  answer : String
}

///|
pub fn decode(arguments : Json) -> FinishInput {
  let answer = match arguments {
    { "answer": String(answer), .. } => answer
    _ => ""
  }
  { answer, }
}

///|
test "decode keeps answer" {
  let input = decode({ "answer": "all done" })
  assert_eq(input.answer, "all done")
}

///|
test "decode preserves multiline answer" {
  let input = decode({ "answer": "line one\nline two" })
  assert_eq(input.answer, "line one\nline two")
}

///|
test "decode ignores extra fields" {
  let input = decode({ "answer": "done", "extra": "ignored" })
  assert_eq(input.answer, "done")
}

///|
test "decode falls back to empty answer" {
  assert_eq(decode({}).answer, "")
  assert_eq(decode({ "answer": 42 }).answer, "")
  assert_eq(decode(Json::null()).answer, "")
}
