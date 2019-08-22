" Test Vim profiler
if !has('profile')
  finish
endif

func Test_profile_func()
  let lines = [
    \ 'profile start Xprofile_func.log',
    \ 'profile func Foo*"',
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
    \ . ' -es --clean'
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
    \ . ' -es --clean'
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
  call assert_match('    2              0.\d\+ func! Foo()',          lines[6])
  call assert_equal('                            endfunc',            lines[7])
  " Loop iterates 10 times. Since script runs twice, body executes 20 times.
  " First line of loop executes one more time than body to detect end of loop.
  call assert_match('^\s*22\s\+\d\+\.\d\+\s\+for i in range(10)$',    lines[8])
  call assert_equal('                              " a comment',      lines[9])
  " if self and total are equal we only get one number
  call assert_match('^\s*20\s\+\(\d\+\.\d\+\s\+\)\=\d\+\.\d\+\s\+call Foo()$', lines[10])
  call assert_match('^\s*20\s\+\d\+\.\d\+\s\+endfor$',                lines[11])
  " if self and total are equal we only get one number
  call assert_match('^\s*2\s\+\(\d\+\.\d\+\s\+\)\=\d\+\.\d\+\s\+call Foo()$', lines[12])
  call assert_equal('',                                               lines[13])

  call delete('Xprofile_file.vim')
  call delete('Xprofile_file.log')
endfunc

func Test_profile_file_with_cont()
  let lines = [
    \ 'echo "hello',
    \ '  \ world"',
    \ 'echo "foo ',
    \ '  \bar"',
    \ ]

  call writefile(lines, 'Xprofile_file.vim')
  call system(v:progpath
    \ . ' -es -u NONE -U NONE -i NONE --noplugin'
    \ . ' -c "profile start Xprofile_file.log"'
    \ . ' -c "profile file Xprofile_file.vim"'
    \ . ' -c "so Xprofile_file.vim"'
    \ . ' -c "qall!"')
  call assert_equal(0, v:shell_error)

  let lines = readfile('Xprofile_file.log')
  call assert_equal(11, len(lines))

  call assert_match('^SCRIPT .*Xprofile_file.vim$',           lines[0])
  call assert_equal('Sourced 1 time',                         lines[1])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',            lines[2])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',            lines[3])
  call assert_equal('',                                       lines[4])
  call assert_equal('count  total (s)   self (s)',            lines[5])
  call assert_match('    1              0.\d\+ echo "hello',  lines[6])
  call assert_equal('                              \ world"', lines[7])
  call assert_match('    1              0.\d\+ echo "foo ',   lines[8])
  call assert_equal('                              \bar"',    lines[9])
  call assert_equal('',                                       lines[10])

  call delete('Xprofile_file.vim')
  call delete('Xprofile_file.log')
endfunc

func Test_profile_completion()
  call feedkeys(":profile \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profile continue dump file func pause start stop', @:)

  call feedkeys(":profile start test_prof\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"profile start.* test_profile\.vim', @:)
endfunc

func Test_profile_errors()
  call assert_fails("profile func Foo", 'E750:')
  call assert_fails("profile pause", 'E750:')
  call assert_fails("profile continue", 'E750:')
endfunc

func Test_profile_truncate_mbyte()
  if &enc !=# 'utf-8'
    return
  endif

  let lines = [
    \ 'scriptencoding utf-8',
    \ 'func! Foo()',
    \ '  return [',
    \ '  \ "' . join(map(range(0x4E00, 0x4E00 + 340), 'nr2char(v:val)'), '') . '",',
    \ '  \ "' . join(map(range(0x4F00, 0x4F00 + 340), 'nr2char(v:val)'), '') . '",',
    \ '  \ ]',
    \ 'endfunc',
    \ 'call Foo()',
    \ ]

  call writefile(lines, 'Xprofile_file.vim')
  call system(v:progpath
    \ . ' -es --cmd "set enc=utf-8"'
    \ . ' -c "profile start Xprofile_file.log"'
    \ . ' -c "profile file Xprofile_file.vim"'
    \ . ' -c "so Xprofile_file.vim"'
    \ . ' -c "qall!"')
  call assert_equal(0, v:shell_error)

  split Xprofile_file.log
  if &fenc != ''
    call assert_equal('utf-8', &fenc)
  endif
  /func! Foo()
  let lnum = line('.')
  call assert_match('^\s*return \[$', getline(lnum + 1))
  call assert_match("\u4F52$", getline(lnum + 2))
  call assert_match("\u5052$", getline(lnum + 3))
  call assert_match('^\s*\\ \]$', getline(lnum + 4))
  bwipe!

  call delete('Xprofile_file.vim')
  call delete('Xprofile_file.log')
endfunc

func Test_profdel_func()
  let lines = [
    \  'profile start Xprofile_file.log',
    \  'func! Foo1()',
    \  'endfunc',
    \  'func! Foo2()',
    \  'endfunc',
    \  'func! Foo3()',
    \  'endfunc',
    \  '',
    \  'profile func Foo1',
    \  'profile func Foo2',
    \  'call Foo1()',
    \  'call Foo2()',
    \  '',
    \  'profile func Foo3',
    \  'profdel func Foo2',
    \  'profdel func Foo3',
    \  'call Foo1()',
    \  'call Foo2()',
    \  'call Foo3()' ]
  call writefile(lines, 'Xprofile_file.vim')
  call system(v:progpath . ' -es --clean -c "so Xprofile_file.vim" -c q')
  call assert_equal(0, v:shell_error)

  let lines = readfile('Xprofile_file.log')
  call assert_equal(24, len(lines))

  " Check that:
  " - Foo1() is called twice (profdel not invoked)
  " - Foo2() is called once (profdel invoked after it was called)
  " - Foo3() is not called (profdel invoked before it was called)
  call assert_equal('FUNCTION  Foo1()',               lines[0])
  call assert_equal('Called 2 times',                 lines[1])
  call assert_equal('FUNCTION  Foo2()',               lines[7])
  call assert_equal('Called 1 time',                  lines[8])
  call assert_equal('FUNCTIONS SORTED ON TOTAL TIME', lines[14])
  call assert_equal('FUNCTIONS SORTED ON SELF TIME',  lines[19])

  call delete('Xprofile_file.vim')
  call delete('Xprofile_file.log')
endfunc

func Test_profdel_star()
  " Foo() is invoked once before and once after 'profdel *'.
  " So profiling should report it only once.
  let lines = [
    \  'profile start Xprofile_file.log',
    \  'func! Foo()',
    \  'endfunc',
    \  'profile func Foo',
    \  'call Foo()',
    \  'profdel *',
    \  'call Foo()' ]
  call writefile(lines, 'Xprofile_file.vim')
  call system(v:progpath . ' -es --clean -c "so Xprofile_file.vim" -c q')
  call assert_equal(0, v:shell_error)

  let lines = readfile('Xprofile_file.log')
  call assert_equal(15, len(lines))

  call assert_equal('FUNCTION  Foo()',                lines[0])
  call assert_equal('Called 1 time',                  lines[1])
  call assert_equal('FUNCTIONS SORTED ON TOTAL TIME', lines[7])
  call assert_equal('FUNCTIONS SORTED ON SELF TIME',  lines[11])

  call delete('Xprofile_file.vim')
  call delete('Xprofile_file.log')
endfunc
