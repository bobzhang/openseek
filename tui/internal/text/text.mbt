///|
pub fn display_width(text : String) -> Int {
  @unicodewidth.str_width(text)
}

///|
pub fn truncate_line(text : String, cols : Int) -> String {
  if cols <= 0 {
    ""
  } else if display_width(text) <= cols {
    text
  } else {
    let suffix = "…"
    let suffix_width = @unicodewidth.str_width(suffix)
    let content_cols = cols - suffix_width
    let builder = StringBuilder()
    let mut width = 0
    for grapheme in @grapheme.grapheme_iter(text) {
      let next_width = @unicodewidth.str_width(grapheme)
      if width + next_width > content_cols {
        break
      }
      builder.write_stringview(grapheme)
      width = width + next_width
    }
    builder.write_string(suffix)
    builder.to_string()
  }
}

///|
pub fn split_lines(text : String) -> Array[String] {
  text.split("\n").map(line => line.to_owned()).collect()
}

///|
pub fn line_at(lines : Array[String], index : Int) -> String {
  if index < 0 || index >= lines.length() {
    ""
  } else {
    lines[index]
  }
}

///|
pub fn grapheme_count(text : String) -> Int {
  @grapheme.graphemes(text).length()
}

///|
pub fn grapheme_slice(text : String, start : Int, end : Int) -> String {
  let graphemes = @grapheme.graphemes(text)
  let length = graphemes.length()
  let start = @clamp.int(start, min=0, max=length)
  let end = @clamp.int(end, min=start, max=length)
  graphemes[start:end].to_string()
}
