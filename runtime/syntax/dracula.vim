" Vim syntax file
" Language:	Dracula
" Maintainer:	Scott Bordelon <slb@artisan.com>
" Last change:  Wed Apr 25 18:50:01 PDT 2001
" Extensions:   drac.*,*.drac,*.drc,*.lvs,*.lpe
" Comment:      Dracula is an industry-standard language created by CADENCE (a
"		company specializing in Electronics Design Automation), for
"		the purposes of Design Rule Checking, Layout vs. Schematic
"		verification, and Layout Parameter Extraction.

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Ignore case
syn case ignore

" A bunch of useful Dracula keywords

"syn match   draculaIdentifier

syn keyword draculaStatement   indisk primary outdisk printfile system
syn keyword draculaStatement   mode scale resolution listerror keepdata
syn keyword draculaStatement   datatype by lt gt output label range touch
syn keyword draculaStatement   inside outside within overlap outlib
syn keyword draculaStatement   schematic model unit parset
syn match   draculaStatement   "flag-\(non45\|acuteangle\|offgrid\)"
syn match   draculaStatement   "text-pri-only"
syn match   draculaStatement   "[=&]"
syn match   draculaStatement   "\[[^,]*\]"
syn match   draculastatement   "^ *\(sel\|width\|ext\|enc\|area\|shrink\|grow\|length\)"
syn match   draculastatement   "^ *\(or\|not\|and\|select\|size\|connect\|sconnect\|int\)"
syn match   draculastatement   "^ *\(softchk\|stamp\|element\|parasitic cap\|attribute cap\)"
syn match   draculastatement   "^ *\(flagnon45\|lextract\|equation\|lpeselect\|lpechk\|attach\)"
syn match   draculaStatement   "\(temporary\|connect\)-layer"
syn match   draculaStatement   "program-dir"
syn match   draculaStatement   "status-command"
syn match   draculaStatement   "batch-queue"
syn match   draculaStatement   "cnames-csen"
syn match   draculaStatement   "filter-lay-opt"
syn match   draculaStatement   "filter-sch-opt"
syn match   draculaStatement   "power-node"
syn match   draculaStatement   "ground-node"
syn match   draculaStatement   "subckt-name"

syn match   draculaType		"\*description"
syn match   draculaType		"\*input-layer"
syn match   draculaType		"\*operation"
syn match   draculaType		"\*end"

syn match   draculaComment ";.*"

syn match   draculaPreProc "^#.*"

"Modify the following as needed.  The trade-off is performance versus
"functionality.
syn sync lines=50

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_dracula_syn_inits")
  if version < 508
    let did_dracula_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink draculaIdentifier Identifier
  HiLink draculaStatement  Statement
  HiLink draculaType       Type
  HiLink draculaComment    Comment
  HiLink draculaPreProc    PreProc

  delcommand HiLink
endif

let b:current_syntax = "dracula"

" vim: ts=8
