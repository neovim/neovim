" Common functions for providers

" Start the provider and perform a 'poll' request
"
" Returns a valid channel on success
function! provider#Poll(argv, orig_name, log_env, ...) abort
  let job = {'rpc': v:true, 'stderr_buffered': v:true}
  if a:0
    let job = extend(job, a:1)
  endif
  try
    let channel_id = jobstart(a:argv, job)
    if channel_id > 0 && rpcrequest(channel_id, 'poll') ==# 'ok'
      return channel_id
    endif
  catch
    echomsg v:throwpoint
    echomsg v:exception
    for row in get(job, 'stderr', [])
      echomsg row
    endfor
  endtry
  throw remote#host#LoadErrorForHost(a:orig_name, a:log_env)
endfunction
