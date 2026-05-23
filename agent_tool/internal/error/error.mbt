///|
/// Extracts the user-facing message from MoonBit's default `fail(...)` error
/// rendering. This keeps tool argument errors stable when validation lives in
/// an internal package and the raw error string includes source locations.
pub fn failure_message(error_text : String) -> String {
  let marker = " FAILED: "
  let pieces : Array[String] = error_text
    .split(marker)
    .map(piece => piece.to_owned())
    .collect()
  if pieces.length() < 2 {
    return error_text
  }
  let message = pieces[pieces.length() - 1]
  if message.has_suffix(")") {
    message[:message.length() - 1].to_owned()
  } else {
    message
  }
}

///|
test "failure_message strips fail wrapper" {
  assert_eq(
    failure_message(
      "Failure(path/to/file.mbt:1:2-1:3@pkg FAILED: arguments.path)",
    ),
    "arguments.path",
  )
  assert_eq(failure_message("arguments.path"), "arguments.path")
}
