" Define a command that has it's actual implementation over a msgpack-rpc
" channel.
function! rpc#define#CommandOnChannel(channel, method, sync, name, opts)
  let rpc_args = [a:channel, '"'.a:method.'"']
  if has_key(a:opts, 'nargs')
    " -nargs, pass arguments in a list
    call add(rpc_args, '[<f-args>]')
  endif

  if has_key(a:opts, 'range')
    if a:opts.range == '' || a:opts.range == '%'
      " -range or -range=%, pass the line range in a list
      call add(rpc_args, '[<line1>, <line2>]')
    elseif matchstr(a:opts.range, '\d') != ''
      " -range=N, pass the count
      call add(rpc_args, '<count>')
    endif
  elseif has_key(a:opts, 'count')
    " count
    call add(rpc_args, '<count>')
  endif

  if has_key(a:opts, 'bang')
    " bang
    call add(rpc_args, '<q-bang> == "!"')
  endif

  if has_key(a:opts, 'register')
    " register
    call add(rpc_args, '<q-reg>')
  endif

  if has_key(a:opts, 'eval')
    if type(a:opts.eval) != type('') || a:opts.eval == ''
      throw "Eval option must be a non-empty string"
    endif
    " evaluate an expression and pass as argument
    call add(rpc_args, 'eval("'.escape(a:opts.eval, '"').'")')
  endif

  exe s:GetCommandPrefix(a:name, a:opts)
        \ . ' call '.s:GetRpcFunction(a:sync).'('.join(rpc_args, ', ').')'
endfunction


" Define a command that has it's actual implementation over a msgpack-rpc host
" registered via rpc#host#Register. The command defined by this function will
" only require the host the first time it is invoked.
"
" If the host cannot start for any reason, an error will be shown and the
" command will be deleted. Otherwise it will call rpc#define#CommandOnChannel
" to define the real command passing the host's channel id.
function! rpc#define#CommandOnHost(host, method, sync, name, opts)
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
    call add(forward_args, ' <args>')
  endif

  exe s:GetCommandPrefix(a:name, a:opts)
        \ .' call rpc#define#CommandBootstrap("'.a:host.'"'
        \ .                                ', "'.a:method.'"'
        \ .                                ', "'.a:sync.'"'
        \ .                                ', "'.a:name.'"'
        \ .                                ', '.string(a:opts).''
        \ .                                ', "'.join(forward_args, '').'"'
        \ .                                ')'
endfunction


function! rpc#define#CommandBootstrap(host, method, sync, name, opts, forward)
  let channel = rpc#host#Require(a:host)

  if channel
    call rpc#define#CommandOnChannel(channel, a:method, a:sync, a:name, a:opts)
    exe a:forward
  else
    delcommand a:name
    echoerr 'Host "'a:host.'" is not available, deleting command "'.a:name.'"'
  endif
endfunction


function! rpc#define#AutocmdOnHost(host, method, sync, event, opts)
  let group = s:GetNextAutocmdGroup()
  let forward = '"doau '.group.' '.a:event.' ".'.'expand("<amatch>")'
  let a:opts.group = group
  let bootstrap_def = s:GetAutocmdPrefix(a:event, a:opts)
        \ .' call rpc#define#AutocmdBootstrap("'.a:host.'"'
        \ .                                ', "'.a:method.'"'
        \ .                                ', "'.a:sync.'"'
        \ .                                ', "'.a:event.'"'
        \ .                                ', '.string(a:opts).''
        \ .                                ', "'.escape(forward, '"').'"'
        \ .                                ')'
  exe bootstrap_def
endfunction


function! rpc#define#AutocmdBootstrap(host, method, sync, event, opts, forward)
  let channel = rpc#host#Require(a:host)

  exe 'autocmd! '.a:opts.group
  if channel
    call rpc#define#AutocmdOnChannel(channel, a:method, a:sync, a:event,
          \ a:opts)
    exe eval(a:forward)
  else
    exe 'augroup! '.a:opts.group
    echoerr 'Host "'a:host.'" for "'.a:event.'" autocmd is not available'
  endif
endfunction


function! rpc#define#AutocmdOnChannel(channel, method, sync, event, opts)
  let rpc_args = [a:channel, '"'.a:method.'"']
  if has_key(a:opts, 'eval')
    if type(a:opts.eval) != type('') || a:opts.eval == ''
      throw "Eval option must be a non-empty string"
    endif
    " evaluate an expression and pass as argument
    call add(rpc_args, 'eval("'.escape(a:opts.eval, '"').'")')
  endif

  let autocmd_def = s:GetAutocmdPrefix(a:event, a:opts)
        \ . ' call '.s:GetRpcFunction(a:sync).'('.join(rpc_args, ', ').')'
  exe autocmd_def
endfunction


function! s:GetRpcFunction(sync)
  if a:sync
    return 'rpcrequest'
  endif
  return 'rpcnotify'
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


function! s:GetAutocmdPrefix(event, opts)
  if has_key(a:opts, 'group')
    let group = a:opts.group
  else
    let group = s:GetNextAutocmdGroup()
  endif
  let rv = ['autocmd!', group, a:event]

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
