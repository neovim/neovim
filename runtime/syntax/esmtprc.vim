" Vim syntax file
" Language:	Esmtp setup file (based on esmtp 0.5.0)
" Maintainer:	Kornel Kielczewski <kornel@gazeta.pl>
" Last Change:	16 Feb 2005

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

"All options
syntax keyword	esmtprcOptions hostname username password starttls certificate_passphrase preconnect identity mda

"All keywords
syntax keyword esmtprcIdentifier default enabled disabled required

"We're trying to be smarer than /."*@.*/ :)
syntax match esmtprcAddress /[a-z0-9_.-]*[a-z0-9]\+@[a-z0-9_.-]*[a-z0-9]\+\.[a-z]\+/
syntax match esmtprcFulladd /[a-z0-9_.-]*[a-z0-9]\+\.[a-z]\+:[0-9]\+/
 
"String..
syntax region esmtprcString start=/"/ end=/"/


highlight link esmtprcOptions		Label
highlight link esmtprcString 		String
highlight link esmtprcAddress		Type
highlight link esmtprcIdentifier 	Identifier
highlight link esmtprcFulladd		Include

let b:current_syntax = "esmtprc"
