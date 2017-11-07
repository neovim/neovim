" Debugger commands.
"
" WORK IN PROGRESS - much doesn't work yet
"
" Open two terminal windows:
" 1. run a pty, as with ":term NONE"
" 2. run gdb, passing the pty
" The current window is used to edit source code and follows gdb.
"
" Author: Bram Moolenaar
" Copyright: Vim license applies

command -nargs=* -complete=file Termdebug call s:StartDebug(<q-args>)

if !exists('debugger')
  let debugger = 'gdb'
endif

func s:StartDebug(cmd)
  " Open a terminal window without a job, to run the debugged program
  let s:ptybuf = term_start('NONE', {})
  let pty = job_info(term_getjob(s:ptybuf))['tty']

  " Open a terminal window to run the debugger.
  let cmd = [g:debugger, '-tty', pty, a:cmd]
  echomsg 'executing "' . join(cmd) . '"'
  let gdbbuf = term_start(cmd, {
	\ 'exit_cb': function('s:EndDebug'),
	\ 'term_finish': 'close'
	\ })
endfunc

func s:EndDebug(job, status)
   exe 'bwipe! ' . s:ptybuf
endfunc
