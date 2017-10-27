" Test Vim profiler
if !has('profile')
  finish
endif

func Test_profile_func()
  let lines = [
    \ "func! Foo1()",
    \ "endfunc",
    \ "func! Foo2()",
    \ "  let l:count = 100",
    \ "  while l:count > 0",
    \ "    let l:count = l:count - 1",
    \ "  endwhile",
    \ "endfunc",
    \ "func! Foo3()",
    \ "endfunc",
    \ "func! Bar()",
    \ "endfunc",
    \ "call Foo1()",
    \ "call Foo1()",
    \ "profile pause",
    \ "call Foo1()",
    \ "profile continue",
    \ "call Foo2()",
    \ "call Foo3()",
    \ "call Bar()",
    \ "if !v:profiling",
    \ "  delfunc Foo2",
    \ "endif",
    \ "delfunc Foo3",
    \ ]

  call writefile(lines, 'Xprofile_func.vim')
  call system(v:progpath
    \ . ' -es -u NONE -U NONE -i NONE --noplugin'
    \ . ' -c "profile start Xprofile_func.log"'
    \ . ' -c "profile func Foo*"'
    \ . ' -c "so Xprofile_func.vim"'
    \ . ' -c "qall!"')
  call assert_equal(0, v:shell_error)

  let lines = readfile('Xprofile_func.log')

  " - Foo1() is called 3 times but should be reported as called twice
  "   since one call is in between "profile pause" .. "profile continue".
  " - Foo2() should come before Foo1() since Foo1() does much more work.
  " - Foo3() is not reported because function is deleted.
  " - Unlike Foo3(), Foo2() should not be deleted since there is a check
  "   for v:profiling.
  " - Bar() is not reported since it does not match "profile func Foo*".
  call assert_equal(28, len(lines))

  call assert_equal('FUNCTION  Foo1()',                            lines[0])
  call assert_equal('Called 2 times',                              lines[1])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',                 lines[2])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',                 lines[3])
  call assert_equal('',                                            lines[4])
  call assert_equal('count  total (s)   self (s)',                 lines[5])
  call assert_equal('',                                            lines[6])
  call assert_equal('FUNCTION  Foo2()',                            lines[7])
  call assert_equal('Called 1 time',                               lines[8])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',                 lines[9])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',                 lines[10])
  call assert_equal('',                                            lines[11])
  call assert_equal('count  total (s)   self (s)',                 lines[12])
  call assert_match('^\s*1\s\+.*\slet l:count = 100$',             lines[13])
  call assert_match('^\s*101\s\+.*\swhile l:count > 0$',           lines[14])
  call assert_match('^\s*100\s\+.*\s  let l:count = l:count - 1$', lines[15])
  call assert_match('^\s*100\s\+.*\sendwhile$',                    lines[16])
  call assert_equal('',                                            lines[17])
  call assert_equal('FUNCTIONS SORTED ON TOTAL TIME',              lines[18])
  call assert_equal('count  total (s)   self (s)  function',       lines[19])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo2()$',              lines[20])
  call assert_match('^\s*2\s\+\d\+\.\d\+\s\+Foo1()$',              lines[21])
  call assert_equal('',                                            lines[22])
  call assert_equal('FUNCTIONS SORTED ON SELF TIME',               lines[23])
  call assert_equal('count  total (s)   self (s)  function',       lines[24])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo2()$',              lines[25])
  call assert_match('^\s*2\s\+\d\+\.\d\+\s\+Foo1()$',              lines[26])
  call assert_equal('',                                            lines[27])

  call delete('Xprofile_func.vim')
  call delete('Xprofile_func.log')
endfunc

func Test_profile_file()
  let lines = [
    \ 'func! Foo()',
    \ 'endfunc',
    \ 'for i in range(10)',
    \ '  " a comment',
    \ '  call Foo()',
    \ 'endfor',
    \ 'call Foo()',
    \ ]

  call writefile(lines, 'Xprofile_file.vim')
  call system(v:progpath
    \ . ' -es -u NONE -U NONE -i NONE --noplugin'
    \ . ' -c "profile start Xprofile_file.log"'
    \ . ' -c "profile file Xprofile_file.vim"'
    \ . ' -c "so Xprofile_file.vim"'
    \ . ' -c "so Xprofile_file.vim"'
    \ . ' -c "qall!"')
  call assert_equal(0, v:shell_error)

  let lines = readfile('Xprofile_file.log')

  call assert_equal(14, len(lines))

  call assert_match('^SCRIPT .*Xprofile_file.vim$',                   lines[0])
  call assert_equal('Sourced 2 times',                                lines[1])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',                    lines[2])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',                    lines[3])
  call assert_equal('',                                               lines[4])
  call assert_equal('count  total (s)   self (s)',                    lines[5])
  call assert_equal('                            func! Foo()',        lines[6])
  call assert_equal('                            endfunc',            lines[7])
  " Loop iterates 10 times. Since script runs twice, body executes 20 times.
  " First line of loop executes one more time than body to detect end of loop.
  call assert_match('^\s*22\s\+\d\+\.\d\+\s\+for i in range(10)$',    lines[8])
  call assert_equal('                              " a comment',      lines[9])
  call assert_match('^\s*20\s\+\d\+\.\d\+\s\+\d\+\.\d\+\s\+call Foo()$', lines[10])
  call assert_match('^\s*20\s\+\d\+\.\d\+\s\+endfor$',                lines[11])
  " if self and total are equal we only get one number
  call assert_match('^\s*2\s\+\(\d\+\.\d\+\s\+\)\=\d\+\.\d\+\s\+call Foo()$', lines[12])
  call assert_equal('',                                               lines[13])

  call delete('Xprofile_file.vim')
  call delete('Xprofile_file.log')
endfunc

func Test_profile_completion()
  call feedkeys(":profile \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profile continue file func pause start', @:)

  call feedkeys(":profile start test_prof\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"profile start.* test_profile\.vim', @:)
endfunc

func Test_profile_errors()
  call assert_fails("profile func Foo", 'E750:')
  call assert_fails("profile pause", 'E750:')
  call assert_fails("profile continue", 'E750:')
endfunc
