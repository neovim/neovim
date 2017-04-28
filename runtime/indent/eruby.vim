" Vim indent file
" Language:		eRuby
" Maintainer:		Tim Pope <vimNOSPAM@tpope.org>
" URL:			https://github.com/vim-ruby/vim-ruby
" Release Coordinator:	Doug Kearns <dougkearns@gmail.com>

if exists("b:did_indent")
  finish
endif

runtime! indent/ruby.vim
unlet! b:did_indent
setlocal indentexpr=

if exists("b:eruby_subtype")
  exe "runtime! indent/".b:eruby_subtype.".vim"
else
  runtime! indent/html.vim
endif
unlet! b:did_indent

" Force HTML indent to not keep state.
let b:html_indent_usestate = 0

if &l:indentexpr == ''
  if &l:cindent
    let &l:indentexpr = 'cindent(v:lnum)'
  else
    let &l:indentexpr = 'indent(prevnonblank(v:lnum-1))'
  endif
endif
let b:eruby_subtype_indentexpr = &l:indentexpr

let b:did_indent = 1

setlocal indentexpr=GetErubyIndent()
setlocal indentkeys=o,O,*<Return>,<>>,{,},0),0],o,O,!^F,=end,=else,=elsif,=rescue,=ensure,=when

" Only define the function once.
if exists("*GetErubyIndent")
  finish
endif

" this file uses line continuations
let s:cpo_sav = &cpo
set cpo&vim

function! GetErubyIndent(...)
  " The value of a single shift-width
  if exists('*shiftwidth')
    let sw = shiftwidth()
  else
    let sw = &sw
  endif

  if a:0 && a:1 == '.'
    let v:lnum = line('.')
  elseif a:0 && a:1 =~ '^\d'
    let v:lnum = a:1
  endif
  let vcol = col('.')
  call cursor(v:lnum,1)
  let inruby = searchpair('<%','','%>','W')
  call cursor(v:lnum,vcol)
  if inruby && getline(v:lnum) !~ '^<%\|^\s*[-=]\=%>'
    let ind = GetRubyIndent(v:lnum)
  else
    exe "let ind = ".b:eruby_subtype_indentexpr

    " Workaround for Andy Wokula's HTML indent. This should be removed after
    " some time, since the newest version is fixed in a different way.
    if b:eruby_subtype_indentexpr =~# '^HtmlIndent('
	  \ && exists('b:indent')
	  \ && type(b:indent) == type({})
	  \ && has_key(b:indent, 'lnum')
      " Force HTML indent to not keep state
      let b:indent.lnum = -1
    endif
  endif
  let lnum = prevnonblank(v:lnum-1)
  let line = getline(lnum)
  let cline = getline(v:lnum)
  if cline =~# '^\s*<%[-=]\=\s*\%(}\|end\|else\|\%(ensure\|rescue\|elsif\|when\).\{-\}\)\s*\%([-=]\=%>\|$\)'
    let ind = ind - sw
  endif
  if line =~# '\S\s*<%[-=]\=\s*\%(}\|end\).\{-\}\s*\%([-=]\=%>\|$\)'
    let ind = ind - sw
  endif
  if line =~# '\%({\|\<do\)\%(\s*|[^|]*|\)\=\s*[-=]\=%>'
    let ind = ind + sw
  elseif line =~# '<%[-=]\=\s*\%(module\|class\|def\|if\|for\|while\|until\|else\|elsif\|case\|when\|unless\|begin\|ensure\|rescue\)\>.*%>'
    let ind = ind + sw
  endif
  if line =~# '^\s*<%[=#-]\=\s*$' && cline !~# '^\s*end\>'
    let ind = ind + sw
  endif
  if line !~# '^\s*<%' && line =~# '%>\s*$' && line !~# '^\s*end\>'
    let ind = ind - sw
  endif
  if cline =~# '^\s*[-=]\=%>\s*$'
    let ind = ind - sw
  endif
  return ind
endfunction

let &cpo = s:cpo_sav
unlet! s:cpo_sav

" vim:set sw=2 sts=2 ts=8 noet:
