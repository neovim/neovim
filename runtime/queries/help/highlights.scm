(headline) @text.title
(column_heading) @text.title
(tag
   "*" @conceal (#set! conceal "")
   name: (_) @label)
(option
   name: (_) @text.literal)
(hotlink
   "|" @conceal (#set! conceal "")
   destination: (_) @text.reference)
(backtick
   "`" @conceal (#set! conceal "")
   content: (_) @string)
(argument) @parameter
