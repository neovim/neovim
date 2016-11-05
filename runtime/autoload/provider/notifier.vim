" The clipboard provider uses shell commands to communicate with the clipboard.
" The provider function will only be registered if one of the supported
" commands are available.
let s:copy = {}
let s:paste = {}

function! s:try_cmd(cmd, ...)
  let argv = split(a:cmd, " ")
  let out = a:0 ? systemlist(argv, a:1, 1) : systemlist(argv, [''], 1)
  if v:shell_error
    if !exists('s:did_error_try_cmd')
      echohl WarningMsg
      echomsg "notification: error: ".(len(out) ? out[0] : '')
      echohl None
      let s:did_error_try_cmd = 1
    endif
    return 0
  endif
  return out
endfunction

let s:err = ''
let s:program = ''

function! provider#clipboard#Error() abort
  return s:err
endfunction

function! provider#notifier#notifysend(title,message,...) abort
  return s:try_cmd("notify-send ". a:message)
endfunction

function! provider#notifier#Executable() abort

  if executable('notify-send')
    let s:program = function('provider#notifier#notifysend')
    return 'notifysend'
  endif
  let s:err = 'notification: No notification tool available. See :help notification'
  return ''
endfunction


if empty(provider#notifier#Executable())
  finish
endif

let s:notifier = {}

function! provider#notifier#Call(title, ...)
	" echom 'hello world'
  " a:args must be a list
  return call(s:program,[a:title] + a:000) " + a:000
endfunction
