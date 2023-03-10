" Vim indent file
" Language:		JSON
" Maintainer:		Eli Parra <eli@elzr.com> https://github.com/elzr/vim-json
" Last Change:          2020 Aug 30
"   https://github.com/jakar/vim-json/commit/20b650e22aa750c4ab6a66aa646bdd95d7cd548a#diff-e81fc111b2052e306d126bd9989f7b7c
"                       2022 Sep 07: b:undo_indent added by Doug Kearns
" Original Author:	Rogerz Zhang <rogerz.zhang at gmail.com> http://github.com/rogerz/vim-json
" Acknowledgement:      Based off of vim-javascript maintained by Darrick Wiebe 
"                       http://www.vim.org/scripts/script.php?script_id=2765

" 0. Initialization {{{1
" =================

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal nosmartindent

" Now, set up our indentation expression and keys that trigger it.
setlocal indentexpr=GetJSONIndent(v:lnum)
setlocal indentkeys=0{,0},0),0[,0],!^F,o,O,e

let b:undo_indent = "setl inde< indk< si<"

" Only define the function once.
if exists("*GetJSONIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" 1. Variables {{{1
" ============

let s:line_term = '\s*\%(\%(\/\/\).*\)\=$'
" Regex that defines blocks.
let s:block_regex = '\%({\)\s*\%(|\%([*@]\=\h\w*,\=\s*\)\%(,\s*[*@]\=\h\w*\)*|\)\=' . s:line_term

" 2. Auxiliary Functions {{{1
" ======================

" Check if the character at lnum:col is inside a string.
function s:IsInString(lnum, col)
  return synIDattr(synID(a:lnum, a:col, 1), 'name') == 'jsonString'
endfunction

" Find line above 'lnum' that isn't empty, or in a string.
function s:PrevNonBlankNonString(lnum)
  let lnum = prevnonblank(a:lnum)
  while lnum > 0
    " If the line isn't empty or in a string, end search.
    let line = getline(lnum)
    if !(s:IsInString(lnum, 1) && s:IsInString(lnum, strlen(line)))
      break
    endif
    let lnum = prevnonblank(lnum - 1)
  endwhile
  return lnum
endfunction

" Check if line 'lnum' has more opening brackets than closing ones.
function s:LineHasOpeningBrackets(lnum)
  let open_0 = 0
  let open_2 = 0
  let open_4 = 0
  let line = getline(a:lnum)
  let pos = match(line, '[][(){}]', 0)
  while pos != -1
    let idx = stridx('(){}[]', line[pos])
    if idx % 2 == 0
      let open_{idx} = open_{idx} + 1
    else
      let open_{idx - 1} = open_{idx - 1} - 1
    endif
    let pos = match(line, '[][(){}]', pos + 1)
  endwhile
  return (open_0 > 0) . (open_2 > 0) . (open_4 > 0)
endfunction

function s:Match(lnum, regex)
  let col = match(getline(a:lnum), a:regex) + 1
  return col > 0 && !s:IsInString(a:lnum, col) ? col : 0
endfunction

" 3. GetJSONIndent Function {{{1
" =========================

function GetJSONIndent(...)
  " 3.1. Setup {{{2
  " ----------
  " For the current line, use the first argument if given, else v:lnum
  let clnum = a:0 ? a:1 : v:lnum

  " Set up variables for restoring position in file.  Could use clnum here.
  let vcol = col('.')

  " 3.2. Work on the current line {{{2
  " -----------------------------

  " Get the current line.
  let line = getline(clnum)
  let ind = -1

  " If we got a closing bracket on an empty line, find its match and indent
  " according to it.
  let col = matchend(line, '^\s*[]}]')

  if col > 0 && !s:IsInString(clnum, col)
    call cursor(clnum, col)
    let bs = strpart('{}[]', stridx('}]', line[col - 1]) * 2, 2)

    let pairstart = escape(bs[0], '[')
    let pairend = escape(bs[1], ']')
    let pairline = searchpair(pairstart, '', pairend, 'bW')

    if pairline > 0 
      let ind = indent(pairline)
    else
      let ind = virtcol('.') - 1
    endif

    return ind
  endif

  " If we are in a multi-line string, don't do anything to it.
  if s:IsInString(clnum, matchend(line, '^\s*') + 1)
    return indent('.')
  endif

  " 3.3. Work on the previous line. {{{2
  " -------------------------------

  let lnum = prevnonblank(clnum - 1)

  if lnum == 0
    return 0
  endif

  " Set up variables for current line.
  let line = getline(lnum)
  let ind = indent(lnum)

  " If the previous line ended with a block opening, add a level of indent.
  " if s:Match(lnum, s:block_regex)
    " return indent(lnum) + shiftwidth()
  " endif

  " If the previous line contained an opening bracket, and we are still in it,
  " add indent depending on the bracket type.
  if line =~ '[[({]'
    let counts = s:LineHasOpeningBrackets(lnum)
    if counts[0] == '1' || counts[1] == '1' || counts[2] == '1'
      return ind + shiftwidth()
    else
      call cursor(clnum, vcol)
    end
  endif

  " }}}2

  return ind
endfunction

" }}}1

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:set sw=2 sts=2 ts=8 noet:
