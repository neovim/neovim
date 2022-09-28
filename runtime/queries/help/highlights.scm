(h1) @text.title
(h2) @text.title
(h3) @text.title
(column_heading) @text.title
(tag
   "*" @conceal (#set! conceal "")
   text: (_) @label)
(taglink
   "|" @conceal (#set! conceal "")
   text: (_) @text.reference)
(optionlink
   text: (_) @text.literal)
(codespan
   "`" @conceal (#set! conceal "")
   text: (_) @string)
(argument) @parameter
