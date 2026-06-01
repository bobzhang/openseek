# bobzhang/openseek/tui/internal/composer

> Width-aware multi-line text editor model behind the TUI's input composer.

`composer` is the editable-text core of the TUI's composer. It owns the user's
text, a cursor that navigates over soft-wrapped *visual* rows, the current
content width, and a prompt-vs-shell `Mode`. It sits below the `render` layer:
it produces plain text plus cursor placement, and the renderer turns that into a
styled terminal surface.

## Responsibilities

- Edit text: grapheme-aware insert, backspace/delete, word motion, and
  kill-line / kill-to-start operations matching readline/emacs conventions.
- Soft-wrap each logical line to the editable content width, so one long line
  becomes several visual rows and the cursor moves between *wrapped* rows
  (Ctrl-P / Ctrl-N via `move_vertical`) rather than only logical lines.
- Track a cursor with wrap-boundary affinity and a preferred display column, and
  scroll a fixed-height window (`view_start`, capped at `max_text_rows`) to keep
  the cursor visible.
- Expose first/last-visual-row queries so the surrounding TUI can hand off to
  history recall when the cursor leaves the top or bottom of the buffer.
- Carry semantic `Mode`: a leading `!` in an empty `Input` buffer enters `Shell`
  mode (first prompt becomes `! `) and is kept out of the editable text.
- Stay rendering-agnostic: no colors, surfaces, or IO. It only emits text and
  cursor offsets (measured in display cells / graphemes); the `render` layer
  paints the surface and anchors it in the terminal.

## Public API

Construction / lifecycle
- `Model::new(max_text_rows?)` — empty composer in `Input` mode.
- `Model::reset()` — clear back to empty `Input`.
- `Model::replace(text, mode~)` — load a full buffer (e.g. a history entry).
- `Model::resize(cols~)` — relay out for the current terminal width.

Editing
- `Model::insert(text)` / `Model::insert_user_text(text)` — insert text; the
  latter applies the leading-`!` shell shortcut.
- `Model::delete_before()` / `Model::delete_after()` — Backspace / Delete.
- `Model::kill_before()` / `Model::kill_after()` — kill to line start / line end.

Cursor movement
- `Model::move_left()` / `Model::move_right()` — by grapheme.
- `Model::move_word_left()` / `Model::move_word_right()` — by word.
- `Model::move_home()` / `Model::move_end()` — logical line start / end.
- `Model::move_vertical(delta)` — between wrapped rows, preserving column.

View accessors
- `Model::text()` / `Model::mode()` — submitted text and semantic mode.
- `Model::visible_text_rows()` — current rendered row count.
- `Model::visible_line(row)` / `Model::input_prefix(row)` — wrapped row text and
  its prompt prefix.
- `Model::cursor_row()` / `Model::cursor_offset()` — cursor placement in the
  visible surface.
- `Model::cursor_at_first_visual_row()` / `Model::cursor_at_last_visual_row()` —
  history-handoff edge queries.

Mode
- `Mode` (`Input` / `Shell`) with `Mode::is_input()` / `Mode::is_shell()`.

Constant
- `DefaultMaxTextRows` — default growth cap before the composer scrolls.

## Layering

Depends on `internal/text`, `kawaz/grapheme`, and `rami3l/unicodewidth` for
grapheme iteration and display-width measurement. It is an `internal/` package,
so it is only importable within `tui/`; the TUI's `render` layer consumes its
output to draw the composer surface.
