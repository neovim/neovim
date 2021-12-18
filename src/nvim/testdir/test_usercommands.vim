" Tests for user defined commands

" Test for <mods> in user defined commands
function Test_cmdmods()
  let g:mods = ''

  command! -nargs=* MyCmd let g:mods .= '<mods> '

  MyCmd
  aboveleft MyCmd
  abo MyCmd
  belowright MyCmd
  bel MyCmd
  botright MyCmd
  bo MyCmd
  browse MyCmd
  bro MyCmd
  confirm MyCmd
  conf MyCmd
  hide MyCmd
  hid MyCmd
  keepalt MyCmd
  keepa MyCmd
  keepjumps MyCmd
  keepj MyCmd
  keepmarks MyCmd
  kee MyCmd
  keeppatterns MyCmd
  keepp MyCmd
  leftabove MyCmd  " results in :aboveleft
  lefta MyCmd
  lockmarks MyCmd
  loc MyCmd
  " noautocmd MyCmd
  noswapfile MyCmd
  nos MyCmd
  rightbelow MyCmd " results in :belowright
  rightb MyCmd
  " sandbox MyCmd
  silent MyCmd
  sil MyCmd
  tab MyCmd
  topleft MyCmd
  to MyCmd
  " unsilent MyCmd
  verbose MyCmd
  verb MyCmd
  vertical MyCmd
  vert MyCmd

  aboveleft belowright botright browse confirm hide keepalt keepjumps
        \ keepmarks keeppatterns lockmarks noswapfile silent tab
        \ topleft verbose vertical MyCmd

  call assert_equal(' aboveleft aboveleft belowright belowright botright ' .
        \ 'botright browse browse confirm confirm hide hide ' .
        \ 'keepalt keepalt keepjumps keepjumps keepmarks keepmarks ' .
        \ 'keeppatterns keeppatterns aboveleft aboveleft lockmarks lockmarks noswapfile ' .
        \ 'noswapfile belowright belowright silent silent tab topleft topleft verbose verbose ' .
        \ 'vertical vertical ' .
        \ 'aboveleft belowright botright browse confirm hide keepalt keepjumps ' .
        \ 'keepmarks keeppatterns lockmarks noswapfile silent tab topleft ' .
        \ 'verbose vertical ', g:mods)

  let g:mods = ''
  command! -nargs=* MyQCmd let g:mods .= '<q-mods> '

  vertical MyQCmd
  call assert_equal('"vertical" ', g:mods)

  delcommand MyCmd
  delcommand MyQCmd
  unlet g:mods
endfunction

func SaveCmdArgs(...)
  let g:args = a:000
endfunc

func Test_f_args()
  command -nargs=* TestFArgs call SaveCmdArgs(<f-args>)

  TestFArgs
  call assert_equal([], g:args)

  TestFArgs one two three
  call assert_equal(['one', 'two', 'three'], g:args)

  TestFArgs one\\two three
  call assert_equal(['one\two', 'three'], g:args)

  TestFArgs one\ two three
  call assert_equal(['one two', 'three'], g:args)

  TestFArgs one\"two three
  call assert_equal(['one\"two', 'three'], g:args)

  delcommand TestFArgs
endfunc

func Test_q_args()
  command -nargs=* TestQArgs call SaveCmdArgs(<q-args>)

  TestQArgs
  call assert_equal([''], g:args)

  TestQArgs one two three
  call assert_equal(['one two three'], g:args)

  TestQArgs one\\two three
  call assert_equal(['one\\two three'], g:args)

  TestQArgs one\ two three
  call assert_equal(['one\ two three'], g:args)

  TestQArgs one\"two three
  call assert_equal(['one\"two three'], g:args)

  delcommand TestQArgs
endfunc

func Test_reg_arg()
  command -nargs=* -reg TestRegArg call SaveCmdArgs("<reg>", "<register>")

  TestRegArg
  call assert_equal(['', ''], g:args)

  TestRegArg x
  call assert_equal(['x', 'x'], g:args)

  delcommand TestRegArg
endfunc

func Test_no_arg()
  command -nargs=* TestNoArg call SaveCmdArgs("<args>", "<>", "<x>", "<lt>")

  TestNoArg
  call assert_equal(['', '<>', '<x>', '<'], g:args)

  TestNoArg one
  call assert_equal(['one', '<>', '<x>', '<'], g:args)

  delcommand TestNoArg
endfunc

func Test_range_arg()
  command -range TestRangeArg call SaveCmdArgs(<range>, <line1>, <line2>)
  new
  call setline(1, range(100))
  let lnum = line('.')

  TestRangeArg
  call assert_equal([0, lnum, lnum], g:args)

  99TestRangeArg
  call assert_equal([1, 99, 99], g:args)

  88,99TestRangeArg
  call assert_equal([2, 88, 99], g:args)

  call assert_fails('102TestRangeArg', 'E16:')

  bwipe!
  delcommand TestRangeArg
endfunc

func Test_Ambiguous()
  command Doit let g:didit = 'yes'
  command Dothat let g:didthat = 'also'
  call assert_fails('Do', 'E464:')
  Doit
  call assert_equal('yes', g:didit)
  Dothat
  call assert_equal('also', g:didthat)
  unlet g:didit
  unlet g:didthat

  delcommand Doit
  Do
  call assert_equal('also', g:didthat)
  delcommand Dothat

  " Nvim removed the ":Ni!" easter egg in 87e107d92.
  call assert_fails("\x4ei\041", 'E492: Not an editor command: Ni!')
endfunc

func Test_redefine_on_reload()
  call writefile(['command ExistingCommand echo "yes"'], 'Xcommandexists')
  call assert_equal(0, exists(':ExistingCommand'))
  source Xcommandexists
  call assert_equal(2, exists(':ExistingCommand'))
  " Redefining a command when reloading a script is OK.
  source Xcommandexists
  call assert_equal(2, exists(':ExistingCommand'))

  " But redefining in another script is not OK.
  call writefile(['command ExistingCommand echo "yes"'], 'Xcommandexists2')
  call assert_fails('source Xcommandexists2', 'E174:')
  call delete('Xcommandexists2')

  " And defining twice in one script is not OK.
  delcommand ExistingCommand
  call assert_equal(0, exists(':ExistingCommand'))
  call writefile([
	\ 'command ExistingCommand echo "yes"',
	\ 'command ExistingCommand echo "no"',
	\ ], 'Xcommandexists')
  call assert_fails('source Xcommandexists', 'E174:')
  call assert_equal(2, exists(':ExistingCommand'))

  call delete('Xcommandexists')
  delcommand ExistingCommand
endfunc

func Test_CmdUndefined()
  call assert_fails('Doit', 'E492:')
  au CmdUndefined Doit :command Doit let g:didit = 'yes'
  Doit
  call assert_equal('yes', g:didit)
  delcommand Doit

  call assert_fails('Dothat', 'E492:')
  au CmdUndefined * let g:didnot = 'yes'
  call assert_fails('Dothat', 'E492:')
  call assert_equal('yes', g:didnot)
endfunc

func Test_CmdErrors()
  call assert_fails('com! docmd :', 'E183:')
  call assert_fails('com! \<Tab> :', 'E182:')
  call assert_fails('com! _ :', 'E182:')
  call assert_fails('com! - DoCmd :', 'E175:')
  call assert_fails('com! -xxx DoCmd :', 'E181:')
  call assert_fails('com! -addr DoCmd :', 'E179:')
  call assert_fails('com! -addr=asdf DoCmd :', 'E180:')
  call assert_fails('com! -complete DoCmd :', 'E179:')
  call assert_fails('com! -complete=xxx DoCmd :', 'E180:')
  call assert_fails('com! -complete=custom DoCmd :', 'E467:')
  call assert_fails('com! -complete=customlist DoCmd :', 'E467:')
  call assert_fails('com! -complete=behave,CustomComplete DoCmd :', 'E468:')
  call assert_fails('com! -complete=file DoCmd :', 'E1208:')
  call assert_fails('com! -nargs=0 -complete=file DoCmd :', 'E1208:')
  call assert_fails('com! -nargs=x DoCmd :', 'E176:')
  call assert_fails('com! -count=1 -count=2 DoCmd :', 'E177:')
  call assert_fails('com! -count=x DoCmd :', 'E178:')
  call assert_fails('com! -range=x DoCmd :', 'E178:')

  com! -nargs=0 DoCmd :
  call assert_fails('DoCmd x', 'E488:')

  com! -nargs=1 DoCmd :
  call assert_fails('DoCmd', 'E471:')

  com! -nargs=+ DoCmd :
  call assert_fails('DoCmd', 'E471:')

  call assert_fails('com DoCmd :', 'E174:')
  comclear
  call assert_fails('delcom DoCmd', 'E184:')
endfunc

func CustomComplete(A, L, P)
  return "January\nFebruary\nMars\n"
endfunc

func CustomCompleteList(A, L, P)
  return [ "Monday", "Tuesday", "Wednesday" ]
endfunc

func Test_CmdCompletion()
  call feedkeys(":com -\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"com -addr bang bar buffer complete count nargs range register', @:)

  call feedkeys(":com -nargs=0 -\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"com -nargs=0 -addr bang bar buffer complete count nargs range register', @:)

  call feedkeys(":com -nargs=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"com -nargs=* + 0 1 ?', @:)

  call feedkeys(":com -addr=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"com -addr=arguments buffers lines loaded_buffers other quickfix tabs windows', @:)

  call feedkeys(":com -complete=co\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"com -complete=color command compiler', @:)

  command! DoCmd1 :
  command! DoCmd2 :
  call feedkeys(":com \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"com DoCmd1 DoCmd2', @:)

  call feedkeys(":DoC\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"DoCmd1 DoCmd2', @:)

  call feedkeys(":delcom DoC\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"delcom DoCmd1 DoCmd2', @:)

  delcom DoCmd1
  call feedkeys(":delcom DoC\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"delcom DoCmd2', @:)

  call feedkeys(":com DoC\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"com DoCmd2', @:)

  delcom DoCmd2
  call feedkeys(":delcom DoC\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"delcom DoC', @:)

  call feedkeys(":com DoC\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"com DoC', @:)

  com! -nargs=1 -complete=behave DoCmd :
  call feedkeys(":DoCmd \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"DoCmd mswin xterm', @:)

  com! -nargs=* -complete=custom,CustomComplete DoCmd :
  call feedkeys(":DoCmd \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"DoCmd January February Mars', @:)

  com! -nargs=? -complete=customlist,CustomCompleteList DoCmd :
  call feedkeys(":DoCmd \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"DoCmd Monday Tuesday Wednesday', @:)

  com! -nargs=+ -complete=custom,CustomCompleteList DoCmd :
  call assert_fails("call feedkeys(':DoCmd \<C-D>', 'tx')", 'E730:')

  com! -nargs=+ -complete=customlist,CustomComp DoCmd :
  call assert_fails("call feedkeys(':DoCmd \<C-D>', 'tx')", 'E117:')

  " custom completion without a function
  com! -nargs=? -complete=custom, DoCmd
  call assert_beeps("call feedkeys(':DoCmd \t', 'tx')")

  " custom completion failure with the wrong function
  com! -nargs=? -complete=custom,min DoCmd
  call assert_fails("call feedkeys(':DoCmd \t', 'tx')", 'E118:')

  delcom DoCmd
endfunc

func CallExecute(A, L, P)
  " Drop first '\n'
  return execute('echo "hi"')[1:]
endfunc

func Test_use_execute_in_completion()
  command! -nargs=* -complete=custom,CallExecute DoExec :
  call feedkeys(":DoExec \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"DoExec hi', @:)
  delcommand DoExec
endfunc

func Test_addr_all()
  throw 'skipped: requires patch v8.1.0341 to pass'
  command! -addr=lines DoSomething let g:a1 = <line1> | let g:a2 = <line2>
  %DoSomething
  call assert_equal(1, g:a1)
  call assert_equal(line('$'), g:a2)

  command! -addr=arguments DoSomething let g:a1 = <line1> | let g:a2 = <line2>
  args one two three
  %DoSomething
  call assert_equal(1, g:a1)
  call assert_equal(3, g:a2)

  command! -addr=buffers DoSomething let g:a1 = <line1> | let g:a2 = <line2>
  %DoSomething
  for low in range(1, bufnr('$'))
    if buflisted(low)
      break
    endif
  endfor
  call assert_equal(low, g:a1)
  call assert_equal(bufnr('$'), g:a2)

  command! -addr=loaded_buffers DoSomething let g:a1 = <line1> | let g:a2 = <line2>
  %DoSomething
  for low in range(1, bufnr('$'))
    if bufloaded(low)
      break
    endif
  endfor
  call assert_equal(low, g:a1)
  for up in range(bufnr('$'), 1, -1)
    if bufloaded(up)
      break
    endif
  endfor
  call assert_equal(up, g:a2)

  command! -addr=windows DoSomething  let g:a1 = <line1> | let g:a2 = <line2>
  new
  %DoSomething
  call assert_equal(1, g:a1)
  call assert_equal(winnr('$'), g:a2)
  bwipe

  command! -addr=tabs DoSomething  let g:a1 = <line1> | let g:a2 = <line2>
  tabnew
  %DoSomething
  call assert_equal(1, g:a1)
  call assert_equal(len(gettabinfo()), g:a2)
  bwipe

  command! -addr=other DoSomething  let g:a1 = <line1> | let g:a2 = <line2>
  DoSomething
  call assert_equal(line('.'), g:a1)
  call assert_equal(line('.'), g:a2)
  %DoSomething
  call assert_equal(1, g:a1)
  call assert_equal(line('$'), g:a2)

  delcommand DoSomething
endfunc

func Test_command_list()
  command! DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0                        :",
        \           execute('command DoCmd'))

  " Test with various -range= and -count= argument values.
  command! -range DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0    .                   :",
        \           execute('command DoCmd'))
  command! -range=% DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0    %                   :",
        \           execute('command! DoCmd'))
  command! -range=2 DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0    2                   :",
        \           execute('command DoCmd'))
  command! -count=2 DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0    2c ?                :",
        \           execute('command DoCmd'))

  " Test with various -addr= argument values.
  command! -addr=lines DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0    .                   :",
        \           execute('command DoCmd'))
  command! -addr=arguments DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0    .  arg              :",
        \           execute('command DoCmd'))
  command! -addr=buffers DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0    .  buf              :",
        \           execute('command DoCmd'))
  command! -addr=loaded_buffers DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0    .  load             :",
        \           execute('command DoCmd'))
  command! -addr=windows DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0    .  win              :",
        \           execute('command DoCmd'))
  command! -addr=tabs DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0    .  tab              :",
        \           execute('command DoCmd'))
  command! -addr=other DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0    .  ?                :",
        \           execute('command DoCmd'))

  " Test with various -complete= argument values (non-exhaustive list)
  command! -nargs=1 -complete=arglist DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             1            arglist     :",
        \           execute('command DoCmd'))
  command! -nargs=* -complete=augroup DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             *            augroup     :",
        \           execute('command DoCmd'))
  command! -nargs=? -complete=custom,CustomComplete DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             ?            custom      :",
        \           execute('command DoCmd'))
  command! -nargs=+ -complete=customlist,CustomComplete DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             +            customlist  :",
        \           execute('command DoCmd'))

  " Test with various -narg= argument values.
  command! -nargs=0 DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0                        :",
        \           execute('command DoCmd'))
  command! -nargs=1 DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             1                        :",
        \           execute('command DoCmd'))
  command! -nargs=* DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             *                        :",
        \           execute('command DoCmd'))
  command! -nargs=? DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             ?                        :",
        \           execute('command DoCmd'))
  command! -nargs=+ DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             +                        :",
        \           execute('command DoCmd'))

  " Test with other arguments.
  command! -bang DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n!   DoCmd             0                        :",
        \           execute('command DoCmd'))
  command! -bar DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n|   DoCmd             0                        :",
        \           execute('command DoCmd'))
  command! -register DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n\"   DoCmd             0                        :",
        \           execute('command DoCmd'))
  command! -buffer DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\nb   DoCmd             0                        :"
        \        .. "\n\"   DoCmd             0                        :",
        \           execute('command DoCmd'))
  comclear

  " Test with many args.
  command! -bang -bar -register -buffer -nargs=+ -complete=environment -addr=windows -count=3 DoCmd :
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n!\"b|DoCmd             +    3c win  environment :",
        \           execute('command DoCmd'))
  comclear

  " Test with special characters in command definition.
  command! DoCmd :<cr><tab><c-d>
  call assert_equal("\n    Name              Args Address Complete    Definition"
        \        .. "\n    DoCmd             0                        :<CR><Tab><C-D>",
        \           execute('command DoCmd'))

  " Test output in verbose mode.
  command! DoCmd :
  call assert_match("^\n"
        \        .. "    Name              Args Address Complete    Definition\n"
        \        .. "    DoCmd             0                        :\n"
        \        .. "\tLast set from .*/test_usercommands.vim line \\d\\+$",
        \           execute('verbose command DoCmd'))

  comclear
  call assert_equal("\nNo user-defined commands found", execute(':command Xxx'))
  call assert_equal("\nNo user-defined commands found", execute('command'))
endfunc
