if exists('g:loaded_node_provider')
  finish
endif
let g:loaded_node_provider = 1

let s:job_opts = {'rpc': v:true, 'on_stderr': function('provider#stderr_collector')}

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

    if !empty($NVIM_NODE_HOST_DEBUG)
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
