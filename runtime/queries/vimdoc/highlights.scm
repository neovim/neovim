(h1) @markup.heading.1

(h2) @markup.heading.2

(h3) @markup.heading.3

(column_heading) @markup.heading.4

(column_heading
  "~" @markup.heading.4
  (#set! conceal ""))

(tag
  "*" @label
  (#set! conceal ""))

(tag
  text: (_) @label)

(taglink
  "|" @markup.link
  (#set! conceal ""))

(taglink
  text: (_) @markup.link)

(optionlink
  text: (_) @markup.link)

(codespan
  "`" @markup.raw
  (#set! conceal ""))

(codespan
  text: (_) @markup.raw)

((codeblock) @markup.raw.block
  (#set! "priority" 90))

(codeblock
  ">" @markup.raw
  (#set! conceal ""))

(codeblock
  (language) @label
  (#set! conceal ""))

(block
  "<" @markup.raw
  (#set! conceal ""))

(argument) @variable.parameter

(keycode) @string.special

(url) @string.special.url

(modeline) @keyword.directive

((note) @comment.note
  (#any-of? @comment.note "Note:" "NOTE:" "Notes:"))

((note) @comment.warning
  (#any-of? @comment.warning "Warning:" "WARNING:"))

((note) @comment.error
  (#any-of? @comment.error "Deprecated:" "DEPRECATED:"))
