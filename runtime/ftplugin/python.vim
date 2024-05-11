" Vim filetype plugin file
" Language:	python
" Maintainer:	Tom Picton <tom@tompicton.com>
" Previous Maintainer: James Sully <sullyj3@gmail.com>
" Previous Maintainer: Johannes Zellner <johannes@zellner.org>
" Last Change:	2024/05/11
" https://github.com/tpict/vim-ftplugin-python

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1
let s:keepcpo= &cpo
set cpo&vim

setlocal cinkeys-=0#
setlocal indentkeys-=0#
setlocal include=^\\s*\\(from\\\|import\\)
setlocal define=^\\s*\\([async ]\\?def\\\|class\\)

" For imports with leading .., append / and replace additional .s with ../
let b:grandparent_match = '^\(.\.\)\(\.*\)'
let b:grandparent_sub = '\=submatch(1)."/".repeat("../",strlen(submatch(2)))'

" For imports with a single leading ., replace it with ./
let b:parent_match = '^\.\(\.\)\@!'
let b:parent_sub = './'

" Replace any . sandwiched between word characters with /
let b:child_match = '\(\w\)\.\(\w\)'
let b:child_sub = '\1/\2'

setlocal includeexpr=substitute(substitute(substitute(
      \v:fname,
      \b:grandparent_match,b:grandparent_sub,''),
      \b:parent_match,b:parent_sub,''),
      \b:child_match,b:child_sub,'g')

setlocal suffixesadd=.py
setlocal comments=b:#,fb:-
setlocal commentstring=#\ %s

if has('python3')
  setlocal omnifunc=python3complete#Complete
elseif has('python')
  setlocal omnifunc=pythoncomplete#Complete
endif

set wildignore+=*.pyc

let b:next_toplevel='\v%$\|^(class\|def\|async def)>'
let b:prev_toplevel='\v^(class\|def\|async def)>'
let b:next_endtoplevel='\v%$\|\S.*\n+(def\|class)'
let b:prev_endtoplevel='\v\S.*\n+(def\|class)'
let b:next='\v%$\|^\s*(class\|def\|async def)>'
let b:prev='\v^\s*(class\|def\|async def)>'
let b:next_end='\v\S\n*(%$\|^(\s*\n*)*(class\|def\|async def)\|^\S)'
let b:prev_end='\v\S\n*(^(\s*\n*)*(class\|def\|async def)\|^\S)'

if !exists('g:no_plugin_maps') && !exists('g:no_python_maps')
    execute "nnoremap <silent> <buffer> ]] :<C-U>call <SID>Python_jump('n', '". b:next_toplevel."', 'W', v:count1)<cr>"
    execute "nnoremap <silent> <buffer> [[ :<C-U>call <SID>Python_jump('n', '". b:prev_toplevel."', 'Wb', v:count1)<cr>"
    execute "nnoremap <silent> <buffer> ][ :<C-U>call <SID>Python_jump('n', '". b:next_endtoplevel."', 'W', v:count1, 0)<cr>"
    execute "nnoremap <silent> <buffer> [] :<C-U>call <SID>Python_jump('n', '". b:prev_endtoplevel."', 'Wb', v:count1, 0)<cr>"
    execute "nnoremap <silent> <buffer> ]m :<C-U>call <SID>Python_jump('n', '". b:next."', 'W', v:count1)<cr>"
    execute "nnoremap <silent> <buffer> [m :<C-U>call <SID>Python_jump('n', '". b:prev."', 'Wb', v:count1)<cr>"
    execute "nnoremap <silent> <buffer> ]M :<C-U>call <SID>Python_jump('n', '". b:next_end."', 'W', v:count1, 0)<cr>"
    execute "nnoremap <silent> <buffer> [M :<C-U>call <SID>Python_jump('n', '". b:prev_end."', 'Wb', v:count1, 0)<cr>"

    execute "onoremap <silent> <buffer> ]] :call <SID>Python_jump('o', '". b:next_toplevel."', 'W', v:count1)<cr>"
    execute "onoremap <silent> <buffer> [[ :call <SID>Python_jump('o', '". b:prev_toplevel."', 'Wb', v:count1)<cr>"
    execute "onoremap <silent> <buffer> ][ :call <SID>Python_jump('o', '". b:next_endtoplevel."', 'W', v:count1, 0)<cr>"
    execute "onoremap <silent> <buffer> [] :call <SID>Python_jump('o', '". b:prev_endtoplevel."', 'Wb', v:count1, 0)<cr>"
    execute "onoremap <silent> <buffer> ]m :call <SID>Python_jump('o', '". b:next."', 'W', v:count1)<cr>"
    execute "onoremap <silent> <buffer> [m :call <SID>Python_jump('o', '". b:prev."', 'Wb', v:count1)<cr>"
    execute "onoremap <silent> <buffer> ]M :call <SID>Python_jump('o', '". b:next_end."', 'W', v:count1, 0)<cr>"
    execute "onoremap <silent> <buffer> [M :call <SID>Python_jump('o', '". b:prev_end."', 'Wb', v:count1, 0)<cr>"

    execute "xnoremap <silent> <buffer> ]] :call <SID>Python_jump('x', '". b:next_toplevel."', 'W', v:count1)<cr>"
    execute "xnoremap <silent> <buffer> [[ :call <SID>Python_jump('x', '". b:prev_toplevel."', 'Wb', v:count1)<cr>"
    execute "xnoremap <silent> <buffer> ][ :call <SID>Python_jump('x', '". b:next_endtoplevel."', 'W', v:count1, 0)<cr>"
    execute "xnoremap <silent> <buffer> [] :call <SID>Python_jump('x', '". b:prev_endtoplevel."', 'Wb', v:count1, 0)<cr>"
    execute "xnoremap <silent> <buffer> ]m :call <SID>Python_jump('x', '". b:next."', 'W', v:count1)<cr>"
    execute "xnoremap <silent> <buffer> [m :call <SID>Python_jump('x', '". b:prev."', 'Wb', v:count1)<cr>"
    execute "xnoremap <silent> <buffer> ]M :call <SID>Python_jump('x', '". b:next_end."', 'W', v:count1, 0)<cr>"
    execute "xnoremap <silent> <buffer> [M :call <SID>Python_jump('x', '". b:prev_end."', 'Wb', v:count1, 0)<cr>"
endif

if !exists('*<SID>Python_jump')
  fun! <SID>Python_jump(mode, motion, flags, count, ...) range
      let l:startofline = (a:0 >= 1) ? a:1 : 1

      if a:mode == 'x'
          normal! gv
      endif

      if l:startofline == 1
          normal! 0
      endif

      let cnt = a:count
      mark '
      while cnt > 0
          call search(a:motion, a:flags)
          let cnt = cnt - 1
      endwhile

      if l:startofline == 1
          normal! ^
      endif
  endfun
endif

if has("browsefilter") && !exists("b:browsefilter")
    let b:browsefilter = "Python Files (*.py)\t*.py\n"
    if has("win32")
	let b:browsefilter .= "All Files (*.*)\t*\n"
    else
	let b:browsefilter .= "All Files (*)\t*\n"
    endif
endif

if !exists("g:python_recommended_style") || g:python_recommended_style != 0
    " As suggested by PEP8.
    setlocal expandtab tabstop=4 softtabstop=4 shiftwidth=4
endif

" Use pydoc for keywordprg.
" Unix users preferentially get pydoc3, then pydoc2.
" Windows doesn't have a standalone pydoc executable in $PATH by default, nor
" does it have separate python2/3 executables, so Windows users just get
" whichever version corresponds to their installed Python version.
if executable('python3')
  setlocal keywordprg=python3\ -m\ pydoc
elseif executable('python')
  setlocal keywordprg=python\ -m\ pydoc
endif

" Script for filetype switching to undo the local stuff we may have changed
let b:undo_ftplugin = 'setlocal cinkeys<'
      \ . '|setlocal comments<'
      \ . '|setlocal commentstring<'
      \ . '|setlocal expandtab<'
      \ . '|setlocal include<'
      \ . '|setlocal includeexpr<'
      \ . '|setlocal indentkeys<'
      \ . '|setlocal keywordprg<'
      \ . '|setlocal omnifunc<'
      \ . '|setlocal shiftwidth<'
      \ . '|setlocal softtabstop<'
      \ . '|setlocal suffixesadd<'
      \ . '|setlocal tabstop<'
      \ . '|silent! nunmap <buffer> [M'
      \ . '|silent! nunmap <buffer> [['
      \ . '|silent! nunmap <buffer> []'
      \ . '|silent! nunmap <buffer> [m'
      \ . '|silent! nunmap <buffer> ]M'
      \ . '|silent! nunmap <buffer> ]['
      \ . '|silent! nunmap <buffer> ]]'
      \ . '|silent! nunmap <buffer> ]m'
      \ . '|silent! ounmap <buffer> [M'
      \ . '|silent! ounmap <buffer> [['
      \ . '|silent! ounmap <buffer> []'
      \ . '|silent! ounmap <buffer> [m'
      \ . '|silent! ounmap <buffer> ]M'
      \ . '|silent! ounmap <buffer> ]['
      \ . '|silent! ounmap <buffer> ]]'
      \ . '|silent! ounmap <buffer> ]m'
      \ . '|silent! xunmap <buffer> [M'
      \ . '|silent! xunmap <buffer> [['
      \ . '|silent! xunmap <buffer> []'
      \ . '|silent! xunmap <buffer> [m'
      \ . '|silent! xunmap <buffer> ]M'
      \ . '|silent! xunmap <buffer> ]['
      \ . '|silent! xunmap <buffer> ]]'
      \ . '|silent! xunmap <buffer> ]m'
      \ . '|unlet! b:browsefilter'
      \ . '|unlet! b:child_match'
      \ . '|unlet! b:child_sub'
      \ . '|unlet! b:grandparent_match'
      \ . '|unlet! b:grandparent_sub'
      \ . '|unlet! b:next'
      \ . '|unlet! b:next_end'
      \ . '|unlet! b:next_endtoplevel'
      \ . '|unlet! b:next_toplevel'
      \ . '|unlet! b:parent_match'
      \ . '|unlet! b:parent_sub'
      \ . '|unlet! b:prev'
      \ . '|unlet! b:prev_end'
      \ . '|unlet! b:prev_endtoplevel'
      \ . '|unlet! b:prev_toplevel'
      \ . '|unlet! b:undo_ftplugin'

let &cpo = s:keepcpo
unlet s:keepcpo
