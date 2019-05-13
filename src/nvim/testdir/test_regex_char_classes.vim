" Tests for regexp with backslash and other special characters inside []
" Also test backslash for hex/octal numbered character.
"
if !has('multi_byte')
  finish
endif

scriptencoding utf-8

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

" Test character classes in regexp using regexpengine 0, 1, 2.
func Test_regex_char_classes()
  new
  let save_enc = &encoding
  set encoding=utf-8

  let input = "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"

  " Format is [cmd_to_run, expected_output]
  let tests = [
    \ [':s/\%#=0\d//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1\d//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2\d//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0[0-9]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1[0-9]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2[0-9]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0\D//g',
    \ "0123456789"],
    \ [':s/\%#=1\D//g',
    \ "0123456789"],
    \ [':s/\%#=2\D//g',
    \ "0123456789"],
    \ [':s/\%#=0[^0-9]//g',
    \ "0123456789"],
    \ [':s/\%#=1[^0-9]//g',
    \ "0123456789"],
    \ [':s/\%#=2[^0-9]//g',
    \ "0123456789"],
    \ [':s/\%#=0\o//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./89:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1\o//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./89:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2\o//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./89:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0[0-7]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./89:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1[0-7]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./89:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2[0-7]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./89:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0\O//g',
    \ "01234567"],
    \ [':s/\%#=1\O//g',
    \ "01234567"],
    \ [':s/\%#=2\O//g',
    \ "01234567"],
    \ [':s/\%#=0[^0-7]//g',
    \ "01234567"],
    \ [':s/\%#=1[^0-7]//g',
    \ "01234567"],
    \ [':s/\%#=2[^0-7]//g',
    \ "01234567"],
    \ [':s/\%#=0\x//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@GHIXYZ[\]^_`ghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1\x//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@GHIXYZ[\]^_`ghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2\x//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@GHIXYZ[\]^_`ghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0[0-9A-Fa-f]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@GHIXYZ[\]^_`ghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1[0-9A-Fa-f]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@GHIXYZ[\]^_`ghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2[0-9A-Fa-f]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@GHIXYZ[\]^_`ghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0\X//g',
    \ "0123456789ABCDEFabcdef"],
    \ [':s/\%#=1\X//g',
    \ "0123456789ABCDEFabcdef"],
    \ [':s/\%#=2\X//g',
    \ "0123456789ABCDEFabcdef"],
    \ [':s/\%#=0[^0-9A-Fa-f]//g',
    \ "0123456789ABCDEFabcdef"],
    \ [':s/\%#=1[^0-9A-Fa-f]//g',
    \ "0123456789ABCDEFabcdef"],
    \ [':s/\%#=2[^0-9A-Fa-f]//g',
    \ "0123456789ABCDEFabcdef"],
    \ [':s/\%#=0\w//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@[\]^`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1\w//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@[\]^`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2\w//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@[\]^`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0[0-9A-Za-z_]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@[\]^`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1[0-9A-Za-z_]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@[\]^`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2[0-9A-Za-z_]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./:;<=>?@[\]^`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0\W//g',
    \ "0123456789ABCDEFGHIXYZ_abcdefghiwxyz"],
    \ [':s/\%#=1\W//g',
    \ "0123456789ABCDEFGHIXYZ_abcdefghiwxyz"],
    \ [':s/\%#=2\W//g',
    \ "0123456789ABCDEFGHIXYZ_abcdefghiwxyz"],
    \ [':s/\%#=0[^0-9A-Za-z_]//g',
    \ "0123456789ABCDEFGHIXYZ_abcdefghiwxyz"],
    \ [':s/\%#=1[^0-9A-Za-z_]//g',
    \ "0123456789ABCDEFGHIXYZ_abcdefghiwxyz"],
    \ [':s/\%#=2[^0-9A-Za-z_]//g',
    \ "0123456789ABCDEFGHIXYZ_abcdefghiwxyz"],
    \ [':s/\%#=0\h//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1\h//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2\h//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0[A-Za-z_]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1[A-Za-z_]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2[A-Za-z_]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0\H//g',
    \ "ABCDEFGHIXYZ_abcdefghiwxyz"],
    \ [':s/\%#=1\H//g',
    \ "ABCDEFGHIXYZ_abcdefghiwxyz"],
    \ [':s/\%#=2\H//g',
    \ "ABCDEFGHIXYZ_abcdefghiwxyz"],
    \ [':s/\%#=0[^A-Za-z_]//g',
    \ "ABCDEFGHIXYZ_abcdefghiwxyz"],
    \ [':s/\%#=1[^A-Za-z_]//g',
    \ "ABCDEFGHIXYZ_abcdefghiwxyz"],
    \ [':s/\%#=2[^A-Za-z_]//g',
    \ "ABCDEFGHIXYZ_abcdefghiwxyz"],
    \ [':s/\%#=0\a//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^_`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1\a//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^_`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2\a//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^_`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0[A-Za-z]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^_`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1[A-Za-z]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^_`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2[A-Za-z]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^_`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0\A//g',
    \ "ABCDEFGHIXYZabcdefghiwxyz"],
    \ [':s/\%#=1\A//g',
    \ "ABCDEFGHIXYZabcdefghiwxyz"],
    \ [':s/\%#=2\A//g',
    \ "ABCDEFGHIXYZabcdefghiwxyz"],
    \ [':s/\%#=0[^A-Za-z]//g',
    \ "ABCDEFGHIXYZabcdefghiwxyz"],
    \ [':s/\%#=1[^A-Za-z]//g',
    \ "ABCDEFGHIXYZabcdefghiwxyz"],
    \ [':s/\%#=2[^A-Za-z]//g',
    \ "ABCDEFGHIXYZabcdefghiwxyz"],
    \ [':s/\%#=0\l//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@ABCDEFGHIXYZ[\]^_`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1\l//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@ABCDEFGHIXYZ[\]^_`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2\l//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@ABCDEFGHIXYZ[\]^_`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0[a-z]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@ABCDEFGHIXYZ[\]^_`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1[a-z]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@ABCDEFGHIXYZ[\]^_`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2[a-z]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@ABCDEFGHIXYZ[\]^_`{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0\L//g',
    \ "abcdefghiwxyz"],
    \ [':s/\%#=1\L//g',
    \ "abcdefghiwxyz"],
    \ [':s/\%#=2\L//g',
    \ "abcdefghiwxyz"],
    \ [':s/\%#=0[^a-z]//g',
    \ "abcdefghiwxyz"],
    \ [':s/\%#=1[^a-z]//g',
    \ "abcdefghiwxyz"],
    \ [':s/\%#=2[^a-z]//g',
    \ "abcdefghiwxyz"],
    \ [':s/\%#=0\u//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1\u//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2\u//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0[A-Z]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1[A-Z]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2[A-Z]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./0123456789:;<=>?@[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0\U//g',
    \ "ABCDEFGHIXYZ"],
    \ [':s/\%#=1\U//g',
    \ "ABCDEFGHIXYZ"],
    \ [':s/\%#=2\U//g',
    \ "ABCDEFGHIXYZ"],
    \ [':s/\%#=0[^A-Z]//g',
    \ "ABCDEFGHIXYZ"],
    \ [':s/\%#=1[^A-Z]//g',
    \ "ABCDEFGHIXYZ"],
    \ [':s/\%#=2[^A-Z]//g',
    \ "ABCDEFGHIXYZ"],
    \ [':s/\%#=0\%' . line('.') . 'l^\t...//g',
    \ "!\"#$%&'()#+'-./0123456789:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1\%' . line('.') . 'l^\t...//g',
    \ "!\"#$%&'()#+'-./0123456789:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2\%' . line('.') . 'l^\t...//g',
    \ "!\"#$%&'()#+'-./0123456789:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0[0-z]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=1[0-z]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=2[0-z]//g',
    \ "\t\<C-L>\<C-M> !\"#$%&'()#+'-./{|}~\<C-?>\u0080\u0082\u0090\u009bΡ记娱"],
    \ [':s/\%#=0[^0-z]//g',
    \ "0123456789:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz"],
    \ [':s/\%#=1[^0-z]//g',
    \ "0123456789:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz"],
    \ [':s/\%#=2[^0-z]//g',
    \ "0123456789:;<=>?@ABCDEFGHIXYZ[\]^_`abcdefghiwxyz"]
    \]

  for [cmd, expected] in tests
      call append(0, input)
      call cursor(1, 1)
      exe cmd
      call assert_equal(expected, getline(1), cmd)
  endfor

  let &encoding = save_enc
  enew!
  close
endfunc
