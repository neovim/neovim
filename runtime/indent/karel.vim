" Vim indent file
" Language: Fanuc Karel
" Maintainer: Patrick Meiser-Knosowski <knosowski@graeffrobotics.de>
" Version: 1.0.0
" Last Change: 28. May 2026

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal nolisp
setlocal nocindent
setlocal nosmartindent
setlocal autoindent
setlocal indentexpr=GetKarelIndent()
setlocal indentkeys=!^F,o,O,=~end,0=~else,0=~case,0=~until,0=~const,0=~type,0=~var,0=~begin
let b:undo_indent = "setlocal lisp< cindent< smartindent< autoindent< indentexpr< indentkeys<"

if get(g:,'karelSpaceIndent',1)
  " Use spaces, not tabs, for indention, 2 is enough. 
  " More or even tabs would waste valuable space on the teach pendant.
  setlocal softtabstop=2
  setlocal shiftwidth=2
  setlocal expandtab
  setlocal shiftround
  let b:undo_indent = b:undo_indent." softtabstop< shiftwidth< expandtab< shiftround<"
endif

" Only define the function once.
if exists("*GetKarelIndent")
  finish
endif
let s:keepcpo = &cpo
set cpo&vim

function GetKarelIndent() abort

  let currentLine = getline(v:lnum)
  if  currentLine =~? '\v^--' && !get(g:, 'karelCommentIndent', 0)
    " If current line has a -- in column 1, keep zero indent.
    " This may be useful if code is commented out at the first column.
    return 0
  endif

  " Find a non-blank line above the current line.
  let preNoneBlankLineNum = s:karelPreNoneBlank(v:lnum - 1)
  if  preNoneBlankLineNum == 0
    " At the start of the file use zero indent.
    return 0
  endif

  let preNoneBlankLine = getline(preNoneBlankLineNum)
  let ind = indent(preNoneBlankLineNum)

  " Define add 'shiftwidth' pattern
  let addShiftwidthPattern =           '\v^\s*('
  let addShiftwidthPattern   ..=               'if>|while>|for>|using>|condition>|.*<structure>'
  let addShiftwidthPattern   ..=               '|else>'
  let addShiftwidthPattern   ..=               '|case>'
  let addShiftwidthPattern   ..=               '|repeat>'
  let addShiftwidthPattern   ..=               '|const>'
  let addShiftwidthPattern   ..=               '|type>'
  let addShiftwidthPattern   ..=               '|var>'
  let addShiftwidthPattern   ..=               '|begin>'
  let addShiftwidthPattern   ..=               '|routine>'
  if get(g:, 'karelIndentBetweenPrg', 1)
    let addShiftwidthPattern ..=               '|program>'
  endif
  let addShiftwidthPattern   ..=             ')'

  " Define Subtract 'shiftwidth' pattern
  let subtractShiftwidthPattern =      '\v^\s*('
  let subtractShiftwidthPattern   ..=          'end(if|while|for|using|condition|structure)?>'
  let subtractShiftwidthPattern   ..=          '|else>'
  let subtractShiftwidthPattern   ..=          '|case>|endselect>'
  let subtractShiftwidthPattern   ..=          '|until>'
  let subtractShiftwidthPattern   ..=          '|const>'
  let subtractShiftwidthPattern   ..=          '|type>'
  let subtractShiftwidthPattern   ..=          '|var>'
  let subtractShiftwidthPattern   ..=          '|begin>'
  let subtractShiftwidthPattern   ..=        ')'

  " Add shiftwidth
  if preNoneBlankLine =~? addShiftwidthPattern
    let ind += &sw
  endif

  " Subtract shiftwidth
  if currentLine =~? subtractShiftwidthPattern
    let ind = ind - &sw
  endif

  " First case after a select gets the indent of the select.
  if currentLine =~? '\v^\s*case>'  
        \&& preNoneBlankLine =~? '\v^\s*select>'
    let ind = ind + &sw
  endif

  return ind
endfunction

" This function works almost like prevnonblank() but handles &-headers,
" comments and continue instructions like blank lines
function s:karelPreNoneBlank(lnum) abort

  let nPreNoneBlank = prevnonblank(a:lnum)

  while nPreNoneBlank > 0 && getline(nPreNoneBlank) =~? '\v^\s*(\&\w\+|--)'
    " Previous none blank line irrelevant. Look further aback.
    let nPreNoneBlank = prevnonblank(nPreNoneBlank - 1)
  endwhile

  return nPreNoneBlank
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:sw=2 sts=2 et
