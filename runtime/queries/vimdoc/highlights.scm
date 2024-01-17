(h1) @markup.heading.1

(h2) @markup.heading.2

(h3) @markup.heading.3

(column_heading) @markup.heading.4

(column_heading
  "~" @markup.heading.4.marker
  (#set! conceal ""))

(tag
  "*" @markup.heading.5.marker
  (#set! conceal "")
  text: (_) @label)

(taglink
  "|" @markup.link
  (#set! conceal "")
  text: (_) @markup.link)

(optionlink
  text: (_) @markup.link)

(codespan
  "`" @markup.raw.delimiter
  (#set! conceal "")
  text: (_) @markup.raw)

((codeblock) @markup.raw.block
  (#set! "priority" 90))

(codeblock
  [
    ">"
    (language)
  ] @markup.raw.delimiter
  (#set! conceal ""))

(block
  "<" @markup.raw.delimiter
  (#set! conceal ""))

(argument) @variable.parameter

(keycode) @string.special

(url) @string.special.url

((note) @comment.note
  (#any-of? @comment.note "Note:" "NOTE:" "Notes:"))

((note) @comment.warning
  (#any-of? @comment.warning "Warning:" "WARNING:"))

((note) @comment.error
  (#any-of? @comment.error "Deprecated:" "DEPRECATED:"))
