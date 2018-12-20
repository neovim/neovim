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
  call assert_fails('com! X :', 'E841:')
  call assert_fails('com! - DoCmd :', 'E175:')
  call assert_fails('com! -xxx DoCmd :', 'E181:')
  call assert_fails('com! -addr DoCmd :', 'E179:')
  call assert_fails('com! -complete DoCmd :', 'E179:')
  call assert_fails('com! -complete=xxx DoCmd :', 'E180:')
  call assert_fails('com! -complete=custom DoCmd :', 'E467:')
  call assert_fails('com! -complete=customlist DoCmd :', 'E467:')
  call assert_fails('com! -complete=behave,CustomComplete DoCmd :', 'E468:')
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
  call assert_equal('"com -addr=arguments buffers lines loaded_buffers quickfix tabs windows', @:)

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

  com! -complete=behave DoCmd :
  call feedkeys(":DoCmd \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"DoCmd mswin xterm', @:)

  " This does not work. Why?
  "call feedkeys(":DoCmd x\<C-A>\<C-B>\"\<CR>", 'tx')
  "call assert_equal('"DoCmd xterm', @:)

  com! -complete=custom,CustomComplete DoCmd :
  call feedkeys(":DoCmd \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"DoCmd January February Mars', @:)

  com! -complete=customlist,CustomCompleteList DoCmd :
  call feedkeys(":DoCmd \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"DoCmd Monday Tuesday Wednesday', @:)

  com! -complete=custom,CustomCompleteList DoCmd :
  call assert_fails("call feedkeys(':DoCmd \<C-D>', 'tx')", 'E730:')

  com! -complete=customlist,CustomComp DoCmd :
  call assert_fails("call feedkeys(':DoCmd \<C-D>', 'tx')", 'E117:')
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
