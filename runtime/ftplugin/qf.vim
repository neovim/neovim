" Vim filetype plugin file
" Language:     Vim's quickfix window
" Maintainer:   Lech Lorens <Lech.Lorens@gmail.com>
" Last Changed: 30 Apr 2012

if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let b:undo_ftplugin = "set stl<"

" Display the command that produced the list in the quickfix window:
setlocal stl=%t%{exists('w:quickfix_title')?\ '\ '.w:quickfix_title\ :\ ''}\ %=%-15(%l,%c%V%)\ %P

function! s:setup_toc() abort
  if get(w:, 'quickfix_title') !~# '\<TOC$' || &syntax != 'qf'
    return
  endif

  let list = getloclist(0)
  if empty(list)
    return
  endif

  let bufnr = list[0].bufnr
  setlocal modifiable
  silent %delete _
  call setline(1, map(list, 'v:val.text'))
  setlocal nomodifiable nomodified
  let &syntax = getbufvar(bufnr, '&syntax')
endfunction

augroup qf_toc
  autocmd!
  autocmd Syntax <buffer> call s:setup_toc()
augroup END
