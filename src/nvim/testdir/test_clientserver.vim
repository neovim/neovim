" Tests for the +clientserver feature.

if !has('job') || !has('clientserver')
  finish
endif

source shared.vim

func Test_client_server()
  let cmd = GetVimCommand()
  if cmd == ''
    return
  endif
  let name = 'XVIMTEXT'
  let cmd .= ' --servername ' . name
  let g:job = job_start(cmd, {'stoponexit': 'kill', 'out_io': 'null'})
  call WaitFor('job_status(g:job) == "run"')
  if job_status(g:job) != 'run'
    call assert_true(0, 'Cannot run the Vim server')
    return
  endif

  " Takes a short while for the server to be active.
  call WaitFor('serverlist() =~ "' . name . '"')
  call assert_match(name, serverlist())

  call remote_foreground(name)

  call remote_send(name, ":let testvar = 'yes'\<CR>")
  call WaitFor('remote_expr("' . name . '", "testvar") == "yes"')
  call assert_equal('yes', remote_expr(name, "testvar"))

  call remote_send(name, ":qa!\<CR>")
  call WaitFor('job_status(g:job) == "dead"')
  if job_status(g:job) != 'dead'
    call assert_true(0, 'Server did not exit')
    call job_stop(g:job, 'kill')
  endif
endfunc

" Uncomment this line to get a debugging log
" call ch_logfile('channellog', 'w')
