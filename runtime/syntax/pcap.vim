" Vim syntax file
" Config file:	printcap
" Maintainer:	Lennart Schultz <Lennart.Schultz@ecmwf.int> (defunct)
"		Modified by Bram
" Last Change:	2003 May 11

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

"define keywords
if version < 600
  set isk=@,46-57,_,-,#,=,192-255
else
  setlocal isk=@,46-57,_,-,#,=,192-255
endif

"first all the bad guys
syn match pcapBad '^.\+$'	       "define any line as bad
syn match pcapBadword '\k\+' contained "define any sequence of keywords as bad
syn match pcapBadword ':' contained    "define any single : as bad
syn match pcapBadword '\\' contained   "define any single \ as bad
"then the good boys
" Boolean keywords
syn match pcapKeyword contained ':\(fo\|hl\|ic\|rs\|rw\|sb\|sc\|sf\|sh\)'
" Numeric Keywords
syn match pcapKeyword contained ':\(br\|du\|fc\|fs\|mx\|pc\|pl\|pw\|px\|py\|xc\|xs\)#\d\+'
" String Keywords
syn match pcapKeyword contained ':\(af\|cf\|df\|ff\|gf\|if\|lf\|lo\|lp\|nd\|nf\|of\|rf\|rg\|rm\|rp\|sd\|st\|tf\|tr\|vf\)=\k*'
" allow continuation
syn match pcapEnd ':\\$' contained
"
syn match pcapDefineLast '^\s.\+$' contains=pcapBadword,pcapKeyword
syn match pcapDefine '^\s.\+$' contains=pcapBadword,pcapKeyword,pcapEnd
syn match pcapHeader '^\k[^|]\+\(|\k[^|]\+\)*:\\$'
syn match pcapComment "#.*$"

syn sync minlines=50


" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_pcap_syntax_inits")
  if version < 508
    let did_pcap_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink pcapBad WarningMsg
  HiLink pcapBadword WarningMsg
  HiLink pcapComment Comment

  delcommand HiLink
endif

let b:current_syntax = "pcap"

" vim: ts=8
