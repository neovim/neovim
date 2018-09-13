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
" For neovim compatibility, the vim specific calls were replaced with neovim
" specific calls:
"   term_start -> term_open
"   term_sendkeys -> jobsend
"   term_getline -> getbufline
"   job_info && term_getjob -> using linux command ps to get the tty
"
"
" Author: Bram Moolenaar
" Copyright: Vim license applies, see ":help license"

" In case this gets loaded twice.
if exists(':Termdebug')
  finish
endif

" Uncomment this line to write logging in "debuglog".
" call ch_logfile('debuglog', 'w')

" The command that starts debugging, e.g. ":Termdebug vim".
" To end type "quit" in the gdb window.
command -nargs=* -complete=file -bang Termdebug call s:StartDebug(<bang>0, <f-args>)
command -nargs=+ -complete=file -bang TermdebugCommand call s:StartDebugCommand(<bang>0, <f-args>)

" Name of the gdb command, defaults to "gdb".
if !exists('termdebugger')
  let termdebugger = 'gdb'
endif

let s:pc_id = 12
let s:break_id = 13
let s:stopped = 1

if &background == 'light'
  hi default debugPC term=reverse ctermbg=lightblue guibg=lightblue
else
  hi default debugPC term=reverse ctermbg=darkblue guibg=darkblue
endif
hi default debugBreakpoint term=reverse ctermbg=red guibg=red

func s:StartDebug(bang, ...)
  " First argument is the command to debug, second core file or process ID.
  call s:StartDebug_internal({'gdb_args': a:000, 'bang': a:bang})
endfunc

func s:StartDebugCommand(bang, ...)
  " First argument is the command to debug, rest are run arguments.
  call s:StartDebug_internal({'gdb_args': [a:1], 'proc_args': a:000[1:], 'bang': a:bang})
endfunc

func s:StartDebug_internal(dict)
  if exists('s:gdbwin')
    echoerr 'Terminal debugger already running'
    return
  endif

  let s:startwin = win_getid(winnr())
  let s:startsigncolumn = &signcolumn

  let s:save_columns = 0
  if exists('g:termdebug_wide')
    if &columns < g:termdebug_wide
      let s:save_columns = &columns
      let &columns = g:termdebug_wide
    endif
    let vertical = 1
  else
    let vertical = 0
  endif

  " Open a terminal window without a job, to run the debugged program
  if has('nvim')
    execute 'new'
    let s:pty_job_id = termopen('tail -f /dev/null;#gdb program')
    if s:pty_job_id == 0
      echoerr 'invalid argument (or job table is full) while opening terminal window'
      return
    elseif s:pty_job_id == -1
      echoerr 'Failed to open the program terminal window'
      return
    endif
    let pty_job_info = nvim_get_chan_info(s:pty_job_id)
    let pty = pty_job_info['pty']
    let s:ptybuf = pty_job_info['buffer']
  else
    let s:ptybuf = term_start('NONE', {
	  \ 'term_name': 'gdb program',
	  \ 'vertical': vertical,
	  \ })
    if s:ptybuf == 0
      echoerr 'Failed to open the program terminal window'
      return
    endif
    let pty = job_info(term_getjob(s:ptybuf))['tty_out']
  endif
  let s:ptywin = win_getid(winnr())
  if vertical
    " Assuming the source code window will get a signcolumn, use two more
    " columns for that, thus one less for the terminal window.
    exe (&columns / 2 - 1) . "wincmd |"
  endif

  " Create a hidden terminal window to communicate with gdb
  if has('nvim')
    let s:comm_job_id = jobstart('tail -f /dev/null;#gdb communication', {'on_stdout': function('s:CommOutputNvim'), 'pty': v:true})
    " hide terminal buffer
    if s:comm_job_id == 0
      echoerr 'invalid argument (or job table is full) while opening communication terminal window'
      exe 'bwipe! ' . s:ptybuf
      return
    elseif s:comm_job_id == -1
      echoerr 'Failed to open the communication terminal window'
      exe 'bwipe! ' . s:ptybuf
      return
    endif
    let comm_job_info = nvim_get_chan_info(s:comm_job_id)
    let commpty = comm_job_info['pty']
  else
    let s:commbuf = term_start('NONE', {
	  \ 'term_name': 'gdb communication',
	  \ 'out_cb': function('s:CommOutputVim'),
	  \ 'hidden': 1,
	  \ })
    if s:commbuf == 0
      echoerr 'Failed to open the communication terminal window'
      exe 'bwipe! ' . s:ptybuf
      return
    endif
    let commpty = job_info(term_getjob(s:commbuf))['tty_out']
  endif

  " Open a terminal window to run the debugger.
  " Add -quiet to avoid the intro message causing a hit-enter prompt.
  let gdb_args = get(a:dict, 'gdb_args', [])
  let proc_args = get(a:dict, 'proc_args', [])

  let cmd = [g:termdebugger, '-quiet', '-tty', pty] + gdb_args
  echomsg 'executing "' . join(cmd) . '"'
  if has('nvim')
    execute 'new'
    let s:gdb_job_id = termopen(cmd, {'on_exit': function('s:EndDebugNvim')})
    if s:gdb_job_id == 0
      echoerr 'invalid argument (or job table is full) while opening gdb terminal window'
      exe 'bwipe! ' . s:ptybuf
      return
    elseif s:gdb_job_id == -1
      echoerr 'Failed to open the gdb terminal window'
      exe 'bwipe! ' . s:ptybuf
      exe 'bwipe! ' . s:commbuf
      return
    endif
    let gdb_job_info = nvim_get_chan_info(s:gdb_job_id)
    let s:gdbbuf = gdb_job_info['buffer']
  else
    let s:gdbbuf = term_start(cmd, {
	  \ 'exit_cb': function('s:EndDebug'),
	  \ 'term_finish': 'close',
	  \ })
    if s:gdbbuf == 0
      echoerr 'Failed to open the gdb terminal window'
      exe 'bwipe! ' . s:ptybuf
      exe 'bwipe! ' . s:commbuf
      return
    endif
  endif
  let s:gdbwin = win_getid(winnr())

  " Set arguments to be run
  if len(proc_args)
    if has('nvim')
      call jobsend(s:gdb_job_id, 'set args ' . join(proc_args) . "\r")
    else
      call term_sendkeys(s:gdbbuf, 'set args ' . join(proc_args) . "\r")
    endif
  endif

  " Connect gdb to the communication pty, using the GDB/MI interface
  if has('nvim')
    call jobsend(s:gdb_job_id, 'new-ui mi ' . commpty . "\r")
  else
    call term_sendkeys(s:gdbbuf, 'new-ui mi ' . commpty . "\r")
  endif

  " Wait for the response to show up, users may not notice the error and wonder
  " why the debugger doesn't work.
  let try_count = 0
  while 1
    let response = ''
    for lnum in range(1,200)
      if has('nvim')
      	let cond = len(getbufline(s:gdbbuf, lnum)) > 0 && getbufline(s:gdbbuf, lnum)[0] =~ 'new-ui mi '
      else
      	let cond = term_getline(s:gdbbuf, lnum) =~ 'new-ui mi '
      endif
      if cond
      	if has('nvim')
	  let response = getbufline(s:gdbbuf, lnum + 1)[0]
	else
	  let response = term_getline(s:gdbbuf, lnum + 1)
	endif
	if response =~ 'Undefined command'
	  echoerr 'Sorry, your gdb is too old, gdb 7.12 is required'
	  exe 'bwipe! ' . s:ptybuf
	  if !has('nvim')
	    exe 'bwipe! ' . s:commbuf
	  endif
	  return
	endif
	if response =~ 'New UI allocated'
	  " Success!
	  break
	endif
      endif
    endfor
    if response =~ 'New UI allocated'
      break
    endif
    let try_count += 1
    if try_count > 1000
      echoerr 'Cannot check if your gdb works, continuing anyway'
      break
    endif
    sleep 10m
  endwhile

  " Interpret commands while the target is running.  This should usualy only be
  " exec-interrupt, since many commands don't work properly while the target is
  " running.
  call s:SendCommand('-gdb-set mi-async on')

  " Disable pagination, it causes everything to stop at the gdb
  " "Type <return> to continue" prompt.
  call s:SendCommand('-gdb-set pagination off')

  " Sign used to highlight the line where the program has stopped.
  " There can be only one.
  sign define debugPC linehl=debugPC

  " Sign used to indicate a breakpoint.
  " Can be used multiple times.
  sign define debugBreakpoint text=>> texthl=debugBreakpoint

  " Install debugger commands in the text window.
  call win_gotoid(s:startwin)
  call s:InstallCommands()
  call win_gotoid(s:gdbwin)

  " Enable showing a balloon with eval info
  if has("balloon_eval") || has("balloon_eval_term")
    set balloonexpr=TermDebugBalloonExpr()
    if has("balloon_eval")
      set ballooneval
    endif
    if has("balloon_eval_term")
      set balloonevalterm
    endif
  endif

  let s:breakpoints = {}

  augroup TermDebug
    au BufRead * call s:BufRead()
    au BufUnload * call s:BufUnloaded()
  augroup END

  " Run the command if the bang attribute was given
  " and got to the window
  if get(a:dict, 'bang', 0)
    call s:SendCommand('-exec-run')
    call win_gotoid(s:ptywin)
  endif

endfunc

function s:EndDebugNvim(job_id, exit_code, event)
  call s:EndDebug(a:job_id, a:exit_code)
endfunction

func s:EndDebug(job, status)
  exe 'bwipe! ' . s:ptybuf
  if !has('nvim')
    exe 'bwipe! ' . s:commbuf
  endif
  unlet s:gdbwin

  let curwinid = win_getid(winnr())

  call win_gotoid(s:startwin)
  let &signcolumn = s:startsigncolumn
  call s:DeleteCommands()

  call win_gotoid(curwinid)
  if s:save_columns > 0
    let &columns = s:save_columns
  endif

  if has("balloon_eval") || has("balloon_eval_term")
    set balloonexpr=
    if has("balloon_eval")
      set noballooneval
    endif
    if has("balloon_eval_term")
      set noballoonevalterm
    endif
  endif

  au! TermDebug
endfunc

" Handle a message received from gdb on the GDB/MI interface.
func s:CommOutputVim(chan, msg)
  let msgs = split(a:msg, "\r")

  for msg in msgs
    " remove prefixed NL
    if msg[0] == "\n"
      let msg = msg[1:]
    endif
    if msg != ''
      if msg =~ '^\(\*stopped\|\*running\|=thread-selected\)'
	call s:HandleCursor(msg)
      elseif msg =~ '^\^done,bkpt=' || msg =~ '^=breakpoint-created,'
	call s:HandleNewBreakpoint(msg)
      elseif msg =~ '^=breakpoint-deleted,'
	call s:HandleBreakpointDelete(msg)
      elseif msg =~ '^\^done,value='
	call s:HandleEvaluate(msg)
      elseif msg =~ '^\^error,msg='
	call s:HandleError(msg)
      endif
    endif
  endfor
endfunc

func s:CommOutputNvim(job_id, msgs, event)

  for msg in a:msgs
    " remove prefixed NL
    if msg[0] == "\n"
      let msg = msg[1:]
    endif
    if msg != ''
      if msg =~ '^\(\*stopped\|\*running\|=thread-selected\)'
	call s:HandleCursor(msg)
      elseif msg =~ '^\^done,bkpt=' || msg =~ '^=breakpoint-created,'
	call s:HandleNewBreakpoint(msg)
      elseif msg =~ '^=breakpoint-deleted,'
	call s:HandleBreakpointDelete(msg)
      elseif msg =~ '^\^done,value='
	call s:HandleEvaluate(msg)
      elseif msg =~ '^\^error,msg='
	call s:HandleError(msg)
      endif
    endif
  endfor
endfunc

" Install commands in the current window to control the debugger.
func s:InstallCommands()
  command Break call s:SetBreakpoint()
  command Clear call s:ClearBreakpoint()
  command Step call s:SendCommand('-exec-step')
  command Over call s:SendCommand('-exec-next')
  command Finish call s:SendCommand('-exec-finish')
  command -nargs=* Run call s:Run(<q-args>)
  command -nargs=* Arguments call s:SendCommand('-exec-arguments ' . <q-args>)
  command Stop call s:SendCommand('-exec-interrupt')
  command Continue call s:SendCommand('-exec-continue')
  command -range -nargs=* Evaluate call s:Evaluate(<range>, <q-args>)
  command Gdb call win_gotoid(s:gdbwin)
  command Program call win_gotoid(s:ptywin)
  command Source call s:GotoStartwinOrCreateIt()
  command Winbar call s:InstallWinbar()

  " TODO: can the K mapping be restored?
  nnoremap K :Evaluate<CR>

  if has('menu') && &mouse != ''
    call s:InstallWinbar()

    if !exists('g:termdebug_popup') || g:termdebug_popup != 0
      let s:saved_mousemodel = &mousemodel
      let &mousemodel = 'popup_setpos'
      an 1.200 PopUp.-SEP3-	<Nop>
      an 1.210 PopUp.Set\ breakpoint	:Break<CR>
      an 1.220 PopUp.Clear\ breakpoint	:Clear<CR>
      an 1.230 PopUp.Evaluate		:Evaluate<CR>
    endif
  endif
endfunc

let s:winbar_winids = []

" Install the window toolbar in the current window.
func s:InstallWinbar()
  if has('menu') && &mouse != ''
    nnoremenu WinBar.Step   :Step<CR>
    nnoremenu WinBar.Next   :Over<CR>
    nnoremenu WinBar.Finish :Finish<CR>
    nnoremenu WinBar.Cont   :Continue<CR>
    nnoremenu WinBar.Stop   :Stop<CR>
    nnoremenu WinBar.Eval   :Evaluate<CR>
    call add(s:winbar_winids, win_getid(winnr()))
  endif
endfunc

" Delete installed debugger commands in the current window.
func s:DeleteCommands()
  delcommand Break
  delcommand Clear
  delcommand Step
  delcommand Over
  delcommand Finish
  delcommand Run
  delcommand Arguments
  delcommand Stop
  delcommand Continue
  delcommand Evaluate
  delcommand Gdb
  delcommand Program
  delcommand Source
  delcommand Winbar

  nunmap K

  if has('menu')
    " Remove the WinBar entries from all windows where it was added.
    let curwinid = win_getid(winnr())
    for winid in s:winbar_winids
      if win_gotoid(winid)
	aunmenu WinBar.Step
	aunmenu WinBar.Next
	aunmenu WinBar.Finish
	aunmenu WinBar.Cont
	aunmenu WinBar.Stop
	aunmenu WinBar.Eval
      endif
    endfor
    call win_gotoid(curwinid)
    let s:winbar_winids = []

    if exists('s:saved_mousemodel')
      let &mousemodel = s:saved_mousemodel
      unlet s:saved_mousemodel
      aunmenu PopUp.-SEP3-
      aunmenu PopUp.Set\ breakpoint
      aunmenu PopUp.Clear\ breakpoint
      aunmenu PopUp.Evaluate
    endif
  endif

  exe 'sign unplace ' . s:pc_id
  for key in keys(s:breakpoints)
    exe 'sign unplace ' . (s:break_id + key)
  endfor
  sign undefine debugPC
  sign undefine debugBreakpoint
  unlet s:breakpoints
endfunc

" :Break - Set a breakpoint at the cursor position.
func s:SetBreakpoint()
  " Setting a breakpoint may not work while the program is running.
  " Interrupt to make it work.
  let do_continue = 0
  if !s:stopped
    let do_continue = 1
    call s:SendCommand('-exec-interrupt')
    sleep 10m
  endif
  call s:SendCommand('-break-insert --source '
	\ . fnameescape(expand('%:p')) . ' --line ' . line('.'))
  if do_continue
    call s:SendCommand('-exec-continue')
  endif
endfunc

" :Clear - Delete a breakpoint at the cursor position.
func s:ClearBreakpoint()
  let fname = fnameescape(expand('%:p'))
  let lnum = line('.')
  for [key, val] in items(s:breakpoints)
    if val['fname'] == fname && val['lnum'] == lnum
      if has('nvim')
      	call jobsend(s:comm_job_id, '-break-delete ' . key . "\r")
      else
      	call term_sendkeys(s:commbuf, '-break-delete ' . key . "\r")
      endif
      " Assume this always wors, the reply is simply "^done".
      exe 'sign unplace ' . (s:break_id + key)
      unlet s:breakpoints[key]
      break
    endif
  endfor
endfunc

" :Next, :Continue, etc - send a command to gdb
func s:SendCommand(cmd)
  if has('nvim')
    call jobsend(s:comm_job_id, a:cmd . "\r")
  else
    call term_sendkeys(s:commbuf, a:cmd . "\r")
  endif
endfunc

func s:Run(args)
  if a:args != ''
    call s:SendCommand('-exec-arguments ' . a:args)
  endif
  call s:SendCommand('-exec-run')
endfunc

func s:SendEval(expr)
  call s:SendCommand('-data-evaluate-expression "' . a:expr . '"')
  let s:evalexpr = a:expr
endfunc

" :Evaluate - evaluate what is under the cursor
func s:Evaluate(range, arg)
  if a:arg != ''
    let expr = a:arg
  elseif a:range == 2
    let pos = getcurpos()
    let reg = getreg('v', 1, 1)
    let regt = getregtype('v')
    normal! gv"vy
    let expr = @v
    call setpos('.', pos)
    call setreg('v', reg, regt)
  else
    let expr = expand('<cexpr>')
  endif
  let s:ignoreEvalError = 0
  call s:SendEval(expr)
endfunc

let s:ignoreEvalError = 0
let s:evalFromBalloonExpr = 0

" Handle the result of data-evaluate-expression
func s:HandleEvaluate(msg)
  let value = substitute(a:msg, '.*value="\(.*\)"', '\1', '')
  let value = substitute(value, '\\"', '"', 'g')
  if s:evalFromBalloonExpr
    if s:evalFromBalloonExprResult == ''
      let s:evalFromBalloonExprResult = s:evalexpr . ': ' . value
    else
      let s:evalFromBalloonExprResult .= ' = ' . value
    endif
    call balloon_show(s:evalFromBalloonExprResult)
  else
    echomsg '"' . s:evalexpr . '": ' . value
  endif

  if s:evalexpr[0] != '*' && value =~ '^0x' && value != '0x0' && value !~ '"$'
    " Looks like a pointer, also display what it points to.
    let s:ignoreEvalError = 1
    call s:SendEval('*' . s:evalexpr)
  else
    let s:evalFromBalloonExpr = 0
  endif
endfunc

" Show a balloon with information of the variable under the mouse pointer,
" if there is any.
func TermDebugBalloonExpr()
  if v:beval_winid != s:startwin
    return
  endif
  let s:evalFromBalloonExpr = 1
  let s:evalFromBalloonExprResult = ''
  let s:ignoreEvalError = 1
  call s:SendEval(v:beval_text)
  return ''
endfunc

" Handle an error.
func s:HandleError(msg)
  if s:ignoreEvalError
    " Result of s:SendEval() failed, ignore.
    let s:ignoreEvalError = 0
    let s:evalFromBalloonExpr = 0
    return
  endif
  echoerr substitute(a:msg, '.*msg="\(.*\)"', '\1', '')
endfunc

func s:GotoStartwinOrCreateIt()
  if !win_gotoid(s:startwin)
    new
    let s:startwin = win_getid(winnr())
    call s:InstallWinbar()
  endif
endfunc

" Handle stopping and running message from gdb.
" Will update the sign that shows the current position.
func s:HandleCursor(msg)
  let wid = win_getid(winnr())

  if a:msg =~ '^\*stopped'
    let s:stopped = 1
  elseif a:msg =~ '^\*running'
    let s:stopped = 0
  endif

  call s:GotoStartwinOrCreateIt()

  let fname = substitute(a:msg, '.*fullname="\([^"]*\)".*', '\1', '')
  if a:msg =~ '^\(\*stopped\|=thread-selected\)' && filereadable(fname)
    let lnum = substitute(a:msg, '.*line="\([^"]*\)".*', '\1', '')
    if lnum =~ '^[0-9]*$'
      if expand('%:p') != fnamemodify(fname, ':p')
	if &modified
	  " TODO: find existing window
	  exe 'split ' . fnameescape(fname)
	  let s:startwin = win_getid(winnr())
	  call s:InstallWinbar()
	else
	  exe 'edit ' . fnameescape(fname)
	endif
      endif
      exe lnum
      exe 'sign unplace ' . s:pc_id
      exe 'sign place ' . s:pc_id . ' line=' . lnum . ' name=debugPC file=' . fname
      setlocal signcolumn=yes
    endif
  else
    exe 'sign unplace ' . s:pc_id
  endif

  call win_gotoid(wid)
endfunc

" Handle setting a breakpoint
" Will update the sign that shows the breakpoint
func s:HandleNewBreakpoint(msg)
  let nr = substitute(a:msg, '.*number="\([0-9]\)*\".*', '\1', '') + 0
  if nr == 0
    return
  endif

  if has_key(s:breakpoints, nr)
    let entry = s:breakpoints[nr]
  else
    let entry = {}
    let s:breakpoints[nr] = entry
  endif

  let fname = substitute(a:msg, '.*fullname="\([^"]*\)".*', '\1', '')
  let lnum = substitute(a:msg, '.*line="\([^"]*\)".*', '\1', '')
  let entry['fname'] = fname
  let entry['lnum'] = lnum

  if bufloaded(fname)
    call s:PlaceSign(nr, entry)
  endif
endfunc

func s:PlaceSign(nr, entry)
  exe 'sign place ' . (s:break_id + a:nr) . ' line=' . a:entry['lnum'] . ' name=debugBreakpoint file=' . a:entry['fname']
  let a:entry['placed'] = 1
endfunc

" Handle deleting a breakpoint
" Will remove the sign that shows the breakpoint
func s:HandleBreakpointDelete(msg)
  let nr = substitute(a:msg, '.*id="\([0-9]*\)\".*', '\1', '') + 0
  if nr == 0
    return
  endif
  if has_key(s:breakpoints, nr)
    let entry = s:breakpoints[nr]
    if has_key(entry, 'placed')
      exe 'sign unplace ' . (s:break_id + nr)
      unlet entry['placed']
    endif
    unlet s:breakpoints[nr]
  endif
endfunc

" Handle a BufRead autocommand event: place any signs.
func s:BufRead()
  let fname = expand('<afile>:p')
  for [nr, entry] in items(s:breakpoints)
    if entry['fname'] == fname
      call s:PlaceSign(nr, entry)
    endif
  endfor
endfunc

" Handle a BufUnloaded autocommand event: unplace any signs.
func s:BufUnloaded()
  let fname = expand('<afile>:p')
  for [nr, entry] in items(s:breakpoints)
    if entry['fname'] == fname
      let entry['placed'] = 0
    endif
  endfor
endfunc

