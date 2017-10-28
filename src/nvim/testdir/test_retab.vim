" Test :retab
func SetUp()
  new
  call setline(1, "\ta  \t    b        c    ")
endfunc

func TearDown()
  bwipe!
endfunc

func Retab(bang, n)
  let l:old_tabstop = &tabstop
  let l:old_line = getline(1)
  exe "retab" . a:bang . a:n
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
endfunc

func Test_retab_error()
  call assert_fails('retab -1',  'E487:')
  call assert_fails('retab! -1', 'E487:')
endfunc
