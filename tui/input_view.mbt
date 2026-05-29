///|
fn input_prefix(input : Input) -> String {
  match input {
    Prompt(_) => "> "
    Command(_) => "$ "
  }
}

///|
fn input_text(input : Input) -> String {
  match input {
    Prompt(text) => text
    Command(command) => command
  }
}

///|
fn input_preview_text(input : Input) -> String {
  let lines = @text.split_lines(input_text(input))
  let first = @text.line_at(lines, 0)
  if lines.length() > 1 {
    first + " …"
  } else {
    first
  }
}

///|
fn Input::to_doc(self : Input) -> Doc {
  let source = @text.split_lines(input_text(self))
  let texts : Array[Text] = []
  for index in 0..<source.length() {
    texts.push(
      Text([
        Span(
          if index == 0 {
            input_prefix(self)
          } else {
            "  "
          },
          style=Style::prompt(),
        ),
        Span::plain(@text.line_at(source, index)),
      ]),
    )
  }
  Doc(texts)
}

///|
fn render_queued_input_line(
  input : Input,
  index~ : Int,
  cols~ : Int,
) -> @viewport.Line {
  let marker = "  \{index + 1}. "
  let prefix = input_prefix(input)
  @viewport.Line::new([
    @viewport.Span::new(marker, style=Style::dim().to_viewport()),
    @viewport.Span::new(prefix, style=Style::prompt().to_viewport()),
    @viewport.Span::new(
      @text.truncate_line(
        input_preview_text(input),
        cols - @text.display_width(marker) - @text.display_width(prefix),
      ),
      style=Style::dim().to_viewport(),
    ),
  ])
}

///|
fn render_queued_inputs(
  inputs : Array[Input],
  cols~ : Int,
) -> Array[@viewport.Line] {
  let rows : Array[@viewport.Line] = []
  if inputs.length() > 0 {
    rows.push(
      @viewport.Line::new([
        @viewport.Span::new(
          @text.truncate_line("queued follow-up inputs:", cols),
          style=Style::dim().to_viewport(),
        ),
      ]),
    )
    for index in 0..<inputs.length() {
      rows.push(render_queued_input_line(inputs[index], index~, cols~))
    }
  }
  rows
}
