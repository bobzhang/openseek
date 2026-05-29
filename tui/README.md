# bobzhang/openseek/tui

Terminal UI primitives for OpenSeek-style agents.

## MVP API

`tui` owns the terminal session and leaves the agent loop to the caller:

```mbt
@tui.with_ui(ui => {
  for ;; {
    match ui.read_event() {
      @tui.Steer(@tui.Prompt(text)) =>
        ui.append_transcript(@tui.Doc::plain("> " + text))
      @tui.Queue(@tui.Prompt(text)) =>
        ui.append_transcript(@tui.Doc::plain("queued: " + text))
      @tui.Steer(@tui.Command(command)) =>
        ui.append_transcript(@tui.Doc::plain("$ " + command))
      @tui.Queue(@tui.Command(command)) =>
        ui.append_transcript(@tui.Doc::plain("queued shell: " + command))
      @tui.Interrupt => ui.set_status(@tui.Text::plain("interrupted"))
      @tui.Quit => break
    }
  }
})
```

Current input mapping:

- `Enter`: submit current input as `Steer(Prompt(text))`.
- `Tab`: submit current input as `Queue(Prompt(text))`.
- Leading `!`: enter shell mode; the prompt changes to `! ` and the marker is
  kept out of editable text.
- Shell mode + `Enter`: submit as `Steer(Command(cmd))`.
- Shell mode + `Tab`: submit as `Queue(Command(cmd))`.
- The composer starts with one editable row and grows with hard-newline input
  up to `composer_max_rows`, which defaults to `4`.
- History and Emacs-style editing keys:
  - `Up`/`Down`, `Ctrl-P`/`Ctrl-N`: move within multiline input, or recall
    submitted history at the first/last logical line.
  - `Ctrl-A`/`Ctrl-E`: move to start/end of the current logical line.
  - `Ctrl-B`/`Ctrl-F`: move left/right.
  - `Ctrl-H`: delete before cursor.
  - `Ctrl-D`: delete after cursor, or quit when the input is empty.
  - `Ctrl-U`/`Ctrl-K`: kill to start/end of the current logical line.
- `Ctrl-C` or `Esc`: return `Interrupt`.

## Package map

- Root package: session lifecycle, public `Ui` API, terminal rendering,
  viewport terminal anchoring, and input event translation.
- `internal/composer`: multiline composer state, shell-mode prompt handling, cursor
  movement, and the visible text window inside the composer.
- `internal/text`: grapheme/display-width aware text helpers used by the composer and
  renderer.

## Rendering Model

The root renderer treats transcript, activity, status, and composer content as
semantic `Doc`/`Text`/`Span` values that lay out into terminal rows. `Viewport`
owns where the live input surface lives on the terminal primary screen:

- activity row, when `set_activity` has live non-transcript state
- separator row
- editable text rows, from one row up to the configured maximum
- status row, with transient input notices temporarily overriding its display

`Surface` is a render product, not a semantic source. It contains the styled
rows the viewport should draw for one frame, plus the cursor position after the
frame is flushed. `Viewport` owns the 1-based terminal top row, terminal size,
transcript insertion above itself, conversion from viewport-local cursor
coordinates to terminal cursor coordinates, and row-level diffing against the
previous surface. Complete transcript output should be appended with
`append_transcript(doc)` or `append_item(item)`. Busy or progress labels that
must not enter the transcript should be rendered with `set_activity(Some(text))`
and cleared with `set_activity(None)`.

The live input area is not drawn until the first redraw. That first redraw
anchors at the current terminal cursor when the terminal answers a
cursor-position query, and falls back to the bottom of the terminal otherwise.
