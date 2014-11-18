" The clipboard provider uses shell commands to communicate with the clipboard.
" The provider function will only be registered if one of the supported
" commands are available.
let s:copy = ''
let s:paste = ''

if executable('pbcopy')
  let s:copy = 'pbcopy'
  let s:paste = 'pbpaste'
elseif executable('xsel')
  let s:copy = 'xsel -i -b'
  let s:paste = 'xsel -o -b'
elseif executable('xclip')
  let s:copy = 'xclip -i -selection clipboard'
  let s:paste = 'xclip -o -selection clipboard'
endif

if s:copy == ''
  echom 'No shell command for communicating with the clipboard found.'
  finish
endif

let s:methods = {}

function! s:ClipboardGet(...)
  return systemlist(s:paste)
endfunction

function! s:ClipboardSet(...)
  call systemlist(s:copy, a:1)
endfunction

let s:methods = {
      \ 'get': function('s:ClipboardGet'),
      \ 'set': function('s:ClipboardSet')
      \ }

function! provider#clipboard#Call(method, args)
  return s:methods[a:method](a:args)
endfunction
