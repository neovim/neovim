" Test ga normal command, and :ascii Ex command.
func Do_ga(c)
  call setline(1, a:c)
  let l:a = execute("norm 1goga")
  let l:b = execute("ascii")
  call assert_equal(l:a, l:b)
  return l:a
endfunc

func Test_ga_command()
  new
  set display=uhex
  call assert_equal("\nNUL",                            Do_ga(''))
  call assert_equal("\n<<01>>  1,  Hex 01,  Oct 001, Digr SH", Do_ga("\x01"))
  call assert_equal("\n<<09>>  9,  Hex 09,  Oct 011, Digr HT", Do_ga("\t"))

  set display=
  call assert_equal("\nNUL",                             Do_ga(''))
  call assert_equal("\n<^A>  1,  Hex 01,  Oct 001, Digr SH",    Do_ga("\x01"))
  call assert_equal("\n<^I>  9,  Hex 09,  Oct 011, Digr HT",    Do_ga("\t"))
  call assert_equal("\n<^@>  0,  Hex 00,  Octal 000",    Do_ga("\n"))

  call assert_equal("\n<e>  101,  Hex 65,  Octal 145",   Do_ga('e'))

  " Test a few multi-bytes characters.
  call assert_equal("\n<é> 233, Hex 00e9, Oct 351, Digr e'",    Do_ga('é'))
  call assert_equal("\n<ẻ> 7867, Hex 1ebb, Oct 17273, Digr e2", Do_ga('ẻ'))
  call assert_equal("\n<\U00012345> 74565, Hex 00012345, Octal 221505", Do_ga("\U00012345"))

  " Test with combining characters.
  call assert_equal("\n<e>  101,  Hex 65,  Octal 145 < ́> 769, Hex 0301, Octal 1401", Do_ga("e\u0301"))
  call assert_equal("\n<e>  101,  Hex 65,  Octal 145 < ́> 769, Hex 0301, Octal 1401 < ̱> 817, Hex 0331, Octal 1461", Do_ga("e\u0301\u0331"))
  call assert_equal("\n<e>  101,  Hex 65,  Octal 145 < ́> 769, Hex 0301, Octal 1401 < ̱> 817, Hex 0331, Octal 1461 < ̸> 824, Hex 0338, Octal 1470", Do_ga("e\u0301\u0331\u0338"))

  " When using Mac fileformat, CR instead of NL is used for line termination
  enew!
  set fileformat=mac
  call assert_equal("\n<^J>  10,  Hex 0a,  Oct 012, Digr NU",    Do_ga("\r"))

  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
