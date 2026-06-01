# bobzhang/openseek/tui/internal/history

> Readline-style command history for the input composer.

`history` stores submitted composer entries (text plus the `@composer.Mode`
they were entered in) along with a navigation cursor, so Up/Ctrl-P and
Down/Ctrl-N can recall previous submissions while preserving the in-progress
draft. The cursor ranges over `[0, entries.length()]`, where the past-the-end
position means "editing the fresh draft." It sits beside the composer in the
TUI input layer, recalling values back into the composer model.

## Responsibilities

- Record submitted entries, skipping empty text and adjacent duplicates.
- Walk backward (`previous`) and forward (`next`) through entries, saving and
  restoring the in-progress draft at the boundary.
- Reset navigation to the fresh draft on edit, submit, or cancel.
- Boundary: stores and recalls entry values only; it does not edit the composer
  or interpret key events.

## Public API

Types

- `Entry` — one recallable submission: composer text plus its `@composer.Mode`.
- `History` — submitted entries plus the navigation cursor and saved draft.

Functions — `Entry`

- `Entry::new(String, @composer.Mode) -> Self` — build an entry from text and
  mode.
- `Entry::text(Self) -> String` — the recalled text.
- `Entry::mode(Self) -> @composer.Mode` — the mode the entry was submitted in.

Functions — `History`

- `History::new() -> Self` — empty history positioned on the fresh draft.
- `History::push(Self, Entry) -> Unit` — append an entry (unless empty or a
  duplicate of the most recent) and reset navigation.
- `History::previous(Self, Entry) -> Entry?` — recall the previous entry,
  saving the current draft on the first step back; `None` if nothing to recall.
- `History::next(Self) -> Entry?` — recall the next entry, returning to the
  saved draft past the last entry; `None` when already at the fresh draft.
- `History::reset_navigation(Self) -> Unit` — return the cursor to the fresh
  draft and forget any saved draft.

## Layering

Depends on `bobzhang/openseek/tui/internal/composer` (for `Mode`). This is an
`internal/` package: it is only importable within `tui/`.
