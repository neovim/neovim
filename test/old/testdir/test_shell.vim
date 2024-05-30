" Test for the shell related options ('shell', 'shellcmdflag', 'shellpipe',
" 'shellquote', 'shellredir', 'shellxescape', and 'shellxquote')

source check.vim
source shared.vim

func Test_shell_options()
  if has('win32')
    " FIXME: This test is flaky on MS-Windows.
    let g:test_is_flaky = 1
  endif

  " The expected value of 'shellcmdflag', 'shellpipe', 'shellquote',
  " 'shellredir', 'shellxescape', 'shellxquote' for the supported shells.
  let shells = []
  if has('unix')
    let shells += [['sh', '-c', '2>&1| tee', '', '>%s 2>&1', '', ''],
          \ ['ksh', '-c', '2>&1| tee', '', '>%s 2>&1', '', ''],
          \ ['mksh', '-c', '2>&1| tee', '', '>%s 2>&1', '', ''],
          \ ['zsh', '-c', '2>&1| tee', '', '>%s 2>&1', '', ''],
          \ ['zsh-beta', '-c', '2>&1| tee', '', '>%s 2>&1', '', ''],
          \ ['bash', '-c', '2>&1| tee', '', '>%s 2>&1', '', ''],
          \ ['fish', '-c', '2>&1| tee', '', '>%s 2>&1', '', ''],
          \ ['ash', '-c', '2>&1| tee', '', '>%s 2>&1', '', ''],
          \ ['dash', '-c', '2>&1| tee', '', '>%s 2>&1', '', ''],
          \ ['csh', '-c', '|& tee', '', '>&', '', ''],
          \ ['tcsh', '-c', '|& tee', '', '>&', '', '']]
  endif
  if has('win32')
    let shells += [['cmd', '/s /c', '2>&1| tee', '', '>%s 2>&1', '', '"']]
  endif

  " start a new Vim instance with 'shell' set to each of the supported shells
  " and check the default shell option settings
  let after =<< trim END
    let l = [&shell, &shellcmdflag, &shellpipe, &shellquote]
    let l += [&shellredir, &shellxescape, &shellxquote]
    call writefile([json_encode(l)], 'Xtestout')
    qall!
  END
  for e in shells
    if RunVim([], after, '--cmd "set shell=' .. e[0] .. '"')
      call assert_equal(e, json_decode(readfile('Xtestout')[0]))
    endif
  endfor

  " Test shellescape() for each of the shells.
  for e in shells
    exe 'set shell=' .. e[0]
    if e[0] =~# '.*csh$' || e[0] =~# '.*csh.exe$'
      let str1 = "'cmd \"arg1\" '\\''arg2'\\'' \\!%#'"
      let str2 = "'cmd \"arg1\" '\\''arg2'\\'' \\\\!\\%\\#'"
    elseif e[0] =~# '.*powershell$' || e[0] =~# '.*powershell.exe$'
      let str1 = "'cmd \"arg1\" ''arg2'' !%#'"
      let str2 = "'cmd \"arg1\" ''arg2'' \\!\\%\\#'"
    else
      let str1 = "'cmd \"arg1\" '\\''arg2'\\'' !%#'"
      let str2 = "'cmd \"arg1\" '\\''arg2'\\'' \\!\\%\\#'"
    endif
    call assert_equal(str1, shellescape("cmd \"arg1\" 'arg2' !%#"), e[0])
    call assert_equal(str2, shellescape("cmd \"arg1\" 'arg2' !%#", 1), e[0])

    " Try running an external command with the shell.
    if executable(e[0])
      " set the shell options for the current 'shell'
      let [&shellcmdflag, &shellpipe, &shellquote, &shellredir,
            \ &shellxescape, &shellxquote] = e[1:6]
      new
      r !echo hello
      call assert_equal('hello', substitute(getline(2), '\W', '', 'g'), e[0])
      bwipe!
    endif
  endfor
  set shell& shellcmdflag& shellpipe& shellquote&
  set shellredir& shellxescape& shellxquote&
  call delete('Xtestout')
endfunc

" Test for the 'shell' option
func Test_shell()
  throw 'Skipped: Nvim missing :shell currently'
  CheckUnix
  let save_shell = &shell
  set shell=
  let caught_e91 = 0
  try
    shell
  catch /E91:/
    let caught_e91 = 1
  endtry
  call assert_equal(1, caught_e91)
  let &shell = save_shell
endfunc

" Test for the 'shellquote' option
func Test_shellquote()
  CheckUnix
  set shellquote=#
  set verbose=20
  redir => v
  silent! !echo Hello
  redir END
  set verbose&
  set shellquote&
  call assert_match(': "#echo Hello#"', v)
endfunc

" Test for the 'shellescape' option
func Test_shellescape()
  let save_shell = &shell
  set shell=bash
  call assert_equal("'text'", shellescape('text'))
  call assert_equal("'te\"xt'", 'te"xt'->shellescape())
  call assert_equal("'te'\\''xt'", shellescape("te'xt"))

  call assert_equal("'te%xt'", shellescape("te%xt"))
  call assert_equal("'te\\%xt'", shellescape("te%xt", 1))
  call assert_equal("'te#xt'", shellescape("te#xt"))
  call assert_equal("'te\\#xt'", shellescape("te#xt", 1))
  call assert_equal("'te!xt'", shellescape("te!xt"))
  call assert_equal("'te\\!xt'", shellescape("te!xt", 1))
  call assert_equal("'te<cword>xt'", shellescape("te<cword>xt"))
  call assert_equal("'te\\<cword>xt'", shellescape("te<cword>xt", 1))
  call assert_equal("'te<cword>%xt'", shellescape("te<cword>%xt"))
  call assert_equal("'te\\<cword>\\%xt'", shellescape("te<cword>%xt", 1))

  call assert_equal("'te\nxt'", shellescape("te\nxt"))
  call assert_equal("'te\\\nxt'", shellescape("te\nxt", 1))
  set shell=tcsh
  call assert_equal("'te\\!xt'", shellescape("te!xt"))
  call assert_equal("'te\\\\!xt'", shellescape("te!xt", 1))
  call assert_equal("'te\\\nxt'", shellescape("te\nxt"))
  call assert_equal("'te\\\\\nxt'", shellescape("te\nxt", 1))

  set shell=fish
  call assert_equal("'text'", shellescape('text'))
  call assert_equal("'te\"xt'", shellescape('te"xt'))
  call assert_equal("'te'\\''xt'", shellescape("te'xt"))

  call assert_equal("'te%xt'", shellescape("te%xt"))
  call assert_equal("'te\\%xt'", shellescape("te%xt", 1))
  call assert_equal("'te#xt'", shellescape("te#xt"))
  call assert_equal("'te\\#xt'", shellescape("te#xt", 1))
  call assert_equal("'te!xt'", shellescape("te!xt"))
  call assert_equal("'te\\!xt'", shellescape("te!xt", 1))

  call assert_equal("'te\\\\xt'", shellescape("te\\xt"))
  call assert_equal("'te\\\\xt'", shellescape("te\\xt", 1))
  call assert_equal("'te\\\\'\\''xt'", shellescape("te\\'xt"))
  call assert_equal("'te\\\\'\\''xt'", shellescape("te\\'xt", 1))
  call assert_equal("'te\\\\!xt'", shellescape("te\\!xt"))
  call assert_equal("'te\\\\\\!xt'", shellescape("te\\!xt", 1))
  call assert_equal("'te\\\\%xt'", shellescape("te\\%xt"))
  call assert_equal("'te\\\\\\%xt'", shellescape("te\\%xt", 1))
  call assert_equal("'te\\\\#xt'", shellescape("te\\#xt"))
  call assert_equal("'te\\\\\\#xt'", shellescape("te\\#xt", 1))

  let &shell = save_shell
endfunc

" Test for 'shellslash'
func Test_shellslash()
  CheckOption shellslash
  let save_shellslash = &shellslash
  " The shell and cmdflag, and expected slash in tempname with shellslash set or
  " unset.  The assert checks the file separator before the leafname.
  " ".*\\\\[^\\\\]*$"
  let shells = [['cmd', '/c', '/', '/'],
        \ ['powershell', '-Command', '/', '/'],
        \ ['sh', '-c', '/', '/']]
  for e in shells
    exe 'set shell=' .. e[0] .. ' | set shellcmdflag=' .. e[1]
    set noshellslash
    let file = tempname()
    call assert_match('^.\+' .. e[2] .. '[^' .. e[2] .. ']\+$', file, e[0] .. ' ' .. e[1] .. ' nossl')
    set shellslash
    let file = tempname()
    call assert_match('^.\+' .. e[3] .. '[^' .. e[3] .. ']\+$', file, e[0] .. ' ' .. e[1] .. ' ssl')
  endfor
  let &shellslash = save_shellslash
endfunc

" Test for 'shellxquote'
func Test_shellxquote()
  CheckUnix

  let save_shell = &shell
  let save_sxq = &shellxquote
  let save_sxe = &shellxescape

  call writefile(['#!/bin/sh', 'echo "Cmd: [$*]" > Xlog'], 'Xtestshell')
  call setfperm('Xtestshell', "r-x------")
  set shell=./Xtestshell

  set shellxquote=\\"
  call feedkeys(":!pwd\<CR>\<CR>", 'xt')
  call assert_equal(['Cmd: [-c "pwd"]'], readfile('Xlog'))

  set shellxquote=(
  call feedkeys(":!pwd\<CR>\<CR>", 'xt')
  call assert_equal(['Cmd: [-c (pwd)]'], readfile('Xlog'))

  set shellxquote=\\"(
  call feedkeys(":!pwd\<CR>\<CR>", 'xt')
  call assert_equal(['Cmd: [-c "(pwd)"]'], readfile('Xlog'))

  set shellxescape=\"&<<()@^
  set shellxquote=(
  call feedkeys(":!pwd\"&<<{}@^\<CR>\<CR>", 'xt')
  call assert_equal(['Cmd: [-c (pwd^"^&^<^<{}^@^^)]'], readfile('Xlog'))

  let &shell = save_shell
  let &shellxquote = save_sxq
  let &shellxescape = save_sxe
  call delete('Xtestshell')
  call delete('Xlog')
endfunc

" Test for using the shell set in the $SHELL environment variable
func Test_set_shell()
  let after =<< trim [CODE]
    call writefile([&shell], "Xtestout")
    quit!
  [CODE]

  if has('win32')
    let $SHELL = 'C:\with space\cmd.exe'
    let expected = '"C:\with space\cmd.exe"'
  else
    let $SHELL = '/bin/with space/sh'
    let expected = '"/bin/with space/sh"'
  endif

  if RunVimPiped([], after, '', '')
    let lines = readfile('Xtestout')
    call assert_equal(expected, lines[0])
  endif
  call delete('Xtestout')
endfunc

func Test_shell_repeat()
  CheckUnix

  let save_shell = &shell

  call writefile(['#!/bin/sh', 'echo "Cmd: [$*]" > Xlog'], 'Xtestshell', 'D')
  call setfperm('Xtestshell', "r-x------")
  set shell=./Xtestshell
  defer delete('Xlog')

  call feedkeys(":!echo coconut\<CR>", 'xt')   " Run command
  call assert_equal(['Cmd: [-c echo coconut]'], readfile('Xlog'))

  call feedkeys(":!!\<CR>", 'xt')              " Re-run previous
  call assert_equal(['Cmd: [-c echo coconut]'], readfile('Xlog'))

  call writefile(['empty'], 'Xlog')
  call feedkeys(":!\<CR>", 'xt')               " :!
  call assert_equal(['Cmd: [-c ]'], readfile('Xlog'))

  call feedkeys(":!!\<CR>", 'xt')              " :! doesn't clear previous command
  call assert_equal(['Cmd: [-c echo coconut]'], readfile('Xlog'))

  call feedkeys(":!echo banana\<CR>", 'xt')    " Make sure setting previous command keeps working after a :! no-op
  call assert_equal(['Cmd: [-c echo banana]'], readfile('Xlog'))
  call feedkeys(":!!\<CR>", 'xt')
  call assert_equal(['Cmd: [-c echo banana]'], readfile('Xlog'))

  let &shell = save_shell
endfunc

func Test_shell_no_prevcmd()
  " this doesn't do anything, just check it doesn't crash
  let after =<< trim END
    exe "normal !!\<CR>"
    call writefile([v:errmsg, 'done'], 'Xtestdone')
    qall!
  END
  if RunVim([], after, '--clean')
    call assert_equal(['E34: No previous command', 'done'], readfile('Xtestdone'))
  endif
  call delete('Xtestdone')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
