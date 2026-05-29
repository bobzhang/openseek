///|
test "decode keeps answer" {
  debug_inspect(
    decode({ "answer": "all done" }),
    content=(
      #|{ answer: "all done" }
    ),
  )
}

///|
test "decode preserves multiline answer" {
  debug_inspect(
    decode({ "answer": "line one\nline two" }),
    content=(
      #|{ answer: "line one\nline two" }
    ),
  )
}

///|
test "decode ignores extra fields" {
  debug_inspect(
    decode({ "answer": "done", "extra": "ignored" }),
    content=(
      #|{ answer: "done" }
    ),
  )
}

///|
test "decode falls back to empty answer" {
  debug_inspect(
    decode({}),
    content=(
      #|{ answer: "" }
    ),
  )
  debug_inspect(
    decode({ "answer": 42 }),
    content=(
      #|{ answer: "" }
    ),
  )
  debug_inspect(
    decode(Json::null()),
    content=(
      #|{ answer: "" }
    ),
  )
}
