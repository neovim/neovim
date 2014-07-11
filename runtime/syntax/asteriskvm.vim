" Vim syntax file
" Language:	Asterisk voicemail config file
" Maintainer: Tilghman Lesher (Corydon76)
" Last Change:	2006 Mar 21
" version 0.2
"
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn sync clear
syn sync fromstart


syn keyword     asteriskvmTodo    TODO contained
syn match       asteriskvmComment         ";.*" contains=asteriskvmTodo
syn match       asteriskvmContext         "\[.\{-}\]"

" ZoneMessages
syn match       asteriskvmZone            "^[[:alnum:]]\+\s*=>\?\s*[[:alnum:]/_]\+|.*$" contains=zoneName,zoneDef
syn match       zoneName                "=\zs[[:alnum:]/_]\+\ze" contained
syn match       zoneDef                 "|\zs.*\ze$" contained

syn match       asteriskvmSetting         "\<\(format\|serveremail\|minmessage\|maxmessage\|maxgreet\|skipms\|maxsilence\|silencethreshold\|maxlogins\)="
syn match       asteriskvmSetting         "\<\(externnotify\|externpass\|directoryintro\|charset\|adsi\(fdn\|sec\|ver\)\|\(pager\)\?fromstring\|email\(subject\|body\|cmd\)\|tz\|cidinternalcontexts\|saydurationm\|dialout\|callback\)="
syn match       asteriskvmSettingBool     "\<\(attach\|pbxskip\|usedirectory\|saycid\|sayduration\|sendvoicemail\|review\|operator\|envelope\|delete\|nextaftercmd\|forcename\|forcegreeting\)=\(yes\|no\|1\|0\|true\|false\|t\|f\)"

" Individual mailbox definitions
syn match       asteriskvmMailbox         "^[[:digit:]]\+\s*=>\?\s*[[:digit:]]\+\(,[^,]*\(,[^,]*\(,[^,]*\(,[^,]*\)\?\)\?\)\?\)\?" contains=mailboxEmail,asteriskvmSetting,asteriskvmSettingBool,comma
syn match       mailboxEmail            ",\zs[^@=,]*@[[:alnum:]\-\.]\+\.[[:alpha:]]\{2,10}\ze" contains=comma
syn match       comma                   "[,|]" contained

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
:if version >= 508 || !exists("did_conf_syntax_inits")
  if version < 508
    let did_conf_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink        asteriskvmComment Comment
  HiLink        asteriskvmContext         Identifier
  HiLink        asteriskvmZone            Type
  HiLink        zoneName                String
  HiLink        zoneDef                 String
  HiLink        asteriskvmSetting         Type
  HiLink        asteriskvmSettingBool     Type

  HiLink        asteriskvmMailbox         Statement
  HiLink        mailboxEmail            String
 delcommand HiLink
endif

let b:current_syntax = "asteriskvm"

" vim: ts=8 sw=2

