" Vim indent file
" Language:	gitolite configuration
" URL:		https://github.com/tmatilai/gitolite.vim
" Maintainer:	Teemu Matilainen <teemu.matilainen@iki.fi>
" Last Change:	2011-12-24

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal autoindent
setlocal indentexpr=GetGitoliteIndent()
setlocal indentkeys=o,O,*<Return>,!^F,=repo,\",=

" Only define the function once.
if exists("*GetGitoliteIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

function! GetGitoliteIndent()
  let prevln = prevnonblank(v:lnum-1)
  let pline = getline(prevln)
  let cline = getline(v:lnum)

  if cline =~ '^\s*\(C\|R\|RW\|RW+\|RWC\|RW+C\|RWD\|RW+D\|RWCD\|RW+CD\|-\)[ \t=]'
    return &sw
  elseif cline =~ '^\s*config\s'
    return &sw
  elseif pline =~ '^\s*repo\s' && cline =~ '^\s*\(#.*\)\?$'
    return &sw
  elseif cline =~ '^\s*#'
    return indent(prevln)
  elseif cline =~ '^\s*$'
    return -1
  else
    return 0
  endif
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
