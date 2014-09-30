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

function! GetErubyIndent(...)
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
  endif
  let lnum = prevnonblank(v:lnum-1)
  let line = getline(lnum)
  let cline = getline(v:lnum)
  if cline =~# '^\s*<%[-=]\=\s*\%(}\|end\|else\|\%(ensure\|rescue\|elsif\|when\).\{-\}\)\s*\%([-=]\=%>\|$\)'
    let ind = ind - &sw
  endif
  if line =~# '\S\s*<%[-=]\=\s*\%(}\|end\).\{-\}\s*\%([-=]\=%>\|$\)'
    let ind = ind - &sw
  endif
  if line =~# '\%({\|\<do\)\%(\s*|[^|]*|\)\=\s*[-=]\=%>'
    let ind = ind + &sw
  elseif line =~# '<%[-=]\=\s*\%(module\|class\|def\|if\|for\|while\|until\|else\|elsif\|case\|when\|unless\|begin\|ensure\|rescue\)\>.*%>'
    let ind = ind + &sw
  endif
  if line =~# '^\s*<%[=#-]\=\s*$' && cline !~# '^\s*end\>'
    let ind = ind + &sw
  endif
  if line !~# '^\s*<%' && line =~# '%>\s*$'
    let ind = ind - &sw
  endif
  if cline =~# '^\s*[-=]\=%>\s*$'
    let ind = ind - &sw
  endif
  return ind
endfunction

" vim:set sw=2 sts=2 ts=8 noet:
