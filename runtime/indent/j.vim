" Vim indent file
" Language:	J
" Maintainer:	David Bürgin <676c7473@gmail.com>
" URL:		https://github.com/glts/vim-j
" Last Change:	2015-01-11

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
  let l:prevlnum = prevnonblank(v:lnum - 1)
  if l:prevlnum == 0
    return 0
  endif
  let l:indent = indent(l:prevlnum)
  let l:prevline = getline(l:prevlnum)
  if l:prevline =~# '^\s*\%(case\|catch[dt]\=\|do\|else\%(if\)\=\|fcase\|for\%(_\a\k*\)\=\|if\|select\|try\|whil\%(e\|st\)\)\.\%(\%(\<end\.\)\@!.\)*$'
    " Increase indentation after an initial control word that starts or
    " continues a block and is not terminated by "end."
    let l:indent += shiftwidth()
  elseif g:j_indent_definitions && (l:prevline =~# '\<\%([1-4]\|13\|adverb\|conjunction\|verb\|monad\|dyad\)\s\+\%(:\s*0\|def\s\+0\|define\)\>' || l:prevline =~# '^\s*:\s*$')
    " Increase indentation in explicit definitions of adverbs, conjunctions,
    " and verbs
    let l:indent += shiftwidth()
  endif
  " Decrease indentation in lines that start with either control words that
  " continue or end a block, or the special items ")" and ":"
  if getline(v:lnum) =~# '^\s*\%()\|:\|\%(case\|catch[dt]\=\|do\|else\%(if\)\=\|end\|fcase\)\.\)'
    let l:indent -= shiftwidth()
  endif
  return l:indent
endfunction
