" Tests for the +clientserver feature.

source check.vim
CheckFeature job

if !has('clientserver')
  call assert_fails('call remote_startserver("local")', 'E942:')
endif

CheckFeature clientserver

source shared.vim

func Check_X11_Connection()
  if has('x11')
    CheckEnv DISPLAY
    try
      call remote_send('xxx', '')
    catch
      if v:exception =~ 'E240:'
        throw 'Skipped: no connection to the X server'
      endif
      " ignore other errors
    endtry
  endif
endfunc

func Test_client_server()
  let g:test_is_flaky = 1
  let cmd = GetVimCommand()
  if cmd == ''
    throw 'GetVimCommand() failed'
  endif
  call Check_X11_Connection()

  let name = 'XVIMTEST'
  let cmd .= ' --servername ' . name
  let job = job_start(cmd, {'stoponexit': 'kill', 'out_io': 'null'})
  call WaitForAssert({-> assert_equal("run", job_status(job))})

  " Takes a short while for the server to be active.
  " When using valgrind it takes much longer.
  call WaitForAssert({-> assert_match(name, serverlist())})

  if !has('win32')
    if RunVim([], [], '--serverlist >Xtest_serverlist')
      let lines = readfile('Xtest_serverlist')
      call assert_true(index(lines, 'XVIMTEST') >= 0)
    endif
    call delete('Xtest_serverlist')
  endif

  eval name->remote_foreground()

  call remote_send(name, ":let testvar = 'yes'\<CR>")
  call WaitFor('remote_expr("' . name . '", "exists(\"testvar\") ? testvar : \"\"", "", 1) == "yes"')
  call assert_equal('yes', remote_expr(name, "testvar", "", 2))
  call assert_fails("let x=remote_expr(name, '2+x')", 'E449:')
  call assert_fails("let x=remote_expr('[], '2+2')", 'E116:')

  if has('unix') && has('gui') && !has('gui_running')
    " Running in a terminal and the GUI is available: Tell the server to open
    " the GUI and check that the remote command still works.
    " Need to wait for the GUI to start up, otherwise the send hangs in trying
    " to send to the terminal window.
    if has('gui_motif')
      " For this GUI ignore the 'failed to create input context' error.
      call remote_send(name, ":call test_ignore_error('E285') | gui -f\<CR>")
    else
      call remote_send(name, ":gui -f\<CR>")
    endif
    " Wait for the server to be up and answering requests.
    " When using valgrind this can be very, very slow.
    sleep 1
    call WaitForAssert({-> assert_match('\d', name->remote_expr("v:version", "", 1))}, 10000)

    call remote_send(name, ":let testvar = 'maybe'\<CR>")
    call WaitForAssert({-> assert_equal('maybe', remote_expr(name, "testvar", "", 2))})
  endif

  call assert_fails('call remote_send("XXX", ":let testvar = ''yes''\<CR>")', 'E241')

  call writefile(['one'], 'Xclientfile')
  let cmd = GetVimProg() .. ' --servername ' .. name .. ' --remote Xclientfile'
  call system(cmd)
  call WaitForAssert({-> assert_equal('Xclientfile', remote_expr(name, "bufname()", "", 2))})
  call WaitForAssert({-> assert_equal('one', remote_expr(name, "getline(1)", "", 2))})
  call writefile(['one', 'two'], 'Xclientfile')
  call system(cmd)
  call WaitForAssert({-> assert_equal('two', remote_expr(name, "getline(2)", "", 2))})
  call delete('Xclientfile')

  " Expression evaluated locally.
  if v:servername == ''
    eval 'MYSELF'->remote_startserver()
    " May get MYSELF1 when running the test again.
    call assert_match('MYSELF', v:servername)
    call assert_fails("call remote_startserver('MYSELF')", 'E941:')
  endif
  let g:testvar = 'myself'
  call assert_equal('myself', remote_expr(v:servername, 'testvar'))
  call remote_send(v:servername, ":let g:testvar2 = 75\<CR>")
  call feedkeys('', 'x')
  call assert_equal(75, g:testvar2)
  call assert_fails('let v = remote_expr(v:servername, "/2")', ['E15:.*/2'])

  call remote_send(name, ":call server2client(expand('<client>'), 'got it')\<CR>", 'g:myserverid')
  call assert_equal('got it', g:myserverid->remote_read(2))

  call remote_send(name, ":eval expand('<client>')->server2client('another')\<CR>", 'g:myserverid')
  let peek_result = 'nothing'
  let r = g:myserverid->remote_peek('peek_result')
  " unpredictable whether the result is already available.
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

  if !has('gui_running')
    " In GUI vim, the following tests display a dialog box

    let cmd = GetVimProg() .. ' --servername ' .. name

    " Run a separate instance to send a command to the server
    call remote_expr(name, 'execute("only")')
    call system(cmd .. ' --remote-send ":new Xclientfile<CR>"')
    call assert_equal('2', remote_expr(name, 'winnr("$")'))
    call assert_equal('Xclientfile', remote_expr(name, 'winbufnr(1)->bufname()'))
    call remote_expr(name, 'execute("only")')

    " Invoke a remote-expr. On MS-Windows, the returned value has a carriage
    " return.
    let l = system(cmd .. ' --remote-expr "2 + 2"')
    call assert_equal(['4'], split(l, "\n"))

    " Edit multiple files using --remote
    call system(cmd .. ' --remote Xclientfile1 Xclientfile2 Xclientfile3')
    call assert_match(".*Xclientfile1\n.*Xclientfile2\n.*Xclientfile3\n", remote_expr(name, 'argv()'))
    eval name->remote_send(":%bw!\<CR>")

    " Edit files in separate tab pages
    call system(cmd .. ' --remote-tab Xclientfile1 Xclientfile2 Xclientfile3')
    call WaitForAssert({-> assert_equal('3', remote_expr(name, 'tabpagenr("$")'))})
    call assert_match('.*\<Xclientfile2', remote_expr(name, 'bufname(tabpagebuflist(2)[0])'))
    eval name->remote_send(":%bw!\<CR>")

    " Edit a file using --remote-wait
    eval name->remote_send(":source $VIMRUNTIME/plugin/rrhelper.vim\<CR>")
    call system(cmd .. ' --remote-wait +enew Xclientfile1')
    call assert_match('.*\<Xclientfile1', remote_expr(name, 'bufname("#")'))
    eval name->remote_send(":%bw!\<CR>")

    " Edit files using --remote-tab-wait
    call system(cmd .. ' --remote-tabwait +tabonly\|enew Xclientfile1 Xclientfile2')
    call assert_equal('1', remote_expr(name, 'tabpagenr("$")'))
    eval name->remote_send(":%bw!\<CR>")

    " Error cases
    if v:lang == "C" || v:lang =~ '^[Ee]n'
      let l = split(system(cmd .. ' --remote +pwd'), "\n")
      call assert_equal("Argument missing after: \"+pwd\"", l[1])
    endif
    let l = system(cmd .. ' --remote-expr "abcd"')
    call assert_match('^E449: ', l)
  endif

  eval name->remote_send(":%bw!\<CR>")
  eval name->remote_send(":qa!\<CR>")
  try
    call WaitForAssert({-> assert_equal("dead", job_status(job))})
  finally
    if job_status(job) != 'dead'
      call assert_report('Server did not exit')
      call job_stop(job, 'kill')
    endif
  endtry

  call assert_fails('call remote_startserver([])', 'E730:')
  call assert_fails("let x = remote_peek([])", 'E730:')
  call assert_fails("let x = remote_read('vim10')",
        \ has('unix') ? ['E573:.*vim10'] : 'E277:')
  call assert_fails("call server2client('abc', 'xyz')",
        \ has('unix') ? ['E573:.*abc'] : 'E258:')
endfunc

" Uncomment this line to get a debugging log
" call ch_logfile('channellog', 'w')

" vim: shiftwidth=2 sts=2 expandtab
