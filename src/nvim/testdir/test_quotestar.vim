" *-register (quotestar) tests

if !has('clipboard')
  finish
endif

source shared.vim

func Do_test_quotestar_for_macunix()
  if empty(exepath('pbcopy')) || empty(exepath('pbpaste'))
    return 'Test requires pbcopy(1) and pbpaste(1)'
  endif

  let @* = ''

  " Test #1: Pasteboard to Vim
  let test_msg = "text from pasteboard to vim via quotestar"
  " Write a piece of text to the pasteboard.
  call system('/bin/echo -n "' . test_msg . '" | pbcopy')
  " See if the *-register is changed as expected.
  call assert_equal(test_msg, @*)

  " Test #2: Vim to Pasteboard
  let test_msg = "text from vim to pasteboard via quotestar"
  " Write a piece of text to the *-register.
  let @* = test_msg
  " See if the pasteboard is changed as expected.
  call assert_equal(test_msg, system('pbpaste'))

  return ''
endfunc

func Do_test_quotestar_for_x11()
  if !has('clientserver') || !has('job')
    return 'Test requires the client-server and job features'
  endif

  let cmd = GetVimCommand()
  if cmd == ''
    return 'GetVimCommand() failed'
  endif
  try
    call remote_send('xxx', '')
  catch
    if v:exception =~ 'E240:'
      " No connection to the X server, give up.
      return
    endif
    " ignore other errors
  endtry

  let name = 'XVIMCLIPBOARD'

  " Make sure a previous server has exited
  try
    call remote_send(name, ":qa!\<CR>")
    call WaitFor('serverlist() !~ "' . name . '"')
  catch /E241:/
  endtry
  call assert_notmatch(name, serverlist())

  let cmd .= ' --servername ' . name
  let g:job = job_start(cmd, {'stoponexit': 'kill', 'out_io': 'null'})
  call WaitFor('job_status(g:job) == "run"')
  if job_status(g:job) != 'run'
    call assert_report('Cannot run the Vim server')
    return ''
  endif

  " Takes a short while for the server to be active.
  call WaitFor('serverlist() =~ "' . name . '"')

  " Wait for the server to be up and answering requests.  One second is not
  " always sufficient.
  call WaitFor('remote_expr("' . name . '", "v:version", "", 2) != ""')

  " Clear the *-register of this vim instance and wait for it to be picked up
  " by the server.
  let @* = 'no'
  call remote_foreground(name)
  call WaitFor('remote_expr("' . name . '", "@*", "", 1) == "no"', 3000)

  " Set the * register on the server.
  call remote_send(name, ":let @* = 'yes'\<CR>")
  call WaitFor('remote_expr("' . name . '", "@*", "", 1) == "yes"', 3000)

  " Check that the *-register of this vim instance is changed as expected.
  call WaitFor('@* == "yes"', 3000)

  if has('unix') && has('gui') && !has('gui_running')
    let @* = ''

    " Running in a terminal and the GUI is avaiable: Tell the server to open
    " the GUI and check that the remote command still works.
    " Need to wait for the GUI to start up, otherwise the send hangs in trying
    " to send to the terminal window.
    if has('gui_athena') || has('gui_motif')
      " For those GUIs, ignore the 'failed to create input context' error.
      call remote_send(name, ":call test_ignore_error('E285') | gui -f\<CR>")
    else
      call remote_send(name, ":gui -f\<CR>")
    endif
    " Wait for the server in the GUI to be up and answering requests.
    call WaitFor('remote_expr("' . name . '", "has(\"gui_running\")", "", 1) =~ "1"')

    call remote_send(name, ":let @* = 'maybe'\<CR>")
    call WaitFor('remote_expr("' . name . '", "@*", "", 1) == "maybe"')
    call assert_equal('maybe', remote_expr(name, "@*", "", 2))

    call assert_equal('maybe', @*)
  endif

  call remote_send(name, ":qa!\<CR>")
  call WaitFor('job_status(g:job) == "dead"')
  if job_status(g:job) != 'dead'
    call assert_report('Server did not exit')
    call job_stop(g:job, 'kill')
  endif

  return ''
endfunc

func Test_quotestar()
  let skipped = ''

  let quotestar_saved = @*

  if has('macunix')
    let skipped = Do_test_quotestar_for_macunix()
  elseif has('x11')
    if empty($DISPLAY)
      let skipped = "Test can only run when $DISPLAY is set."
    else
      let skipped = Do_test_quotestar_for_x11()
    endif
  else
    let skipped = "Test is not implemented yet for this platform."
  endif

  let @* = quotestar_saved

  if !empty(skipped)
    throw 'Skipped: ' . skipped
  endif
endfunc
