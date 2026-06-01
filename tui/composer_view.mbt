///|
fn render_separator_line(cols~ : Int) -> @viewport.Line {
  @viewport.Line::new([
    @viewport.Span::new(
      String::make(cols, '─'),
      style=Style::dim().to_viewport(),
    ),
  ])
}

///|
fn composer_input_style() -> @viewport.Style {
  Style::default().to_viewport()
}

///|
fn composer_prompt_style() -> @viewport.Style {
  Style::prompt().to_viewport()
}

///|
fn render_prompt_line(
  prefix~ : String,
  line~ : String,
  cols~ : Int,
) -> @viewport.Line {
  let prefix_width = @text.display_width(prefix)
  let content = @text.truncate_line(line, cols - prefix_width)
  let used = prefix_width + @text.display_width(content)
  let fill_cols = if used < cols { cols - used } else { 0 }
  @viewport.Line::new([
    @viewport.Span::new(prefix, style=composer_prompt_style()),
    @viewport.Span::new(content, style=composer_input_style()),
    @viewport.Span::new(
      String::make(fill_cols, ' '),
      style=composer_input_style(),
    ),
  ])
}

///|
fn render_status_line(
  status : Text,
  notice : Text?,
  cols~ : Int,
) -> @viewport.Line {
  notice.unwrap_or(status).first_line(width=cols)
}

///|
fn render_composer_surface(
  composer : @composer.Model,
  activity : Text?,
  queued_inputs : Array[Input],
  status : Text,
  notice : Text?,
  cols~ : Int,
) -> @viewport.Surface {
  let rows : Array[@viewport.Line] = []
  for row in render_queued_inputs(queued_inputs, cols~) {
    rows.push(row)
  }
  if activity is Some(activity) {
    rows.push(@viewport.Line::new([]))
    rows.push(activity.first_line(width=cols))
    rows.push(@viewport.Line::new([]))
  }
  let composer_top = rows.length()
  rows.push(render_separator_line(cols~))
  for row in 0..<composer.visible_text_rows() {
    rows.push(
      render_prompt_line(
        prefix=composer.input_prefix(row),
        line=composer.visible_line(row),
        cols~,
      ),
    )
  }
  rows.push(render_separator_line(cols~))
  rows.push(render_status_line(status, notice, cols~))
  @viewport.Surface::new(
    width=cols,
    rows~,
    cursor=@viewport.Cursor::new(
      row=composer_top + 1 + composer.cursor_row(),
      col=composer.cursor_offset(cols),
    ),
  )
}
