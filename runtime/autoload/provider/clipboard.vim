" The clipboard provider uses shell commands to communicate with the clipboard.
" The provider function will only be registered if a supported command is
" available.
let s:copy = {}
let s:paste = {}

" When caching is enabled, store the jobid of the xclip/xsel process keeping
" ownership of the selection, so we know how long the cache is valid.
let s:selection = { 'owner': 0, 'data': [] }

function! s:selection.on_exit(jobid, data, event)
  " At this point this nvim instance might already have launched
  " a new provider instance. Don't drop ownership in this case.
  if self.owner == a:jobid
    let self.owner = 0
  endif
endfunction

let s:selections = { '*': s:selection, '+': copy(s:selection)}

function! s:try_cmd(cmd, ...)
  let argv = split(a:cmd, " ")
  let out = a:0 ? systemlist(argv, a:1, 1) : systemlist(argv, [''], 1)
  if v:shell_error
    if !exists('s:did_error_try_cmd')
      echohl WarningMsg
      echomsg "clipboard: error: ".(len(out) ? out[0] : '')
      echohl None
      let s:did_error_try_cmd = 1
    endif
    return 0
  endif
  return out
endfunction

" Returns TRUE if `cmd` exits with success, else FALSE.
function! s:cmd_ok(cmd)
  call system(a:cmd)
  return v:shell_error == 0
endfunction

let s:cache_enabled = 1
let s:err = ''

function! provider#clipboard#Error() abort
  return s:err
endfunction

function! s:set_executable() abort
  if g:clipboard_executable ==# 'pbcopy'
    let s:copy['+'] = 'pbcopy'
    let s:paste['+'] = 'pbpaste'
    let s:copy['*'] = s:copy['+']
    let s:paste['*'] = s:paste['+']
    let s:cache_enabled = 0
  elseif g:clipboard_executable ==# 'xsel'
    let s:copy['+'] = 'xsel --nodetach -i -b'
    let s:paste['+'] = 'xsel -o -b'
    let s:copy['*'] = 'xsel --nodetach -i -p'
    let s:paste['*'] = 'xsel -o -p'
  elseif g:clipboard_executable ==# 'xclip'
    let s:copy['+'] = 'xclip -quiet -i -selection clipboard'
    let s:paste['+'] = 'xclip -o -selection clipboard'
    let s:copy['*'] = 'xclip -quiet -i -selection primary'
    let s:paste['*'] = 'xclip -o -selection primary'
  elseif g:clipboard_executable ==# 'lemonade'
    let s:copy['+'] = 'lemonade copy'
    let s:paste['+'] = 'lemonade paste'
    let s:copy['*'] = 'lemonade copy'
    let s:paste['*'] = 'lemonade paste'
  elseif g:clipboard_executable ==# 'doitclient'
    let s:copy['+'] = 'doitclient wclip'
    let s:paste['+'] = 'doitclient wclip -r'
    let s:copy['*'] = s:copy['+']
    let s:paste['*'] = s:paste['+']
  elseif g:clipboard_executable ==# 'win32yank'
    let s:copy['+'] = 'win32yank -i --crlf'
    let s:paste['+'] = 'win32yank -o --lf'
    let s:copy['*'] = s:copy['+']
    let s:paste['*'] = s:paste['+']
  else
    let s:err = 'clipboard: The clipboard tool is not supported. See :help clipboard'
    return ''
  endif
  return g:clipboard_executable
endfunction

function! provider#clipboard#Executable() abort
  if !exists('g:clipboard_executable')
    if has('mac') && executable('pbcopy')
      let g:clipboard_executable = 'pbcopy'
    elseif exists('$DISPLAY') && executable('xsel') && s:cmd_ok('xsel -o -b')
      let g:clipboard_executable = 'xsel'
    elseif exists('$DISPLAY') && executable('xclip')
      let g:clipboard_executable = 'xclip'
    elseif executable('lemonade')
      let g:clipboard_executable = 'lemonade'
    elseif executable('doitclient')
      let g:clipboard_executable = 'doitclient'
    elseif executable('win32yank')
      let g:clipboard_executable = 'win32yank'
    else
      let s:err = 'clipboard: No clipboard tool available. See :help clipboard'
      return ''
    endif
  endif
  return s:set_executable()
endfunction

if empty(provider#clipboard#Executable())
  finish
endif

let s:clipboard = {}

function! s:clipboard.get(reg)
  if s:selections[a:reg].owner > 0
    return s:selections[a:reg].data
  end
  return s:try_cmd(s:paste[a:reg])
endfunction

function! s:clipboard.set(lines, regtype, reg)
  if a:reg == '"'
    call s:clipboard.set(a:lines,a:regtype,'+')
    if s:copy['*'] != s:copy['+']
      call s:clipboard.set(a:lines,a:regtype,'*')
    end
    return 0
  end
  if s:cache_enabled == 0
    call s:try_cmd(s:copy[a:reg], a:lines)
    return 0
  end

  let selection = s:selections[a:reg]
  if selection.owner > 0
    " The previous provider instance should exit when the new one takes
    " ownership, but kill it to be sure we don't fill up the job table.
    call jobstop(selection.owner)
  end
  let selection.data = [a:lines, a:regtype]
  let argv = split(s:copy[a:reg], " ")
  let selection.detach = s:cache_enabled
  let selection.cwd = "/"
  let jobid = jobstart(argv, selection)
  if jobid <= 0
    echohl WarningMsg
    echo "clipboard: error when invoking provider"
    echohl None
    return 0
  endif
  call jobsend(jobid, a:lines)
  call jobclose(jobid, 'stdin')
  let selection.owner = jobid
endfunction

function! provider#clipboard#Call(method, args)
  return call(s:clipboard[a:method],a:args,s:clipboard)
endfunction
