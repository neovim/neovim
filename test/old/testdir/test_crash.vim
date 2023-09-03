" Some tests, that used to crash Vim
source check.vim
source screendump.vim

CheckScreendump

func Test_crash1()
  " The following used to crash Vim
  let opts = #{wait_for_ruler: 0, rows: 20}
  let args = ' -u NONE -i NONE -n -e -s -S '
  let buf = RunVimInTerminal(args .. ' crash/poc_huaf1', opts)
  call VerifyScreenDump(buf, 'Test_crash_01', {})
  exe buf .. "bw!"

  let buf = RunVimInTerminal(args .. ' crash/poc_huaf2', opts)
  call VerifyScreenDump(buf, 'Test_crash_01', {})
  exe buf .. "bw!"

  let buf = RunVimInTerminal(args .. ' crash/poc_huaf3', opts)
  call VerifyScreenDump(buf, 'Test_crash_01', {})
  exe buf .. "bw!"

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
