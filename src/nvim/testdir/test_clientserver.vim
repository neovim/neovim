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
  if has('x11')
    if empty($DISPLAY)
      throw 'Skipped: $DISPLAY is not set'
    endif
    try
      call remote_send('xxx', '')
    catch
      if v:exception =~ 'E240:'
	throw 'Skipped: no connection to the X server'
      endif
      " ignore other errors
    endtry
  endif

  let name = 'XVIMTEST'
  let cmd .= ' --servername ' . name
  let g:job = job_start(cmd, {'stoponexit': 'kill', 'out_io': 'null'})
  call WaitFor('job_status(g:job) == "run"')
  if job_status(g:job) != 'run'
    call assert_report('Cannot run the Vim server')
    return
  endif

  " Takes a short while for the server to be active.
  call WaitFor('serverlist() =~ "' . name . '"')
  call assert_match(name, serverlist())

  call remote_foreground(name)

  call remote_send(name, ":let testvar = 'yes'\<CR>")
  call WaitFor('remote_expr("' . name . '", "exists(\"testvar\") ? testvar : \"\"", "", 1) == "yes"')
  call assert_equal('yes', remote_expr(name, "testvar", "", 2))

  if has('unix') && has('gui') && !has('gui_running')
    " Running in a terminal and the GUI is available: Tell the server to open
    " the GUI and check that the remote command still works.
    " Need to wait for the GUI to start up, otherwise the send hangs in trying
    " to send to the terminal window.
    if has('gui_athena') || has('gui_motif')
      " For those GUIs, ignore the 'failed to create input context' error.
      call remote_send(name, ":call test_ignore_error('E285') | gui -f\<CR>")
    else
      call remote_send(name, ":gui -f\<CR>")
    endif
    " Wait for the server to be up and answering requests.
    sleep 100m
    call WaitFor('remote_expr("' . name . '", "v:version", "", 1) != ""')
    call assert_true(remote_expr(name, "v:version", "", 1) != "")

    call remote_send(name, ":let testvar = 'maybe'\<CR>")
    call WaitFor('remote_expr("' . name . '", "testvar", "", 1) == "maybe"')
    call assert_equal('maybe', remote_expr(name, "testvar", "", 2))
  endif

  call assert_fails('call remote_send("XXX", ":let testvar = ''yes''\<CR>")', 'E241')

  " Expression evaluated locally.
  if v:servername == ''
    call remote_startserver('MYSELF')
    " May get MYSELF1 when running the test again.
    call assert_match('MYSELF', v:servername)
  endif
  let g:testvar = 'myself'
  call assert_equal('myself', remote_expr(v:servername, 'testvar'))

  call remote_send(name, ":call server2client(expand('<client>'), 'got it')\<CR>", 'g:myserverid')
  call assert_equal('got it', remote_read(g:myserverid, 2))

  call remote_send(name, ":call server2client(expand('<client>'), 'another')\<CR>", 'g:myserverid')
  let peek_result = 'nothing'
  let r = remote_peek(g:myserverid, 'peek_result')
  " unpredictable whether the result is already avaialble.
  if r > 0
    call assert_equal('another', peek_result)
  elseif r == 0
    call assert_equal('nothing', peek_result)
  else
    call assert_report('remote_peek() failed')
  endif
  let g:peek_result = 'empty'
  call WaitFor('remote_peek(g:myserverid, "g:peek_result") > 0')
  call assert_equal('another', g:peek_result)
  call assert_equal('another', remote_read(g:myserverid, 2))

  call remote_send(name, ":qa!\<CR>")
  call WaitFor('job_status(g:job) == "dead"')
  if job_status(g:job) != 'dead'
    call assert_report('Server did not exit')
    call job_stop(g:job, 'kill')
  endif
endfunc

" Uncomment this line to get a debugging log
" call ch_logfile('channellog', 'w')
