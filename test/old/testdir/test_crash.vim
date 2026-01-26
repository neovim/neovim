" Some tests, that used to crash Vim
source check.vim
source screendump.vim

CheckScreendump

" Run the command in terminal and wait for it to complete via notification
func s:RunCommandAndWait(buf, cmd)
  call term_sendkeys(a:buf, a:cmd .. "; printf '" .. TermNotifyParentCmd(v:false) .. "'\<cr>")
  if ValgrindOrAsan()
    " test times out on ASAN CI builds
    call WaitForChildNotification(10000)
  else
    call WaitForChildNotification()
  endif
endfunc

func Test_crash1()
  CheckNotBSD
  CheckExecutable dash

  " The following used to crash Vim
  let opts = #{cmd: 'sh'}
  let vim  = GetVimProg()

  let buf = RunVimInTerminal('sh', opts)

  let file = 'crash/poc_huaf1'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ '  && echo "crash 1: [OK]" > X_crash1_result.txt')

  let file = 'crash/poc_huaf2'
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ '  && echo "crash 2: [OK]" >> X_crash1_result.txt')

  let file = 'crash/poc_huaf3'
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ '  && echo "crash 3: [OK]" >> X_crash1_result.txt')

  let file = 'crash/bt_quickfix_poc'
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ '  && echo "crash 4: [OK]" >> X_crash1_result.txt')
  " clean up
  call delete('Xerr')

  let file = 'crash/poc_tagfunc.vim'
  let args = printf(cmn_args, vim, file)
  " using || because this poc causes vim to exit with exitstatus != 0
  call s:RunCommandAndWait(buf, args ..
    \ '  || echo "crash 5: [OK]" >> X_crash1_result.txt')


  let file = 'crash/bt_quickfix1_poc'
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ '  && echo "crash 6: [OK]" >> X_crash1_result.txt')
  " clean up
  call delete('X')

  let file = 'crash/vim_regsub_both_poc'
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ '  && echo "crash 7: [OK]" >> X_crash1_result.txt')

  let file = 'crash/vim_msg_trunc_poc'
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ '  || echo "crash 8: [OK]" >> X_crash1_result.txt')

  let file = 'crash/crash_scrollbar'
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ '  && echo "crash 9: [OK]" >> X_crash1_result.txt')

  let file = 'crash/editing_arg_idx_POC_1'
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ '  || echo "crash 10: [OK]" >> X_crash1_result.txt')
  call delete('Xerr')
  call delete('@')

  " clean up
  exe buf .. "bw!"

  sp X_crash1_result.txt

  let expected = [
      \ 'crash 1: [OK]',
      \ 'crash 2: [OK]',
      \ 'crash 3: [OK]',
      \ 'crash 4: [OK]',
      \ 'crash 5: [OK]',
      \ 'crash 6: [OK]',
      \ 'crash 7: [OK]',
      \ 'crash 8: [OK]',
      \ 'crash 9: [OK]',
      \ 'crash 10: [OK]',
      \ ]

  call assert_equal(expected, getline(1, '$'))
  bw!

  call delete('X_crash1_result.txt')
endfunc

func Test_crash1_2()
  CheckNotBSD
  CheckExecutable dash

  " The following used to crash Vim
  let opts = #{cmd: 'sh'}
  let vim  = GetVimProg()
  let result = 'X_crash1_2_result.txt'

  let buf = RunVimInTerminal('sh', opts)

  let file = 'crash/poc1'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ '  && echo "crash 1: [OK]" > '.. result)

  let file = 'crash/poc_win_enter_ext'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ '  && echo "crash 2: [OK]" >> '.. result)

  let file = 'crash/poc_suggest_trie_walk'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ '  && echo "crash 3: [OK]" >> '.. result)

  let file = 'crash/poc_did_set_langmap'
  let cmn_args = "%s -u NONE -i NONE -n -X -m -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ ' ; echo "crash 4: [OK]" >> '.. result)

  let file = 'crash/reverse_text_overflow'
  let cmn_args = "%s -u NONE -i NONE -n -X -m -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ ' ; echo "crash 5: [OK]" >> '.. result)

  let file = 'Xdiff'
  let lines =<< trim END
    diffs a
    edit Xdiff
    file b
    exe "norm! \<C-w>\<C-w>"
    exe "norm! \<C-w>\<C-w>"
    exe "norm! \<C-w>\<C-w>"
    exe "norm! \<C-w>\<C-w>"
    exe "norm! \<C-w>\<C-w>"
    exe "norm! \<C-w>\L"
    exe "norm! \<C-j>oy\<C-j>"
    edit Xdiff
    sil!so
  END
  call writefile(lines, file, 'D')
  let cmn_args = "%s -u NONE -i NONE -X -m -n -e -s -u %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args ..
    \ ' && echo "crash 6: [OK]" >> '.. result)


  " clean up
  exe buf .. "bw!"
  exe "sp " .. result
  let expected = [
      \ 'crash 1: [OK]',
      \ 'crash 2: [OK]',
      \ 'crash 3: [OK]',
      \ 'crash 4: [OK]',
      \ 'crash 5: [OK]',
      \ 'crash 6: [OK]',
      \ ]

  call assert_equal(expected, getline(1, '$'))
  bw!
  call delete(result)
endfunc

" This test just runs various scripts, that caused issues before.
" We are not really asserting anything here, it's just important
" that ASAN does not detect any issues.
func Test_crash1_3()
  let vim  = GetVimProg()
  let buf = RunVimInTerminal('sh', #{cmd: 'sh'})

  let file = 'crash/poc_ex_substitute'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args)

  let file = 'crash/poc_uaf_exec_instructions'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args)

  let file = 'crash/poc_uaf_check_argument_types'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args)

  let file = 'crash/double_free'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args)

  let file = 'crash/dialog_changed_uaf'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args)

  let file = 'crash/nullpointer'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args)

  let file = 'crash/heap_overflow3'
  let cmn_args = "%s -u NONE -i NONE -n -X -m -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args)

  let file = 'crash/heap_overflow_glob2regpat'
  let cmn_args = "%s -u NONE -i NONE -n -X -m -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args)

  let file = 'crash/nullptr_regexp_nfa'
  let cmn_args = "%s -u NONE -i NONE -n -X -m -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call s:RunCommandAndWait(buf, args)

  " clean up
  exe buf .. "bw!"
  bw!
endfunc

func Test_crash2()
  CheckScreendump
  " The following used to crash Vim
  let opts = #{wait_for_ruler: 0, rows: 20}
  let args = ' -u NONE -i NONE -n -e -s -S '
  let buf = RunVimInTerminal(args .. ' crash/vim_regsub_both', opts)
  call VerifyScreenDump(buf, 'Test_crash_01', {})
  exe buf .. "bw!"
endfunc

func TearDown()
  " That file is created at Test_crash1_3() by dialog_changed_uaf
  " but cleaning up in that test doesn't remove it. Let's try again at
  " the end of this test script
  call delete('Untitled')
endfunc

func Test_crash_bufwrite()
  let lines =<< trim END
    w! ++enc=ucs4 Xoutput
    call writefile(['done'], 'Xbufwrite')
  END
  call writefile(lines, 'Xvimrc')
  let opts = #{wait_for_ruler: 0, rows: 20}
  let args = ' -u NONE -i NONE -b -S Xvimrc'
  let buf = RunVimInTerminal(args .. ' samples/buffer-test.txt', opts)
  call TermWait(buf, 1000)
  call StopVimInTerminal(buf)
  call WaitForAssert({-> assert_true(filereadable('Xbufwrite'))})
  call assert_equal(['done'], readfile('Xbufwrite'))
  call delete('Xbufwrite')
  call delete('Xoutput')
  call delete('Xvimrc')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
