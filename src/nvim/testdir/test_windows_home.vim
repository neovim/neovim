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
  "call assert_equal(a:exp, $HOME)
  "call assert_equal(a:exp, expand('~', ':p'))
  if !a:0
    call CheckHomeIsMissingFromSubprocessEnvironment()
  else
    call CheckHomeIsInSubprocessEnvironment(a:exp)
  endif
endfunc

func TestWindowsHome()
  command! -nargs=* SaveEnv call <SID>save_env(<f-args>)
  command! -nargs=* RestoreEnv call <SID>restore_env()
  command! -nargs=* UnletEnv call <SID>unlet_env(<f-args>)

  SaveEnv $HOME $USERPROFILE $HOMEDRIVE $HOMEPATH
  try
    RestoreEnv
    UnletEnv $HOME $USERPROFILE $HOMEPATH
    let $HOMEDRIVE = 'C:'
    call CheckHome('C:\')

    RestoreEnv
    UnletEnv $HOME $USERPROFILE
    let $HOMEDRIVE = 'C:'
    let $HOMEPATH = '\foobar'
    call CheckHome('C:\foobar')

    RestoreEnv
    UnletEnv $HOME $HOMEDRIVE $HOMEPATH
    let $USERPROFILE = 'C:\foo'
    call CheckHome('C:\foo')

    RestoreEnv
    UnletEnv $HOME
    let $USERPROFILE = 'C:\foo'
    let $HOMEDRIVE = 'C:'
    let $HOMEPATH = '\baz'
    call CheckHome('C:\foo')

    RestoreEnv
    let $HOME = 'C:\bar'
    let $USERPROFILE = 'C:\foo'
    let $HOMEDRIVE = 'C:'
    let $HOMEPATH = '\baz'
    call CheckHome('C:\bar', 1)

    RestoreEnv
    let $HOME = '%USERPROFILE%\bar'
    let $USERPROFILE = 'C:\foo'
    let $HOMEDRIVE = 'C:'
    let $HOMEPATH = '\baz'
    call CheckHome('%USERPROFILE%\bar', 1)

    RestoreEnv
    let $HOME = '%USERPROFILE'
    let $USERPROFILE = 'C:\foo'
    let $HOMEDRIVE = 'C:'
    let $HOMEPATH = '\baz'
    call CheckHome('%USERPROFILE', 1)

    RestoreEnv
    let $HOME = 'C:\%USERPROFILE%'
    let $USERPROFILE = 'C:\foo'
    let $HOMEDRIVE = 'C:'
    let $HOMEPATH = '\baz'
    call CheckHome('C:\%USERPROFILE%', 1)

    if has('channel')
      RestoreEnv
      UnletEnv $HOME
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
