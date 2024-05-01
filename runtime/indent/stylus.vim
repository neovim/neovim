" Vim indent file
" Language: Stylus
" Maintainer: Marc Harter
" Last Change: 2010 May 21
" Based On: sass.vim from Tim Pope
"
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetStylusIndent()
setlocal indentkeys=o,O,*<Return>,},],0),!^F
let b:undo_indent = "setl indentexpr< indentkeys<"

if exists("*GetStylusIndent")  " only define once
  finish
endif

function s:prevnonblanknoncomment(lnum)
  let lnum = a:lnum
  while lnum > 1
    let lnum = prevnonblank(lnum)
    let line = getline(lnum)
    if line =~ '\*/'
      while lnum > 1 && line !~ '/\*'
        let lnum -= 1
      endwhile
      if line =~ '^\s*/\*'
        let lnum -= 1
      else
        break
      endif
    else
      break
    endif
  endwhile
  return lnum
endfunction

function s:count_braces(lnum, count_open)
  let n_open = 0
  let n_close = 0
  let line = getline(a:lnum)
  let pattern = '[{}]'
  let i = match(line, pattern)
  while i != -1
    if synIDattr(synID(a:lnum, i + 1, 0), 'name') !~ 'css\%(Comment\|StringQ\{1,2}\)'
      if line[i] == '{'
        let n_open += 1
      elseif line[i] == '}'
        if n_open > 0
          let n_open -= 1
        else
          let n_close += 1
        endif
      endif
    endif
    let i = match(line, pattern, i + 1)
  endwhile
  return a:count_open ? n_open : n_close
endfunction

" function CheckCSSIndent()
"   let line = getline(v:lnum)
"   if line =~ '^\s*\*'
"     return cindent(v:lnum)
"   endif
" 
"   let pnum = s:prevnonblanknoncomment(v:lnum - 1)
"   if pnum == 0
"     return 0
"   endif

function! GetStylusIndent()
  let line = getline(v:lnum)
  if line =~ '^\s*\*'
    return cindent(v:lnum)
  endif

  let pnum = s:prevnonblanknoncomment(v:lnum - 1)
  if pnum == 0
    return 0
  endif

  let lnum     = prevnonblank(v:lnum-1)
  if lnum == 0
    return 0
  endif

  let pline = getline(pnum)

  if pline =~ '[}{]'
    return indent(pnum) + s:count_braces(pnum, 1) * &sw - s:count_braces(v:lnum, 0) * &sw
  endif

  let line     = substitute(getline(lnum),'[\s()]\+$','','')  " get last line strip ending whitespace
  let cline    = substitute(substitute(getline(v:lnum),'\s\+$','',''),'^\s\+','','')  " get current line, trimmed
  let lastcol  = strlen(line)  " get last col in prev line
  let line     = substitute(line,'^\s\+','','')  " then remove preceeding whitespace
  let indent   = indent(lnum)  " get indent on prev line
  let cindent  = indent(v:lnum)  " get indent on current line
  let increase = indent + &sw  " increase indent by the shift width
  if indent   == indent(lnum)
    let indent = cindent <= indent ? indent : increase
  endif

  let group = synIDattr(synID(lnum,lastcol,1),'name')

  " if group !~? 'css.*' && line =~? ')\s*$' " match user functions
  "   return increase
  if group =~? '\v^%(cssTagName|cssClassName|cssIdentifier|cssSelectorOp|cssSelectorOp2|cssBraces|cssAttributeSelector|cssPseudo|stylusId|stylusClass)$'
    return increase
  elseif (group == 'stylusUserFunction') && (indent(lnum) == '0') " mixin definition
    return increase
  else
    return indent
  endif
endfunction

" vim:set sw=2;
