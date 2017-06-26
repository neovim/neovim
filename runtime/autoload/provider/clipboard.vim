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

let s:providers = [
      \ {
      \   'name': 'pbcopy/pbpaste',
      \   'copy': {
      \      '+': 'pbcopy',
      \      '*': 'pbcopy',
      \    },
      \   'paste': {
      \      '+': 'pbpaste',
      \      '*': 'pbpaste',
      \   },
      \   'cache_enabled': 0,
      \   'check': 'executable("pbcopy")',
      \ },
      \ {
      \   'name': 'xsel',
      \   'copy': {
      \      '+': 'xsel --nodetach -i -b',
      \      '*': 'xsel --nodetach -i -p',
      \    },
      \   'paste': {
      \      '+': 'xsel -o -b',
      \      '*': 'xsel -o -p',
      \   },
      \   'cache_enabled': 1,
      \   'check': 'exists("$DISPLAY") && executable("xsel") && s:cmd_ok("xsel -o -b")',
      \ },
      \ {
      \   'name': 'xclip',
      \   'copy': {
      \      '+': 'xclip -quiet -i -selection clipboard',
      \      '*': 'xclip -quiet -i -selection primary',
      \    },
      \   'paste': {
      \      '+': 'xclip -o -selection clipboard',
      \      '*': 'xclip -o -selection primary',
      \   },
      \   'cache_enabled': 1,
      \   'check': 'exists("$DISPLAY") && executable("xclip")',
      \ },
      \ {
      \   'name': 'lemonade',
      \   'copy': {
      \      '+': 'lemonade copy',
      \      '*': 'lemonade copy',
      \    },
      \   'paste': {
      \      '+': 'lemonade paste',
      \      '*': 'lemonade paste',
      \   },
      \   'cache_enabled': 1,
      \   'check': 'executable("lemonade")',
      \ },
      \ {
      \   'name': 'doitclient',
      \   'copy': {
      \      '+': 'doitclient wclip',
      \      '*': 'doitclient wclip',
      \    },
      \   'paste': {
      \      '+': 'doitclient wclip -r',
      \      '*': 'doitclient wclip -r',
      \   },
      \   'cache_enabled': 1,
      \   'check': 'executable("doitclient")',
      \ },
      \ {
      \   'name': 'win32yank',
      \   'copy': {
      \      '+': 'win32yank -i --crlf',
      \      '*': 'win32yank -i --crlf',
      \    },
      \   'paste': {
      \      '+': 'win32yank -i --lf',
      \      '*': 'win32yank -i --lf',
      \   },
      \   'cache_enabled': 1,
      \   'check': 'executable("win32yank")',
      \ },
      \ {
      \   'name': 'tmux',
      \   'copy': {
      \      '+': 'tmux load-buffer -',
      \      '*': 'tmux load-buffer -',
      \    },
      \   'paste': {
      \      '+': 'tmux save-buffer -',
      \      '*': 'tmux save-buffer -',
      \   },
      \   'cache_enabled': 1,
      \   'check': 'exists("$TMUX") && executable("tmux")',
      \ },
      \ ]

function! s:set_provider(p) abort
    let s:copy = a:p.copy
    let s:paste = a:p.paste
    let s:cache_enabled = a:p.cache_enabled
    return a:p.name
endfunction

function! provider#clipboard#Executable() abort
  if exists('g:clipboard_provider')
    return s:set_provider(g:clipboard_provider)
  endif
  for p in s:providers
    if eval(p.check)
      return s:set_provider(p)
    endif
  endfor
  let s:err = 'clipboard: No clipboard tool available. See :help clipboard'
  return ''
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
