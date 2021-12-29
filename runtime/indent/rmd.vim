" Vim indent file
" Language:	Rmd
" Author:	Jakson Alves de Aquino <jalvesaq@gmail.com>
" Homepage:     https://github.com/jalvesaq/R-Vim-runtime
" Last Change:	Sun Mar 28, 2021  08:05PM


" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
runtime indent/r.vim
let s:RIndent = function(substitute(&indentexpr, "()", "", ""))
let b:did_indent = 1

setlocal indentkeys=0{,0},<:>,!^F,o,O,e
setlocal indentexpr=GetRmdIndent()

if exists("*GetRmdIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Simple Python indentation algorithm
function s:GetPyIndent()
  let plnum = prevnonblank(v:lnum - 1)
  let pline = getline(plnum)
  let cline = getline(v:lnum)
  if pline =~ '^s```\s*{\s*python '
    return 0
  elseif pline =~ ':$'
    return indent(plnum) + &shiftwidth
  elseif cline =~ 'else:$'
    return indent(plnum) - &shiftwidth
  endif
  return indent(plnum)
endfunction

function s:GetMdIndent()
  let pline = getline(v:lnum - 1)
  let cline = getline(v:lnum)
  if prevnonblank(v:lnum - 1) < v:lnum - 1 || cline =~ '^\s*[-\+\*]\s' || cline =~ '^\s*\d\+\.\s\+'
    return indent(v:lnum)
  elseif pline =~ '^\s*[-\+\*]\s'
    return indent(v:lnum - 1) + 2
  elseif pline =~ '^\s*\d\+\.\s\+'
    return indent(v:lnum - 1) + 3
  endif
  return indent(prevnonblank(v:lnum - 1))
endfunction

function s:GetYamlIndent()
  let plnum = prevnonblank(v:lnum - 1)
  let pline = getline(plnum)
  if pline =~ ':\s*$'
    return indent(plnum) + shiftwidth()
  elseif pline =~ '^\s*- '
    return indent(v:lnum) + 2
  endif
  return indent(plnum)
endfunction

function GetRmdIndent()
  if getline(".") =~ '^[ \t]*```{r .*}$' || getline(".") =~ '^[ \t]*```$'
    return 0
  endif
  if search('^[ \t]*```{r', "bncW") > search('^[ \t]*```$', "bncW")
    return s:RIndent()
  elseif v:lnum > 1 && (search('^---$', "bnW") == 1 &&
        \ (search('^---$', "nW") > v:lnum || search('^\.\.\.$', "nW") > v:lnum))
    return s:GetYamlIndent()
  elseif search('^[ \t]*```{python', "bncW") > search('^[ \t]*```$', "bncW")
    return s:GetPyIndent()
  else
    return s:GetMdIndent()
  endif
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2
