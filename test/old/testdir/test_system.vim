" Tests for system() and systemlist()

source shared.vim
source check.vim

func Test_System()
  if !has('win32')
    call assert_equal("123\n", system('echo 123'))
    call assert_equal(['123'], systemlist('echo 123'))
    call assert_equal('123',   system('cat', '123'))
    call assert_equal(['123'], systemlist('cat', '123'))
    call assert_equal(["as\<NL>df"], systemlist('cat', ["as\<NL>df"]))
  else
    call assert_equal("123\n", system('echo 123'))
    call assert_equal(["123\r"], systemlist('echo 123'))
    call assert_equal("123\n",   system('more', '123'))
    call assert_equal(["123\r"], systemlist('more', '123'))
    call assert_equal(["as\r", "df\r"], systemlist('more', ["as\<NL>df"]))
  endif

  new Xdummy
  call setline(1, ['asdf', "pw\<NL>er", 'xxxx'])

  if executable('wc')
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
  endif

  if !has('win32')
    let out = systemlist('cat', bufnr('%'))
    call assert_equal(['asdf', "pw\<NL>er", 'xxxx'],  out)
  else
    let out = systemlist('more', bufnr('%'))
    call assert_equal(["asdf\r", "pw\r", "er\r", "xxxx\r"],  out)
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

" Check that Vim does not execute anything from current directory
func Test_windows_external_cmd_in_cwd()
  CheckMSWindows

  " just in case
  call system('rd /S /Q Xfolder')
  call mkdir('Xfolder', 'R')
  cd Xfolder

  let contents = ['@echo off', 'echo filename1.txt:1:AAAA']
  call writefile(contents, 'findstr.cmd')

  let file1 = ['AAAA', 'THIS FILE SHOULD NOT BE FOUND']
  let file2 = ['BBBB', 'THIS FILE SHOULD BE FOUND']

  call writefile(file1, 'filename1.txt')
  call writefile(file2, 'filename2.txt')

  if has('quickfix')
    " use silent to avoid hit-enter-prompt
    sil grep BBBB filename*.txt
    call assert_equal('filename2.txt', @%)
  endif

  let output = system('findstr BBBB filename*')
  " Match trailing newline byte
  call assert_match('filename2.txt:BBBB.', output)

  if has('gui')
    set guioptions+=!
    let output = system('findstr BBBB filename*')
    call assert_match('filename2.txt:BBBB.', output)
  endif

  cd -
  set guioptions&
endfunc

" vim: shiftwidth=2 sts=2 expandtab
