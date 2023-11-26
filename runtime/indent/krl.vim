" Vim indent file
" Language: Kuka Robot Language
" Maintainer: Patrick Meiser-Knosowski <knosowski@graeffrobotics.de>
" Version: 3.0.0
" Last Change: 15. Apr 2022
" Credits: Based on indent/vim.vim

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal nolisp
setlocal nocindent
setlocal nosmartindent
setlocal autoindent
setlocal indentexpr=GetKrlIndent()
setlocal indentkeys=!^F,o,O,=~end,0=~else,0=~case,0=~default,0=~until,0=~continue,=~part
let b:undo_indent = "setlocal lisp< cindent< smartindent< autoindent< indentexpr< indentkeys<"

if get(g:,'krlSpaceIndent',1)
  " Use spaces, not tabs, for indention, 2 is enough. 
  " More or even tabs would waste valuable space on the teach pendant.
  setlocal softtabstop=2
  setlocal shiftwidth=2
  setlocal expandtab
  setlocal shiftround
  let b:undo_indent = b:undo_indent." softtabstop< shiftwidth< expandtab< shiftround<"
endif

" Only define the function once.
if exists("*GetKrlIndent")
  finish
endif
let s:keepcpo = &cpo
set cpo&vim

function GetKrlIndent() abort

  let currentLine = getline(v:lnum)
  if  currentLine =~? '\v^;(\s*(end)?fold>)@!' && !get(g:, 'krlCommentIndent', 0)
    " If current line has a ; in column 1 and is no fold, keep zero indent.
    " This may be useful if code is commented out at the first column.
    return 0
  endif

  " Find a non-blank line above the current line.
  let preNoneBlankLineNum = s:KrlPreNoneBlank(v:lnum - 1)
  if  preNoneBlankLineNum == 0
    " At the start of the file use zero indent.
    return 0
  endif

  let preNoneBlankLine = getline(preNoneBlankLineNum)
  let ind = indent(preNoneBlankLineNum)

  " Define add 'shiftwidth' pattern
  let addShiftwidthPattern =           '\v^\s*('
  if get(g:, 'krlIndentBetweenDef', 1)
    let addShiftwidthPattern ..=               '(global\s+)?def(fct|dat)?\s+\$?\w'
    let addShiftwidthPattern ..=               '|'
  endif
  let addShiftwidthPattern   ..=               'if>|while>|for>|loop>'
  let addShiftwidthPattern   ..=               '|else>'
  let addShiftwidthPattern   ..=               '|case>|default>'
  let addShiftwidthPattern   ..=               '|repeat>'
  let addShiftwidthPattern   ..=               '|skip>|(ptp_)?spline>'
  let addShiftwidthPattern   ..=               '|time_block\s+(start|part)>'
  let addShiftwidthPattern   ..=               '|const_vel\s+start>'
  let addShiftwidthPattern   ..=             ')'

  " Define Subtract 'shiftwidth' pattern
  let subtractShiftwidthPattern =      '\v^\s*('
  if get(g:, 'krlIndentBetweenDef', 1)
    let subtractShiftwidthPattern ..=          'end(fct|dat)?>'
    let subtractShiftwidthPattern ..=          '|'
  endif
  let subtractShiftwidthPattern   ..=          'end(if|while|for|loop)>'
  let subtractShiftwidthPattern   ..=          '|else>'
  let subtractShiftwidthPattern   ..=          '|case>|default>|endswitch>'
  let subtractShiftwidthPattern   ..=          '|until>'
  let subtractShiftwidthPattern   ..=          '|end(skip|spline)>'
  let subtractShiftwidthPattern   ..=          '|time_block\s+(part|end)>'
  let subtractShiftwidthPattern   ..=          '|const_vel\s+end>'
  let subtractShiftwidthPattern   ..=        ')'

  " Add shiftwidth
  if preNoneBlankLine =~? addShiftwidthPattern
    let ind += &sw
  endif

  " Subtract shiftwidth
  if currentLine =~? subtractShiftwidthPattern
    let ind = ind - &sw
  endif

  " First case after a switch gets the indent of the switch.
  if currentLine =~? '\v^\s*case>'  
        \&& preNoneBlankLine =~? '\v^\s*switch>'
    let ind = ind + &sw
  endif

  " align continue with the following instruction
  if currentLine =~? '\v^\s*continue>'  
        \&& getline(v:lnum + 1) =~? subtractShiftwidthPattern
    let ind = ind - &sw
  endif

  return ind
endfunction

" This function works almost like prevnonblank() but handles &-headers,
" comments and continue instructions like blank lines
function s:KrlPreNoneBlank(lnum) abort

  let nPreNoneBlank = prevnonblank(a:lnum)

  while nPreNoneBlank > 0 && getline(nPreNoneBlank) =~? '\v^\s*(\&\w\+|;|continue>)'
    " Previous none blank line irrelevant. Look further aback.
    let nPreNoneBlank = prevnonblank(nPreNoneBlank - 1)
  endwhile

  return nPreNoneBlank
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:sw=2 sts=2 et
