" *-register (quotestar) tests

if !has('clipboard')
  finish
endif

source shared.vim

let s:where = 0
func Abort(id)
  call assert_report('Test timed out at ' . s:where)
  call FinishTesting()
endfunc

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

  " Some of these commands may hang when failing.
  call timer_start(10000, 'Abort')

  let s:where = 1
  let name = 'XVIMCLIPBOARD'
  let cmd .= ' --servername ' . name
  let g:job = job_start(cmd, {'stoponexit': 'kill', 'out_io': 'null'})
  call WaitFor('job_status(g:job) == "run"')
  if job_status(g:job) != 'run'
    call assert_report('Cannot run the Vim server')
    return ''
  endif
  let s:where = 2

  " Takes a short while for the server to be active.
  call WaitFor('serverlist() =~ "' . name . '"')
  call assert_match(name, serverlist())
  let s:where = 3

  " Clear the *-register of this vim instance.
  let @* = ''

  " Try to change the *-register of the server.
  call remote_foreground(name)
  let s:where = 4
  call remote_send(name, ":let @* = 'yes'\<CR>")
  let s:where = 5
  call WaitFor('remote_expr("' . name . '", "@*") == "yes"')
  let s:where = 6
  call assert_equal('yes', remote_expr(name, "@*"))
  let s:where = 7

  " Check that the *-register of this vim instance is changed as expected.
  call assert_equal('yes', @*)

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
    let s:where = 8
    sleep 500m
    call remote_send(name, ":let @* = 'maybe'\<CR>")
    let s:where = 9
    call WaitFor('remote_expr("' . name . '", "@*") == "maybe"')
    let s:where = 10
    call assert_equal('maybe', remote_expr(name, "@*"))
    let s:where = 11

    call assert_equal('maybe', @*)
  endif

  call remote_send(name, ":qa!\<CR>")
  let s:where = 12
  call WaitFor('job_status(g:job) == "dead"')
  let s:where = 13
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
  elseif !empty("$DISPLAY")
    let skipped = Do_test_quotestar_for_x11()
  else
    let skipped = "Test is not implemented yet for this platform."
  endif

  let @* = quotestar_saved

  if !empty(skipped)
    throw 'Skipped: ' . skipped
  endif
endfunc
