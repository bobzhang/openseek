///|
pub(all) enum ToolStatus {
  InProgress
  Completed
  Failed
  Declined
} derive(Eq, Debug)

///|
fn ToolStatus::style(self : ToolStatus) -> @doc.Style {
  match self {
    InProgress => @doc.Style::dim()
    Completed => @doc.Style::default()
    Failed => @doc.Style::error()
    Declined => @doc.Style::dim()
  }
}

///|
pub struct ToolCall {
  title : @doc.Text
  status : ToolStatus?
  details : Array[@doc.Text]
}

///|
pub fn ToolCall::ToolCall(
  title : @doc.Text,
  status? : ToolStatus,
  details? : Array[@doc.Text] = [],
) -> ToolCall {
  { title, status, details: details.copy() }
}

///|
pub(all) enum TranscriptItem {
  Input(Input)
  Response(String)
  Reasoning(String)
  ToolCall(ToolCall)
  Error(String)
}

///|
/// Prefix each split line of `text` with a bullet/continuation marker in
/// `style`, producing one `@doc.Text` block per line.
fn bulleted_lines(
  text : @doc.Text,
  first~ : String,
  rest~ : String,
  style~ : @doc.Style,
) -> Array[@doc.Text] {
  let texts : Array[@doc.Text] = []
  let lines = text.split_lines()
  for index in 0..<lines.length() {
    let marker = if index == 0 { first } else { rest }
    texts.push(lines[index].prepend_span(@doc.Span(marker, style~)))
  }
  texts
}

///|
fn TranscriptItem::to_doc(self : TranscriptItem) -> @doc.Doc {
  match self {
    Input(input) => input.to_doc()
    Response(content) =>
      @doc.Doc(
        bulleted_lines(
          @doc.Text::plain(content),
          first="• ",
          rest="  ",
          style=@doc.Style::dim(),
        ),
      )
    Reasoning(text) =>
      @doc.Doc(
        bulleted_lines(
          @doc.Text([@doc.Span(text, style=@doc.Style::dim())]),
          first="• ",
          rest="  ",
          style=@doc.Style::dim(),
        ),
      )
    ToolCall(call) => {
      let bullet_style = call.status
        .map(status => status.style())
        .unwrap_or(@doc.Style::dim())
      let texts : Array[@doc.Text] = [
        call.title.prepend_span(@doc.Span("• ", style=bullet_style)),
      ]
      let mut has_detail_line = false
      for detail in call.details {
        for line in detail.split_lines() {
          let marker = if has_detail_line { "    " } else { "  └ " }
          texts.push(
            line.prepend_span(@doc.Span(marker, style=@doc.Style::dim())),
          )
          has_detail_line = true
        }
      }
      @doc.Doc(texts)
    }
    Error(message) => {
      let error_style = @doc.Style::error()
      @doc.Doc(
        bulleted_lines(
          @doc.Text([@doc.Span(message, style=error_style)]),
          first="■ ",
          rest="  ",
          style=error_style,
        ),
      )
    }
  }
}
