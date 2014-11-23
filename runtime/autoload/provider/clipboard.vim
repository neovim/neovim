" The clipboard provider uses shell commands to communicate with the clipboard.
" The provider function will only be registered if one of the supported
" commands are available.
let s:copy = ''
let s:paste = ''

function! s:try_cmd(cmd, ...)
  let out = a:0 ? systemlist(a:cmd, a:1) : systemlist(a:cmd)
  if v:shell_error
    echo "clipboard: error: ".(len(out) ? out[0] : '')
    return ''
  endif
  return out
endfunction

if executable('pbcopy')
  let s:copy = 'pbcopy'
  let s:paste = 'pbpaste'
elseif executable('xsel')
  let s:copy = 'xsel -i -b'
  let s:paste = 'xsel -o -b'
elseif executable('xclip')
  let s:copy = 'xclip -i -selection clipboard'
  let s:paste = 'xclip -o -selection clipboard'
else
  echom 'clipboard: No shell command for communicating with the clipboard found.'
  finish
endif

let s:clipboard = {}

function! s:clipboard.get(...)
  return s:try_cmd(s:paste)
endfunction

function! s:clipboard.set(...)
  call s:try_cmd(s:copy, a:1)
endfunction

function! provider#clipboard#Call(method, args)
  return s:clipboard[a:method](a:args)
endfunction
