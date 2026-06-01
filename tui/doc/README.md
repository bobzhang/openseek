# bobzhang/openseek/tui/doc

> Styled-text vocabulary — Style/Span/Text/Doc — plus the `ToDoc` projection trait.

`doc` is the layer where renderable content is described: styled spans of text,
single-line `Text`, and multi-line `Doc` blocks, together with the `ToDoc` trait
that semantic types implement to project themselves into a `Doc`. It sits above
the passive `internal/surface` render vocabulary and below the semantic `core`
model: `Doc`/`Text` lay themselves out into width-aware `@surface.Line`s, while
`core` and other callers supply the meaning. All container types are opaque.

## Responsibilities

- Define `Style` (foreground/background/underline, with named presets) and its
  conversion into a `@surface.Style`.
- Define `Span` (a styled string fragment), `Text` (one logical line of spans),
  and `Doc` (a block of `Text`s).
- Lay out and wrap content into `@surface.Line`s: width-aware wrapping, tab
  expansion to 8-column stops, dropping of stray control characters, and
  newline-as-hard-break.
- Own the `ToDoc` trait — the single seam through which semantic values become
  renderable `Doc`s.
- It leaves the *meaning* of content to higher layers (`core`) and the *drawing*
  of laid-out lines to lower layers (`surface` and the renderer).

## Public API

Styles:
- `Style` (opaque) — `new`, `default`, `dim`, `error`, `prompt`, `to_surface`.

Spans and text:
- `Span` (opaque) — `Span`, `plain`.
- `Text` (opaque) — `Text`, `plain`, `prepend_span`, `split_lines`,
  `first_line(width~)`, `wrap(width~)`.
- `dim_text(String) -> Text` — convenience for a dim single-line `Text`.

Documents:
- `Doc` (opaque) — `Doc`, `plain`, `layout(width~) -> Array[@surface.Line]`.

Trait:
- `ToDoc` — `fn to_doc(Self) -> Doc`, implemented by semantic types in their home
  packages.

## Layering

Depends on `internal/surface` (the layout target), `tty/color` (style colors),
and `grapheme`/`unicodewidth` (grapheme- and display-width-aware wrapping). It has
no IO and no knowledge of the semantic model; `core` depends on it to attach
`Doc` projections to its types.
