" Vim indent file
" Language:	J
" Maintainer:	David Bürgin <676c7473@gmail.com>
" URL:		https://github.com/glts/vim-j
" Last Change:	2014-04-05

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetJIndent()
setlocal indentkeys-=0{,0},:,0#
setlocal indentkeys+=0),0<:>,=case.,=catch.,=catchd.,=catcht.,=do.,=else.,=elseif.,=end.,=fcase.

let b:undo_indent = 'setlocal indentkeys< indentexpr<'

if exists('*GetJIndent')
  finish
endif

" If g:j_indent_definitions is true, the bodies of explicit definitions of
" adverbs, conjunctions, and verbs will be indented. Default is false (0).
if !exists('g:j_indent_definitions')
  let g:j_indent_definitions = 0
endif

function GetJIndent() abort
  let prevlnum = prevnonblank(v:lnum-1)
  if prevlnum == 0
    return 0
  endif
  let indent = indent(prevlnum)
  let prevline = getline(prevlnum)
  if prevline =~# '^\s*\%(case\|catch[dt]\=\|do\|else\%(if\)\=\|fcase\|for\%(_\a\k*\)\=\|if\|select\|try\|whil\%(e\|st\)\)\.\%(\%(\<end\.\)\@!.\)*$'
    " Increase indentation after an initial control word that starts or
    " continues a block and is not terminated by "end."
    let indent += shiftwidth()
  elseif g:j_indent_definitions && (prevline =~# '\<\%([1-4]\|13\|adverb\|conjunction\|verb\|monad\|dyad\)\s\+\%(:\s*0\|def\s\+0\|define\)\>' || prevline =~# '^\s*:\s*$')
    " Increase indentation in explicit definitions of adverbs, conjunctions,
    " and verbs
    let indent += shiftwidth()
  endif
  " Decrease indentation in lines that start with either control words that
  " continue or end a block, or the special items ")" and ":"
  if getline(v:lnum) =~# '^\s*\%()\|:\|\%(case\|catch[dt]\=\|do\|else\%(if\)\=\|end\|fcase\)\.\)'
    let indent -= shiftwidth()
  endif
  return indent
endfunction
