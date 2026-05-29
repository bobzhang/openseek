///|
pub(all) enum ToolStatus {
  InProgress
  Completed
  Failed
  Declined
} derive(Eq, Debug)

///|
fn ToolStatus::style(self : ToolStatus) -> Style {
  match self {
    InProgress => Style::dim()
    Completed => Style::default()
    Failed => Style::new(foreground=Basic(Red))
    Declined => Style::dim()
  }
}

///|
pub struct ToolCall {
  title : Text
  status : ToolStatus?
  details : Array[Text]
}

///|
pub fn ToolCall::ToolCall(
  title : Text,
  status? : ToolStatus,
  details? : Array[Text] = [],
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
fn Text::split_lines(self : Text) -> Array[Text] {
  let lines : Array[Text] = []
  let mut spans : Array[Span] = []
  for span in self.spans {
    let parts = span.text.split("\n").to_array()
    for index in 0..<parts.length() {
      if index > 0 {
        lines.push(Text(spans))
        spans = []
      }
      let part = parts[index].to_owned()
      if part.length() > 0 {
        spans.push(Span(part, style=span.style))
      }
    }
  }
  lines.push(Text(spans))
  lines
}

///|
fn TranscriptItem::to_doc(self : TranscriptItem) -> Doc {
  match self {
    Input(input) => input.to_doc()
    Response(content) => {
      let texts : Array[Text] = []
      let lines = Text::plain(content).split_lines()
      for index in 0..<lines.length() {
        texts.push(
          Text(
            [
              Span(if index == 0 { "• " } else { "  " }, style=Style::dim()),
              ..lines[index].spans,
            ],
          ),
        )
      }
      Doc(texts)
    }
    Reasoning(text) => {
      let texts : Array[Text] = []
      let lines = Text([Span(text, style=Style::dim())]).split_lines()
      for index in 0..<lines.length() {
        texts.push(
          Text(
            [
              Span(if index == 0 { "• " } else { "  " }, style=Style::dim()),
              ..lines[index].spans,
            ],
          ),
        )
      }
      Doc(texts)
    }
    ToolCall(call) => {
      let bullet_style = call.status
        .map(status => status.style())
        .unwrap_or(Style::dim())
      let texts : Array[Text] = [
        Text([Span("• ", style=bullet_style), ..call.title.spans]),
      ]
      let mut has_detail_line = false
      for detail in call.details {
        for line in detail.split_lines() {
          texts.push(
            Text(
              [
                Span(
                  if has_detail_line {
                    "    "
                  } else {
                    "  └ "
                  },
                  style=Style::dim(),
                ),
                ..line.spans,
              ],
            ),
          )
          has_detail_line = true
        }
      }
      Doc(texts)
    }
    Error(message) => {
      let texts : Array[Text] = []
      let error_style = Style::new(foreground=Basic(Red))
      let lines = Text([Span(message, style=error_style)]).split_lines()
      for index in 0..<lines.length() {
        texts.push(
          Text(
            [
              Span(if index == 0 { "■ " } else { "  " }, style=error_style),
              ..lines[index].spans,
            ],
          ),
        )
      }
      Doc(texts)
    }
  }
}
