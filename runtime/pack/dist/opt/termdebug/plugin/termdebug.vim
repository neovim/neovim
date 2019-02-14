" Debugger plugin using gdb.
"
" WORK IN PROGRESS - much doesn't work yet
"
" Open two visible terminal windows:
" 1. run a pty, as with ":term NONE"
" 2. run gdb, passing the pty
" The current window is used to view source code and follows gdb.
"
" A third terminal window is hidden, it is used for communication with gdb.
"
" The communication with gdb uses GDB/MI.  See:
" https://sourceware.org/gdb/current/onlinedocs/gdb/GDB_002fMI.html
"
" Author: Bram Moolenaar
" Copyright: Vim license applies, see ":help license"

" In case this gets loaded twice.
if exists(':Termdebug')
  finish
endif

" The command that starts debugging, e.g. ":Termdebug vim".
" To end type "quit" in the gdb window.
command -nargs=* -complete=file Termdebug call s:StartDebug(<q-args>)

" Name of the gdb command, defaults to "gdb".
if !exists('debugger')
  let debugger = 'gdb'
endif

" Sign used to highlight the line where the program has stopped.
sign define debugPC linehl=debugPC
if &background == 'light'
  hi debugPC term=reverse ctermbg=lightblue guibg=lightblue
else
  hi debugPC term=reverse ctermbg=darkblue guibg=darkblue
endif
let s:pc_id = 12

func s:StartDebug(cmd)
  let s:startwin = win_getid(winnr())
  let s:startsigncolumn = &signcolumn

  " Open a terminal window without a job, to run the debugged program
  let s:ptybuf = term_start('NONE', {
	\ 'term_name': 'gdb program',
	\ })
  if s:ptybuf == 0
    echoerr 'Failed to open the program terminal window'
    return
  endif
  let pty = job_info(term_getjob(s:ptybuf))['tty_out']

  " Create a hidden terminal window to communicate with gdb
  let s:commbuf = term_start('NONE', {
	\ 'term_name': 'gdb communication',
	\ 'out_cb': function('s:CommOutput'),
	\ 'hidden': 1,
	\ })
  if s:commbuf == 0
    echoerr 'Failed to open the communication terminal window'
    exe 'bwipe! ' . s:ptybuf
    return
  endif
  let commpty = job_info(term_getjob(s:commbuf))['tty_out']

  " Open a terminal window to run the debugger.
  let cmd = [g:debugger, '-tty', pty, a:cmd]
  echomsg 'executing "' . join(cmd) . '"'
  let gdbbuf = term_start(cmd, {
	\ 'exit_cb': function('s:EndDebug'),
	\ 'term_finish': 'close',
	\ })
  if gdbbuf == 0
    echoerr 'Failed to open the gdb terminal window'
    exe 'bwipe! ' . s:ptybuf
    exe 'bwipe! ' . s:commbuf
    return
  endif

  " Connect gdb to the communication pty, using the GDB/MI interface
  call term_sendkeys(gdbbuf, 'new-ui mi ' . commpty . "\r")
endfunc

func s:EndDebug(job, status)
  exe 'bwipe! ' . s:ptybuf
  exe 'bwipe! ' . s:commbuf
  call setwinvar(s:startwin, '&signcolumn', s:startsigncolumn)
endfunc

" Handle a message received from gdb on the GDB/MI interface.
func s:CommOutput(chan, msg)
  let msgs = split(a:msg, "\r")

  for msg in msgs
    " remove prefixed NL
    if msg[0] == "\n"
      let msg = msg[1:]
    endif
    if msg != ''
      if msg =~ '^\*\(stopped\|running\)'
	let wid = win_getid(winnr())

	if win_gotoid(s:startwin)
	  if msg =~ '^\*stopped'
	    " TODO: proper parsing
	    let fname = substitute(msg, '.*fullname="\([^"]*\)".*', '\1', '')
	    let lnum = substitute(msg, '.*line="\([^"]*\)".*', '\1', '')
	    if lnum =~ '^[0-9]*$'
	      if expand('%:h') != fname
		if &modified
		  " TODO: find existing window
		  exe 'split ' . fnameescape(fname)
		  let s:startwin = win_getid(winnr())
		else
		  exe 'edit ' . fnameescape(fname)
		endif
	      endif
	      exe lnum
	      exe 'sign place ' . s:pc_id . ' line=' . lnum . ' name=debugPC file=' . fnameescape(fname)
	      setlocal signcolumn=yes
	    endif
	  else
	    exe 'sign unplace ' . s:pc_id
	  endif

	  call win_gotoid(wid)
	endif
      endif
    endif
  endfor
endfunc
