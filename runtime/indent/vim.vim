" Vim indent file
" Language:	Vim script
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2012 Aug 02

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetVimIndent()
setlocal indentkeys+==end,=else,=cat,=fina,=END,0\\

let b:undo_indent = "setl indentkeys< indentexpr<"

" Only define the function once.
if exists("*GetVimIndent")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

function GetVimIndent()
  let ignorecase_save = &ignorecase
  try
    let &ignorecase = 0
    return GetVimIndentIntern()
  finally
    let &ignorecase = ignorecase_save
  endtry
endfunc

function GetVimIndentIntern()
  " Find a non-blank line above the current line.
  let lnum = prevnonblank(v:lnum - 1)

  " If the current line doesn't start with '\' and below a line that starts
  " with '\', use the indent of the line above it.
  if getline(v:lnum) !~ '^\s*\\'
    while lnum > 0 && getline(lnum) =~ '^\s*\\'
      let lnum = lnum - 1
    endwhile
  endif

  " At the start of the file use zero indent.
  if lnum == 0
    return 0
  endif

  " Add a 'shiftwidth' after :if, :while, :try, :catch, :finally, :function
  " and :else.  Add it three times for a line that starts with '\' after
  " a line that doesn't (or g:vim_indent_cont if it exists).
  let ind = indent(lnum)
  if getline(v:lnum) =~ '^\s*\\' && v:lnum > 1 && getline(lnum) !~ '^\s*\\'
    if exists("g:vim_indent_cont")
      let ind = ind + g:vim_indent_cont
    else
      let ind = ind + &sw * 3
    endif
  elseif getline(lnum) =~ '^\s*aug\%[roup]' && getline(lnum) !~ '^\s*aug\%[roup]\s*!\=\s\+END'
    let ind = ind + &sw
  else
    let line = getline(lnum)
    let i = match(line, '\(^\||\)\s*\(if\|wh\%[ile]\|for\|try\|cat\%[ch]\|fina\%[lly]\|fu\%[nction]\|el\%[seif]\)\>')
    if i >= 0
      let ind += &sw
      if strpart(line, i, 1) == '|' && has('syntax_items')
            \ && synIDattr(synID(lnum, i, 1), "name") =~ '\(Comment\|String\)$'
        let ind -= &sw
      endif
    endif
  endif

  " If the previous line contains an "end" after a pipe, but not in an ":au"
  " command.  And not when there is a backslash before the pipe.
  " And when syntax HL is enabled avoid a match inside a string.
  let line = getline(lnum)
  let i = match(line, '[^\\]|\s*\(ene\@!\)')
  if i > 0 && line !~ '^\s*au\%[tocmd]'
    if !has('syntax_items') || synIDattr(synID(lnum, i + 2, 1), "name") !~ '\(Comment\|String\)$'
      let ind = ind - &sw
    endif
  endif


  " Subtract a 'shiftwidth' on a :endif, :endwhile, :catch, :finally, :endtry,
  " :endfun, :else and :augroup END.
  if getline(v:lnum) =~ '^\s*\(ene\@!\|cat\|fina\|el\|aug\%[roup]\s*!\=\s\+END\)'
    let ind = ind - &sw
  endif

  return ind
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:sw=2
