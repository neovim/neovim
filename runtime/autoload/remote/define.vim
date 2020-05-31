function! remote#define#CommandOnHost(host, method, sync, name, opts)
  let prefix = ''

  if has_key(a:opts, 'range')
    if a:opts.range == '' || a:opts.range == '%'
      " -range or -range=%, pass the line range in a list
      let prefix = '<line1>,<line2>'
    elseif matchstr(a:opts.range, '\d') != ''
      " -range=N, pass the count
      let prefix = '<count>'
    endif
  elseif has_key(a:opts, 'count')
    let prefix = '<count>'
  endif

  let forward_args = [prefix.a:name]

  if has_key(a:opts, 'bang')
    call add(forward_args, '<bang>')
  endif

  if has_key(a:opts, 'register')
    call add(forward_args, ' <register>')
  endif

  if has_key(a:opts, 'nargs')
    call add(forward_args, ' " . <q-args> . "')
  endif

  exe s:GetCommandPrefix(a:name, a:opts)
        \ .' call remote#define#CommandBootstrap("'.a:host.'"'
        \ .                                ', "'.a:method.'"'
        \ .                                ', '.string(a:sync)
        \ .                                ', "'.a:name.'"'
        \ .                                ', '.string(a:opts).''
        \ .                                ', "'.join(forward_args, '').'"'
        \ .                                ')'
endfunction


function! remote#define#CommandBootstrap(host, method, sync, name, opts, forward)
  let channel = remote#host#Require(a:host)

  if channel
    call remote#define#CommandOnChannel(channel, a:method, a:sync, a:name, a:opts)
    exe a:forward
  else
    exe 'delcommand '.a:name
    echoerr 'Host "'a:host.'" is not available, deleting command "'.a:name.'"'
  endif
endfunction


function! remote#define#CommandOnChannel(channel, method, sync, name, opts)
  let rpcargs = [a:channel, '"'.a:method.'"']
  if has_key(a:opts, 'nargs')
    " -nargs, pass arguments in a list
    call add(rpcargs, '[<f-args>]')
  endif

  if has_key(a:opts, 'range')
    if a:opts.range == '' || a:opts.range == '%'
      " -range or -range=%, pass the line range in a list
      call add(rpcargs, '[<line1>, <line2>]')
    elseif matchstr(a:opts.range, '\d') != ''
      " -range=N, pass the count
      call add(rpcargs, '<count>')
    endif
  elseif has_key(a:opts, 'count')
    " count
    call add(rpcargs, '<count>')
  endif

  if has_key(a:opts, 'bang')
    " bang
    call add(rpcargs, '<q-bang> == "!"')
  endif

  if has_key(a:opts, 'register')
    " register
    call add(rpcargs, '<q-reg>')
  endif

  call s:AddEval(rpcargs, a:opts)
  exe s:GetCommandPrefix(a:name, a:opts)
        \ . ' call '.s:GetRpcFunction(a:sync).'('.join(rpcargs, ', ').')'
endfunction


function! remote#define#AutocmdOnHost(host, method, sync, name, opts)
  let group = s:GetNextAutocmdGroup()
  let forward = '"doau '.group.' '.a:name.' ".'
        \ . 'fnameescape(expand("<amatch>"))'
  let a:opts.group = group
  let bootstrap_def = s:GetAutocmdPrefix(a:name, a:opts)
        \ .' call remote#define#AutocmdBootstrap("'.a:host.'"'
        \ .                                ', "'.a:method.'"'
        \ .                                ', '.string(a:sync)
        \ .                                ', "'.a:name.'"'
        \ .                                ', '.string(a:opts).''
        \ .                                ', "'.escape(forward, '"').'"'
        \ .                                ')'
  exe bootstrap_def
endfunction


function! remote#define#AutocmdBootstrap(host, method, sync, name, opts, forward)
  let channel = remote#host#Require(a:host)

  exe 'autocmd! '.a:opts.group
  if channel
    call remote#define#AutocmdOnChannel(channel, a:method, a:sync, a:name,
          \ a:opts)
    exe eval(a:forward)
  else
    exe 'augroup! '.a:opts.group
    echoerr 'Host "'a:host.'" for "'.a:name.'" autocmd is not available'
  endif
endfunction


function! remote#define#AutocmdOnChannel(channel, method, sync, name, opts)
  let rpcargs = [a:channel, '"'.a:method.'"']
  call s:AddEval(rpcargs, a:opts)

  let autocmd_def = s:GetAutocmdPrefix(a:name, a:opts)
        \ . ' call '.s:GetRpcFunction(a:sync).'('.join(rpcargs, ', ').')'
  exe autocmd_def
endfunction


function! remote#define#FunctionOnHost(host, method, sync, name, opts)
  let group = s:GetNextAutocmdGroup()
  exe 'autocmd! '.group.' FuncUndefined '.a:name
        \ .' call remote#define#FunctionBootstrap("'.a:host.'"'
        \ .                                 ', "'.a:method.'"'
        \ .                                 ', '.string(a:sync)
        \ .                                 ', "'.a:name.'"'
        \ .                                 ', '.string(a:opts)
        \ .                                 ', "'.group.'"'
        \ .                                 ')'
endfunction


function! remote#define#FunctionBootstrap(host, method, sync, name, opts, group)
  let channel = remote#host#Require(a:host)

  exe 'autocmd! '.a:group
  exe 'augroup! '.a:group
  if channel
    call remote#define#FunctionOnChannel(channel, a:method, a:sync, a:name,
          \ a:opts)
  else
    echoerr 'Host "'a:host.'" for "'.a:name.'" function is not available'
  endif
endfunction


function! remote#define#FunctionOnChannel(channel, method, sync, name, opts)
  let rpcargs = [a:channel, '"'.a:method.'"', 'a:000']
  if has_key(a:opts, 'range')
    call add(rpcargs, '[a:firstline, a:lastline]')
  endif
  call s:AddEval(rpcargs, a:opts)

  let function_def = s:GetFunctionPrefix(a:name, a:opts)
        \ . 'return '.s:GetRpcFunction(a:sync).'('.join(rpcargs, ', ').')'
        \ . "\nendfunction"
  exe function_def
endfunction

let s:busy = {}
let s:pending_notifications = {}

function! s:GetRpcFunction(sync)
  if a:sync ==# 'urgent'
    return 'rpcnotify'
  elseif a:sync
    return 'remote#define#request'
  endif
  return 'remote#define#notify'
endfunction

function! remote#define#notify(chan, ...)
  if get(s:busy, a:chan, 0) > 0
    let pending = get(s:pending_notifications, a:chan, [])
    call add(pending, deepcopy(a:000))
    let s:pending_notifications[a:chan] = pending
  else
    call call('rpcnotify', [a:chan] + a:000)
  endif
endfunction

function! remote#define#request(chan, ...)
  let s:busy[a:chan] = get(s:busy, a:chan, 0)+1
  let val = call('rpcrequest', [a:chan]+a:000)
  let s:busy[a:chan] -= 1
  if s:busy[a:chan] == 0
    for msg in get(s:pending_notifications, a:chan, [])
      call call('rpcnotify', [a:chan] + msg)
    endfor
    let s:pending_notifications[a:chan] = []
  endif
  return val
endfunction

function! s:GetCommandPrefix(name, opts)
  return 'command!'.s:StringifyOpts(a:opts, ['nargs', 'complete', 'range',
        \ 'count', 'bang', 'bar', 'register']).' '.a:name
endfunction


" Each msgpack-rpc autocommand has it's own unique group, which is derived
" from an autoincrementing gid(group id). This is required for replacing the
" autocmd implementation with the lazy-load mechanism
let s:next_gid = 1
function! s:GetNextAutocmdGroup()
  let gid = s:next_gid
  let s:next_gid += 1

  let group_name = 'RPC_DEFINE_AUTOCMD_GROUP_'.gid
  " Ensure the group is defined
  exe 'augroup '.group_name.' | augroup END'
  return group_name
endfunction


function! s:GetAutocmdPrefix(name, opts)
  if has_key(a:opts, 'group')
    let group = a:opts.group
  else
    let group = s:GetNextAutocmdGroup()
  endif
  let rv = ['autocmd!', group, a:name]

  if has_key(a:opts, 'pattern')
    call add(rv, a:opts.pattern)
  else
    call add(rv, '*')
  endif

  if has_key(a:opts, 'nested') && a:opts.nested
    call add(rv, 'nested')
  endif

  return join(rv, ' ')
endfunction


function! s:GetFunctionPrefix(name, opts)
  let res = "function! ".a:name."(...)"
  if has_key(a:opts, 'range')
    let res = res." range"
  endif
  return res."\n"
endfunction


function! s:StringifyOpts(opts, keys)
  let rv = []
  for key in a:keys
    if has_key(a:opts, key)
      call add(rv, ' -'.key)
      let val = a:opts[key]
      if type(val) != type('') || val != ''
        call add(rv, '='.val)
      endif
    endif
  endfor
  return join(rv, '')
endfunction


function! s:AddEval(rpcargs, opts)
  if has_key(a:opts, 'eval')
    if type(a:opts.eval) != type('') || a:opts.eval == ''
      throw "Eval option must be a non-empty string"
    endif
    " evaluate an expression and pass as argument
    call add(a:rpcargs, 'eval("'.escape(a:opts.eval, '"').'")')
  endif
endfunction
