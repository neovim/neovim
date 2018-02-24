" Tests for regexp with backslash and other special characters inside []
" Also test backslash for hex/octal numbered character.

function RunSTest(value, calls, expected)
  new
  call feedkeys("i" . a:value, "mx")
  exec a:calls
  call assert_equal(a:expected, getline(1), printf("wrong result for %s", a:calls))
  quit!
endfunction

function RunXTest(value, search_exp, expected)
  new
  call feedkeys("i" . a:value, "mx")
  call feedkeys("gg" . a:search_exp . "\nx", "mx")
  call assert_equal(a:expected, getline(1), printf("wrong result for %s", a:search_exp))
  quit!
endfunction


function Test_x_search()
  let res = "test text test text"
  call RunXTest("test \\text test text", "/[\\x]", res)
  call RunXTest("test \ttext test text", "/[\\t\\]]", res)
  call RunXTest("test text ]test text", "/[]y]", res)
  call RunXTest("test ]text test text", "/[\\]]", res)
  call RunXTest("test text te^st text", "/[y^]", res)
  call RunXTest("test te$xt test text", "/[$y]", res)
  call RunXTest("test taext test text", "/[\\x61]", res)
  call RunXTest("test tbext test text","/[\\x60-\\x64]", res)
  call RunXTest("test 5text test text","/[\\x785]", res)
  call RunXTest("testc text test text","/[\\o143]", res)
  call RunXTest("tesdt text test text","/[\\o140-\\o144]", res)
  call RunXTest("test7 text test text", "/[\\o417]", res)
  call RunXTest("test text tBest text", "/\\%x42", res)
  call RunXTest("test text teCst text", "/\\%o103", res)
  call RunXTest("test text \<C-V>x00test text", "/[\\x00]", res)
endfunction

function Test_s_search()
  let res = "test text test text"
  call RunSTest("test te\<C-V>x00xt t\<C-V>x04est t\<C-V>x10ext", "s/[\\x00-\\x10]//g", res)
  call RunSTest("test \\xyztext test text", "s/[\\x-z]\\+//", res)
  call RunSTest("test text tev\\uyst text", "s/[\\u-z]\\{2,}//", res)
  call RunSTest("xx aaaaa xx a", "s/\\(a\\)\\+//", "xx  xx a")
  call RunSTest("xx aaaaa xx a", "s/\\(a*\\)\\+//", "xx aaaaa xx a")
  call RunSTest("xx aaaaa xx a", "s/\\(a*\\)*//", "xx aaaaa xx a")
  call RunSTest("xx aaaaa xx", "s/\\(a\\)\\{2,3}/A/", "xx Aaa xx")
  call RunSTest("xx aaaaa xx", "s/\\(a\\)\\{-2,3}/A/", "xx Aaaa xx")
  call RunSTest("xx aaa12aa xx", "s/\\(a\\)*\\(12\\)\\@>/A/", "xx Aaa xx")
  call RunSTest("xx foobar xbar xx", "s/\\(foo\\)\\@<!bar/A/", "xx foobar xA xx")
  call RunSTest("xx an file xx", "s/\\(an\\_s\\+\\)\\@<=file/A/", "xx an A xx")
  call RunSTest("x= 9;", "s/^\\(\\h\\w*\\%(->\\|\\.\\)\\=\\)\\+=/XX/", "XX 9;")
  call RunSTest("hh= 77;", "s/^\\(\\h\\w*\\%(->\\|\\.\\)\\=\\)\\+=/YY/", "YY 77;")
  call RunSTest(" aaa ", "s/aaa/xyz/", " xyz ")
  call RunSTest(" xyz", "s/~/bcd/", " bcd")
  call RunSTest(" bcdbcdbcd", "s/~\\+/BB/", " BB")
endfunction
