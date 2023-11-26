" Language:     Dot
" Filenames:    *.dot
" Maintainer:   Markus Mottl  <markus.mottl@gmail.com>
" URL:          http://www.ocaml.info/vim/syntax/dot.vim
" Last Change:  2021 Mar 24 - better attr + escape string matching, new keywords (Farbod Salamat-Zadeh)
"               2011 May 17 - improved identifier matching + two new keywords
"               2001 May 04 - initial version

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:keepcpo = &cpo
set cpo&vim

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

" Escape strings
syn match    dotEscString /\v\\(N|G|E|T|H|L)/ containedin=dotString
syn match    dotEscString /\v\\(n|l|r)/       containedin=dotString

" General keywords
syn keyword  dotKeyword graph digraph subgraph node edge strict

" Node, edge and graph attributes
syn keyword  dotType _background area arrowhead arrowsize arrowtail bb bgcolor
      \ center charset class clusterrank color colorscheme comment compound
      \ concentrate constraint Damping decorate defaultdist dim dimen dir
      \ diredgeconstraints distortion dpi edgehref edgetarget edgetooltip
      \ edgeURL epsilon esep fillcolor fixedsize fontcolor fontname fontnames
      \ fontpath fontsize forcelabels gradientangle group head_lp headclip
      \ headhref headlabel headport headtarget headtooltip headURL height href
      \ id image imagepath imagepos imagescale inputscale K label label_scheme
      \ labelangle labeldistance labelfloat labelfontcolor labelfontname
      \ labelfontsize labelhref labeljust labelloc labeltarget labeltooltip
      \ labelURL landscape layer layerlistsep layers layerselect layersep 
      \ layout len levels levelsgap lhead lheight lp ltail lwidth margin
      \ maxiter mclimit mindist minlen mode model mosek newrank nodesep 
      \ nojustify normalize notranslate nslimit nslimit1 ordering orientation
      \ outputorder overlap overlap_scaling overlap_shrink pack packmode pad
      \ page pagedir pencolor penwidth peripheries pin pos quadtree quantum
      \ rank rankdir ranksep ratio rects regular remincross repulsiveforce
      \ resolution root rotate rotation samehead sametail samplepoints scale
      \ searchsize sep shape shapefile showboxes sides size skew smoothing
      \ sortv splines start style stylesheet tail_lp tailclip tailhref 
      \ taillabel tailport tailtarget tailtooltip tailURL target tooltip
      \ truecolor URL vertices viewport voro_margin weight width xdotversion 
      \ xlabel xlp z

" Special chars
syn match    dotKeyChar  "="
syn match    dotKeyChar  ";"
syn match    dotKeyChar  "->"
syn match    dotKeyChar  "--"

" Identifier
syn match    dotIdentifier /\<\w\+\(:\w\+\)\?\>/

" Synchronization
syn sync minlines=50
syn sync maxlines=500

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_dot_syntax_inits")
  if version < 508
    let did_dot_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

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
  HiLink dotEscString	 Keyword
  HiLink dotIdentifier	 Identifier

  delcommand HiLink
endif

let b:current_syntax = "dot"

let &cpo = s:keepcpo
unlet s:keepcpo

" vim: ts=8
