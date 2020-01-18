" Test for $HOME on Windows.

if !has('win32')
  finish
endif

let s:env = {}

func s:restore_env()
  for i in keys(s:env)
    exe 'let ' . i . '=s:env["' . i . '"]'
  endfor
endfunc

func s:save_env(...)
  for i in a:000
    exe 'let s:env["' . i . '"]=' . i
  endfor
endfunc

func s:unlet_env(...)
  for i in a:000
    exe 'let ' . i . '=""'
  endfor
endfunc

func CheckHomeIsMissingFromSubprocessEnvironment()
  silent! let out = system('set')
  let env = filter(split(out, "\n"), 'v:val=~"^HOME="')
  call assert_equal(0, len(env))
endfunc

func CheckHomeIsInSubprocessEnvironment(exp)
  silent! let out = system('set')
  let env = filter(split(out, "\n"), 'v:val=~"^HOME="')
  let home = len(env) == 0 ? "" : substitute(env[0], '[^=]\+=', '', '')
  call assert_equal(a:exp, home)
endfunc

func CheckHome(exp, ...)
  call assert_equal(a:exp, $HOME)
  call assert_equal(a:exp, expand('~', ':p'))
  if !a:0
    call CheckHomeIsMissingFromSubprocessEnvironment()
  else
    call CheckHomeIsInSubprocessEnvironment(a:1)
  endif
endfunc

func Test_WindowsHome()
  command! -nargs=* SaveEnv call <SID>save_env(<f-args>)
  command! -nargs=* RestoreEnv call <SID>restore_env()
  command! -nargs=* UnletEnv call <SID>unlet_env(<f-args>)
  set noshellslash

  let save_home = $HOME
  SaveEnv $USERPROFILE $HOMEDRIVE $HOMEPATH
  try
    " Normal behavior: use $HOMEDRIVE and $HOMEPATH, ignore $USERPROFILE
    let $USERPROFILE = 'unused'
    let $HOMEDRIVE = 'C:'
    let $HOMEPATH = '\foobar'
    let $HOME = ''  " Force recomputing "homedir"
    call CheckHome('C:\foobar')

    " Same, but with $HOMEPATH not set
    UnletEnv $HOMEPATH
    let $HOME = ''  " Force recomputing "homedir"
    call CheckHome('C:\')

    " Use $USERPROFILE if $HOMEPATH and $HOMEDRIVE are empty
    UnletEnv $HOMEDRIVE $HOMEPATH
    let $USERPROFILE = 'C:\foo'
    let $HOME = ''  " Force recomputing "homedir"
    call CheckHome('C:\foo')

    " If $HOME is set the others don't matter
    let $HOME = 'C:\bar'
    let $USERPROFILE = 'unused'
    let $HOMEDRIVE = 'unused'
    let $HOMEPATH = 'unused'
    call CheckHome('C:\bar', 'C:\bar')

    " If $HOME contains %USERPROFILE% it is expanded
    let $USERPROFILE = 'C:\foo'
    let $HOME = '%USERPROFILE%\bar'
    let $HOMEDRIVE = 'unused'
    let $HOMEPATH = 'unused'
    call CheckHome('C:\foo\bar', '%USERPROFILE%\bar')

    " Invalid $HOME is kept
    let $USERPROFILE = 'C:\foo'
    let $HOME = '%USERPROFILE'
    let $HOMEDRIVE = 'unused'
    let $HOMEPATH = 'unused'
    call CheckHome('%USERPROFILE', '%USERPROFILE')

    " %USERPROFILE% not at start of $HOME is not expanded
    let $USERPROFILE = 'unused'
    let $HOME = 'C:\%USERPROFILE%'
    let $HOMEDRIVE = 'unused'
    let $HOMEPATH = 'unused'
    call CheckHome('C:\%USERPROFILE%', 'C:\%USERPROFILE%')

    if has('channel')
      RestoreEnv
      let $HOME = save_home
      let env = ''
      let job = job_start('cmd /c set', {'out_cb': {ch,x->[env,execute('let env=x')]}})
      sleep 1
      let env = filter(split(env, "\n"), 'v:val=="HOME"')
      let home = len(env) == 0 ? "" : env[0]
      call assert_equal('', home)
    endif
  finally
    RestoreEnv
    delcommand SaveEnv
    delcommand RestoreEnv
    delcommand UnletEnv
  endtry
endfunc
