" Vim filetype plugin
" Language:	J
" Maintainer:	David Bürgin <dbuergin@gluet.ch>
" URL:		https://gitlab.com/glts/vim-j
" Last Change:	2015-10-27

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo&vim

setlocal iskeyword=48-57,A-Z,a-z,_
setlocal comments=:NB.
setlocal commentstring=NB.\ %s
setlocal formatoptions-=t
setlocal matchpairs=(:)
setlocal path-=/usr/include

" Includes. To make the shorthand form "require 'web/cgi'" work, double the
" last path component. Also strip off leading folder names like "~addons/".
setlocal include=\\v^\\s*(load\|require)\\s*'\\zs\\f+\\ze'
setlocal includeexpr=substitute(substitute(tr(v:fname,'\\','/'),'\\v^[^~][^/.]*(/[^/.]+)$','&\\1',''),'\\v^\\~[^/]+/','','')
setlocal suffixesadd=.ijs

let b:undo_ftplugin = 'setlocal suffixesadd< includeexpr< include< path< matchpairs< formatoptions< commentstring< comments< iskeyword<'

" Section movement with ]] ][ [[ []. The start/end patterns below are amended
" inside the function in order to avoid matching on the current cursor line.
let s:sectionstart = '\%(\s*Note\|.\{-}\<\%([0-4]\|13\|noun\|adverb\|conjunction\|verb\|monad\|dyad\)\s\+\%(:\s*0\|def\s\+0\|define\)\)\>.*'
let s:sectionend = '\s*)\s*'

function! s:SearchSection(end, backwards, visualmode) abort
  if a:visualmode !=# ''
    normal! gv
  endif
  let l:flags = a:backwards ? 'bsW' : 'sW'
  if a:end
    call search('^' . s:sectionend . (a:backwards ? '\n\_.\{-}\%#' : '$'), l:flags)
  else
    call search('^' . s:sectionstart . (a:backwards ? '\n\_.\{-}\%#' : '$'), l:flags)
  endif
endfunction

noremap <buffer> <silent> ]] :<C-U>call <SID>SearchSection(0, 0, '')<CR>
xnoremap <buffer> <silent> ]] :<C-U>call <SID>SearchSection(0, 0, visualmode())<CR>
sunmap <buffer> ]]
noremap <buffer> <silent> ][ :<C-U>call <SID>SearchSection(1, 0, '')<CR>
xnoremap <buffer> <silent> ][ :<C-U>call <SID>SearchSection(1, 0, visualmode())<CR>
sunmap <buffer> ][
noremap <buffer> <silent> [[ :<C-U>call <SID>SearchSection(0, 1, '')<CR>
xnoremap <buffer> <silent> [[ :<C-U>call <SID>SearchSection(0, 1, visualmode())<CR>
sunmap <buffer> [[
noremap <buffer> <silent> [] :<C-U>call <SID>SearchSection(1, 1, '')<CR>
xnoremap <buffer> <silent> [] :<C-U>call <SID>SearchSection(1, 1, visualmode())<CR>
sunmap <buffer> []

let b:undo_ftplugin .= ' | silent! execute "unmap <buffer> ]]"'
                   \ . ' | silent! execute "unmap <buffer> ]["'
                   \ . ' | silent! execute "unmap <buffer> [["'
                   \ . ' | silent! execute "unmap <buffer> []"'

" Browse dialog filter on Windows (see ":help browsefilter")
if has('gui_win32') && !exists('b:browsefilter')
  let b:browsefilter = "J Script Files (*.ijs)\t*.ijs\n"
                   \ . "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin .= ' | unlet! b:browsefilter'
endif

" Enhanced "%" matching (see ":help matchit")
if exists('loaded_matchit') && !exists('b:match_words')
  let b:match_ignorecase = 0
  let b:match_words = '^\%(\s*Note\|.\{-}\<\%([0-4]\|13\|noun\|adverb\|conjunction\|verb\|monad\|dyad\)\s\+\%(\:\s*0\|def\s\+0\|define\)\)\>:^\s*\:\s*$:^\s*)\s*$'
                  \ . ',\<\%(for\%(_\a\k*\)\=\|if\|select\|try\|whil\%(e\|st\)\)\.:\<\%(case\|catch[dt]\=\|else\%(if\)\=\|fcase\)\.:\<end\.'
  let b:undo_ftplugin .= ' | unlet! b:match_ignorecase b:match_words'
endif

let &cpo = s:save_cpo
unlet s:save_cpo
