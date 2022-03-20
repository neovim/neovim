" Vim indent file
" Language:     Liquid
" Maintainer:   Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2022 Mar 15

if exists('b:did_indent')
  finish
endif

set indentexpr=
if exists('b:liquid_subtype')
  exe 'runtime! indent/'.b:liquid_subtype.'.vim'
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
let b:liquid_subtype_indentexpr = &l:indentexpr

let b:did_indent = 1

setlocal indentexpr=GetLiquidIndent()
setlocal indentkeys=o,O,*<Return>,<>>,{,},0),0],o,O,!^F,=end,=endif,=endunless,=endifchanged,=endcase,=endfor,=endtablerow,=endcapture,=else,=elsif,=when,=empty

let b:undo_indent = "setl inde< indk<"

" Only define the function once.
if exists('*GetLiquidIndent')
  finish
endif

function! s:count(string, pattern) abort
  let string = substitute(a:string,'\C'.a:pattern,"\n",'g')
  return strlen(substitute(string,"[^\n]",'','g'))
endfunction

function! GetLiquidIndent(...) abort
  if a:0 && a:1 == '.'
    let v:lnum = line('.')
  elseif a:0 && a:1 =~ '^\d'
    let v:lnum = a:1
  endif
  let vcol = col('.')
  call cursor(v:lnum,1)
  exe "let ind = ".b:liquid_subtype_indentexpr
  let lnum = prevnonblank(v:lnum-1)
  let line = getline(lnum)
  let cline = getline(v:lnum)
  let line  = substitute(line,'\C^\%(\s*{%-\=\s*end\w*\s*-\=%}\)\+','','')
  let line  = substitute(line,'\C\%(\s*{%-\=\s*if.\+-\=%}.\+{%-\=\s*endif\s*-\=%}\)\+','','g')
  let line .= matchstr(cline,'\C^\%(\s*{%-\=\s*end\w*\s*-\=%}\)\+')
  let cline = substitute(cline,'\C^\%(\s*{%-\=\s*end\w*\s*-\=%}\)\+','','')
  let sw = shiftwidth()
  let ind += sw * s:count(line,'{%-\=\s*\%(if\|elsif\|else\|unless\|ifchanged\|case\|when\|for\|empty\|tablerow\|capture\)\>')
  let ind -= sw * s:count(line,'{%-\=\s*end\%(if\|unless\|ifchanged\|case\|for\|tablerow\|capture\)\>')
  let ind -= sw * s:count(cline,'{%-\=\s*\%(elsif\|else\|when\|empty\)\>')
  let ind -= sw * s:count(cline,'{%-\=\s*end\w*$')
  return ind
endfunction
