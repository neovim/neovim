" Debugger plugin using gdb.
"
" Author: Bram Moolenaar
" Copyright: Vim license applies, see ":help license"
" Last Change: 2023 Nov 02
"
" WORK IN PROGRESS - The basics works stable, more to come
" Note: In general you need at least GDB 7.12 because this provides the
" frame= response in MI thread-selected events we need to sync stack to file.
" The one included with "old" MingW is too old (7.6.1), you may upgrade it or
" use a newer version from http://www.equation.com/servlet/equation.cmd?fa=gdb
"
" There are two ways to run gdb:
" - In a terminal window; used if possible, does not work on MS-Windows
"   Not used when g:termdebug_use_prompt is set to 1.
" - Using a "prompt" buffer; may use a terminal window for the program
"
" For both the current window is used to view source code and shows the
" current statement from gdb.
"
" USING A TERMINAL WINDOW
"
" Opens two visible terminal windows:
" 1. runs a pty for the debugged program, as with ":term NONE"
" 2. runs gdb, passing the pty of the debugged program
" A third terminal window is hidden, it is used for communication with gdb.
"
" USING A PROMPT BUFFER
"
" Opens a window with a prompt buffer to communicate with gdb.
" Gdb is run as a job with callbacks for I/O.
" On Unix another terminal window is opened to run the debugged program
" On MS-Windows a separate console is opened to run the debugged program
"
" The communication with gdb uses GDB/MI.  See:
" https://sourceware.org/gdb/current/onlinedocs/gdb/GDB_002fMI.html
"
" NEOVIM COMPATIBILITY
"
" The vim specific functionalities were replaced with neovim specific calls:
" - term_start -> termopen
" - term_sendkeys -> chansend
" - term_getline -> getbufline
" - job_info && term_getjob -> nvim_get_chan_info
" - balloon -> vim.lsp.util.open_floating_preview

func s:Echoerr(msg)
  echohl ErrorMsg | echom $'[termdebug] {a:msg}' | echohl None
endfunc

" In case this gets sourced twice.
if exists(':Termdebug')
  call s:Echoerr('Termdebug already loaded.')
  finish
endif

" The terminal feature does not work with gdb on win32.
if !has('win32')
  let s:way = 'terminal'
else
  let s:way = 'prompt'
endif

let s:keepcpo = &cpo
set cpo&vim

" The command that starts debugging, e.g. ":Termdebug vim".
" To end type "quit" in the gdb window.
command -nargs=* -complete=file -bang Termdebug call s:StartDebug(<bang>0, <f-args>)
command -nargs=+ -complete=file -bang TermdebugCommand call s:StartDebugCommand(<bang>0, <f-args>)

let s:pc_id = 12
let s:asm_id = 13
let s:break_id = 14  " breakpoint number is added to this
let s:stopped = v:true
let s:running = v:false

let s:parsing_disasm_msg = 0
let s:asm_lines = []
let s:asm_addr = ''

" Take a breakpoint number as used by GDB and turn it into an integer.
" The breakpoint may contain a dot: 123.4 -> 123004
" The main breakpoint has a zero subid.
func s:Breakpoint2SignNumber(id, subid)
  return s:break_id + a:id * 1000 + a:subid
endfunction

" Define or adjust the default highlighting, using background "new".
" When the 'background' option is set then "old" has the old value.
func s:Highlight(init, old, new)
  let default = a:init ? 'default ' : ''
  if a:new ==# 'light' && a:old !=# 'light'
    exe $"hi {default}debugPC term=reverse ctermbg=lightblue guibg=lightblue"
  elseif a:new ==# 'dark' && a:old !=# 'dark'
    exe $"hi {default}debugPC term=reverse ctermbg=darkblue guibg=darkblue"
  endif
endfunc

" Define the default highlighting, using the current 'background' value.
func s:InitHighlight()
  call s:Highlight(1, '', &background)
  hi default debugBreakpoint term=reverse ctermbg=red guibg=red
  hi default debugBreakpointDisabled term=reverse ctermbg=gray guibg=gray
endfunc

" Setup an autocommand to redefine the default highlight when the colorscheme
" is changed.
func s:InitAutocmd()
  augroup TermDebug
    autocmd!
    autocmd ColorScheme * call s:InitHighlight()
  augroup END
endfunc

" Get the command to execute the debugger as a list, defaults to ["gdb"].
func s:GetCommand()
  if exists('g:termdebug_config')
    let cmd = get(g:termdebug_config, 'command', 'gdb')
  elseif exists('g:termdebugger')
    let cmd = g:termdebugger
  else
    let cmd = 'gdb'
  endif

  return type(cmd) == v:t_list ? copy(cmd) : [cmd]
endfunc

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
    call s:Echoerr('Terminal debugger already running, cannot run two')
    return
  endif
  let gdbcmd = s:GetCommand()
  if !executable(gdbcmd[0])
    call s:Echoerr($'Cannot execute debugger program "{gdbcmd[0]}"')
    return
  endif

  let s:ptywin = 0
  let s:pid = 0
  let s:asmwin = 0
  let s:asmbufnr = 0
  let s:varwin = 0
  let s:varbufnr = 0

  if exists('#User#TermdebugStartPre')
    doauto <nomodeline> User TermdebugStartPre
  endif

  " Uncomment this line to write logging in "debuglog".
  " call ch_logfile('debuglog', 'w')

  let s:sourcewin = win_getid()

  " Remember the old value of 'signcolumn' for each buffer that it's set in, so
  " that we can restore the value for all buffers.
  let b:save_signcolumn = &signcolumn
  let s:signcolumn_buflist = [bufnr()]

  let s:saved_columns = 0
  let s:allleft = v:false
  let wide = 0
  if exists('g:termdebug_config')
    let wide = get(g:termdebug_config, 'wide', 0)
  elseif exists('g:termdebug_wide')
    let wide = g:termdebug_wide
  endif
  if wide > 0
    if &columns < wide
      let s:saved_columns = &columns
      let &columns = wide
      " If we make the Vim window wider, use the whole left half for the debug
      " windows.
      let s:allleft = v:true
    endif
    let s:vertical = v:true
  else
    let s:vertical = v:false
  endif

  " Override using a terminal window by setting g:termdebug_use_prompt to 1.
  let use_prompt = 0
  if exists('g:termdebug_config')
    let use_prompt = get(g:termdebug_config, 'use_prompt', 0)
  elseif exists('g:termdebug_use_prompt')
    let use_prompt = g:termdebug_use_prompt
  endif
  if !has('win32') && !use_prompt
    let s:way = 'terminal'
  else
    let s:way = 'prompt'
  endif

  if s:way == 'prompt'
    call s:StartDebug_prompt(a:dict)
  else
    call s:StartDebug_term(a:dict)
  endif

  if s:GetDisasmWindow()
    let curwinid = win_getid()
    call s:GotoAsmwinOrCreateIt()
    call win_gotoid(curwinid)
  endif

  if s:GetVariablesWindow()
    let curwinid = win_getid()
    call s:GotoVariableswinOrCreateIt()
    call win_gotoid(curwinid)
  endif

  if exists('#User#TermdebugStartPost')
    doauto <nomodeline> User TermdebugStartPost
  endif
endfunc

" Use when debugger didn't start or ended.
func s:CloseBuffers()
  exe $'bwipe! {s:ptybufnr}'
  if s:asmbufnr > 0 && bufexists(s:asmbufnr)
    exe $'bwipe! {s:asmbufnr}'
  endif
  if s:varbufnr > 0 && bufexists(s:varbufnr)
    exe $'bwipe! {s:varbufnr}'
  endif
  let s:running = v:false
  unlet! s:gdbwin
endfunc

func s:IsGdbStarted()
  if !s:gdb_running
    let cmd_name = string(s:GetCommand()[0])
    call s:Echoerr($'{cmd_name} exited unexpectedly')
    call s:CloseBuffers()
    return v:false
  endif
  return v:true
endfunc

" Open a terminal window without a job, to run the debugged program in.
func s:StartDebug_term(dict)
  execute s:vertical ? 'vnew' : 'new'
  let s:pty_job_id = termopen('tail -f /dev/null;#gdb program')
  if s:pty_job_id == 0
    call s:Echoerr('Invalid argument (or job table is full) while opening terminal window')
    return
  elseif s:pty_job_id == -1
    call s:Echoerr('Failed to open the program terminal window')
    return
  endif
  let pty_job_info = nvim_get_chan_info(s:pty_job_id)
  let s:ptybufnr = pty_job_info['buffer']
  let pty = pty_job_info['pty']
  let s:ptywin = win_getid()
  if s:vertical
    " Assuming the source code window will get a signcolumn, use two more
    " columns for that, thus one less for the terminal window.
    exe $":{(&columns / 2 - 1)}wincmd |"
    if s:allleft
      " use the whole left column
      wincmd H
    endif
  endif

  " Create a hidden terminal window to communicate with gdb
  let s:comm_job_id = jobstart('tail -f /dev/null;#gdb communication', {
        \ 'on_stdout': function('s:JobOutCallback', {'last_line': '', 'real_cb': function('s:CommOutput')}),
        \ 'pty': v:true,
        \ })
  " hide terminal buffer
  if s:comm_job_id == 0
    call s:Echoerr('Invalid argument (or job table is full) while opening communication terminal window')
    exe 'bwipe! ' . s:ptybufnr
    return
  elseif s:comm_job_id == -1
    call s:Echoerr('Failed to open the communication terminal window')
    exe $'bwipe! {s:ptybufnr}'
    return
  endif
  let comm_job_info = nvim_get_chan_info(s:comm_job_id)
  let commpty = comm_job_info['pty']

  let gdb_args = get(a:dict, 'gdb_args', [])
  let proc_args = get(a:dict, 'proc_args', [])

  let gdb_cmd = s:GetCommand()

  if exists('g:termdebug_config') && has_key(g:termdebug_config, 'command_add_args')
    let gdb_cmd = g:termdebug_config.command_add_args(gdb_cmd, pty)
  else
    " Add -quiet to avoid the intro message causing a hit-enter prompt.
    let gdb_cmd += ['-quiet']
    " Disable pagination, it causes everything to stop at the gdb
    let gdb_cmd += ['-iex', 'set pagination off']
    " Interpret commands while the target is running.  This should usually only
    " be exec-interrupt, since many commands don't work properly while the
    " target is running (so execute during startup).
    let gdb_cmd += ['-iex', 'set mi-async on']
    " Open a terminal window to run the debugger.
    let gdb_cmd += ['-tty', pty]
    " Command executed _after_ startup is done, provides us with the necessary
    " feedback
    let gdb_cmd += ['-ex', 'echo startupdone\n']
  endif

  if exists('g:termdebug_config') && has_key(g:termdebug_config, 'command_filter')
    let gdb_cmd = g:termdebug_config.command_filter(gdb_cmd)
  endif

  " Adding arguments requested by the user
  let gdb_cmd += gdb_args

  execute 'new'
  " call ch_log($'executing "{join(gdb_cmd)}"')
  let s:gdb_job_id = termopen(gdb_cmd, {'on_exit': function('s:EndTermDebug')})
  if s:gdb_job_id == 0
    call s:Echoerr('Invalid argument (or job table is full) while opening gdb terminal window')
    exe 'bwipe! ' . s:ptybufnr
    return
  elseif s:gdb_job_id == -1
    call s:Echoerr('Failed to open the gdb terminal window')
    call s:CloseBuffers()
    return
  endif
  let s:gdb_running = v:true
  let s:starting = v:true
  let gdb_job_info = nvim_get_chan_info(s:gdb_job_id)
  let s:gdbbufnr = gdb_job_info['buffer']
  let s:gdbwin = win_getid()

  " Wait for the "startupdone" message before sending any commands.
  let try_count = 0
  while 1
    if !s:IsGdbStarted()
      return
    endif

    for lnum in range(1, 200)
      if get(getbufline(s:gdbbufnr, lnum), 0, '') =~ 'startupdone'
        let try_count = 9999
        break
      endif
    endfor
    let try_count += 1
    if try_count > 300
      " done or give up after five seconds
      break
    endif
    sleep 10m
  endwhile

  " Set arguments to be run.
  if !empty(proc_args)
    call chansend(s:gdb_job_id, $"server set args {join(proc_args)}\r")
  endif

  " Connect gdb to the communication pty, using the GDB/MI interface.
  " Prefix "server" to avoid adding this to the history.
  call chansend(s:gdb_job_id, $"server new-ui mi {commpty}\r")

  " Wait for the response to show up, users may not notice the error and wonder
  " why the debugger doesn't work.
  let try_count = 0
  while 1
    if !s:IsGdbStarted()
      return
    endif

    let response = ''
    for lnum in range(1, 200)
      let line1 = get(getbufline(s:gdbbufnr, lnum), 0, '')
      let line2 = get(getbufline(s:gdbbufnr, lnum + 1), 0, '')
      if line1 =~ 'new-ui mi '
        " response can be in the same line or the next line
        let response = line1 . line2
        if response =~ 'Undefined command'
          call s:Echoerr('Sorry, your gdb is too old, gdb 7.12 is required')
          " CHECKME: possibly send a "server show version" here
          call s:CloseBuffers()
          return
        endif
        if response =~ 'New UI allocated'
          " Success!
          break
        endif
      elseif line1 =~ 'Reading symbols from' && line2 !~ 'new-ui mi '
        " Reading symbols might take a while, try more times
        let try_count -= 1
      endif
    endfor
    if response =~ 'New UI allocated'
      break
    endif
    let try_count += 1
    if try_count > 100
      call s:Echoerr('Cannot check if your gdb works, continuing anyway')
      break
    endif
    sleep 10m
  endwhile

  let s:starting = v:false

  " Set the filetype, this can be used to add mappings.
  set filetype=termdebug

  call s:StartDebugCommon(a:dict)
endfunc

" Open a window with a prompt buffer to run gdb in.
func s:StartDebug_prompt(dict)
  if s:vertical
    vertical new
  else
    new
  endif
  let s:gdbwin = win_getid()
  let s:promptbuf = bufnr('')
  call prompt_setprompt(s:promptbuf, 'gdb> ')
  set buftype=prompt

  if empty(glob('gdb'))
    file gdb
  elseif empty(glob('Termdebug-gdb-console'))
    file Termdebug-gdb-console
  else
    call s:Echoerr("You have a file/folder named 'gdb'
          \ or 'Termdebug-gdb-console'.
          \ Please exit and rename them because Termdebug may not work as expected.")
  endif

  call prompt_setcallback(s:promptbuf, function('s:PromptCallback'))
  call prompt_setinterrupt(s:promptbuf, function('s:PromptInterrupt'))

  if s:vertical
    " Assuming the source code window will get a signcolumn, use two more
    " columns for that, thus one less for the terminal window.
    exe $":{(&columns / 2 - 1)}wincmd |"
  endif

  let gdb_args = get(a:dict, 'gdb_args', [])
  let proc_args = get(a:dict, 'proc_args', [])

  let gdb_cmd = s:GetCommand()
  " Add -quiet to avoid the intro message causing a hit-enter prompt.
  let gdb_cmd += ['-quiet']
  " Disable pagination, it causes everything to stop at the gdb, needs to be run early
  let gdb_cmd += ['-iex', 'set pagination off']
  " Interpret commands while the target is running.  This should usually only
  " be exec-interrupt, since many commands don't work properly while the
  " target is running (so execute during startup).
  let gdb_cmd += ['-iex', 'set mi-async on']
  " directly communicate via mi2
  let gdb_cmd += ['--interpreter=mi2']

  " Adding arguments requested by the user
  let gdb_cmd += gdb_args

  " call ch_log($'executing "{join(gdb_cmd)}"')
  let s:gdbjob = jobstart(gdb_cmd, {
        \ 'on_exit': function('s:EndPromptDebug'),
        \ 'on_stdout': function('s:JobOutCallback', {'last_line': '', 'real_cb': function('s:GdbOutCallback')}),
        \ })
  if s:gdbjob == 0
    call s:Echoerr('Invalid argument (or job table is full) while starting gdb job')
    exe $'bwipe! {s:ptybufnr}'
    return
  elseif s:gdbjob == -1
    call s:Echoerr('Failed to start the gdb job')
    call s:CloseBuffers()
    return
  endif
  exe $'au BufUnload <buffer={s:promptbuf}> ++once call jobstop(s:gdbjob)'

  let s:ptybufnr = 0
  if has('win32')
    " MS-Windows: run in a new console window for maximum compatibility
    call s:SendCommand('set new-console on')
  else
    " Unix: Run the debugged program in a terminal window.  Open it below the
    " gdb window.
    belowright new
    let s:pty_job_id = termopen('tail -f /dev/null;#gdb program')
    if s:pty_job_id == 0
      call s:Echoerr('Invalid argument (or job table is full) while opening terminal window')
      return
    elseif s:pty_job_id == -1
      call s:Echoerr('Failed to open the program terminal window')
      return
    endif
    let pty_job_info = nvim_get_chan_info(s:pty_job_id)
    let s:ptybufnr = pty_job_info['buffer']
    let pty = pty_job_info['pty']
    let s:ptywin = win_getid()
    call s:SendCommand($'tty {pty}')

    " Since GDB runs in a prompt window, the environment has not been set to
    " match a terminal window, need to do that now.
    call s:SendCommand('set env TERM = xterm-color')
    call s:SendCommand($'set env ROWS = {winheight(s:ptywin)}')
    call s:SendCommand($'set env LINES = {winheight(s:ptywin)}')
    call s:SendCommand($'set env COLUMNS = {winwidth(s:ptywin)}')
    call s:SendCommand($'set env COLORS = {&t_Co}')
    call s:SendCommand($'set env VIM_TERMINAL = {v:version}')
  endif
  call s:SendCommand('set print pretty on')
  call s:SendCommand('set breakpoint pending on')

  " Set arguments to be run
  if len(proc_args)
    call s:SendCommand($'set args {join(proc_args)}')
  endif

  call s:StartDebugCommon(a:dict)
  startinsert
endfunc

func s:StartDebugCommon(dict)
  " Sign used to highlight the line where the program has stopped.
  " There can be only one.
  call sign_define('debugPC', #{linehl: 'debugPC'})

  " Install debugger commands in the text window.
  call win_gotoid(s:sourcewin)
  call s:InstallCommands()
  call win_gotoid(s:gdbwin)

  " Contains breakpoints that have been placed, key is a string with the GDB
  " breakpoint number.
  " Each entry is a dict, containing the sub-breakpoints.  Key is the subid.
  " For a breakpoint that is just a number the subid is zero.
  " For a breakpoint "123.4" the id is "123" and subid is "4".
  " Example, when breakpoint "44", "123", "123.1" and "123.2" exist:
  " {'44': {'0': entry}, '123': {'0': entry, '1': entry, '2': entry}}
  let s:breakpoints = {}

  " Contains breakpoints by file/lnum.  The key is "fname:lnum".
  " Each entry is a list of breakpoint IDs at that position.
  let s:breakpoint_locations = {}

  augroup TermDebug
    au BufRead * call s:BufRead()
    au BufUnload * call s:BufUnloaded()
    au OptionSet background call s:Highlight(0, v:option_old, v:option_new)
  augroup END

  " Run the command if the bang attribute was given and got to the debug
  " window.
  if get(a:dict, 'bang', 0)
    call s:SendResumingCommand('-exec-run')
    call win_gotoid(s:ptywin)
  endif
endfunc

" Send a command to gdb.  "cmd" is the string without line terminator.
func s:SendCommand(cmd)
  " call ch_log($'sending to gdb: {a:cmd}')
  if s:way == 'prompt'
    call chansend(s:gdbjob, $"{a:cmd}\n")
  else
    call chansend(s:comm_job_id, $"{a:cmd}\r")
  endif
endfunc

" This is global so that a user can create their mappings with this.
func TermDebugSendCommand(cmd)
  if s:way == 'prompt'
    call chansend(s:gdbjob, $"{a:cmd}\n")
  else
    let do_continue = 0
    if !s:stopped
      let do_continue = 1
      if s:way == 'prompt'
        " Need to send a signal to get the UI to listen.  Strangely this is only
        " needed once.
        call jobstop(s:gdbjob)
      else
        Stop
      endif
      sleep 10m
    endif
    " TODO: should we prepend CTRL-U to clear the command?
    call chansend(s:gdb_job_id, $"{a:cmd}\r")
    if do_continue
      Continue
    endif
  endif
endfunc

" Send a command that resumes the program.  If the program isn't stopped the
" command is not sent (to avoid a repeated command to cause trouble).
" If the command is sent then reset s:stopped.
func s:SendResumingCommand(cmd)
  if s:stopped
    " reset s:stopped here, it may take a bit of time before we get a response
    let s:stopped = v:false
    " call ch_log('assume that program is running after this command')
    call s:SendCommand(a:cmd)
  " else
    " call ch_log($'dropping command, program is running: {a:cmd}')
  endif
endfunc

" Function called when entering a line in the prompt buffer.
func s:PromptCallback(text)
  call s:SendCommand(a:text)
endfunc

" Function called when pressing CTRL-C in the prompt buffer and when placing a
" breakpoint.
func s:PromptInterrupt()
  " call ch_log('Interrupting gdb')
  if has('win32')
    " Using job_stop() does not work on MS-Windows, need to send SIGTRAP to
    " the debugger program so that gdb responds again.
    if s:pid == 0
      call s:Echoerr('Cannot interrupt gdb, did not find a process ID')
    else
      call debugbreak(s:pid)
    endif
  else
    call v:lua.vim.uv.kill(jobpid(s:gdbjob), 'sigint')
  endif
endfunc

" Wrapper around job callback that handles partial lines (:h channel-lines).
" It should be called from a Dictionary with the following keys:
" - last_line: the last (partial) line received
" - real_cb: a callback that assumes full lines
func s:JobOutCallback(jobid, data, event) dict
  let eof = (a:data == [''])
  let msgs = a:data
  let msgs[0] = self.last_line .. msgs[0]
  if eof
    let self.last_line = ''
  else
    let self.last_line = msgs[-1]
    unlet msgs[-1]
  endif
  call self.real_cb(a:jobid, msgs, a:event)
endfunc

" Function called when gdb outputs text.
func s:GdbOutCallback(job_id, msgs, event)
  " call ch_log($'received from gdb: {a:text}')

  let comm_msgs = []
  let lines = []

  for msg in a:msgs
    " Disassembly messages need to be forwarded as-is.
    if s:parsing_disasm_msg || msg =~ '^&"disassemble'
      call s:CommOutput(a:job_id, [msg], a:event)
      continue
    endif

    " Drop the gdb prompt, we have our own.
    " Drop status and echo'd commands.
    if msg == '(gdb) ' || msg == '^done' || msg[0] == '&'
      continue
    endif

    if msg =~ '^\^error,msg='
      if exists('s:evalexpr')
            \ && s:DecodeMessage(msg[11:], v:false)
            \    =~ 'A syntax error in expression, near\|No symbol .* in current context'
        " Silently drop evaluation errors.
        unlet s:evalexpr
        continue
      endif
    elseif msg[0] == '~'
      call add(lines, s:DecodeMessage(msg[1:], v:false))
      continue
    endif

    call add(comm_msgs, msg)
  endfor

  let curwinid = win_getid()
  call win_gotoid(s:gdbwin)

  " Add the output above the current prompt.
  for line in lines
    call append(line('$') - 1, line)
  endfor
  if !empty(lines)
    set modified
  endif

  call win_gotoid(curwinid)
  call s:CommOutput(a:job_id, comm_msgs, a:event)
endfunc

" Decode a message from gdb.  "quotedText" starts with a ", return the text up
" to the next unescaped ", unescaping characters:
" - remove line breaks (unless "literal" is v:true)
" - change \" to "
" - change \\t to \t (unless "literal" is v:true)
" - change \0xhh to \xhh (disabled for now)
" - change \ooo to octal
" - change \\ to \
func s:DecodeMessage(quotedText, literal)
  if a:quotedText[0] != '"'
    call s:Echoerr($'DecodeMessage(): missing quote in {a:quotedText}')
    return
  endif
  let msg = a:quotedText
        \ ->substitute('^"\|[^\\]\zs".*', '', 'g')
        \ ->substitute('\\"', '"', 'g')
        "\ multi-byte characters arrive in octal form
        "\ NULL-values must be kept encoded as those break the string otherwise
        \ ->substitute('\\000', s:NullRepl, 'g')
        \ ->substitute('\\\o\o\o', {-> eval('"' .. submatch(0) .. '"')}, 'g')
        "\ Note: GDB docs also mention hex encodings - the translations below work
        "\       but we keep them out for performance-reasons until we actually see
        "\       those in mi-returns
        "\ \ ->substitute('\\0x\(\x\x\)', {-> eval('"\x' .. submatch(1) .. '"')}, 'g')
        "\ \ ->substitute('\\0x00', s:NullRepl, 'g')
        \ ->substitute('\\\\', '\', 'g')
        \ ->substitute(s:NullRepl, '\\000', 'g')
  if !a:literal
    return msg
        \ ->substitute('\\t', "\t", 'g')
        \ ->substitute('\\n', '', 'g')
  else
    return msg
  endif
endfunc
const s:NullRepl = 'XXXNULLXXX'

" Extract the "name" value from a gdb message with fullname="name".
func s:GetFullname(msg)
  if a:msg !~ 'fullname'
    return ''
  endif
  let name = s:DecodeMessage(substitute(a:msg, '.*fullname=', '', ''), v:true)
  if has('win32') && name =~ ':\\\\'
    " sometimes the name arrives double-escaped
    let name = substitute(name, '\\\\', '\\', 'g')
  endif
  return name
endfunc

" Extract the "addr" value from a gdb message with addr="0x0001234".
func s:GetAsmAddr(msg)
  if a:msg !~ 'addr='
    return ''
  endif
  let addr = s:DecodeMessage(substitute(a:msg, '.*addr=', '', ''), v:false)
  return addr
endfunc

func s:EndTermDebug(job_id, exit_code, event)
  let s:gdb_running = v:false
  if s:starting
    return
  endif

  if exists('#User#TermdebugStopPre')
    doauto <nomodeline> User TermdebugStopPre
  endif

  unlet s:gdbwin
  call s:EndDebugCommon()
endfunc

func s:EndDebugCommon()
  let curwinid = win_getid()

  if exists('s:ptybufnr') && s:ptybufnr
    exe $'bwipe! {s:ptybufnr}'
  endif
  if s:asmbufnr > 0 && bufexists(s:asmbufnr)
    exe $'bwipe! {s:asmbufnr}'
  endif
  if s:varbufnr > 0 && bufexists(s:varbufnr)
    exe $'bwipe! {s:varbufnr}'
  endif
  let s:running = v:false

  " Restore 'signcolumn' in all buffers for which it was set.
  call win_gotoid(s:sourcewin)
  let was_buf = bufnr()
  for bufnr in s:signcolumn_buflist
    if bufexists(bufnr)
      exe $":{bufnr}buf"
      if exists('b:save_signcolumn')
        let &signcolumn = b:save_signcolumn
        unlet b:save_signcolumn
      endif
    endif
  endfor
  if bufexists(was_buf)
    exe $":{was_buf}buf"
  endif

  call s:DeleteCommands()

  call win_gotoid(curwinid)

  if s:saved_columns > 0
    let &columns = s:saved_columns
  endif

  if exists('#User#TermdebugStopPost')
    doauto <nomodeline> User TermdebugStopPost
  endif

  au! TermDebug
endfunc

func s:EndPromptDebug(job_id, exit_code, event)
  if exists('#User#TermdebugStopPre')
    doauto <nomodeline> User TermdebugStopPre
  endif

  if bufexists(s:promptbuf)
    exe $'bwipe! {s:promptbuf}'
  endif

  call s:EndDebugCommon()
  unlet s:gdbwin
  "call ch_log("Returning from EndPromptDebug()")
endfunc

" - CommOutput: &"disassemble $pc\n"
" - CommOutput: ~"Dump of assembler code for function main(int, char**):\n"
" - CommOutput: ~"   0x0000555556466f69 <+0>:\tpush   rbp\n"
" ...
" - CommOutput: ~"   0x0000555556467cd0:\tpop    rbp\n"
" - CommOutput: ~"   0x0000555556467cd1:\tret    \n"
" - CommOutput: ~"End of assembler dump.\n"
" - CommOutput: ^done

" - CommOutput: &"disassemble $pc\n"
" - CommOutput: &"No function contains specified address.\n"
" - CommOutput: ^error,msg="No function contains specified address."
func s:HandleDisasmMsg(msg)
  if a:msg =~ '^\^done'
    let curwinid = win_getid()
    if win_gotoid(s:asmwin)
      silent! %delete _
      call setline(1, s:asm_lines)
      set nomodified
      set filetype=asm

      let lnum = search($'^{s:asm_addr}')
      if lnum != 0
        call sign_unplace('TermDebug', #{id: s:asm_id})
        call sign_place(s:asm_id, 'TermDebug', 'debugPC', '%', #{lnum: lnum})
      endif

      call win_gotoid(curwinid)
    endif

    let s:parsing_disasm_msg = 0
    let s:asm_lines = []
  elseif a:msg =~ '^\^error,msg='
    if s:parsing_disasm_msg == 1
      " Disassemble call ran into an error. This can happen when gdb can't
      " find the function frame address, so let's try to disassemble starting
      " at current PC
      call s:SendCommand('disassemble $pc,+100')
    endif
    let s:parsing_disasm_msg = 0
  elseif a:msg =~ '^&"disassemble \$pc'
    if a:msg =~ '+100'
      " This is our second disasm attempt
      let s:parsing_disasm_msg = 2
    endif
  elseif a:msg !~ '^&"disassemble'
    let value = substitute(a:msg, '^\~\"[ ]*', '', '')
    let value = substitute(value, '^=>[ ]*', '', '')
    " Nvim already trims the final "\r" in s:CommOutput()
    " let value = substitute(value, '\\n\"\r$', '', '')
    let value = substitute(value, '\\n\"$', '', '')
    let value = substitute(value, '\r', '', '')
    let value = substitute(value, '\\t', ' ', 'g')

    if value != '' || !empty(s:asm_lines)
      call add(s:asm_lines, value)
    endif
  endif
endfunc

func s:ParseVarinfo(varinfo)
  let dict = {}
  let nameIdx = matchstrpos(a:varinfo, '{name="\([^"]*\)"')
  let dict['name'] = a:varinfo[nameIdx[1] + 7 : nameIdx[2] - 2]
  let typeIdx = matchstrpos(a:varinfo, ',type="\([^"]*\)"')
  " 'type' maybe is a url-like string,
  " try to shorten it and show only the /tail
  let dict['type'] = (a:varinfo[typeIdx[1] + 7 : typeIdx[2] - 2])->fnamemodify(':t')
  let valueIdx = matchstrpos(a:varinfo, ',value="\(.*\)"}')
  if valueIdx[1] == -1
    let dict['value'] = 'Complex value'
  else
    let dict['value'] = a:varinfo[valueIdx[1] + 8 : valueIdx[2] - 3]
  endif
  return dict
endfunc

func s:HandleVariablesMsg(msg)
  let curwinid = win_getid()
  if win_gotoid(s:varwin)

    silent! %delete _
    let spaceBuffer = 20
    let spaces = repeat(' ', 16)
    call setline(1, $'Type{spaces}Name{spaces}Value')
    let cnt = 1
    let capture = '{name=".\{-}",\%(arg=".\{-}",\)\{0,1\}type=".\{-}"\%(,value=".\{-}"\)\{0,1\}}'
    let varinfo = matchstr(a:msg, capture, 0, cnt)
    while varinfo != ''
      let vardict = s:ParseVarinfo(varinfo)
      call setline(cnt + 1, vardict['type'] .
            \ repeat(' ', max([20 - len(vardict['type']), 1])) .
            \ vardict['name'] .
            \ repeat(' ', max([20 - len(vardict['name']), 1])) .
            \ vardict['value'])
      let cnt += 1
      let varinfo = matchstr(a:msg, capture, 0, cnt)
    endwhile
  endif
  call win_gotoid(curwinid)
endfunc

func s:CommOutput(job_id, msgs, event)
  for msg in a:msgs
    " Nvim job lines are split on "\n", so trim a suffixed CR.
    if msg[-1:] == "\r"
      let msg = msg[:-2]
    endif

    if s:parsing_disasm_msg
      call s:HandleDisasmMsg(msg)
    elseif msg != ''
      if msg =~ '^\(\*stopped\|\*running\|=thread-selected\)'
        call s:HandleCursor(msg)
      elseif msg =~ '^\^done,bkpt=' || msg =~ '^=breakpoint-created,'
        call s:HandleNewBreakpoint(msg, 0)
      elseif msg =~ '^=breakpoint-modified,'
        call s:HandleNewBreakpoint(msg, 1)
      elseif msg =~ '^=breakpoint-deleted,'
        call s:HandleBreakpointDelete(msg)
      elseif msg =~ '^=thread-group-started'
        call s:HandleProgramRun(msg)
      elseif msg =~ '^\^done,value='
        call s:HandleEvaluate(msg)
      elseif msg =~ '^\^error,msg='
        call s:HandleError(msg)
      elseif msg =~ '^&"disassemble'
        let s:parsing_disasm_msg = 1
        let s:asm_lines = []
        call s:HandleDisasmMsg(msg)
      elseif msg =~ '^\^done,variables='
        call s:HandleVariablesMsg(msg)
      endif
    endif
  endfor
endfunc

func s:GotoProgram()
  if has('win32')
    if executable('powershell')
      call system(printf('powershell -Command "add-type -AssemblyName microsoft.VisualBasic;[Microsoft.VisualBasic.Interaction]::AppActivate(%d);"', s:pid))
    endif
  else
    call win_gotoid(s:ptywin)
  endif
endfunc

" Install commands in the current window to control the debugger.
func s:InstallCommands()
  let save_cpo = &cpo
  set cpo&vim

  command -nargs=? Break call s:SetBreakpoint(<q-args>)
  command -nargs=? Tbreak call s:SetBreakpoint(<q-args>, v:true)
  command Clear call s:ClearBreakpoint()
  command Step call s:SendResumingCommand('-exec-step')
  command Over call s:SendResumingCommand('-exec-next')
  command -nargs=? Until call s:Until(<q-args>)
  command Finish call s:SendResumingCommand('-exec-finish')
  command -nargs=* Run call s:Run(<q-args>)
  command -nargs=* Arguments call s:SendResumingCommand('-exec-arguments ' . <q-args>)

  if s:way == 'prompt'
    command Stop call s:PromptInterrupt()
    command Continue call s:SendCommand('continue')
  else
    command Stop call s:SendCommand('-exec-interrupt')
    " using -exec-continue results in CTRL-C in the gdb window not working,
    " communicating via commbuf (= use of SendCommand) has the same result
    "command Continue  call s:SendCommand('-exec-continue')
    command Continue call chansend(s:gdb_job_id, "continue\r")
  endif

  command -nargs=* Frame call s:Frame(<q-args>)
  command -count=1 Up call s:Up(<count>)
  command -count=1 Down call s:Down(<count>)

  command -range -nargs=* Evaluate call s:Evaluate(<range>, <q-args>)
  command Gdb call win_gotoid(s:gdbwin)
  command Program call s:GotoProgram()
  command Source call s:GotoSourcewinOrCreateIt()
  command Asm call s:GotoAsmwinOrCreateIt()
  command Var call s:GotoVariableswinOrCreateIt()
  command Winbar call s:InstallWinbar(1)

  let map = 1
  if exists('g:termdebug_config')
    let map = get(g:termdebug_config, 'map_K', 1)
  elseif exists('g:termdebug_map_K')
    let map = g:termdebug_map_K
  endif
  if map
    let s:saved_K_map = maparg('K', 'n', 0, 1)
    if !empty(s:saved_K_map) && !s:saved_K_map.buffer || empty(s:saved_K_map)
      nnoremap K :Evaluate<CR>
    endif
  endif

  let map = 1
  if exists('g:termdebug_config')
    let map = get(g:termdebug_config, 'map_plus', 1)
  endif
  if map
    let s:saved_plus_map = maparg('+', 'n', 0, 1)
    if !empty(s:saved_plus_map) && !s:saved_plus_map.buffer || empty(s:saved_plus_map)
      nnoremap <expr> + $'<Cmd>{v:count1}Up<CR>'
    endif
  endif

  let map = 1
  if exists('g:termdebug_config')
    let map = get(g:termdebug_config, 'map_minus', 1)
  endif
  if map
    let s:saved_minus_map = maparg('-', 'n', 0, 1)
    if !empty(s:saved_minus_map) && !s:saved_minus_map.buffer || empty(s:saved_minus_map)
      nnoremap <expr> - $'<Cmd>{v:count1}Down<CR>'
    endif
  endif


  if has('menu') && &mouse != ''
    call s:InstallWinbar(0)

    let popup = 1
    if exists('g:termdebug_config')
      let popup = get(g:termdebug_config, 'popup', 1)
    elseif exists('g:termdebug_popup')
      let popup = g:termdebug_popup
    endif
    if popup
      let s:saved_mousemodel = &mousemodel
      let &mousemodel = 'popup_setpos'
      an 1.200 PopUp.-SEP3-     <Nop>
      an 1.210 PopUp.Set\ breakpoint    :Break<CR>
      an 1.220 PopUp.Clear\ breakpoint  :Clear<CR>
      an 1.230 PopUp.Run\ until         :Until<CR>
      an 1.240 PopUp.Evaluate           :Evaluate<CR>
    endif
  endif

  let &cpo = save_cpo
endfunc

" let s:winbar_winids = []

" Install the window toolbar in the current window.
func s:InstallWinbar(force)
  " if has('menu') && &mouse != ''
  "   nnoremenu WinBar.Step   :Step<CR>
  "   nnoremenu WinBar.Next   :Over<CR>
  "   nnoremenu WinBar.Finish :Finish<CR>
  "   nnoremenu WinBar.Cont   :Continue<CR>
  "   nnoremenu WinBar.Stop   :Stop<CR>
  "   nnoremenu WinBar.Eval   :Evaluate<CR>
  "   call add(s:winbar_winids, win_getid())
  " endif
endfunc

" Delete installed debugger commands in the current window.
func s:DeleteCommands()
  delcommand Break
  delcommand Tbreak
  delcommand Clear
  delcommand Step
  delcommand Over
  delcommand Until
  delcommand Finish
  delcommand Run
  delcommand Arguments
  delcommand Stop
  delcommand Continue
  delcommand Frame
  delcommand Up
  delcommand Down
  delcommand Evaluate
  delcommand Gdb
  delcommand Program
  delcommand Source
  delcommand Asm
  delcommand Var
  delcommand Winbar

  if exists('s:saved_K_map')
    if !empty(s:saved_K_map) && !s:saved_K_map.buffer
      nunmap K
      call mapset(s:saved_K_map)
    elseif empty(s:saved_K_map)
      nunmap K
    endif
    unlet s:saved_K_map
  endif
  if exists('s:saved_plus_map')
    if !empty(s:saved_plus_map) && !s:saved_plus_map.buffer
      nunmap +
      call mapset(s:saved_plus_map)
    elseif empty(s:saved_plus_map)
      nunmap +
    endif
    unlet s:saved_plus_map
  endif
  if exists('s:saved_minus_map')
    if !empty(s:saved_minus_map) && !s:saved_minus_map.buffer
      nunmap -
      call mapset(s:saved_minus_map)
    elseif empty(s:saved_minus_map)
      nunmap -
    endif
    unlet s:saved_minus_map
  endif

  if has('menu')
    " Remove the WinBar entries from all windows where it was added.
    " let curwinid = win_getid()
    " for winid in s:winbar_winids
    "   if win_gotoid(winid)
    "     aunmenu WinBar.Step
    "     aunmenu WinBar.Next
    "     aunmenu WinBar.Finish
    "     aunmenu WinBar.Cont
    "     aunmenu WinBar.Stop
    "     aunmenu WinBar.Eval
    "   endif
    " endfor
    " call win_gotoid(curwinid)
    " let s:winbar_winids = []

    if exists('s:saved_mousemodel')
      let &mousemodel = s:saved_mousemodel
      unlet s:saved_mousemodel
      aunmenu PopUp.-SEP3-
      aunmenu PopUp.Set\ breakpoint
      aunmenu PopUp.Clear\ breakpoint
      aunmenu PopUp.Run\ until
      aunmenu PopUp.Evaluate
    endif
  endif

  call sign_unplace('TermDebug')
  unlet s:breakpoints
  unlet s:breakpoint_locations

  call sign_undefine('debugPC')
  call sign_undefine(s:BreakpointSigns->map("'debugBreakpoint' .. v:val"))
  let s:BreakpointSigns = []
endfunc

func s:QuoteArg(x)
  " Find all the occurrences of " and \ and escape them and double quote
  " the resulting string.
  return printf('"%s"', a:x->substitute('[\\"]', '\\&', 'g'))
endfunc

" :Until - Execute until past a specified position or current line
func s:Until(at)
  if s:stopped
    " reset s:stopped here, it may take a bit of time before we get a response
    let s:stopped = v:false
    " call ch_log('assume that program is running after this command')
    " Use the fname:lnum format
    let at = empty(a:at) ? s:QuoteArg($"{expand('%:p')}:{line('.')}") : a:at
    call s:SendCommand($'-exec-until {at}')
  " else
    " call ch_log('dropping command, program is running: exec-until')
  endif
endfunc

" :Break - Set a breakpoint at the cursor position.
func s:SetBreakpoint(at, tbreak=v:false)
  " Setting a breakpoint may not work while the program is running.
  " Interrupt to make it work.
  let do_continue = 0
  if !s:stopped
    let do_continue = 1
    Stop
    sleep 10m
  endif

  " Use the fname:lnum format, older gdb can't handle --source.
  let at = empty(a:at) ? s:QuoteArg($"{expand('%:p')}:{line('.')}") : a:at
  if a:tbreak
    let cmd = $'-break-insert -t {at}'
  else
    let cmd = $'-break-insert {at}'
  endif
  call s:SendCommand(cmd)
  if do_continue
    Continue
  endif
endfunc

" :Clear - Delete a breakpoint at the cursor position.
func s:ClearBreakpoint()
  let fname = fnameescape(expand('%:p'))
  let lnum = line('.')
  let bploc = printf('%s:%d', fname, lnum)
  if has_key(s:breakpoint_locations, bploc)
    let idx = 0
    let nr = 0
    for id in s:breakpoint_locations[bploc]
      if has_key(s:breakpoints, id)
        " Assume this always works, the reply is simply "^done".
        call s:SendCommand($'-break-delete {id}')
        for subid in keys(s:breakpoints[id])
          call sign_unplace('TermDebug',
                \ #{id: s:Breakpoint2SignNumber(id, subid)})
        endfor
        unlet s:breakpoints[id]
        unlet s:breakpoint_locations[bploc][idx]
        let nr = id
        break
      else
        let idx += 1
      endif
    endfor
    if nr != 0
      if empty(s:breakpoint_locations[bploc])
        unlet s:breakpoint_locations[bploc]
      endif
      echomsg $'Breakpoint {nr} cleared from line {lnum}.'
    else
      call s:Echoerr($'Internal error trying to remove breakpoint at line {lnum}!')
    endif
  else
    echomsg $'No breakpoint to remove at line {lnum}.'
  endif
endfunc

func s:Run(args)
  if a:args != ''
    call s:SendResumingCommand($'-exec-arguments {a:args}')
  endif
  call s:SendResumingCommand('-exec-run')
endfunc

" :Frame - go to a specific frame in the stack
func s:Frame(arg)
  " Note: we explicit do not use mi's command
  " call s:SendCommand('-stack-select-frame "' . a:arg .'"')
  " as we only get a "done" mi response and would have to open the file
  " 'manually' - using cli command "frame" provides us with the mi response
  " already parsed and allows for more formats
  if a:arg =~ '^\d\+$' || a:arg == ''
    " specify frame by number
    call s:SendCommand($'-interpreter-exec mi "frame {a:arg}"')
  elseif a:arg =~ '^0x[0-9a-fA-F]\+$'
    " specify frame by stack address
    call s:SendCommand($'-interpreter-exec mi "frame address {a:arg}"')
  else
    " specify frame by function name
    call s:SendCommand($'-interpreter-exec mi "frame function {a:arg}"')
  endif
endfunc

" :Up - go a:count frames in the stack "higher"
func s:Up(count)
  " the 'correct' one would be -stack-select-frame N, but we don't know N
  call s:SendCommand($'-interpreter-exec console "up {a:count}"')
endfunc

" :Down - go a:count frames in the stack "below"
func s:Down(count)
  " the 'correct' one would be -stack-select-frame N, but we don't know N
  call s:SendCommand($'-interpreter-exec console "down {a:count}"')
endfunc

func s:SendEval(expr)
  " check for "likely" boolean expressions, in which case we take it as lhs
  if a:expr =~ "[=!<>]="
    let exprLHS = a:expr
  else
    " remove text that is likely an assignment
    let exprLHS = substitute(a:expr, ' *=.*', '', '')
  endif

  " encoding expression to prevent bad errors
  let expr_escaped = a:expr
        \ ->substitute('\\', '\\\\', 'g')
        \ ->substitute('"', '\\"', 'g')
  call s:SendCommand($'-data-evaluate-expression "{expr_escaped}"')
  let s:evalexpr = exprLHS
endfunc

" :Evaluate - evaluate what is specified / under the cursor
func s:Evaluate(range, arg)
  if s:eval_float_win_id > 0 && nvim_win_is_valid(s:eval_float_win_id)
        \ && a:range == 0 && empty(a:arg)
    call nvim_set_current_win(s:eval_float_win_id)
    return
  endif
  let expr = s:GetEvaluationExpression(a:range, a:arg)
  let s:evalFromBalloonExpr = v:true
  let s:evalFromBalloonExprResult = ''
  let s:ignoreEvalError = v:false
  call s:SendEval(expr)
endfunc

" get what is specified / under the cursor
func s:GetEvaluationExpression(range, arg)
  if a:arg != ''
    " user supplied evaluation
    let expr = s:CleanupExpr(a:arg)
    " DSW: replace "likely copy + paste" assignment
    let expr = substitute(expr, '"\([^"]*\)": *', '\1=', 'g')
  elseif a:range == 2
    let pos = getcurpos()
    let reg = getreg('v', 1, 1)
    let regt = getregtype('v')
    normal! gv"vy
    let expr = s:CleanupExpr(@v)
    call setpos('.', pos)
    call setreg('v', reg, regt)
    let s:evalFromBalloonExpr = v:true
  else
    " no evaluation provided: get from C-expression under cursor
    " TODO: allow filetype specific lookup #9057
    let expr = expand('<cexpr>')
    let s:evalFromBalloonExpr = v:true
  endif
  return expr
endfunc

" clean up expression that may get in because of range
" (newlines and surrounding whitespace)
" As it can also be specified via ex-command for assignments this function
" may not change the "content" parts (like replacing contained spaces)
func s:CleanupExpr(expr)
  " replace all embedded newlines/tabs/...
  let expr = substitute(a:expr, '\_s', ' ', 'g')

  if &filetype ==# 'cobol'
    " extra cleanup for COBOL:
    " - a semicolon nmay be used instead of a space
    " - a trailing comma or period is ignored as it commonly separates/ends
    "   multiple expr
    let expr = substitute(expr, ';', ' ', 'g')
    let expr = substitute(expr, '[,.]\+ *$', '', '')
  endif

  " get rid of leading and trailing spaces
  let expr = substitute(expr, '^ *', '', '')
  let expr = substitute(expr, ' *$', '', '')
  return expr
endfunc

let s:ignoreEvalError = v:false
let s:evalFromBalloonExpr = v:false
let s:evalFromBalloonExprResult = ''

let s:eval_float_win_id = -1

" Handle the result of data-evaluate-expression
func s:HandleEvaluate(msg)
  let value = a:msg
        \ ->substitute('.*value="\(.*\)"', '\1', '')
        \ ->substitute('\\"', '"', 'g')
        \ ->substitute('\\\\', '\\', 'g')
        "\ multi-byte characters arrive in octal form, replace everything but NULL values
        \ ->substitute('\\000', s:NullRepl, 'g')
        \ ->substitute('\\\o\o\o', {-> eval('"' .. submatch(0) .. '"')}, 'g')
        "\ Note: GDB docs also mention hex encodings - the translations below work
        "\       but we keep them out for performance-reasons until we actually see
        "\       those in mi-returns
        "\ ->substitute('\\0x00', s:NullRep, 'g')
        "\ ->substitute('\\0x\(\x\x\)', {-> eval('"\x' .. submatch(1) .. '"')}, 'g')
        \ ->substitute(s:NullRepl, '\\000', 'g')
        \ ->substitute('', '\1', '')
  if s:evalFromBalloonExpr
    if s:evalFromBalloonExprResult == ''
      let s:evalFromBalloonExprResult = $'{s:evalexpr}: {value}'
    else
      let s:evalFromBalloonExprResult ..= $' = {value}'
    endif
    " NEOVIM:
    " - Result pretty-printing is not implemented. Vim prettifies the result
    "   with balloon_split(), which is not ported to nvim.
    " - Manually implement window focusing. Sometimes the result of pointer
    "   evaluation arrives in two separate messages, one for the address
    "   itself and the other for the value in that address. So with the stock
    "   focus option, the second message will focus the window containing the
    "   first message.
    let s:eval_float_win_id = luaeval('select(2, vim.lsp.util.open_floating_preview(_A))', [s:evalFromBalloonExprResult])
  else
    echomsg $'"{s:evalexpr}": {value}'
  endif

  if s:evalexpr[0] != '*' && value =~ '^0x' && value != '0x0' && value !~ '"$'
    " Looks like a pointer, also display what it points to.
    let s:ignoreEvalError = v:true
    call s:SendEval($'*{s:evalexpr}')
  endif
endfunc

" Handle an error.
func s:HandleError(msg)
  if s:ignoreEvalError
    " Result of s:SendEval() failed, ignore.
    let s:ignoreEvalError = v:false
    let s:evalFromBalloonExpr = v:false
    return
  endif
  let msgVal = substitute(a:msg, '.*msg="\(.*\)"', '\1', '')
  call s:Echoerr(substitute(msgVal, '\\"', '"', 'g'))
endfunc

func s:GotoSourcewinOrCreateIt()
  if !win_gotoid(s:sourcewin)
    new
    let s:sourcewin = win_getid()
    call s:InstallWinbar(0)
  endif
endfunc

func s:GetDisasmWindow()
  if exists('g:termdebug_config')
    return get(g:termdebug_config, 'disasm_window', 0)
  endif
  if exists('g:termdebug_disasm_window')
    return g:termdebug_disasm_window
  endif
  return 0
endfunc

func s:GetDisasmWindowHeight()
  if exists('g:termdebug_config')
    return get(g:termdebug_config, 'disasm_window_height', 0)
  endif
  if exists('g:termdebug_disasm_window') && g:termdebug_disasm_window > 1
    return g:termdebug_disasm_window
  endif
  return 0
endfunc

func s:GotoAsmwinOrCreateIt()
  if !win_gotoid(s:asmwin)
    let mdf = ''
    if win_gotoid(s:sourcewin)
      " 60 is approx spaceBuffer * 3
      if winwidth(0) > (78 + 60)
        let mdf = 'vert'
        exe $'{mdf} :60new'
      else
        exe 'rightbelow new'
      endif
    else
      exe 'new'
    endif

    let s:asmwin = win_getid()

    setlocal nowrap
    setlocal number
    setlocal noswapfile
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal signcolumn=no
    setlocal modifiable

    if s:asmbufnr > 0 && bufexists(s:asmbufnr)
      exe $'buffer {s:asmbufnr}'
    elseif empty(glob('Termdebug-asm-listing'))
      silent file Termdebug-asm-listing
      let s:asmbufnr = bufnr('Termdebug-asm-listing')
    else
      call s:Echoerr("You have a file/folder named 'Termdebug-asm-listing'.
          \ Please exit and rename it because Termdebug may not work as expected.")
    endif

    if mdf != 'vert' && s:GetDisasmWindowHeight() > 0
      exe $'resize {s:GetDisasmWindowHeight()}'
    endif
  endif

  if s:asm_addr != ''
    let lnum = search($'^{s:asm_addr}')
    if lnum == 0
      if s:stopped
        call s:SendCommand('disassemble $pc')
      endif
    else
      call sign_unplace('TermDebug', #{id: s:asm_id})
      call sign_place(s:asm_id, 'TermDebug', 'debugPC', '%', #{lnum: lnum})
    endif
  endif
endfunc

func s:GetVariablesWindow()
  if exists('g:termdebug_config')
    return get(g:termdebug_config, 'variables_window', 0)
  endif
  if exists('g:termdebug_disasm_window')
    return g:termdebug_variables_window
  endif
  return 0
endfunc

func s:GetVariablesWindowHeight()
  if exists('g:termdebug_config')
    return get(g:termdebug_config, 'variables_window_height', 0)
  endif
  if exists('g:termdebug_variables_window') && g:termdebug_variables_window > 1
    return g:termdebug_variables_window
  endif
  return 0
endfunc

func s:GotoVariableswinOrCreateIt()
  if !win_gotoid(s:varwin)
    let mdf = ''
    if win_gotoid(s:sourcewin)
      " 60 is approx spaceBuffer * 3
      if winwidth(0) > (78 + 60)
        let mdf = 'vert'
        exe $'{mdf} :60new'
      else
        exe 'rightbelow new'
      endif
    else
      exe 'new'
    endif

    let s:varwin = win_getid()

    setlocal nowrap
    setlocal noswapfile
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal signcolumn=no
    setlocal modifiable

    if s:varbufnr > 0 && bufexists(s:varbufnr)
      exe $'buffer {s:varbufnr}'
    elseif empty(glob('Termdebug-variables-listing'))
      silent file Termdebug-variables-listing
      let s:varbufnr = bufnr('Termdebug-variables-listing')
    else
      call s:Echoerr("You have a file/folder named 'Termdebug-variables-listing'.
          \ Please exit and rename it because Termdebug may not work as expected.")
    endif

    if mdf != 'vert' && s:GetVariablesWindowHeight() > 0
      exe $'resize {s:GetVariablesWindowHeight()}'
    endif
  endif

  if s:running
    call s:SendCommand('-stack-list-variables 2')
  endif
endfunc

" Handle stopping and running message from gdb.
" Will update the sign that shows the current position.
func s:HandleCursor(msg)
  let wid = win_getid()

  if a:msg =~ '^\*stopped'
    "call ch_log('program stopped')
    let s:stopped = v:true
    if a:msg =~ '^\*stopped,reason="exited-normally"'
      let s:running = v:false
    endif
  elseif a:msg =~ '^\*running'
    "call ch_log('program running')
    let s:stopped = v:false
    let s:running = v:true
  endif

  if a:msg =~ 'fullname='
    let fname = s:GetFullname(a:msg)
  else
    let fname = ''
  endif

  if a:msg =~ 'addr='
    let asm_addr = s:GetAsmAddr(a:msg)
    if asm_addr != ''
      let s:asm_addr = asm_addr

      let curwinid = win_getid()
      if win_gotoid(s:asmwin)
        let lnum = search($'^{s:asm_addr}')
        if lnum == 0
          call s:SendCommand('disassemble $pc')
        else
          call sign_unplace('TermDebug', #{id: s:asm_id})
          call sign_place(s:asm_id, 'TermDebug', 'debugPC', '%', #{lnum: lnum})
        endif

        call win_gotoid(curwinid)
      endif
    endif
  endif

  if s:running && s:stopped && bufwinnr('Termdebug-variables-listing') != -1
    call s:SendCommand('-stack-list-variables 2')
  endif

  if a:msg =~ '^\(\*stopped\|=thread-selected\)' && filereadable(fname)
    let lnum = substitute(a:msg, '.*line="\([^"]*\)".*', '\1', '')
    if lnum =~ '^[0-9]*$'
      call s:GotoSourcewinOrCreateIt()
      if expand('%:p') != fnamemodify(fname, ':p')
        echomsg $"different fname: '{expand('%:p')}' vs '{fnamemodify(fname, ':p')}'"
        augroup Termdebug
          " Always open a file read-only instead of showing the ATTENTION
          " prompt, since it is unlikely we want to edit the file.
          " The file may be changed but not saved, warn for that.
          au SwapExists * echohl WarningMsg
          \ | echo 'Warning: file is being edited elsewhere'
          \ | echohl None
          \ | let v:swapchoice = 'o'
        augroup END
        if &modified
          " TODO: find existing window
          exe $'split {fnameescape(fname)}'
          let s:sourcewin = win_getid()
          call s:InstallWinbar(0)
        else
          exe $'edit {fnameescape(fname)}'
        endif
        augroup Termdebug
          au! SwapExists
        augroup END
      endif
      exe $":{lnum}"
      normal! zv
      call sign_unplace('TermDebug', #{id: s:pc_id})
      call sign_place(s:pc_id, 'TermDebug', 'debugPC', fname,
            \ #{lnum: lnum, priority: 110})
      if !exists('b:save_signcolumn')
        let b:save_signcolumn = &signcolumn
        call add(s:signcolumn_buflist, bufnr())
      endif
      setlocal signcolumn=yes
    endif
  elseif !s:stopped || fname != ''
    call sign_unplace('TermDebug', #{id: s:pc_id})
  endif

  call win_gotoid(wid)
endfunc

let s:BreakpointSigns = []

func s:CreateBreakpoint(id, subid, enabled)
  let nr = printf('%d.%d', a:id, a:subid)
  if index(s:BreakpointSigns, nr) == -1
    call add(s:BreakpointSigns, nr)
    if a:enabled == "n"
      let hiName = "debugBreakpointDisabled"
    else
      let hiName = "debugBreakpoint"
    endif
    let label = ''
    if exists('g:termdebug_config')
      let label = get(g:termdebug_config, 'sign', '')
    endif
    if label == ''
      let label = printf('%02X', a:id)
      if a:id > 255
        let label = 'F+'
      endif
    endif
    call sign_define($'debugBreakpoint{nr}',
          \ #{text: slice(label, 0, 2),
          \ texthl: hiName})
  endif
endfunc

func! s:SplitMsg(s)
  return split(a:s, '{.\{-}}\zs')
endfunction

" Handle setting a breakpoint
" Will update the sign that shows the breakpoint
func s:HandleNewBreakpoint(msg, modifiedFlag)
  if a:msg !~ 'fullname='
    " a watch or a pending breakpoint does not have a file name
    if a:msg =~ 'pending='
      let nr = substitute(a:msg, '.*number=\"\([0-9.]*\)\".*', '\1', '')
      let target = substitute(a:msg, '.*pending=\"\([^"]*\)\".*', '\1', '')
      echomsg $'Breakpoint {nr} ({target}) pending.'
    endif
    return
  endif
  for msg in s:SplitMsg(a:msg)
    let fname = s:GetFullname(msg)
    if empty(fname)
      continue
    endif
    let nr = substitute(msg, '.*number="\([0-9.]*\)\".*', '\1', '')
    if empty(nr)
      return
    endif

    " If "nr" is 123 it becomes "123.0" and subid is "0".
    " If "nr" is 123.4 it becomes "123.4.0" and subid is "4"; "0" is discarded.
    let [id, subid; _] = map(split(nr . '.0', '\.'), 'v:val + 0')
    let enabled = substitute(msg, '.*enabled="\([yn]\)".*', '\1', '')
    call s:CreateBreakpoint(id, subid, enabled)

    if has_key(s:breakpoints, id)
      let entries = s:breakpoints[id]
    else
      let entries = {}
      let s:breakpoints[id] = entries
    endif
    if has_key(entries, subid)
      let entry = entries[subid]
    else
      let entry = {}
      let entries[subid] = entry
    endif

    let lnum = substitute(msg, '.*line="\([^"]*\)".*', '\1', '')
    let entry['fname'] = fname
    let entry['lnum'] = lnum

    let bploc = printf('%s:%d', fname, lnum)
    if !has_key(s:breakpoint_locations, bploc)
      let s:breakpoint_locations[bploc] = []
    endif
    let s:breakpoint_locations[bploc] += [id]

    if bufloaded(fname)
      call s:PlaceSign(id, subid, entry)
      let posMsg = $' at line {lnum}.'
    else
      let posMsg = $' in {fname} at line {lnum}.'
    endif
    if !a:modifiedFlag
      let actionTaken = 'created'
    elseif enabled == 'n'
      let actionTaken = 'disabled'
    else
      let actionTaken = 'enabled'
    endif
    echom $'Breakpoint {nr} {actionTaken}{posMsg}'
  endfor
endfunc

func s:PlaceSign(id, subid, entry)
  let nr = printf('%d.%d', a:id, a:subid)
  call sign_place(s:Breakpoint2SignNumber(a:id, a:subid), 'TermDebug',
        \ $'debugBreakpoint{nr}', a:entry['fname'],
        \ #{lnum: a:entry['lnum'], priority: 110})
  let a:entry['placed'] = 1
endfunc

" Handle deleting a breakpoint
" Will remove the sign that shows the breakpoint
func s:HandleBreakpointDelete(msg)
  let id = substitute(a:msg, '.*id="\([0-9]*\)\".*', '\1', '') + 0
  if empty(id)
    return
  endif
  if has_key(s:breakpoints, id)
    for [subid, entry] in items(s:breakpoints[id])
      if has_key(entry, 'placed')
        call sign_unplace('TermDebug',
              \ #{id: s:Breakpoint2SignNumber(id, subid)})
        unlet entry['placed']
      endif
    endfor
    unlet s:breakpoints[id]
    echomsg $'Breakpoint {id} cleared.'
  endif
endfunc

" Handle the debugged program starting to run.
" Will store the process ID in s:pid
func s:HandleProgramRun(msg)
  let nr = substitute(a:msg, '.*pid="\([0-9]*\)\".*', '\1', '') + 0
  if nr == 0
    return
  endif
  let s:pid = nr
  " call ch_log($'Detected process ID: {s:pid}')
endfunc

" Handle a BufRead autocommand event: place any signs.
func s:BufRead()
  let fname = expand('<afile>:p')
  for [id, entries] in items(s:breakpoints)
    for [subid, entry] in items(entries)
      if entry['fname'] == fname
        call s:PlaceSign(id, subid, entry)
      endif
    endfor
  endfor
endfunc

" Handle a BufUnloaded autocommand event: unplace any signs.
func s:BufUnloaded()
  let fname = expand('<afile>:p')
  for [id, entries] in items(s:breakpoints)
    for [subid, entry] in items(entries)
      if entry['fname'] == fname
        let entry['placed'] = 0
      endif
    endfor
  endfor
endfunc

call s:InitHighlight()
call s:InitAutocmd()

let &cpo = s:keepcpo
unlet s:keepcpo

" vim: sw=2 sts=2 et
