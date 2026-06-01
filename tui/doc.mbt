///|
/// A renderable document made of logical text blocks.
///
/// `Doc` is used for committed transcript output. Each `Text` block is wrapped
/// independently when the document is laid out for the current terminal width.
struct Doc {
  texts : Array[Text]
}

///|
/// Build a document from a sequence of text blocks.
pub fn Doc::Doc(texts : Array[Text]) -> Doc {
  { texts: texts.copy() }
}

///|
/// Build a document containing one unstyled text block.
pub fn Doc::plain(text : String) -> Doc {
  Doc([Text::plain(text)])
}

///|
/// A logical text block made of styled spans.
///
/// Text wraps by terminal display width and treats newline characters as forced
/// row breaks.
struct Text {
  spans : Array[Span]
}

///|
/// Build a text block from a sequence of styled spans.
pub fn Text::Text(spans : Array[Span]) -> Text {
  { spans: spans.copy() }
}

///|
/// Build a text block containing one unstyled span.
pub fn Text::plain(text : String) -> Text {
  Text([Span::plain(text)])
}

///|
/// A string fragment with an associated terminal style.
struct Span {
  text : String
  style : Style
}

///|
/// Build a styled span.
///
/// If `style` is omitted, the span uses `Style::default`.
pub fn Span::Span(text : String, style? : Style = Style::default()) -> Span {
  { text, style }
}

///|
/// Build an unstyled span.
pub fn Span::plain(text : String) -> Span {
  Span(text)
}

///|
/// Terminal styling applied while a span is written.
///
/// A style can set foreground color, background color, and underline. Terminal
/// styling is reset after each span is emitted.
struct Style {
  foreground : @tty/color.Color
  background : @tty/color.Color
  underline : Bool
} derive(Eq)

///|
/// Return the default terminal style.
pub fn Style::default() -> Style {
  { foreground: Default, background: Default, underline: false }
}

///|
/// Build a terminal style.
///
/// Omitted color arguments use the terminal default, and `underline` defaults
/// to `false`.
pub fn Style::new(
  foreground? : @tty/color.Color = Default,
  background? : @tty/color.Color = Default,
  underline? : Bool = false,
) -> Style {
  { foreground, background, underline }
}

///|
/// Return the subdued style used for secondary agentui text.
pub fn Style::dim() -> Style {
  Style::new(foreground=Basic(BrightBlack))
}

///|
/// Return the prompt style used for submitted and live input prefixes.
pub fn Style::prompt() -> Style {
  Style::new(foreground=Basic(BrightGreen))
}

///|
fn Style::to_viewport(self : Style) -> @viewport.Style {
  @viewport.Style::new(
    foreground=self.foreground,
    background=self.background,
    underline=self.underline,
  )
}

///|
/// Terminal tab stop width. Tabs in transcript content are expanded to spaces
/// up to the next multiple of this, matching the conventional terminal default.
const TabWidth : Int = 8

///|
/// Whether a grapheme is a C0 control character or DEL. `\n` and `\t` are
/// handled separately by the wrapper, so this only matches the remaining
/// controls (`\r`, etc.) that must not reach the terminal verbatim.
fn is_control_grapheme(grapheme : String) -> Bool {
  match grapheme.get_char(0) {
    Some(c) => {
      let code = c.to_int()
      code < 0x20 || code == 0x7f
    }
    None => false
  }
}

///|
fn Text::wrap(self : Text, width~ : Int) -> Array[@viewport.Line] {
  let rows : Array[@viewport.Line] = []
  let mut spans : Array[@viewport.Span] = []
  let mut used = 0
  let width = if width < 1 { 1 } else { width }
  for span in self.spans {
    let style = span.style.to_viewport()
    for grapheme in @grapheme.grapheme_iter(span.text) {
      let text = grapheme.to_owned()
      if text == "\n" {
        rows.push(@viewport.Line::new(spans))
        spans = []
        used = 0
      } else {
        // Normalize control characters so the columns we count match what the
        // terminal draws. A raw `\t` jumps to the terminal's tab stop and a
        // `\r` returns the cursor to column 1; neither is modeled by `used`, so
        // they shove following text into the wrong column.
        let pieces : Array[String] = if text == "\t" {
          Array::make(TabWidth - used % TabWidth, " ")
        } else if is_control_grapheme(text) {
          []
        } else {
          [text]
        }
        for piece in pieces {
          let next = @unicodewidth.str_width(piece)
          if used > 0 && used + next > width {
            rows.push(@viewport.Line::new(spans))
            spans = []
            used = 0
          }
          spans.push(@viewport.Span::new(piece, style~))
          used += next
        }
      }
    }
  }
  rows.push(@viewport.Line::new(spans))
  rows
}

///|
fn Text::first_line(self : Text, width~ : Int) -> @viewport.Line {
  match self.wrap(width~).get(0) {
    Some(line) => line
    None => @viewport.Line::new([])
  }
}

///|
fn Doc::layout(self : Doc, width~ : Int) -> Array[@viewport.Line] {
  let rows : Array[@viewport.Line] = []
  for text in self.texts {
    for row in text.wrap(width~) {
      rows.push(row)
    }
  }
  rows
}

///|
fn dim_text(text : String) -> Text {
  Text([Span(text, style=Style::dim())])
}
