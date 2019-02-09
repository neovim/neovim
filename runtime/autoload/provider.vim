" Common functions for providers

" Start the provider and perform a 'poll' request
"
" Returns a valid channel on success
function! provider#Poll(argv, long_name, log_env) abort
  let job = {'rpc': v:true}

  " Jobs are exptected to log errors etc using nvim_log() via the rpc api;
  " we're just writing stderr to the log file as a courtesy to users who are
  " trying to debug broken providers. Therefore we we log the events at
  " "WARN" level because anything coming via stderr indicates a problem
  " with the provider.
  let job['on_stderr'] = function('s:LogEvent', [printf('%s:stderr', a:long_name), 'WARN'])

  try
    " attempt to start the provider
    call s:Log('INFO', printf('Starting %s: %s', a:long_name, a:argv))
    let channel_id = jobstart(a:argv, job)

    if channel_id <= 0
      throw printf('jobstart() returned %d', channel_id)
    endif

    " check that the the provider is responding
    if rpcrequest(channel_id, 'poll') ==# 'ok'
      call s:Log('INFO', a:long_name . ' is alive')
      return channel_id
    endif
  catch
    let err = printf('Failed starting %s: %s',  a:long_name, v:exception)
    echomsg v:throwpoint
    echomsg err
    call s:Log('ERROR', err)
  endtry

  throw printf('Failed to load %s. Startup errors should be recorded in $NVIM_LOG_FILE'
        \ .', or possibly %s if you are using an older neovim client library.',
        \ a:long_name, a:log_env)
endfunction

function! s:Log(log_level, msg)
  call nvim_log(a:log_level, [a:msg], {'who': 'provider.vim'})
endfun

function! s:LogEvent(who, log_level, job, data, event)
  call nvim_log(a:log_level, a:data, {'who': a:who})
endfunction
