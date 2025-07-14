" Test :retab

source check.vim

func SetUp()
  new
  call setline(1, "\ta  \t    b        c    ")
endfunc

func TearDown()
  bwipe!
endfunc

func Retab(bang, n, subopt='', test_line='')
  let l:old_tabstop = &tabstop
  let l:old_line = getline(1)
  if a:test_line != ''
    call setline(1, a:test_line)
  endif
  exe "retab" . a:bang . ' ' . a:subopt . ' ' . a:n
  let l:line = getline(1)
  call setline(1, l:old_line)
  if a:n > 0
    " :retab changes 'tabstop' to n with argument n > 0.
    call assert_equal(a:n, &tabstop)
    exe 'set tabstop=' . l:old_tabstop
  else
    " :retab does not change 'tabstop' with empty or n <= 0.
    call assert_equal(l:old_tabstop, &tabstop)
  endif
  return l:line
endfunc

func Test_retab()
  set tabstop=8 noexpandtab
  call assert_equal("\ta\t    b        c    ",            Retab('',  ''))
  call assert_equal("\ta\t    b        c    ",            Retab('',  0))
  call assert_equal("\ta\t    b        c    ",            Retab('',  8))
  call assert_equal("\ta\t    b\t     c\t  ",             Retab('!', ''))
  call assert_equal("\ta\t    b\t     c\t  ",             Retab('!', 0))
  call assert_equal("\ta\t    b\t     c\t  ",             Retab('!', 8))

  call assert_equal("\t\ta\t\t\tb        c    ",          Retab('',  4))
  call assert_equal("\t\ta\t\t\tb\t\t c\t  ",             Retab('!', 4))

  call assert_equal("        a\t\tb        c    ",        Retab('',  10))
  call assert_equal("        a\t\tb        c    ",        Retab('!', 10))

  set tabstop=8 expandtab
  call assert_equal("        a           b        c    ", Retab('',  ''))
  call assert_equal("        a           b        c    ", Retab('',  0))
  call assert_equal("        a           b        c    ", Retab('',  8))
  call assert_equal("        a           b        c    ", Retab('!', ''))
  call assert_equal("        a           b        c    ", Retab('!', 0))
  call assert_equal("        a           b        c    ", Retab('!', 8))

  call assert_equal("        a           b        c    ", Retab(' ', 4))
  call assert_equal("        a           b        c    ", Retab('!', 4))

  call assert_equal("        a           b        c    ", Retab(' ', 10))
  call assert_equal("        a           b        c    ", Retab('!', 10))

  set tabstop=4 noexpandtab
  call assert_equal("\ta\t\tb        c    ",              Retab('',  ''))
  call assert_equal("\ta\t\tb\t\t c\t  ",                 Retab('!', ''))
  call assert_equal("\t a\t\t\tb        c    ",           Retab('',  3))
  call assert_equal("\t a\t\t\tb\t\t\tc\t  ",             Retab('!', 3))
  call assert_equal("    a\t  b        c    ",            Retab('',  5))
  call assert_equal("    a\t  b\t\t c\t ",                Retab('!', 5))

  set tabstop=4 expandtab
  call assert_equal("    a       b        c    ",         Retab('',  ''))
  call assert_equal("    a       b        c    ",         Retab('!', ''))
  call assert_equal("    a       b        c    ",         Retab('',  3))
  call assert_equal("    a       b        c    ",         Retab('!', 3))
  call assert_equal("    a       b        c    ",         Retab('',  5))
  call assert_equal("    a       b        c    ",         Retab('!', 5))

  " Test with '-indentonly'
  let so='-indentonly'
  set tabstop=8 noexpandtab
  call assert_equal("\ta  \t    b        c    ",          Retab('',  '', so))
  call assert_equal("\ta  \t    b        c    ",          Retab('',  0, so))
  call assert_equal("\ta  \t    b        c    ",          Retab('',  8, so))
  call assert_equal("\ta  \t    b        c    ",          Retab('!', '', so))
  call assert_equal("\ta  \t    b        c    ",          Retab('!', 0, so))
  call assert_equal("\ta  \t    b        c    ",          Retab('!', 8, so))

  call assert_equal("\t\ta  \t    b        c    ",        Retab('',  4, so))
  call assert_equal("\t\ta  \t    b        c    ",        Retab('!', 4, so))

  call assert_equal("        a  \t    b        c    ",    Retab('',  10, so))
  call assert_equal("        a  \t    b        c    ",    Retab('!', 10, so))

  set tabstop=8 expandtab
  call assert_equal("        a  \t    b        c    ",    Retab('',  '', so))
  call assert_equal("        a  \t    b        c    ",    Retab('',  0, so))
  call assert_equal("        a  \t    b        c    ",    Retab('',  8, so))
  call assert_equal("        a  \t    b        c    ",    Retab('!', '', so))
  call assert_equal("        a  \t    b        c    ",    Retab('!', 0, so))
  call assert_equal("        a  \t    b        c    ",    Retab('!', 8, so))

  call assert_equal("        a  \t    b        c    ",    Retab(' ', 4, so))
  call assert_equal("        a  \t    b        c    ",    Retab('!', 4, so))

  call assert_equal("        a  \t    b        c    ",    Retab(' ', 10, so))
  call assert_equal("        a  \t    b        c    ",    Retab('!', 10, so))

  set tabstop=4 noexpandtab
  call assert_equal("\ta  \t    b        c    ",          Retab('',  '', so))
  call assert_equal("\ta  \t    b        c    ",          Retab('!', '', so))
  call assert_equal("\t a  \t    b        c    ",         Retab('',  3, so))
  call assert_equal("\t a  \t    b        c    ",         Retab('!', 3, so))
  call assert_equal("    a  \t    b        c    ",        Retab('',  5, so))
  call assert_equal("    a  \t    b        c    ",        Retab('!', 5, so))

  set tabstop=4 expandtab
  call assert_equal("    a  \t    b        c    ",        Retab('',  '', so))
  call assert_equal("    a  \t    b        c    ",        Retab('!', '', so))
  call assert_equal("    a  \t    b        c    ",        Retab('',  3, so))
  call assert_equal("    a  \t    b        c    ",        Retab('!', 3, so))
  call assert_equal("    a  \t    b        c    ",        Retab('',  5, so))
  call assert_equal("    a  \t    b        c    ",        Retab('!', 5, so))

  " Test for variations in leading whitespace
  let so='-indentonly'
  let test_line="    \t    a\t        "
  set tabstop=8 noexpandtab
  call assert_equal("\t    a\t        ",    Retab('',  '', so, test_line))
  call assert_equal("\t    a\t        ",    Retab('!',  '', so, test_line))
  set tabstop=8 expandtab
  call assert_equal("            a\t        ", Retab('',  '', so, test_line))
  call assert_equal("            a\t        ", Retab('!',  '', so, test_line))

  let test_line="            a\t        "
  set tabstop=8 noexpandtab
  call assert_equal(test_line,              Retab('',  '', so, test_line))
  call assert_equal("\t    a\t        ",    Retab('!',  '', so, test_line))
  set tabstop=8 expandtab
  call assert_equal(test_line,              Retab('',  '', so, test_line))
  call assert_equal(test_line,              Retab('!',  '', so, test_line))

  set tabstop& expandtab&
endfunc

func Test_retab_error()
  call assert_fails('retab -1',  'E487:')
  call assert_fails('retab! -1', 'E487:')
  call assert_fails('ret -1000', 'E487:')
  call assert_fails('ret 10000', 'E475:')
  call assert_fails('ret 80000000000000000000', 'E475:')
  call assert_fails('retab! -in', 'E475:')
  call assert_fails('retab! -indentonly2', 'E475:')
  call assert_fails('retab! -indentonlyx 0', 'E475:')
endfunc

func RetabLoop()
  while 1
    set ts=4000
    retab 4
  endwhile
endfunc

func Test_retab_endless()
  " inside try/catch we can catch the error message
  call setline(1, "\t0\t")
  let caught = 'no'
  try
    call RetabLoop()
  catch /E1240:/
    let caught = v:exception
  endtry
  call assert_match('E1240:', caught)

  set tabstop&
endfunc

func Test_nocatch_retab_endless()
  " when not inside try/catch an interrupt is generated to get out of loops
  call setline(1, "\t0\t")
  call assert_fails('call RetabLoop()', ['E1240:', 'Interrupted'])

  set tabstop&
endfunc


" vim: shiftwidth=2 sts=2 expandtab
