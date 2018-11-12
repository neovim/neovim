" Common functions for providers

" Start the provider and perform a 'poll' request
"
" Returns a valid channel on success
function! provider#Poll(argv, long_name, log_env) abort
  let job = {'rpc': v:true}

  " Jobs are exptected to log errors etc using nvim_log() via the rpc api;
  " we're just writing stderr to the log file as a courtesy to users who are
  " trying to debug broken providers. Therefore we we log the events at
  " "WARNING" level because anything coming via stderr indicates a problem
  " with the provider.
  let job['on_stderr'] = function('s:LogEvent', [printf('%s:stderr', a:long_name), 'WARNING'])

  try
    let channel_id = jobstart(a:argv, job)
    if channel_id > 0 && rpcrequest(channel_id, 'poll') ==# 'ok'
      return channel_id
    endif
  catch
    echomsg v:throwpoint
    echomsg v:exception
  endtry

  throw printf('Failed to load %s. Startup errors should be recorded in $NVIM_LOG_FILE'
        \ .', or possibly %s if you are using an older neovim client library.',
        \ a:long_name, a:log_env)
endfunction

function! s:LogEvent(who, log_level, job, data, event)
  call nvim_log(a:log_level, lines, {'who': who})
endfunction
