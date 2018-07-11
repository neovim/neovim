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

  if has('unix') && has('gui') && !has('gui_running')
    " Running in a terminal and the GUI is avaiable: Tell the server to open
    " the GUI and check that the remote command still works.
    " Need to wait for the GUI to start up, otherwise the send hangs in trying
    " to send to the terminal window.
    call remote_send(name, ":gui -f\<CR>")
    sleep 500m
    call remote_send(name, ":let testvar = 'maybe'\<CR>")
    call WaitFor('remote_expr("' . name . '", "testvar") == "maybe"')
    call assert_equal('maybe', remote_expr(name, "testvar"))
  endif

  call assert_fails('call remote_send("XXX", ":let testvar = ''yes''\<CR>")', 'E241')

  " Expression evaluated locally.
  if v:servername == ''
    call remote_startserver('MYSELF')
    call assert_equal('MYSELF', v:servername)
  endif
  let g:testvar = 'myself'
  call assert_equal('myself', remote_expr(v:servername, 'testvar'))

  call remote_send(name, ":call server2client(expand('<client>'), 'got it')\<CR>", 'g:myserverid')
  call assert_equal('got it', remote_read(g:myserverid))

  call remote_send(name, ":qa!\<CR>")
  call WaitFor('job_status(g:job) == "dead"')
  if job_status(g:job) != 'dead'
    call assert_true(0, 'Server did not exit')
    call job_stop(g:job, 'kill')
  endif
endfunc

" Uncomment this line to get a debugging log
" call ch_logfile('channellog', 'w')
