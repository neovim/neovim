if exists('g:loaded_node_provider')
  finish
endif
let g:loaded_node_provider = 1

let s:job_opts = {'rpc': v:true, 'on_stderr': function('provider#stderr_collector')}

" Support for --inspect-brk requires node 6.12+ or 7.6+ or 8+
" Return 1 if it is supported
" Return 0 otherwise
function! provider#node#can_inspect()
  if !executable('node')
    return 0
  endif
  let node_v = split(system(['node', '-v']), "\n")[0]
  if v:shell_error || node_v[0] !=# 'v'
    return 0
  endif
  " [major, minor, patch]
  let node_v = split(node_v[1:], '\.')
  return len(node_v) == 3 && (
  \ (node_v[0] > 7) ||
  \ (node_v[0] == 7 && node_v[1] >= 6) ||
  \ (node_v[0] == 6 && node_v[1] >= 12)
  \ )
endfunction

function! provider#node#Detect() abort
  return has('win32') ? exepath('neovim-node-host.cmd') : exepath('neovim-node-host')
endfunction

function! provider#node#Prog()
  return s:prog
endfunction

function! provider#node#Require(host) abort
  if s:err != ''
    echoerr s:err
    return
  endif

  if has('win32')
    let args = provider#node#Prog()
  else
    let args = ['node']

    if !empty($NVIM_NODE_HOST_DEBUG) && provider#node#can_inspect()
      call add(args, '--inspect-brk')
    endif

    call add(args , provider#node#Prog())
  endif

  try
    let channel_id = jobstart(args, s:job_opts)
    if rpcrequest(channel_id, 'poll') ==# 'ok'
      return channel_id
    endif
  catch
    echomsg v:throwpoint
    echomsg v:exception
    for row in provider#get_stderr(channel_id)
      echomsg row
    endfor
  endtry
  finally
    call provider#clear_stderr(channel_id)
  endtry
  throw remote#host#LoadErrorForHost(a:host.orig_name, '$NVIM_NODE_LOG_FILE')
endfunction

function! provider#node#Call(method, args)
  if s:err != ''
    echoerr s:err
    return
  endif

  if !exists('s:host')
    try
      let s:host = remote#host#Require('node')
    catch
      let s:err = v:exception
      echohl WarningMsg
      echomsg v:exception
      echohl None
      return
    endtry
  endif
  return call('rpcrequest', insert(insert(a:args, 'node_'.a:method), s:host))
endfunction


let s:err = ''
let s:prog = provider#node#Detect()

if empty(s:prog)
  let s:err = 'Cannot find the "neovim" node package. Try :CheckHealth'
endif

call remote#host#RegisterPlugin('node-provider', 'node', [])
