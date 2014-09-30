" Vim settings file
" Language:     LambdaProlog (Teyjus)
" Maintainer:   Markus Mottl  <markus.mottl@gmail.com>
" URL:          http://www.ocaml.info/vim/ftplugin/lprolog.vim
" Last Change:  2006 Feb 05
"               2001 Sep 16 - fixed 'no_mail_maps'-bug (MM)
"               2001 Sep 02 - initial release  (MM)

" Only do these settings when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't do other file type settings for this buffer
let b:did_ftplugin = 1

" Error format
setlocal efm=%+A./%f:%l.%c:\ %m formatprg=fmt\ -w75\ -p\\%

" Formatting of comments
setlocal formatprg=fmt\ -w75\ -p\\%

" Add mappings, unless the user didn't want this.
if !exists("no_plugin_maps") && !exists("no_lprolog_maps")
  " Uncommenting
  if !hasmapto('<Plug>Comment')
    nmap <buffer> <LocalLeader>c <Plug>LUncomOn
    vmap <buffer> <LocalLeader>c <Plug>BUncomOn
    nmap <buffer> <LocalLeader>C <Plug>LUncomOff
    vmap <buffer> <LocalLeader>C <Plug>BUncomOff
  endif

  nnoremap <buffer> <Plug>LUncomOn mz0i/* <ESC>$A */<ESC>`z
  nnoremap <buffer> <Plug>LUncomOff <ESC>:s/^\/\* \(.*\) \*\//\1/<CR>
  vnoremap <buffer> <Plug>BUncomOn <ESC>:'<,'><CR>`<O<ESC>0i/*<ESC>`>o<ESC>0i*/<ESC>`<
  vnoremap <buffer> <Plug>BUncomOff <ESC>:'<,'><CR>`<dd`>dd`<
endif
