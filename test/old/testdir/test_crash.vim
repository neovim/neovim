" Some tests, that used to crash Vim
source check.vim
source screendump.vim

CheckScreendump

func Test_crash1()
  CheckNotBSD
  CheckExecutable dash
  " Test 7 fails on Mac ...
  CheckNotMac

  " The following used to crash Vim
  let opts = #{cmd: 'sh'}
  let vim  = GetVimProg()

  let buf = RunVimInTerminal('sh', opts)

  let file = 'crash/poc_huaf1'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args ..
    \ '  && echo "crash 1: [OK]" > X_crash1_result.txt' .. "\<cr>")
  call TermWait(buf, 50)

  let file = 'crash/poc_huaf2'
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args ..
    \ '  && echo "crash 2: [OK]" >> X_crash1_result.txt' .. "\<cr>")
  call TermWait(buf, 50)

  let file = 'crash/poc_huaf3'
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args ..
    \ '  && echo "crash 3: [OK]" >> X_crash1_result.txt' .. "\<cr>")
  call TermWait(buf, 100)

  let file = 'crash/bt_quickfix_poc'
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args ..
    \ '  && echo "crash 4: [OK]" >> X_crash1_result.txt' .. "\<cr>")
  " clean up
  call delete('Xerr')
  " This test takes a bit longer
  call TermWait(buf, 1000)

  let file = 'crash/poc_tagfunc.vim'
  let args = printf(cmn_args, vim, file)
  " using || because this poc causes vim to exit with exitstatus != 0
  call term_sendkeys(buf, args ..
    \ '  || echo "crash 5: [OK]" >> X_crash1_result.txt' .. "\<cr>")

  call TermWait(buf, 100)

  let file = 'crash/bt_quickfix1_poc'
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args ..
    \ '  && echo "crash 6: [OK]" >> X_crash1_result.txt' .. "\<cr>")
  " clean up
  call delete('X')
  call TermWait(buf, 3000)

  let file = 'crash/vim_regsub_both_poc'
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args ..
    \ '  && echo "crash 7: [OK]" >> X_crash1_result.txt' .. "\<cr>")
  call TermWait(buf, 3000)

  let file = 'crash/vim_msg_trunc_poc'
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args ..
    \ '  || echo "crash 8: [OK]" >> X_crash1_result.txt' .. "\<cr>")
  call TermWait(buf, 3000)

  let file = 'crash/crash_scrollbar'
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args ..
    \ '  && echo "crash 9: [OK]" >> X_crash1_result.txt' .. "\<cr>")
  call TermWait(buf, 1000)

  let file = 'crash/editing_arg_idx_POC_1'
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args ..
    \ '  || echo "crash 10: [OK]" >> X_crash1_result.txt' .. "\<cr>")
  call TermWait(buf, 1000)
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
  let g:test_is_flaky = 1

  " The following used to crash Vim
  let opts = #{cmd: 'sh'}
  let vim  = GetVimProg()
  let result = 'X_crash1_2_result.txt'

  let buf = RunVimInTerminal('sh', opts)

  let file = 'crash/poc1'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args ..
    \ '  && echo "crash 1: [OK]" > '.. result .. "\<cr>")
  call TermWait(buf, 150)

  let file = 'crash/poc_win_enter_ext'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args ..
    \ '  && echo "crash 2: [OK]" >> '.. result .. "\<cr>")
  call TermWait(buf, 350)

  let file = 'crash/poc_suggest_trie_walk'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args ..
    \ '  && echo "crash 3: [OK]" >> '.. result .. "\<cr>")
  call TermWait(buf, 150)

  let file = 'crash/poc_did_set_langmap'
  let cmn_args = "%s -u NONE -i NONE -n -X -m -n -e -s -S %s -c ':qa!'"
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args ..
    \ ' ; echo "crash 4: [OK]" >> '.. result .. "\<cr>")
  call TermWait(buf, 150)

  " clean up
  exe buf .. "bw!"
  exe "sp " .. result
  let expected = [
      \ 'crash 1: [OK]',
      \ 'crash 2: [OK]',
      \ 'crash 3: [OK]',
      \ 'crash 4: [OK]',
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
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'\<cr>"
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args)
  call TermWait(buf, 150)

  let file = 'crash/poc_uaf_exec_instructions'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'\<cr>"
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args)
  call TermWait(buf, 150)

  let file = 'crash/poc_uaf_check_argument_types'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'\<cr>"
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args)
  call TermWait(buf, 150)

  let file = 'crash/double_free'
  let cmn_args = "%s -u NONE -i NONE -n -e -s -S %s -c ':qa!'\<cr>"
  let args = printf(cmn_args, vim, file)
  call term_sendkeys(buf, args)
  call TermWait(buf, 50)

  " clean up
  exe buf .. "bw!"
  bw!
endfunc

func Test_crash2()
  " The following used to crash Vim
  let opts = #{wait_for_ruler: 0, rows: 20}
  let args = ' -u NONE -i NONE -n -e -s -S '
  let buf = RunVimInTerminal(args .. ' crash/vim_regsub_both', opts)
  call VerifyScreenDump(buf, 'Test_crash_01', {})
  exe buf .. "bw!"
endfunc

" vim: shiftwidth=2 sts=2 expandtab
