" Vim indent file
" Language:	Vim script
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2021 Apr 18

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetVimIndent()
setlocal indentkeys+==end,=},=else,=cat,=finall,=END,0\\,0=\"\\\ 
setlocal indentkeys-=0#

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

let s:lineContPat = '^\s*\(\\\|"\\ \)'

function GetVimIndentIntern()
  " Find a non-blank line above the current line.
  let lnum = prevnonblank(v:lnum - 1)

  " The previous line, ignoring line continuation
  let prev_text_end = lnum > 0 ? getline(lnum) : ''

  " If the current line doesn't start with '\' or '"\ ' and below a line that
  " starts with '\' or '"\ ', use the indent of the line above it.
  let cur_text = getline(v:lnum)
  if cur_text !~ s:lineContPat
    while lnum > 0 && getline(lnum) =~ s:lineContPat
      let lnum = lnum - 1
    endwhile
  endif

  " At the start of the file use zero indent.
  if lnum == 0
    return 0
  endif

  " the start of the previous line, skipping over line continuation
  let prev_text = getline(lnum)
  let found_cont = 0

  " Add a 'shiftwidth' after :if, :while, :try, :catch, :finally, :function
  " and :else.  Add it three times for a line that starts with '\' or '"\ '
  " after a line that doesn't (or g:vim_indent_cont if it exists).
  let ind = indent(lnum)

  " In heredoc indenting works completely differently.
  if has('syntax_items') 
    let syn_here = synIDattr(synID(v:lnum, 1, 1), "name")
    if syn_here =~ 'vimLetHereDocStop'
      " End of heredoc: use indent of matching start line
      let lnum = v:lnum - 1
      while lnum > 0
	let attr = synIDattr(synID(lnum, 1, 1), "name")
	if attr != '' && attr !~ 'vimLetHereDoc'
	  return indent(lnum)
	endif
	let lnum -= 1
      endwhile
      return 0
    endif
    if syn_here =~ 'vimLetHereDoc'
      if synIDattr(synID(lnum, 1, 1), "name") !~ 'vimLetHereDoc'
	" First line in heredoc: increase indent
	return ind + shiftwidth()
      endif
      " Heredoc continues: no change in indent
      return ind
    endif
  endif

  if cur_text =~ s:lineContPat && v:lnum > 1 && prev_text !~ s:lineContPat
    let found_cont = 1
    if exists("g:vim_indent_cont")
      let ind = ind + g:vim_indent_cont
    else
      let ind = ind + shiftwidth() * 3
    endif
  elseif prev_text =~ '^\s*aug\%[roup]\s\+' && prev_text !~ '^\s*aug\%[roup]\s\+[eE][nN][dD]\>'
    let ind = ind + shiftwidth()
  else
    " A line starting with :au does not increment/decrement indent.
    " A { may start a block or a dict.  Assume that when a } follows it's a
    " terminated dict.
    if prev_text !~ '^\s*au\%[tocmd]' && prev_text !~ '^\s*{.*}'
      let i = match(prev_text, '\(^\||\)\s*\(export\s\+\)\?\({\|\(if\|wh\%[ile]\|for\|try\|cat\%[ch]\|fina\|finall\%[y]\|fu\%[nction]\|def\|el\%[seif]\)\>\)')
      if i >= 0
	let ind += shiftwidth()
	if strpart(prev_text, i, 1) == '|' && has('syntax_items')
	      \ && synIDattr(synID(lnum, i, 1), "name") =~ '\(Comment\|String\)$'
	  let ind -= shiftwidth()
	endif
      endif
    endif
  endif

  " If the previous line contains an "end" after a pipe, but not in an ":au"
  " command.  And not when there is a backslash before the pipe.
  " And when syntax HL is enabled avoid a match inside a string.
  let i = match(prev_text, '[^\\]|\s*\(ene\@!\)')
  if i > 0 && prev_text !~ '^\s*au\%[tocmd]'
    if !has('syntax_items') || synIDattr(synID(lnum, i + 2, 1), "name") !~ '\(Comment\|String\)$'
      let ind = ind - shiftwidth()
    endif
  endif

  " For a line starting with "}" find the matching "{".  If it is at the start
  " of the line align with it, probably end of a block.
  " Use the mapped "%" from matchit to find the match, otherwise we may match
  " a { inside a comment or string.
  if cur_text =~ '^\s*}'
    if maparg('%') != ''
      exe v:lnum
      silent! normal %
      if line('.') < v:lnum && getline('.') =~ '^\s*{'
	let ind = indent('.')
      endif
    else
      " todo: use searchpair() to find a match
    endif
  endif

  " Below a line starting with "}" find the matching "{".  If it is at the
  " end of the line we must be below the end of a dictionary.
  if prev_text =~ '^\s*}'
    if maparg('%') != ''
      exe lnum
      silent! normal %
      if line('.') == lnum || getline('.') !~ '^\s*{'
	let ind = ind - shiftwidth()
      endif
    else
      " todo: use searchpair() to find a match
    endif
  endif

  " Below a line starting with "]" we must be below the end of a list.
  " Include a "}" and "},} in case a dictionary ends too.
  if prev_text_end =~ '^\s*\(},\=\s*\)\=]'
    let ind = ind - shiftwidth()
  endif

  let ends_in_comment = has('syntax_items')
	\ && synIDattr(synID(lnum, len(getline(lnum)), 1), "name") =~ '\(Comment\|String\)$'

  " A line ending in "{" or "[" is most likely the start of a dict/list literal,
  " indent the next line more.  Not for a continuation line or {{{.
  if !ends_in_comment && prev_text_end =~ '\s[{[]\s*$' && !found_cont
    let ind = ind + shiftwidth()
  endif

  " Subtract a 'shiftwidth' on a :endif, :endwhile, :catch, :finally, :endtry,
  " :endfun, :else and :augroup END.
  if cur_text =~ '^\s*\(ene\@!\|cat\|finall\|el\|aug\%[roup]\s\+[eE][nN][dD]\)'
    let ind = ind - shiftwidth()
  endif

  return ind
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:sw=2
