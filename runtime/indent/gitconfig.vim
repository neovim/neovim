" Vim indent file
" Language:	git config file
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2017 Jun 13

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal autoindent
setlocal indentexpr=GetGitconfigIndent()
setlocal indentkeys=o,O,*<Return>,0[,],0;,0#,=,!^F

let b:undo_indent = 'setl ai< inde< indk<'

" Only define the function once.
if exists("*GetGitconfigIndent")
  finish
endif

function! GetGitconfigIndent()
  let sw    = shiftwidth()
  let line  = getline(prevnonblank(v:lnum-1))
  let cline = getline(v:lnum)
  if line =~  '\\\@<!\%(\\\\\)*\\$'
    " odd number of slashes, in a line continuation
    return 2 * sw
  elseif cline =~ '^\s*\['
    return 0
  elseif cline =~ '^\s*\a'
    return sw
  elseif cline == ''       && line =~ '^\['
    return sw
  else
    return -1
  endif
endfunction
