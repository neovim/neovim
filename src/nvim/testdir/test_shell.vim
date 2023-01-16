" Test for the shell related options ('shell', 'shellcmdflag', 'shellpipe',
" 'shellquote', 'shellredir', 'shellxescape', and 'shellxquote')

source check.vim
source shared.vim

func Test_shell_options()
  " For each shell, the following options are checked:
  " 'shellcmdflag', 'shellpipe', 'shellquote', 'shellredir', 'shellxescape',
  " 'shellxquote'
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
    let shells += [['cmd', '/c', '>%s 2>&1', '', '>%s 2>&1', '"&|<>()@^', ''],
          \ ['cmd.exe', '/c', '>%s 2>&1', '', '>%s 2>&1', '"&|<>()@^', '('],
          \ ['powershell.exe', '-c', '>', '', '>', '"&|<>()@^', '"'],
          \ ['powershell', '-c', '>', '', '>', '"&|<>()@^', '"'],
          \ ['sh.exe', '-c', '>%s 2>&1', '', '>%s 2>&1', '"&|<>()@^', '"'],
          \ ['ksh.exe', '-c', '>%s 2>&1', '', '>%s 2>&1', '"&|<>()@^', '"'],
          \ ['mksh.exe', '-c', '>%s 2>&1', '', '>%s 2>&1', '"&|<>()@^', '"'],
          \ ['pdksh.exe', '-c', '>%s 2>&1', '', '>%s 2>&1', '"&|<>()@^', '"'],
          \ ['zsh.exe', '-c', '>%s 2>&1', '', '>%s 2>&1', '"&|<>()@^', '"'],
          \ ['zsh-beta.exe', '-c', '>%s 2>&1', '', '>%s 2>&1', '"&|<>()@^', '"'],
          \ ['bash.exe', '-c', '>%s 2>&1', '', '>%s 2>&1', '"&|<>()@^', '"'],
          \ ['dash.exe', '-c', '>%s 2>&1', '', '>%s 2>&1', '"&|<>()@^', '"'],
          \ ['csh.exe', '-c', '>&', '', '>&', '"&|<>()@^', '"'],
          \ ['tcsh.exe', '-c', '>&', '', '>&', '"&|<>()@^', '"']]
  endif

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

  for e in shells
    exe 'set shell=' .. e[0]
    if e[0] =~# '.*csh$' || e[0] =~# '.*csh.exe$'
      let str1 = "'cmd \"arg1\" '\\''arg2'\\'' \\!%#'"
      let str2 = "'cmd \"arg1\" '\\''arg2'\\'' \\\\!\\%\\#'"
    else
      let str1 = "'cmd \"arg1\" '\\''arg2'\\'' !%#'"
      let str2 = "'cmd \"arg1\" '\\''arg2'\\'' \\!\\%\\#'"
    endif
    call assert_equal(str1, shellescape("cmd \"arg1\" 'arg2' !%#"), e[0])
    call assert_equal(str2, shellescape("cmd \"arg1\" 'arg2' !%#", 1), e[0])
  endfor
  set shell&
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

  call assert_equal("'te\nxt'", shellescape("te\nxt"))
  call assert_equal("'te\\\nxt'", shellescape("te\nxt", 1))
  set shell=tcsh
  call assert_equal("'te\\!xt'", shellescape("te!xt"))
  call assert_equal("'te\\\\!xt'", shellescape("te!xt", 1))
  call assert_equal("'te\\\nxt'", shellescape("te\nxt"))
  call assert_equal("'te\\\\\nxt'", shellescape("te\nxt", 1))

  let &shell = save_shell
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

" vim: shiftwidth=2 sts=2 expandtab
