" Vim syntax file
" Language:	Asterisk config file
" Maintainer: 	Jean Aunis <jean.aunis@yahoo.fr>
" Previous Maintainer:	brc007
" Updated for 1.2 by Tilghman Lesher (Corydon76)
" Last Change:	2015 Feb 27
" version 0.4

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn sync clear
syn sync fromstart

syn keyword     asteriskTodo    TODO contained
syn match       asteriskComment         ";.*" contains=asteriskTodo
syn match       asteriskContext         "\[.\{-}\]"
syn match       asteriskExten           "^\s*\zsexten\s*=>\?\s*[^,]\+\ze," contains=asteriskPattern nextgroup=asteriskPriority
syn match       asteriskExten           "^\s*\zssame\s*=>\?\s*\ze" nextgroup=asteriskPriority
syn match       asteriskExten           "^\s*\(register\|channel\|ignorepat\|include\|l\?e\?switch\|\(no\)\?load\)\s*=>\?"
syn match       asteriskPattern         "_\(\[[[:alnum:]#*\-]\+\]\|[[:alnum:]#*]\)*\.\?" contained
syn match       asteriskPattern         "[^A-Za-z0-9,]\zs[[:alnum:]#*]\+\ze" contained
syn match       asteriskApp             ",\zs[a-zA-Z]\+\ze$"
syn match       asteriskApp             ",\zs[a-zA-Z]\+\ze("
" Digits plus oldlabel (newlabel)
syn match       asteriskPriority        "\zs[[:digit:]]\+\(+[[:alpha:]][[:alnum:]_]*\)\?\(([[:alpha:]][[:alnum:]_]*)\)\?\ze," contains=asteriskLabel
" oldlabel plus digits (newlabel)
syn match       asteriskPriority        "\zs[[:alpha:]][[:alnum:]_]*+[[:digit:]]\+\(([[:alpha:]][[:alnum:]_]*)\)\?\ze," contains=asteriskLabel
" s or n plus digits (newlabel)
syn match       asteriskPriority        "\zs[sn]\(+[[:digit:]]\+\)\?\(([[:alpha:]][[:alnum:]_]*)\)\?\ze," contains=asteriskLabel
syn match       asteriskLabel           "(\zs[[:alpha:]][[:alnum:]]*\ze)" contained
syn match       asteriskError           "^\s*#\s*[[:alnum:]]*"
syn match       asteriskInclude         "^\s*#\s*\(include\|exec\)\s.*"
syn match       asteriskVar             "\${_\{0,2}[[:alpha:]][[:alnum:]_]*\(:-\?[[:digit:]]\+\(:[[:digit:]]\+\)\?\)\?}"
syn match       asteriskVar             "_\{0,2}[[:alpha:]][[:alnum:]_]*\ze="
syn match       asteriskVarLen          "\${_\{0,2}[[:alpha:]][[:alnum:]_]*(.*)}" contains=asteriskVar,asteriskVarLen,asteriskExp
syn match       asteriskVarLen          "(\zs[[:alpha:]][[:alnum:]_]*(.\{-})\ze=" contains=asteriskVar,asteriskVarLen,asteriskExp
syn match       asteriskExp             "\$\[.\{-}\]" contains=asteriskVar,asteriskVarLen,asteriskExp
syn match       asteriskCodecsPermit    "^\s*\(allow\|disallow\)\s*=\s*.*$" contains=asteriskCodecs
syn match       asteriskCodecs          "\(vp9\|vp8\|h264\|h263p\|h263\|h261\|jpeg\|opus\|g722\|g723\|gsm\|ulaw\|alaw\|g719\|g726\|g726aal2\|siren7\|siren14\|adpcm\|slin\|lpc10\|g729\|speex\|ilbc\|wav\|all\s*$\)"
syn match       asteriskError           "^\(type\|auth\|permit\|deny\|bindaddr\|host\)\s*=.*$"
syn match       asteriskType            "^\zstype=\ze\<\(peer\|user\|friend\)\>$" contains=asteriskTypeType
syn match       asteriskTypeType        "\<\(peer\|user\|friend\)\>" contained
syn match       asteriskAuth            "^\zsauth\s*=\ze\s*\<\(md5\|rsa\|plaintext\)\>$" contains=asteriskAuthType
syn match       asteriskAuthType        "\<\(md5\|rsa\|plaintext\)\>"
syn match       asteriskAuth            "^\zs\(secret\|inkeys\|outkey\)\s*=\ze.*$"
syn match       asteriskAuth            "^\(permit\|deny\)\s*=\s*\d\{1,3}\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}/\d\{1,3}\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}\s*$" contains=asteriskIPRange
syn match       asteriskIPRange         "\d\{1,3}\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}/\d\{1,3}\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}" contained
syn match       asteriskIP              "\d\{1,3}\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}" contained
syn match       asteriskHostname        "[[:alnum:]][[:alnum:]\-\.]*\.[[:alpha:]]{2,10}" contained
syn match       asteriskPort            "\d\{1,5}" contained
syn match       asteriskSetting         "^bindaddr\s*=\s*\d\{1,3}\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}$" contains=asteriskIP
syn match       asteriskSetting         "^port\s*=\s*\d\{1,5}\s*$" contains=asteriskPort
syn match       asteriskSetting         "^host\s*=\s*\(dynamic\|\(\d\{1,3}\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}\)\|\([[:alnum:]][[:alnum:]\-\.]*\.[[:alpha:]]{2,10}\)\)" contains=asteriskIP,asteriskHostname

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link        asteriskComment		Comment
hi def link        asteriskExten		String
hi def link        asteriskContext         Preproc
hi def link        asteriskPattern         Type
hi def link        asteriskApp             Statement
hi def link        asteriskInclude         Preproc
hi def link        asteriskIncludeBad	Error
hi def link        asteriskPriority        Preproc
hi def link        asteriskLabel           Type
hi def link        asteriskVar             String
hi def link        asteriskVarLen          Function
hi def link        asteriskExp             Type
hi def link        asteriskCodecsPermit    Preproc
hi def link        asteriskCodecs          String
hi def link        asteriskType            Statement
hi def link        asteriskTypeType        Type
hi def link        asteriskAuth            String
hi def link        asteriskAuthType        Type
hi def link        asteriskIPRange         Identifier
hi def link        asteriskIP              Identifier
hi def link        asteriskPort            Identifier
hi def link        asteriskHostname        Identifier
hi def link        asteriskSetting         Statement
hi def link        asteriskError           Error

let b:current_syntax = "asterisk" 
" vim: ts=8 sw=2

