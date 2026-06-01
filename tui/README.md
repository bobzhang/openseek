# bobzhang/openseek/tui

> The terminal controller and IO façade for OpenSeek-style agents.

`tui` owns the live terminal session: it opens the tty, draws a bottom-anchored
input area in place while keeping the transcript in native scrollback, translates
key presses into semantic events, and hands them to the application loop. It sits
at the top of the layering, driving the lower `viewport`, `composer`, `render`,
`doc`, and `core` packages, and leaves the agent loop itself to the caller.

## Responsibilities

- Own the terminal session lifecycle: open the tty in raw mode, request the kitty
  keyboard enhancement, draw the first frame, and always restore the terminal on
  exit (`with_ui`).
- Run the event loop: read tty input on a background task, map keys to semantic
  `Event`s, and serialize all redraws through a single command queue.
- Maintain the transcript in scrollback and redraw the live area (activity,
  composer, queued inputs, status) in place, including resize replay.
- Translate input into the `core` model (`Steer`/`Queue` of `Prompt`/`Command`,
  `Interrupt`, `Quit`) and re-export those model types.
- Leave the agent loop, command execution, and business logic to the caller: the
  controller only surfaces events and renders what the caller pushes.

## Public API

- `with_ui(config?, body)` — open a session and run `body` with a live `Ui`,
  restoring the terminal afterwards on both success and error paths.
- `Ui::read_event()` — block for the next semantic `@tui.Event`.
- `Ui::append_transcript(@doc.Doc)` / `Ui::append_item(TranscriptItem)` — append
  permanent output to the scrollback transcript.
- `Ui::set_activity(@doc.Text?)` — show/clear a transient busy label above the
  composer (never enters the transcript).
- `Ui::set_queued_inputs(Array[Input])` — display the pending input queue.
- `Ui::set_status(@doc.Text)` — set the persistent status line.
- `Config` / `Config::new(esc_timeout_ms?, composer_max_rows?)` — session tuning.
- Re-exported model types: `@tui.Input`, `@tui.Event`, `@tui.ToolStatus`,
  `@tui.ToolCall`, `@tui.TranscriptItem` (from `core`). Styled-text types
  `Doc`/`Text` live in the `@doc` package and appear in `Ui` signatures as
  `@doc.Doc` / `@doc.Text`.

## Usage

`tui` owns the terminal session and leaves the agent loop to the caller:

```mbt
@tui.with_ui(ui => {
  for ;; {
    match ui.read_event() {
      @tui.Steer(@tui.Prompt(text)) =>
        ui.append_transcript(@doc.Doc::plain("> " + text))
      @tui.Queue(@tui.Prompt(text)) =>
        ui.append_transcript(@doc.Doc::plain("queued: " + text))
      @tui.Steer(@tui.Command(command)) =>
        ui.append_transcript(@doc.Doc::plain("$ " + command))
      @tui.Queue(@tui.Command(command)) =>
        ui.append_transcript(@doc.Doc::plain("queued shell: " + command))
      @tui.Interrupt => ui.set_status(@doc.Text::plain("interrupted"))
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
- `Shift-Enter` / `Ctrl-J`: insert a hard newline without submitting.
- History and Emacs-style editing keys:
  - `Up`/`Down`, `Ctrl-P`/`Ctrl-N`: move within multiline input, or recall
    submitted history at the first/last logical line.
  - `Ctrl-A`/`Ctrl-E`: move to start/end of the current logical line.
  - `Ctrl-B`/`Ctrl-F`: move left/right.
  - `Alt-B`/`Alt-F`: move one word left/right.
  - `Ctrl-H`: delete before cursor.
  - `Ctrl-D`: delete after cursor, or quit when the input is empty.
  - `Ctrl-U`/`Ctrl-K`: kill to start/end of the current logical line.
- `Ctrl-C` or `Esc`: return `Interrupt`.

## Layering

`tui` is the top layer and depends on everything below it:

- `core`: the semantic model it re-exports and produces (`Input`, `Event`,
  `TranscriptItem`, ...).
- `doc`: styled-text vocabulary (`Doc`/`Text`/`Span`) used in `Ui` signatures.
- `render`: lays out the composer area into a `Surface`.
- `composer`: width-aware multiline input editor state and shell-mode handling.
- `history`: readline-style command history.
- `surface`: passive render-data vocabulary describing what to draw.
- `viewport`: the inline DECSTBM engine that anchors and redraws the live area
  while pushing the transcript into native scrollback.
- `task`: single-slot async queue that serializes redraws and key handling.
- `tty`: the raw terminal IO the session drives.

It depends on these so the controller can stay a thin IO façade: lower layers
describe and lay out content, while `tui` decides when to read, when to draw, and
how input becomes model events.
