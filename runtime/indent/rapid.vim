" ABB Rapid Command indent file for Vim
" Language: ABB Rapid Command
" Maintainer: Patrick Meiser-Knosowski <knosowski@graeffrobotics.de>
" Version: 2.2.7
" Last Change: 12. May 2023
" Credits: Based on indent/vim.vim
"
" Suggestions of improvement are very welcome. Please email me!
"
" Known bugs: ../doc/rapid.txt
"
" TODO
" * indent wrapped lines which do not end with an ; or special key word,
"     maybe this is a better idea, but then () and [] has to be changed as
"     well
"

if exists("g:rapidNoSpaceIndent")
  if !exists("g:rapidSpaceIndent")
    let g:rapidSpaceIndent = !g:rapidNoSpaceIndent
  endif
  unlet g:rapidNoSpaceIndent
endif

" Only load this indent file when no other was loaded.
if exists("b:did_indent") || get(g:,'rapidNoIndent',0)
  finish
endif
let b:did_indent = 1

setlocal nolisp
setlocal nosmartindent
setlocal autoindent
setlocal indentexpr=GetRapidIndent()
if get(g:,'rapidNewStyleIndent',0)
  setlocal indentkeys=!^F,o,O,0=~endmodule,0=~error,0=~undo,0=~backward,0=~endproc,0=~endrecord,0=~endtrap,0=~endfunc,0=~else,0=~endif,0=~endtest,0=~endfor,0=~endwhile,:,<[>,<]>,<(>,<)>
else
  setlocal indentkeys=!^F,o,O,0=~endmodule,0=~error,0=~undo,0=~backward,0=~endproc,0=~endrecord,0=~endtrap,0=~endfunc,0=~else,0=~endif,0=~endtest,0=~endfor,0=~endwhile,:
endif
let b:undo_indent="setlocal lisp< si< ai< inde< indk<"

if get(g:,'rapidSpaceIndent',1)
  " Use spaces for indention, 2 is enough. 
  " More or even tabs wastes space on the teach pendant.
  setlocal softtabstop=2
  setlocal shiftwidth=2
  setlocal expandtab
  setlocal shiftround
  let b:undo_indent = b:undo_indent." sts< sw< et< sr<"
endif

" Only define the function once.
if exists("*GetRapidIndent")
  finish
endif

let s:keepcpo= &cpo
set cpo&vim

function GetRapidIndent()
  let ignorecase_save = &ignorecase
  try
    let &ignorecase = 0
    return s:GetRapidIndentIntern()
  finally
    let &ignorecase = ignorecase_save
  endtry
endfunction

function s:GetRapidIndentIntern() abort

  let l:currentLineNum = v:lnum
  let l:currentLine = getline(l:currentLineNum)

  if  l:currentLine =~ '^!' && !get(g:,'rapidCommentIndent',0)
    " If current line is ! line comment, do not change indent
    " This may be useful if code is commented out at the first column.
    return 0
  endif

  " Find a non-blank line above the current line.
  let l:preNoneBlankLineNum = s:RapidPreNoneBlank(v:lnum - 1)
  if  l:preNoneBlankLineNum == 0
    " At the start of the file use zero indent.
    return 0
  endif

  let l:preNoneBlankLine = getline(l:preNoneBlankLineNum)
  let l:ind = indent(l:preNoneBlankLineNum)

  " Define add a 'shiftwidth' pattern
  let l:addShiftwidthPattern  = '\c\v^\s*('
  let l:addShiftwidthPattern .=           '((local|task)\s+)?(module|record|proc|func|trap)\s+\k'
  let l:addShiftwidthPattern .=           '|(backward|error|undo)>'
  let l:addShiftwidthPattern .=         ')'
  "
  " Define Subtract 'shiftwidth' pattern
  let l:subtractShiftwidthPattern  = '\c\v^\s*('
  let l:subtractShiftwidthPattern .=           'end(module|record|proc|func|trap)>'
  let l:subtractShiftwidthPattern .=           '|(backward|error|undo)>'
  let l:subtractShiftwidthPattern .=         ')'

  " Add shiftwidth
  if l:preNoneBlankLine =~ l:addShiftwidthPattern
        \|| s:RapidLenTilStr(l:preNoneBlankLineNum, "then",     0)>=0
        \|| s:RapidLenTilStr(l:preNoneBlankLineNum, "else",     0)>=0
        \|| s:RapidLenTilStr(l:preNoneBlankLineNum, "do",       0)>=0
        \|| s:RapidLenTilStr(l:preNoneBlankLineNum, "case",     0)>=0
        \|| s:RapidLenTilStr(l:preNoneBlankLineNum, "default",  0)>=0
    let l:ind += &sw
  endif

  " Subtract shiftwidth
  if l:currentLine =~ l:subtractShiftwidthPattern
        \|| s:RapidLenTilStr(l:currentLineNum, "endif",     0)>=0
        \|| s:RapidLenTilStr(l:currentLineNum, "endfor",    0)>=0
        \|| s:RapidLenTilStr(l:currentLineNum, "endwhile",  0)>=0
        \|| s:RapidLenTilStr(l:currentLineNum, "endtest",   0)>=0
        \|| s:RapidLenTilStr(l:currentLineNum, "else",      0)>=0
        \|| s:RapidLenTilStr(l:currentLineNum, "elseif",    0)>=0
        \|| s:RapidLenTilStr(l:currentLineNum, "case",      0)>=0
        \|| s:RapidLenTilStr(l:currentLineNum, "default",   0)>=0
    let l:ind = l:ind - &sw
  endif

  " First case (or default) after a test gets the indent of the test.
  if (s:RapidLenTilStr(l:currentLineNum, "case", 0)>=0 || s:RapidLenTilStr(l:currentLineNum, "default", 0)>=0) && s:RapidLenTilStr(l:preNoneBlankLineNum, "test", 0)>=0
    let l:ind += &sw
  endif

  " continued lines with () or []
  let l:OpenSum  = s:RapidLoneParen(l:preNoneBlankLineNum,"(") + s:RapidLoneParen(l:preNoneBlankLineNum,"[")
  if get(g:,'rapidNewStyleIndent',0)
    let l:CloseSum = s:RapidLoneParen(l:preNoneBlankLineNum,")") + s:RapidLoneParen(l:currentLineNum,"]")
  else
    let l:CloseSum = s:RapidLoneParen(l:preNoneBlankLineNum,")") + s:RapidLoneParen(l:preNoneBlankLineNum,"]")
  endif
  if l:OpenSum > l:CloseSum
    let l:ind += (l:OpenSum * 4 * &sw)
  elseif l:OpenSum < l:CloseSum
    let l:ind -= (l:CloseSum * 4 * &sw)
  endif

  return l:ind
endfunction

" Returns the length of the line until a:str occur outside a string or
" comment. Search starts at string index a:startIdx.
" If a:str is a word also add word boundaries and case insensitivity.
" Note: rapidTodoComment and rapidDebugComment are not taken into account.
function s:RapidLenTilStr(lnum, str, startIdx) abort

  let l:line = getline(a:lnum)
  let l:len  = strlen(l:line)
  let l:idx  = a:startIdx
  let l:str  = a:str
  if l:str =~ '^\k\+$'
    let l:str = '\c\<' . l:str . '\>'
  endif

  while l:len > l:idx
    let l:idx = match(l:line, l:str, l:idx)
    if l:idx < 0
      " a:str not found
      return -1
    endif
    let l:synName = synIDattr(synID(a:lnum,l:idx+1,0),"name")
    if         l:synName != "rapidString"
          \&&  l:synName != "rapidConcealableString"
          \&& (l:synName != "rapidComment" || l:str =~ '^!')
      " a:str found outside string or line comment
      return l:idx
    endif
    " a:str is part of string or line comment
    let l:idx += 1 " continue search for a:str
  endwhile
  
  " a:str not found or l:len <= a:startIdx
  return -1
endfunction

" a:lchar should be one of (, ), [, ], { or }
" returns the number of opening/closing parentheses which have no
" closing/opening match in getline(a:lnum)
function s:RapidLoneParen(lnum,lchar) abort
  if a:lchar == "(" || a:lchar == ")"
    let l:opnParChar = "("
    let l:clsParChar = ")"
  elseif a:lchar == "[" || a:lchar == "]"
    let l:opnParChar = "["
    let l:clsParChar = "]"
  elseif a:lchar == "{" || a:lchar == "}"
    let l:opnParChar = "{"
    let l:clsParChar = "}"
  else
    return 0
  endif

  let l:line = getline(a:lnum)

  " look for the first ! which is not part of a string 
  let l:len = s:RapidLenTilStr(a:lnum,"!",0)
  if l:len == 0
    return 0 " first char is !; ignored
  endif

  let l:opnParen = 0
  " count opening brackets
  let l:i = 0
  while l:i >= 0
    let l:i = s:RapidLenTilStr(a:lnum, l:opnParChar, l:i)
    if l:i >= 0
      let l:opnParen += 1
      let l:i += 1
    endif
  endwhile

  let l:clsParen = 0
  " count closing brackets
  let l:i = 0
  while l:i >= 0
    let l:i = s:RapidLenTilStr(a:lnum, l:clsParChar, l:i)
    if l:i >= 0
      let l:clsParen += 1
      let l:i += 1
    endif
  endwhile

  if (a:lchar == "(" || a:lchar == "[" || a:lchar == "{") && l:opnParen>l:clsParen
    return (l:opnParen-l:clsParen)
  elseif (a:lchar == ")" || a:lchar == "]" || a:lchar == "}") && l:clsParen>l:opnParen
    return (l:clsParen-l:opnParen)
  endif

  return 0
endfunction

" This function works almost like prevnonblank() but handles %%%-headers and
" comments like blank lines
function s:RapidPreNoneBlank(lnum) abort

  let nPreNoneBlank = prevnonblank(a:lnum)

  while nPreNoneBlank>0 && getline(nPreNoneBlank) =~ '\v\c^\s*(\%\%\%|!)'
    " Previous none blank line irrelevant. Look further aback.
    let nPreNoneBlank = prevnonblank(nPreNoneBlank - 1)
  endwhile

  return nPreNoneBlank
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:sw=2 sts=2 et
