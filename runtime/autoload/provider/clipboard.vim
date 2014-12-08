" The clipboard provider uses shell commands to communicate with the clipboard.
" The provider function will only be registered if one of the supported
" commands are available.
let s:copy = {}
let s:paste = {}

function! s:try_cmd(cmd, ...)
  let out = a:0 ? systemlist(a:cmd, a:1, 1) : systemlist(a:cmd, [''], 1)
  if v:shell_error
    echo "clipboard: error: ".(len(out) ? out[0] : '')
    return ''
  endif
  return out
endfunction

if executable('pbcopy')
  let s:copy['+'] = 'pbcopy'
  let s:paste['+'] = 'pbpaste'
  let s:copy['*'] = s:copy['+']
  let s:paste['*'] = s:paste['+']
elseif executable('xclip')
  let s:copy['+'] = 'xclip -i -selection clipboard'
  let s:paste['+'] = 'xclip -o -selection clipboard'
  let s:copy['*'] = 'xclip -i -selection primary'
  let s:paste['*'] = 'xclip -o -selection primary'
elseif executable('xsel')
  let s:copy['+'] = 'xsel -i -b'
  let s:paste['+'] = 'xsel -o -b'
  let s:copy['*'] = 'xsel -i -p'
  let s:paste['*'] = 'xsel -o -p'
else
  echom 'clipboard: No shell command for communicating with the clipboard found.'
  finish
endif

let s:clipboard = {}

function! s:clipboard.get(reg)
  return s:try_cmd(s:paste[a:reg])
endfunction

function! s:clipboard.set(lines, regtype, reg)
  call s:try_cmd(s:copy[a:reg], a:lines)
endfunction

function! provider#clipboard#Call(method, args)
  return call(s:clipboard[a:method],a:args,s:clipboard)
endfunction
