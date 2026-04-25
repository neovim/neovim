" Vim indent file
" Vim reST indent file
" Language: reStructuredText Documentation Format
" Maintainer: Marshall Ward <marshall.ward@gmail.com>
" Previous Maintainer: Nikolai Weibull <now@bitwi.se>
" Latest Revision: 2020-03-31
" 2023 Aug 28 by Vim Project (undo_indent)
" 2025 Oct 13 by Vim project: preserve indentation #18566

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

" Save and modify cpoptions
let s:save_cpo = &cpo
set cpo&vim

setlocal indentexpr=GetRSTIndent()
setlocal indentkeys=!^F,o,O
setlocal nosmartindent

let b:undo_indent = "setlocal indentexpr< indentkeys< smartindent<"

if exists("*GetRSTIndent")
  finish
endif

let s:itemization_pattern = '^\s*[-*+]\s'
let s:enumeration_pattern = '^\s*\%(\d\+\|#\)\.\s\+'
let s:note_pattern = '^\.\. '

function! s:get_paragraph_start()
    let paragraph_mark_start = getpos("'{")[1]
    return getline(paragraph_mark_start) =~
        \ '\S' ? paragraph_mark_start : paragraph_mark_start + 1
endfunction

function GetRSTIndent()
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
    return 0
  endif

  let ind = indent(lnum)
  let line = getline(lnum)

  let psnum = s:get_paragraph_start()
  if psnum != 0
      if getline(psnum) =~ s:note_pattern
          let ind = max([3, ind])
      endif
  endif

  if line =~ s:itemization_pattern
    let ind += 2
  elseif line =~ s:enumeration_pattern
    let ind += matchend(line, s:enumeration_pattern)
  endif

  let line = getline(v:lnum - 1)

  " Indent :FIELD: lines.  Don’t match if there is no text after the field or
  " if the text ends with a sent-ender.
   if line =~ '^:.\+:\s\{-1,\}\S.\+[^.!?:]$'
     return matchend(line, '^:.\{-1,}:\s\+')
   endif

  if line =~ '^\s*$'
    execute lnum
    call search('^\s*\%([-*+]\s\|\%(\d\+\|#\)\.\s\|\.\.\|$\)', 'bW')
    let line = getline('.')
    if line =~ s:itemization_pattern
      let ind -= 2
    elseif line =~ s:enumeration_pattern
      let ind -= matchend(line, s:enumeration_pattern)
    elseif line =~ '^\s*\.\.'
      let ind -= 3
    endif
  endif

  return ind
endfunction

" Restore 'cpoptions'
let &cpo = s:save_cpo
unlet s:save_cpo
