" Vim filetype plugin file
" Language:	python
" Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:	2014 Feb 09
" Last Change By Johannes: Wed, 21 Apr 2004 13:13:08 CEST

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1
let s:keepcpo= &cpo
set cpo&vim

setlocal cinkeys-=0#
setlocal indentkeys-=0#
setlocal include=^\\s*\\(from\\\|import\\)
setlocal includeexpr=substitute(v:fname,'\\.','/','g')
setlocal suffixesadd=.py
setlocal comments=b:#,fb:-
setlocal commentstring=#\ %s

setlocal omnifunc=pythoncomplete#Complete

set wildignore+=*.pyc

nnoremap <silent> <buffer> ]] :call <SID>Python_jump('/^\(class\\|def\)')<cr>
nnoremap <silent> <buffer> [[ :call <SID>Python_jump('?^\(class\\|def\)')<cr>
nnoremap <silent> <buffer> ]m :call <SID>Python_jump('/^\s*\(class\\|def\)')<cr>
nnoremap <silent> <buffer> [m :call <SID>Python_jump('?^\s*\(class\\|def\)')<cr>

if !exists('*<SID>Python_jump')
  fun! <SID>Python_jump(motion) range
      let cnt = v:count1
      let save = @/    " save last search pattern
      mark '
      while cnt > 0
	  silent! exe a:motion
	  let cnt = cnt - 1
      endwhile
      call histdel('/', -1)
      let @/ = save    " restore last search pattern
  endfun
endif

if has("browsefilter") && !exists("b:browsefilter")
    let b:browsefilter = "Python Files (*.py)\t*.py\n" .
		       \ "All Files (*.*)\t*.*\n"
endif

" As suggested by PEP8.
setlocal expandtab shiftwidth=4 softtabstop=4 tabstop=8

" First time: try finding "pydoc".
if !exists('g:pydoc_executable')
    if executable('pydoc')
        let g:pydoc_executable = 1
    else
        let g:pydoc_executable = 0
    endif
endif
" If "pydoc" was found use it for keywordprg.
if g:pydoc_executable
    setlocal keywordprg=pydoc
endif

let &cpo = s:keepcpo
unlet s:keepcpo
