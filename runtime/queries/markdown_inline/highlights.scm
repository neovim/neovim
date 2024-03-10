; From MDeiml/tree-sitter-markdown
(code_span) @markup.raw @nospell

(emphasis) @markup.italic

(strong_emphasis) @markup.strong

(strikethrough) @markup.strikethrough

(shortcut_link
  (link_text) @nospell)

[
  (backslash_escape)
  (hard_line_break)
] @string.escape

; Conceal codeblock and text style markers
((code_span_delimiter) @markup.raw.delimiter
  (#set! conceal ""))

((emphasis_delimiter) @conceal
  (#set! conceal ""))

; Conceal inline links
(inline_link
  [
    "["
    "]"
    "("
    (link_destination)
    ")"
  ] @markup.link
  (#set! conceal ""))

(inline_link
  (link_text) @markup.link.label
  (link_destination) @markup.link
  (#set! @markup.link.label "url" @markup.link))

; Conceal image links
(image
  [
    "!"
    "["
    "]"
    "("
    (link_destination)
    ")"
  ] @markup.link
  (#set! conceal ""))

; Conceal full reference links
(full_reference_link
  [
    "["
    "]"
    (link_label)
  ] @markup.link
  (#set! conceal ""))

; Conceal collapsed reference links
(collapsed_reference_link
  [
    "["
    "]"
  ] @markup.link
  (#set! conceal ""))

; Conceal shortcut links
(shortcut_link
  [
    "["
    "]"
  ] @markup.link
  (#set! conceal ""))

[
  (link_destination)
  (uri_autolink)
] @markup.link.url @nospell

[
  (link_label)
  (link_text)
  (link_title)
  (image_description)
] @markup.link.label

; Replace common HTML entities.
((entity_reference) @character.special
  (#eq? @character.special "&nbsp;")
  (#set! conceal ""))

((entity_reference) @character.special
  (#eq? @character.special "&lt;")
  (#set! conceal "<"))

((entity_reference) @character.special
  (#eq? @character.special "&gt;")
  (#set! conceal ">"))

((entity_reference) @character.special
  (#eq? @character.special "&amp;")
  (#set! conceal "&"))

((entity_reference) @character.special
  (#eq? @character.special "&quot;")
  (#set! conceal "\""))

((entity_reference) @character.special
  (#any-of? @character.special "&ensp;" "&emsp;")
  (#set! conceal " "))
