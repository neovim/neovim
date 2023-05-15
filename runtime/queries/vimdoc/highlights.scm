(h1) @text.title.1
(h2) @text.title.2
(h3) @text.title.3
(column_heading) @text.title.4
(column_heading
   "~" @conceal (#set! conceal ""))
(tag
   "*" @conceal (#set! conceal "")
   text: (_) @label)
(taglink
   "|" @conceal (#set! conceal "")
   text: (_) @text.reference)
(optionlink
   text: (_) @text.reference)
(codespan
   "`" @conceal (#set! conceal "")
   text: (_) @text.literal)
(codeblock) @text.literal
(codeblock
   [">" (language)] @conceal (#set! conceal ""))
(block
   "<" @conceal (#set! conceal ""))
(argument) @parameter
(keycode) @string.special
(url) @text.uri
