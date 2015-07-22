" The clipboard provider uses shell commands to communicate with the clipboard.
" The provider function will only be registered if a supported command is
" available.
let s:copy = {}
let s:paste = {}

" Store the jobid of the copy/paste process keeping ownership of the
" selection, so we know how long the cache is valid.
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
    echohl WarningMsg
    echo "clipboard: error: ".(len(out) ? out[0] : '')
    echohl None
    return 0
  endif
  return out
endfunction

if executable('pbcopy')
  let s:copy['+'] = 'pbcopy'
  let s:paste['+'] = 'pbpaste'
  let s:copy['*'] = s:copy['+']
  let s:paste['*'] = s:paste['+']
elseif executable('xclip')
  let s:copy['+'] = 'xclip -quiet -i -selection clipboard'
  let s:paste['+'] = 'xclip -o -selection clipboard'
  let s:copy['*'] = 'xclip -quiet -i -selection primary'
  let s:paste['*'] = 'xclip -o -selection primary'
elseif executable('xsel')
  let s:copy['+'] = 'xsel --nodetach -i -b'
  let s:paste['+'] = 'xsel -o -b'
  let s:copy['*'] = 'xsel --nodetach -i -p'
  let s:paste['*'] = 'xsel -o -p'
else
  echom 'clipboard: No clipboard tool available. See :help nvim-clipboard'
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
  let selection = s:selections[a:reg]
  if selection.owner > 0
    " The previous provider instance should exit when the new one takes
    " ownership, but kill it to be sure we don't fill up the job table.
    call jobstop(selection.owner)
  end
  let selection.data = [a:lines, a:regtype]
  let argv = split(s:copy[a:reg], " ")
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
  if a:method == 'get'
    let data = s:selections[a:args[0]].data  " empty or [lines, regtype]
    let regtype = get(data, 1, 'v')
    return [call(s:clipboard[a:method], a:args, s:clipboard), regtype]
  else  " 'set'
    return call(s:clipboard[a:method], a:args, s:clipboard)
  endif
endfunction
