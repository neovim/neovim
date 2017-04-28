" Vim syntax file
" Config file:	printcap
" Maintainer:	Lennart Schultz <Lennart.Schultz@ecmwf.int> (defunct)
"		Modified by Bram
" Last Change:	2003 May 11

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

"define keywords
setlocal isk=@,46-57,_,-,#,=,192-255

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
" Only when an item doesn't have highlighting yet

hi def link pcapBad WarningMsg
hi def link pcapBadword WarningMsg
hi def link pcapComment Comment


let b:current_syntax = "pcap"

" vim: ts=8
