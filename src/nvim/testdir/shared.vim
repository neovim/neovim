" Functions shared by several tests.

" {Nvim}
" Filepath captured from output may be truncated, like this:
"   /home/va...estdir/Xtest-tmpdir/nvimxbXN4i/10
" Get last 2 segments, then combine with $TMPDIR.
func! Fix_truncated_tmpfile(fname)
  " sanity check
  if $TMPDIR ==# ''
    throw '$TMPDIR is empty'
  endif
  if a:fname !~# $TMPDIR
    throw '$TMPDIR not in fname: '.a:fname
  endif
  let last2segments = matchstr(a:fname, '[\/][^\/]\+[\/][^\/]\+$')
  return $TMPDIR.last2segments
endfunc

" Get the name of the Python executable.
" Also keeps it in s:python.
func PythonProg()
  " This test requires the Python command to run the test server.
  " This most likely only works on Unix and Windows.
  if has('unix')
    " We also need the job feature or the pkill command to make sure the server
    " can be stopped.
    if !(executable('python') && (has('job') || executable('pkill')))
      return ''
    endif
    let s:python = 'python'
  elseif has('win32')
    " Use Python Launcher for Windows (py.exe) if available.
    if executable('py.exe')
      let s:python = 'py.exe'
    elseif executable('python.exe')
      let s:python = 'python.exe'
    else
      return ''
    endif
  else
    return ''
  endif
  return s:python
endfunc

" Run "cmd".  Returns the job if using a job.
func RunCommand(cmd)
  let job = 0
  if has('job')
    let job = job_start(a:cmd, {"stoponexit": "hup"})
    call job_setoptions(job, {"stoponexit": "kill"})
  elseif has('win32')
    exe 'silent !start cmd /c start "test_channel" ' . a:cmd
  else
    exe 'silent !' . a:cmd . '&'
  endif
  return job
endfunc

" Read the port number from the Xportnr file.
func GetPort()
  let l = []
  for i in range(200)
    try
      let l = readfile("Xportnr")
    catch
    endtry
    if len(l) >= 1
      break
    endif
    sleep 10m
  endfor
  call delete("Xportnr")

  if len(l) == 0
    " Can't make the connection, give up.
    return 0
  endif
  return l[0]
endfunc

" Run a Python server for "cmd" and call "testfunc".
" Always kills the server before returning.
func RunServer(cmd, testfunc, args)
  " The Python program writes the port number in Xportnr.
  call delete("Xportnr")

  if len(a:args) == 1
    let arg = ' ' . a:args[0]
  else
    let arg = ''
  endif
  let pycmd = s:python . " " . a:cmd . arg

  try
    let g:currentJob = RunCommand(pycmd)

    " Wait for up to 2 seconds for the port number to be there.
    let port = GetPort()
    if port == 0
      call assert_false(1, "Can't start " . a:cmd)
      return
    endif

    call call(function(a:testfunc), [port])
  catch
    call assert_false(1, 'Caught exception: "' . v:exception . '" in ' . v:throwpoint)
  finally
    call s:kill_server(a:cmd)
  endtry
endfunc

func s:kill_server(cmd)
  if has('job')
    if exists('g:currentJob')
      call job_stop(g:currentJob)
      unlet g:currentJob
    endif
  elseif has('win32')
    let cmd = substitute(a:cmd, ".py", '', '')
    call system('taskkill /IM ' . s:python . ' /T /F /FI "WINDOWTITLE eq ' . cmd . '"')
  else
    call system("pkill -f " . a:cmd)
  endif
endfunc

" Wait for up to a second for "expr" to become true.
" Return time slept in milliseconds.  With the +reltime feature this can be
" more than the actual waiting time.  Without +reltime it can also be less.
func WaitFor(expr)
  " using reltime() is more accurate, but not always available
  if has('reltime')
    let start = reltime()
  else
    let slept = 0
  endif
  for i in range(100)
    try
      if eval(a:expr)
	if has('reltime')
	  return float2nr(reltimefloat(reltime(start)) * 1000)
	endif
	return slept
      endif
    catch
    endtry
    if !has('reltime')
      let slept += 10
    endif
    sleep 10m
  endfor
  return 1000
endfunc

" Wait for up to a given milliseconds.
" With the +timers feature this waits for key-input by getchar(), Resume()
" feeds key-input and resumes process. Return time waited in milliseconds.
" Without +timers it uses simply :sleep.
func Standby(msec)
  if has('timers')
    let start = reltime()
    let g:_standby_timer = timer_start(a:msec, function('s:feedkeys'))
    call getchar()
    return float2nr(reltimefloat(reltime(start)) * 1000)
  else
    execute 'sleep ' a:msec . 'm'
    return a:msec
  endif
endfunc

func Resume()
  if exists('g:_standby_timer')
    call timer_stop(g:_standby_timer)
    call s:feedkeys(0)
    unlet g:_standby_timer
  endif
endfunc

func s:feedkeys(timer)
  call feedkeys('x', 'nt')
endfunc

" Get the command to run Vim, with -u NONE and --headless arguments.
" Returns an empty string on error.
func GetVimCommand()
  let cmd = v:progpath
  let cmd = substitute(cmd, '-u \f\+', '-u NONE', '')
  if cmd !~ '-u NONE'
    let cmd = cmd . ' -u NONE'
  endif
  let cmd .= ' --headless -i NONE'
  let cmd = substitute(cmd, 'VIMRUNTIME=.*VIMRUNTIME;', '', '')
  return cmd
endfunc

" Run Vim, using the "vimcmd" file and "-u NORC".
" "before" is a list of Vim commands to be executed before loading plugins.
" "after" is a list of Vim commands to be executed after loading plugins.
" Plugins are not loaded, unless 'loadplugins' is set in "before".
" Return 1 if Vim could be executed.
func RunVim(before, after, arguments)
  return RunVimPiped(a:before, a:after, a:arguments, '')
endfunc

func RunVimPiped(before, after, arguments, pipecmd)
  let $NVIM_LOG_FILE = exists($NVIM_LOG_FILE) ? $NVIM_LOG_FILE : 'Xnvim.log'
  let cmd = GetVimCommand()
  if cmd == ''
    return 0
  endif
  let args = ''
  if len(a:before) > 0
    call writefile(a:before, 'Xbefore.vim')
    let args .= ' --cmd "so Xbefore.vim"'
  endif
  if len(a:after) > 0
    call writefile(a:after, 'Xafter.vim')
    let args .= ' -S Xafter.vim'
  endif

  exe "silent !" . a:pipecmd . cmd . args . ' ' . a:arguments

  if len(a:before) > 0
    call delete('Xbefore.vim')
  endif
  if len(a:after) > 0
    call delete('Xafter.vim')
  endif
  return 1
endfunc
