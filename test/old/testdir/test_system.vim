" Tests for system() and systemlist()

source shared.vim
source check.vim

func Test_System()
  if !executable('echo') || !executable('cat') || !executable('wc')
    return
  endif
  let out = 'echo 123'->system()
  call assert_equal("123\n", out)

  let out = 'echo 123'->systemlist()
  if &shell =~# 'cmd.exe$'
    call assert_equal(["123\r"], out)
  else
    call assert_equal(['123'], out)
  endif

  call assert_equal('123',   system('cat', '123'))
  call assert_equal(['123'], systemlist('cat', '123'))
  call assert_equal(["as\<NL>df"], systemlist('cat', ["as\<NL>df"]))

  new Xdummy
  call setline(1, ['asdf', "pw\<NL>er", 'xxxx'])
  let out = system('wc -l', bufnr('%'))
  " On OS/X we get leading spaces
  let out = substitute(out, '^ *', '', '')
  call assert_equal("3\n", out)

  let out = systemlist('wc -l', bufnr('%'))
  " On Windows we may get a trailing CR.
  if out != ["3\r"]
    " On OS/X we get leading spaces
    if type(out) == v:t_list
      let out[0] = substitute(out[0], '^ *', '', '')
    endif
    call assert_equal(['3'],  out)
  endif

  let out = systemlist('cat', bufnr('%'))
  " On Windows we may get a trailing CR.
  if out != ["asdf\r", "pw\<NL>er\r", "xxxx\r"]
    call assert_equal(['asdf', "pw\<NL>er", 'xxxx'],  out)
  endif
  bwipe!

  call assert_fails('call system("wc -l", 99999)', 'E86:')
endfunc

func Test_system_exmode()
  if has('unix') " echo $? only works on Unix
    let cmd = ' -es -c "source Xscript" +q; echo "result=$?"'
    " Need to put this in a script, "catch" isn't found after an unknown
    " function.
    call writefile(['try', 'call doesnotexist()', 'catch', 'endtry'], 'Xscript', 'D')
    let a = system(GetVimCommand() . cmd)
    call assert_match('result=0', a)
    call assert_equal(0, v:shell_error)
  endif

  " Error before try does set error flag.
  call writefile(['call nosuchfunction()', 'try', 'call doesnotexist()', 'catch', 'endtry'], 'Xscript')
  if has('unix') " echo $? only works on Unix
    let a = system(GetVimCommand() . cmd)
    call assert_notequal('0', a[0])
  endif

  let cmd = ' -es -c "source Xscript" +q'
  let a = system(GetVimCommand() . cmd)
  call assert_notequal(0, v:shell_error)

  if has('unix') " echo $? only works on Unix
    let cmd = ' -es -c "call doesnotexist()" +q; echo $?'
    let a = system(GetVimCommand() . cmd)
    call assert_notequal(0, a[0])
  endif

  let cmd = ' -es -c "call doesnotexist()" +q'
  let a = system(GetVimCommand(). cmd)
  call assert_notequal(0, v:shell_error)

  if has('unix') " echo $? only works on Unix
    let cmd = ' -es -c "call doesnotexist()|let a=1" +q; echo $?'
    let a = system(GetVimCommand() . cmd)
    call assert_notequal(0, a[0])
  endif

  let cmd = ' -es -c "call doesnotexist()|let a=1" +q'
  let a = system(GetVimCommand() . cmd)
  call assert_notequal(0, v:shell_error)
endfunc

func Test_system_with_shell_quote()
  CheckMSWindows

  call mkdir('Xdir with spaces', 'p')
  call system('copy "%COMSPEC%" "Xdir with spaces\cmd.exe"')

  let shell_save = &shell
  let shellxquote_save = &shellxquote
  try
    " Set 'shell' always needs noshellslash.
    let shellslash_save = &shellslash
    set noshellslash
    let shell_tests = [
          \ expand('$COMSPEC'),
          \ '"' . fnamemodify('Xdir with spaces\cmd.exe', ':p') . '"',
          \]
    let &shellslash = shellslash_save

    let sxq_tests = ['', '(', '"']

    " Matrix tests: 'shell' * 'shellxquote'
    for shell in shell_tests
      let &shell = shell
      for sxq in sxq_tests
        let &shellxquote = sxq

        let msg = printf('shell=%s shellxquote=%s', &shell, &shellxquote)

        try
          let out = 'echo 123'->system()
        catch
          call assert_report(printf('%s: %s', msg, v:exception))
          continue
        endtry

        " On Windows we may get a trailing space and CR.
        if out != "123 \n"
          call assert_equal("123\n", out, msg)
        endif

      endfor
    endfor

  finally
    let &shell = shell_save
    let &shellxquote = shellxquote_save
    call delete('Xdir with spaces', 'rf')
  endtry
endfunc

" vim: shiftwidth=2 sts=2 expandtab
