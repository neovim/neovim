" Vim syntax file
" Language:     Dot
" Filenames:    *.dot
" Maintainer:   Markus Mottl  <markus.mottl@gmail.com>
" URL:          http://www.ocaml.info/vim/syntax/dot.vim
" Last Change:  2011 May 17 - improved identifier matching + two new keywords
"               2001 May 04 - initial version

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Errors
syn match    dotParErr     ")"
syn match    dotBrackErr   "]"
syn match    dotBraceErr   "}"

" Enclosing delimiters
syn region   dotEncl transparent matchgroup=dotParEncl start="(" matchgroup=dotParEncl end=")" contains=ALLBUT,dotParErr
syn region   dotEncl transparent matchgroup=dotBrackEncl start="\[" matchgroup=dotBrackEncl end="\]" contains=ALLBUT,dotBrackErr
syn region   dotEncl transparent matchgroup=dotBraceEncl start="{" matchgroup=dotBraceEncl end="}" contains=ALLBUT,dotBraceErr

" Comments
syn region   dotComment start="//" end="$" contains=dotComment,dotTodo
syn region   dotComment start="/\*" end="\*/" contains=dotComment,dotTodo
syn keyword  dotTodo contained TODO FIXME XXX

" Strings
syn region   dotString    start=+"+ skip=+\\\\\|\\"+ end=+"+

" General keywords
syn keyword  dotKeyword  digraph node edge subgraph

" Graph attributes
syn keyword  dotType center layers margin mclimit name nodesep nslimit
syn keyword  dotType ordering page pagedir rank rankdir ranksep ratio
syn keyword  dotType rotate size

" Node attributes
syn keyword  dotType distortion fillcolor fontcolor fontname fontsize
syn keyword  dotType height layer orientation peripheries regular
syn keyword  dotType shape shapefile sides skew width

" Edge attributes
syn keyword  dotType arrowhead arrowsize arrowtail constraint decorateP
syn keyword  dotType dir headclip headlabel headport labelangle labeldistance
syn keyword  dotType labelfontcolor labelfontname labelfontsize
syn keyword  dotType minlen port_label_distance samehead sametail
syn keyword  dotType tailclip taillabel tailport weight

" Shared attributes (graphs, nodes, edges)
syn keyword  dotType color

" Shared attributes (graphs and edges)
syn keyword  dotType bgcolor label URL

" Shared attributes (nodes and edges)
syn keyword  dotType fontcolor fontname fontsize layer style

" Special chars
syn match    dotKeyChar  "="
syn match    dotKeyChar  ";"
syn match    dotKeyChar  "->"

" Identifier
syn match    dotIdentifier /\<\w\+\(:\w\+\)\?\>/

" Synchronization
syn sync minlines=50
syn sync maxlines=500

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
command -nargs=+ HiLink hi def link <args>

HiLink dotParErr	 Error
HiLink dotBraceErr	 Error
HiLink dotBrackErr	 Error

HiLink dotComment	 Comment
HiLink dotTodo	 Todo

HiLink dotParEncl	 Keyword
HiLink dotBrackEncl	 Keyword
HiLink dotBraceEncl	 Keyword

HiLink dotKeyword	 Keyword
HiLink dotType	 Type
HiLink dotKeyChar	 Keyword

HiLink dotString	 String
HiLink dotIdentifier	 Identifier

delcommand HiLink

let b:current_syntax = "dot"

" vim: ts=8
