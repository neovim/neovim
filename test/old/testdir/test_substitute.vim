" Tests for the substitute (:s) command

source shared.vim
source check.vim
source screendump.vim

" NOTE: This needs to be the first test to be
"       run in the file, since it depends on
"       that the previous substitution atom
"       was not yet set.
"
" recursive call of :s and sub-replace special
" (did cause heap-use-after free in < v9.0.2121)
func Test_aaaa_substitute_expr_recursive_special()
  func R()
    " FIXME: leaving out the 'n' flag leaks memory, why?
    %s/./\='.'/gn
  endfunc
  new Xfoobar_UAF
  put ='abcdef'
  let bufnr = bufnr('%')
  try
    silent! :s/./~\=R()/0
    "call assert_fails(':s/./~\=R()/0', 'E939:')
    let @/='.'
    ~g
  catch /^Vim\%((\a\+)\)\=:E565:/
  endtry
  delfunc R
  exe bufnr .. "bw!"
endfunc

func Test_multiline_subst()
  enew!
  call append(0, ["1 aa",
	      \ "bb",
	      \ "cc",
	      \ "2 dd",
	      \ "ee",
	      \ "3 ef",
	      \ "gh",
	      \ "4 ij",
	      \ "5 a8",
	      \ "8b c9",
	      \ "9d",
	      \ "6 e7",
	      \ "77f",
	      \ "xxxxx"])

  1
  " test if replacing a line break works with a back reference
  /^1/,/^2/s/\n\(.\)/ \1/
  " test if inserting a line break works with a back reference
  /^3/,/^4/s/\(.\)$/\r\1/
  " test if replacing a line break with another line break works
  /^5/,/^6/s/\(\_d\{3}\)/x\1x/
  call assert_equal('1 aa bb cc 2 dd ee', getline(1))
  call assert_equal('3 e', getline(2))
  call assert_equal('f', getline(3))
  call assert_equal('g', getline(4))
  call assert_equal('h', getline(5))
  call assert_equal('4 i', getline(6))
  call assert_equal('j', getline(7))
  call assert_equal('5 ax8', getline(8))
  call assert_equal('8xb cx9', getline(9))
  call assert_equal('9xd', getline(10))
  call assert_equal('6 ex7', getline(11))
  call assert_equal('7x7f', getline(12))
  call assert_equal('xxxxx', getline(13))
  enew!
endfunc

func Test_substitute_variants()
  " Validate that all the 2-/3-letter variants which embed the flags into the
  " command name actually work.
  enew!
  let ln = 'Testing string'
  let variants = [
	\ { 'cmd': ':s/Test/test/c', 'exp': 'testing string', 'prompt': 'y' },
	\ { 'cmd': ':s/foo/bar/ce', 'exp': ln },
	\ { 'cmd': ':s/t/r/cg', 'exp': 'Tesring srring', 'prompt': 'a' },
	\ { 'cmd': ':s/t/r/ci', 'exp': 'resting string', 'prompt': 'y' },
	\ { 'cmd': ':s/t/r/cI', 'exp': 'Tesring string', 'prompt': 'y' },
	\ { 'cmd': ':s/t/r/c', 'exp': 'Testing string', 'prompt': 'n' },
	\ { 'cmd': ':s/t/r/cn', 'exp': ln },
	\ { 'cmd': ':s/t/r/cp', 'exp': 'Tesring string', 'prompt': 'y' },
	\ { 'cmd': ':s/t/r/cl', 'exp': 'Tesring string', 'prompt': 'y' },
	\ { 'cmd': ':s/t/r/gc', 'exp': 'Tesring srring', 'prompt': 'a' },
	\ { 'cmd': ':s/i/I/gc', 'exp': 'TestIng string', 'prompt': 'l' },
	\ { 'cmd': ':s/foo/bar/ge', 'exp': ln },
	\ { 'cmd': ':s/t/r/g', 'exp': 'Tesring srring' },
	\ { 'cmd': ':s/t/r/gi', 'exp': 'resring srring' },
	\ { 'cmd': ':s/t/r/gI', 'exp': 'Tesring srring' },
	\ { 'cmd': ':s/t/r/gn', 'exp': ln },
	\ { 'cmd': ':s/t/r/gp', 'exp': 'Tesring srring' },
	\ { 'cmd': ':s/t/r/gl', 'exp': 'Tesring srring' },
	\ { 'cmd': ':s//r/gr', 'exp': 'Testr strr' },
	\ { 'cmd': ':s/t/r/ic', 'exp': 'resting string', 'prompt': 'y' },
	\ { 'cmd': ':s/foo/bar/ie', 'exp': ln },
	\ { 'cmd': ':s/t/r/i', 'exp': 'resting string' },
	\ { 'cmd': ':s/t/r/iI', 'exp': 'Tesring string' },
	\ { 'cmd': ':s/t/r/in', 'exp': ln },
	\ { 'cmd': ':s/t/r/ip', 'exp': 'resting string' },
	\ { 'cmd': ':s//r/ir', 'exp': 'Testr string' },
	\ { 'cmd': ':s/t/r/Ic', 'exp': 'Tesring string', 'prompt': 'y' },
	\ { 'cmd': ':s/foo/bar/Ie', 'exp': ln },
	\ { 'cmd': ':s/t/r/Ig', 'exp': 'Tesring srring' },
	\ { 'cmd': ':s/t/r/Ii', 'exp': 'resting string' },
	\ { 'cmd': ':s/t/r/I', 'exp': 'Tesring string' },
	\ { 'cmd': ':s/t/r/Ip', 'exp': 'Tesring string' },
	\ { 'cmd': ':s/t/r/Il', 'exp': 'Tesring string' },
	\ { 'cmd': ':s//r/Ir', 'exp': 'Testr string' },
	\ { 'cmd': ':s//r/rc', 'exp': 'Testr string', 'prompt': 'y' },
	\ { 'cmd': ':s//r/rg', 'exp': 'Testr strr' },
	\ { 'cmd': ':s//r/ri', 'exp': 'Testr string' },
	\ { 'cmd': ':s//r/rI', 'exp': 'Testr string' },
	\ { 'cmd': ':s//r/rn', 'exp': 'Testing string' },
	\ { 'cmd': ':s//r/rp', 'exp': 'Testr string' },
	\ { 'cmd': ':s//r/rl', 'exp': 'Testr string' },
	\ { 'cmd': ':s//r/r', 'exp': 'Testr string' },
	\ { 'cmd': ':s/i/I/gc', 'exp': 'Testing string', 'prompt': 'q' },
	\]

  for var in variants
    for run in [1, 2]
      let cmd = var.cmd
      if run == 2 && cmd =~ "/.*/.*/."
	" Change  :s/from/to/{flags}  to  :s{flags}
	let cmd = substitute(cmd, '/.*/', '', '')
      endif
      call setline(1, [ln])
      let msg = printf('using "%s"', cmd)
      let @/='ing'
      let v:errmsg = ''
      call feedkeys(cmd . "\<CR>" . get(var, 'prompt', ''), 'ntx')
      " No error should exist (matters for testing e flag)
      call assert_equal('', v:errmsg, msg)
      call assert_equal(var.exp, getline('.'), msg)
    endfor
  endfor
endfunc

" Test the l, p, # flags.
func Test_substitute_flags_lp()
  new
  call setline(1, "abc\tdef\<C-h>ghi")

  let a = execute('s/a/a/p')
  call assert_equal("\nabc     def^Hghi", a)

  let a = execute('s/a/a/l')
  call assert_equal("\nabc^Idef^Hghi$", a)

  let a = execute('s/a/a/#')
  call assert_equal("\n  1 abc     def^Hghi", a)

  let a = execute('s/a/a/p#')
  call assert_equal("\n  1 abc     def^Hghi", a)

  let a = execute('s/a/a/l#')
  call assert_equal("\n  1 abc^Idef^Hghi$", a)

  let a = execute('s/a/a/')
  call assert_equal("", a)

  bwipe!
endfunc

func Test_substitute_repeat()
  " This caused an invalid memory access.
  split Xfile
  s/^/x
  call feedkeys("Qsc\<CR>y", 'tx')
  bwipe!
endfunc

" Test :s with ? as delimiter.
func Test_substitute_question_delimiter()
  new
  call setline(1, '??:??')
  %s?\?\??!!?g
  call assert_equal('!!:!!', getline(1))
  bwipe!
endfunc

" Test %s/\n// which is implemented as a special case to use a
" more efficient join rather than doing a regular substitution.
func Test_substitute_join()
  new

  call setline(1, ["foo\tbar", "bar\<C-H>foo"])
  let a = execute('%s/\n//')
  call assert_equal("", a)
  call assert_equal(["foo\tbarbar\<C-H>foo"], getline(1, '$'))
  call assert_equal('\n', histget("search", -1))

  call setline(1, ["foo\tbar", "bar\<C-H>foo"])
  let a = execute('%s/\n//g')
  call assert_equal("", a)
  call assert_equal(["foo\tbarbar\<C-H>foo"], getline(1, '$'))
  call assert_equal('\n', histget("search", -1))

  call setline(1, ["foo\tbar", "bar\<C-H>foo"])
  let a = execute('%s/\n//p')
  call assert_equal("\nfoo     barbar^Hfoo", a)
  call assert_equal(["foo\tbarbar\<C-H>foo"], getline(1, '$'))
  call assert_equal('\n', histget("search", -1))

  call setline(1, ["foo\tbar", "bar\<C-H>foo"])
  let a = execute('%s/\n//l')
  call assert_equal("\nfoo^Ibarbar^Hfoo$", a)
  call assert_equal(["foo\tbarbar\<C-H>foo"], getline(1, '$'))
  call assert_equal('\n', histget("search", -1))

  call setline(1, ["foo\tbar", "bar\<C-H>foo"])
  let a = execute('%s/\n//#')
  call assert_equal("\n  1 foo     barbar^Hfoo", a)
  call assert_equal(["foo\tbarbar\<C-H>foo"], getline(1, '$'))
  call assert_equal('\n', histget("search", -1))

  call setline(1, ['foo', 'bar', 'baz', 'qux'])
  call execute('1,2s/\n//')
  call assert_equal(['foobarbaz', 'qux'], getline(1, '$'))

  bwipe!
endfunc

func Test_substitute_count()
  new
  call setline(1, ['foo foo', 'foo foo', 'foo foo', 'foo foo', 'foo foo'])
  2

  s/foo/bar/3
  call assert_equal(['foo foo', 'bar foo', 'bar foo', 'bar foo', 'foo foo'],
  \                 getline(1, '$'))

  call assert_fails('s/foo/bar/0', 'E939:')

  call setline(1, ['foo foo', 'foo foo', 'foo foo', 'foo foo', 'foo foo'])
  2,4s/foo/bar/ 10
  call assert_equal(['foo foo', 'foo foo', 'foo foo', 'bar foo', 'bar foo'],
        \           getline(1, '$'))

  call assert_fails('s/./b/2147483647', 'E1510:')
  bwipe!
endfunc

" Test substitute 'n' flag (report number of matches, do not substitute).
func Test_substitute_flag_n()
  new
  let lines = ['foo foo', 'foo foo', 'foo foo', 'foo foo', 'foo foo']
  call setline(1, lines)

  call assert_equal("\n3 matches on 3 lines", execute('2,4s/foo/bar/n'))
  call assert_equal("\n6 matches on 3 lines", execute('2,4s/foo/bar/gn'))

  " c flag (confirm) should be ignored when using n flag.
  call assert_equal("\n3 matches on 3 lines", execute('2,4s/foo/bar/nc'))

  " No substitution should have been done.
  call assert_equal(lines, getline(1, '$'))

  %delete _
  call setline(1, ['A', 'Bar', 'Baz'])
  call assert_equal("\n1 match on 1 line", execute('s/\nB\@=//gn'))

  bwipe!
endfunc

func Test_substitute_errors()
  new
  call setline(1, 'foobar')

  call assert_fails('s/FOO/bar/', 'E486:')
  call assert_fails('s/foo/bar/@', 'E488:')
  call assert_fails('s/\(/bar/', 'E54:')
  call assert_fails('s afooabara', 'E146:')
  call assert_fails('s\\a', 'E10:')

  setl nomodifiable
  call assert_fails('s/foo/bar/', 'E21:')

  call assert_fails("let s=substitute([], 'a', 'A', 'g')", 'E730:')
  call assert_fails("let s=substitute('abcda', [], 'A', 'g')", 'E730:')
  call assert_fails("let s=substitute('abcda', 'a', [], 'g')", 'E730:')
  call assert_fails("let s=substitute('abcda', 'a', 'A', [])", 'E730:')
  call assert_fails("let s=substitute('abc', '\\%(', 'A', 'g')", 'E53:')

  bwipe!
endfunc

" Test for *sub-replace-special* and *sub-replace-expression* on substitute().
func Test_sub_replace_1()
  " Run the tests with 'magic' on
  set magic
  set cpo&
  call assert_equal('AA', substitute('A', 'A', '&&', ''))
  call assert_equal('&', substitute('B', 'B', '\&', ''))
  call assert_equal('C123456789987654321', substitute('C123456789', 'C\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)', '\0\9\8\7\6\5\4\3\2\1', ''))
  call assert_equal('d', substitute('D', 'D', 'd', ''))
  call assert_equal('~', substitute('E', 'E', '~', ''))
  call assert_equal('~', substitute('F', 'F', '\~', ''))
  call assert_equal('Gg', substitute('G', 'G', '\ugg', ''))
  call assert_equal('Hh', substitute('H', 'H', '\Uh\Eh', ''))
  call assert_equal('iI', substitute('I', 'I', '\lII', ''))
  call assert_equal('jJ', substitute('J', 'J', '\LJ\EJ', ''))
  call assert_equal('Kk', substitute('K', 'K', '\Uk\ek', ''))
  call assert_equal("l\<C-V>\<C-M>l",
			\ substitute('lLl', 'L', "\<C-V>\<C-M>", ''))
  call assert_equal("m\<C-M>m", substitute('mMm', 'M', '\r', ''))
  call assert_equal("n\<C-V>\<C-M>n",
			\ substitute('nNn', 'N', "\\\<C-V>\<C-M>", ''))
  call assert_equal("o\no", substitute('oOo', 'O', '\n', ''))
  call assert_equal("p\<C-H>p", substitute('pPp', 'P', '\b', ''))
  call assert_equal("q\tq", substitute('qQq', 'Q', '\t', ''))
  call assert_equal('r\r', substitute('rRr', 'R', '\\', ''))
  call assert_equal('scs', substitute('sSs', 'S', '\c', ''))
  call assert_equal("u\nu", substitute('uUu', 'U', "\n", ''))
  call assert_equal("v\<C-H>v", substitute('vVv', 'V', "\b", ''))
  call assert_equal("w\\w", substitute('wWw', 'W', "\\", ''))
  call assert_equal("x\<C-M>x", substitute('xXx', 'X', "\r", ''))
  call assert_equal("YyyY", substitute('Y', 'Y', '\L\uyYy\l\EY', ''))
  call assert_equal("zZZz", substitute('Z', 'Z', '\U\lZzZ\u\Ez', ''))
  " \v or \V after $
  call assert_equal('abxx', substitute('abcd', 'xy$\v|cd$', 'xx', ''))
  call assert_equal('abxx', substitute('abcd', 'xy$\V\|cd\$', 'xx', ''))
endfunc

func Test_sub_replace_2()
  " Run the tests with 'magic' off
  set nomagic
  set cpo&
  call assert_equal('AA', substitute('A', 'A', '&&', ''))
  call assert_equal('&', substitute('B', 'B', '\&', ''))
  call assert_equal('C123456789987654321', substitute('C123456789', 'C\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)', '\0\9\8\7\6\5\4\3\2\1', ''))
  call assert_equal('d', substitute('D', 'D', 'd', ''))
  call assert_equal('~', substitute('E', 'E', '~', ''))
  call assert_equal('~', substitute('F', 'F', '\~', ''))
  call assert_equal('Gg', substitute('G', 'G', '\ugg', ''))
  call assert_equal('Hh', substitute('H', 'H', '\Uh\Eh', ''))
  call assert_equal('iI', substitute('I', 'I', '\lII', ''))
  call assert_equal('jJ', substitute('J', 'J', '\LJ\EJ', ''))
  call assert_equal('Kk', substitute('K', 'K', '\Uk\ek', ''))
  call assert_equal("l\<C-V>\<C-M>l",
			\ substitute('lLl', 'L', "\<C-V>\<C-M>", ''))
  call assert_equal("m\<C-M>m", substitute('mMm', 'M', '\r', ''))
  call assert_equal("n\<C-V>\<C-M>n",
			\ substitute('nNn', 'N', "\\\<C-V>\<C-M>", ''))
  call assert_equal("o\no", substitute('oOo', 'O', '\n', ''))
  call assert_equal("p\<C-H>p", substitute('pPp', 'P', '\b', ''))
  call assert_equal("q\tq", substitute('qQq', 'Q', '\t', ''))
  call assert_equal('r\r', substitute('rRr', 'R', '\\', ''))
  call assert_equal('scs', substitute('sSs', 'S', '\c', ''))
  call assert_equal("t\<C-M>t", substitute('tTt', 'T', "\r", ''))
  call assert_equal("u\nu", substitute('uUu', 'U', "\n", ''))
  call assert_equal("v\<C-H>v", substitute('vVv', 'V', "\b", ''))
  call assert_equal('w\w', substitute('wWw', 'W', "\\", ''))
  call assert_equal('XxxX', substitute('X', 'X', '\L\uxXx\l\EX', ''))
  call assert_equal('yYYy', substitute('Y', 'Y', '\U\lYyY\u\Ey', ''))
endfunc

func Test_sub_replace_3()
  set magic&
  set cpo&
  call assert_equal('a\a', substitute('aAa', 'A', '\="\\"', ''))
  call assert_equal('b\\b', substitute('bBb', 'B', '\="\\\\"', ''))
  call assert_equal("c\rc", substitute('cCc', 'C', "\\=\"\r\"", ''))
  call assert_equal("d\\\rd", substitute('dDd', 'D', "\\=\"\\\\\r\"", ''))
  call assert_equal("e\\\\\re", substitute('eEe', 'E', "\\=\"\\\\\\\\\r\"", ''))
  call assert_equal('f\rf', substitute('fFf', 'F', '\="\\r"', ''))
  call assert_equal('j\nj', substitute('jJj', 'J', '\="\\n"', ''))
  call assert_equal("k\<C-M>k", substitute('kKk', 'K', '\="\r"', ''))
  call assert_equal("l\nl", substitute('lLl', 'L', '\="\n"', ''))
endfunc

" Test for submatch() on substitute().
func Test_sub_replace_4()
  set magic&
  set cpo&
  call assert_equal('a\a', substitute('aAa', 'A',
		\ '\=substitute(submatch(0), ".", "\\", "")', ''))
  call assert_equal('b\b', substitute('bBb', 'B',
		\ '\=substitute(submatch(0), ".", "\\\\", "")', ''))
  call assert_equal("c\<C-V>\<C-M>c", substitute('cCc', 'C', '\=substitute(submatch(0), ".", "\<C-V>\<C-M>", "")', ''))
  call assert_equal("d\<C-V>\<C-M>d", substitute('dDd', 'D', '\=substitute(submatch(0), ".", "\\\<C-V>\<C-M>", "")', ''))
  call assert_equal("e\\\<C-V>\<C-M>e", substitute('eEe', 'E', '\=substitute(submatch(0), ".", "\\\\\<C-V>\<C-M>", "")', ''))
  call assert_equal("f\<C-M>f", substitute('fFf', 'F', '\=substitute(submatch(0), ".", "\\r", "")', ''))
  call assert_equal("j\nj", substitute('jJj', 'J', '\=substitute(submatch(0), ".", "\\n", "")', ''))
  call assert_equal("k\rk", substitute('kKk', 'K', '\=substitute(submatch(0), ".", "\r", "")', ''))
  call assert_equal("l\nl", substitute('lLl', 'L', '\=substitute(submatch(0), ".", "\n", "")', ''))
endfunc

func Test_sub_replace_5()
  set magic&
  set cpo&
  call assert_equal('A123456789987654321', substitute('A123456789',
		\ 'A\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)',
		\ '\=submatch(0) . submatch(9) . submatch(8) . ' .
		\ 'submatch(7) . submatch(6) . submatch(5) . ' .
		\ 'submatch(4) . submatch(3) . submatch(2) . submatch(1)',
		\ ''))
   call assert_equal("[['A123456789'], ['9'], ['8'], ['7'], ['6'], " .
		\ "['5'], ['4'], ['3'], ['2'], ['1']]",
		\ substitute('A123456789',
		\ 'A\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)',
		\ '\=string([submatch(0, 1), submatch(9, 1), ' .
		\ 'submatch(8, 1), 7->submatch(1), submatch(6, 1), ' .
		\ 'submatch(5, 1), submatch(4, 1), submatch(3, 1), ' .
		\ 'submatch(2, 1), submatch(1, 1)])',
		\ ''))
endfunc

func Test_sub_replace_6()
  set magic&
  " Nvim: no "/" flag in 'cpoptions'.
  " set cpo+=/
  call assert_equal('a', substitute('A', 'A', 'a', ''))
  call assert_equal('%', substitute('B', 'B', '%', ''))
  set cpo-=/
  call assert_equal('c', substitute('C', 'C', 'c', ''))
  call assert_equal('%', substitute('D', 'D', '%', ''))
endfunc

func Test_sub_replace_7()
  set magic&
  set cpo&
  call assert_equal('AA', substitute('AA', 'A.', '\=submatch(0)', ''))
  call assert_equal("B\nB", substitute("B\nB", 'B.', '\=submatch(0)', ''))
  call assert_equal("['B\n']B", substitute("B\nB", 'B.', '\=string(submatch(0, 1))', ''))
  call assert_equal('-abab', substitute('-bb', '\zeb', 'a', 'g'))
  call assert_equal('c-cbcbc', substitute('-bb', '\ze', 'c', 'g'))
endfunc

" Test for *:s%* on :substitute.
func Test_sub_replace_8()
  new
  set magic&
  set cpo&
  $put =',,X'
  s/\(^\|,\)\ze\(,\|X\)/\1N/g
  call assert_equal('N,,NX', getline("$"))
  $put =',,Y'
  let cmd = ':s/\(^\|,\)\ze\(,\|Y\)/\1N/gc'
  call feedkeys(cmd . "\<CR>a", "xt")
  call assert_equal('N,,NY', getline("$"))
  :$put =',,Z'
  let cmd = ':s/\(^\|,\)\ze\(,\|Z\)/\1N/gc'
  call feedkeys(cmd . "\<CR>yy", "xt")
  call assert_equal('N,,NZ', getline("$"))
  enew! | close
endfunc

func Test_sub_replace_9()
  new
  set magic&
  set cpo&
  $put ='xxx'
  call feedkeys(":s/x/X/gc\<CR>yyq", "xt")
  call assert_equal('XXx', getline("$"))
  enew! | close
endfunc

func Test_sub_replace_10()
   set magic&
   set cpo&
   call assert_equal('a1a2a3a', substitute('123', '\zs', 'a', 'g'))
   call assert_equal('aaa', substitute('123', '\zs.', 'a', 'g'))
   call assert_equal('1a2a3a', substitute('123', '.\zs', 'a', 'g'))
   call assert_equal('a1a2a3a', substitute('123', '\ze', 'a', 'g'))
   call assert_equal('a1a2a3', substitute('123', '\ze.', 'a', 'g'))
   call assert_equal('aaa', substitute('123', '.\ze', 'a', 'g'))
   call assert_equal('aa2a3a', substitute('123', '1\|\ze', 'a', 'g'))
   call assert_equal('1aaa', substitute('123', '1\zs\|[23]', 'a', 'g'))
endfunc

func SubReplacer(text, submatches)
  return a:text .. a:submatches[0] .. a:text
endfunc
func SubReplacerVar(text, ...)
  return a:text .. a:1[0] .. a:text
endfunc
func SubReplacer20(t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, submatches)
  return a:t3 .. a:submatches[0] .. a:t11
endfunc

func Test_substitute_partial()
  call assert_equal('1foo2foo3', substitute('123', '2', function('SubReplacer', ['foo']), 'g'))
  call assert_equal('1foo2foo3', substitute('123', '2', function('SubReplacerVar', ['foo']), 'g'))

  " 19 arguments plus one is just OK
  let Replacer = function('SubReplacer20', repeat(['foo'], 19))
  call assert_equal('1foo2foo3', substitute('123', '2', Replacer, 'g'))

  " 20 arguments plus one is too many
  let Replacer = function('SubReplacer20', repeat(['foo'], 20))
  call assert_fails("call substitute('123', '2', Replacer, 'g')", 'E118:')
endfunc

func Test_substitute_float()
  CheckFeature float

  call assert_equal('number 1.23', substitute('number ', '$', { -> 1.23 }, ''))
  " vim9 assert_equal('number 1.23', substitute('number ', '$', () => 1.23, ''))
endfunc

" Tests for *sub-replace-special* and *sub-replace-expression* on :substitute.

" Execute a list of :substitute command tests
func Run_SubCmd_Tests(tests)
  enew!
  for t in a:tests
    let start = line('.') + 1
    let end = start + len(t[2]) - 1
    exe "normal o" . t[0]
    call cursor(start, 1)
    exe t[1]
    call assert_equal(t[2], getline(start, end), t[1])
  endfor
  enew!
endfunc

func Test_sub_cmd_1()
  set magic
  set cpo&

  " List entry format: [input, cmd, output]
  let tests = [['A', 's/A/&&/', ['AA']],
	      \ ['B', 's/B/\&/', ['&']],
	      \ ['C123456789', 's/C\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)/\0\9\8\7\6\5\4\3\2\1/', ['C123456789987654321']],
	      \ ['D', 's/D/d/', ['d']],
	      \ ['E', 's/E/~/', ['d']],
	      \ ['F', 's/F/\~/', ['~']],
	      \ ['G', 's/G/\ugg/', ['Gg']],
	      \ ['H', 's/H/\Uh\Eh/', ['Hh']],
	      \ ['I', 's/I/\lII/', ['iI']],
	      \ ['J', 's/J/\LJ\EJ/', ['jJ']],
	      \ ['K', 's/K/\Uk\ek/', ['Kk']],
	      \ ['lLl', "s/L/\<C-V>\<C-M>/", ["l\<C-V>", 'l']],
	      \ ['mMm', 's/M/\r/', ['m', 'm']],
	      \ ['nNn', "s/N/\\\<C-V>\<C-M>/", ["n\<C-V>", 'n']],
	      \ ['oOo', 's/O/\n/', ["o\no"]],
	      \ ['pPp', 's/P/\b/', ["p\<C-H>p"]],
	      \ ['qQq', 's/Q/\t/', ["q\tq"]],
	      \ ['rRr', 's/R/\\/', ['r\r']],
	      \ ['sSs', 's/S/\c/', ['scs']],
	      \ ['tTt', "s/T/\<C-V>\<C-J>/", ["t\<C-V>\<C-J>t"]],
	      \ ['U', 's/U/\L\uuUu\l\EU/', ['UuuU']],
	      \ ['V', 's/V/\U\lVvV\u\Ev/', ['vVVv']],
	      \ ['\', 's/\\/\\\\/', ['\\']]
	      \ ]
  call Run_SubCmd_Tests(tests)
endfunc

func Test_sub_cmd_2()
  set nomagic
  set cpo&

  " List entry format: [input, cmd, output]
  let tests = [['A', 's/A/&&/', ['&&']],
	      \ ['B', 's/B/\&/', ['B']],
	      \ ['C123456789', 's/\mC\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)/\0\9\8\7\6\5\4\3\2\1/', ['C123456789987654321']],
	      \ ['D', 's/D/d/', ['d']],
	      \ ['E', 's/E/~/', ['~']],
	      \ ['F', 's/F/\~/', ['~']],
	      \ ['G', 's/G/\ugg/', ['Gg']],
	      \ ['H', 's/H/\Uh\Eh/', ['Hh']],
	      \ ['I', 's/I/\lII/', ['iI']],
	      \ ['J', 's/J/\LJ\EJ/', ['jJ']],
	      \ ['K', 's/K/\Uk\ek/', ['Kk']],
	      \ ['lLl', "s/L/\<C-V>\<C-M>/", ["l\<C-V>", 'l']],
	      \ ['mMm', 's/M/\r/', ['m', 'm']],
	      \ ['nNn', "s/N/\\\<C-V>\<C-M>/", ["n\<C-V>", 'n']],
	      \ ['oOo', 's/O/\n/', ["o\no"]],
	      \ ['pPp', 's/P/\b/', ["p\<C-H>p"]],
	      \ ['qQq', 's/Q/\t/', ["q\tq"]],
	      \ ['rRr', 's/R/\\/', ['r\r']],
	      \ ['sSs', 's/S/\c/', ['scs']],
	      \ ['tTt', "s/T/\<C-V>\<C-J>/", ["t\<C-V>\<C-J>t"]],
	      \ ['U', 's/U/\L\uuUu\l\EU/', ['UuuU']],
	      \ ['V', 's/V/\U\lVvV\u\Ev/', ['vVVv']],
	      \ ['\', 's/\\/\\\\/', ['\\']]
	      \ ]
  call Run_SubCmd_Tests(tests)
endfunc

func Test_sub_cmd_3()
  set nomagic
  set cpo&

  " List entry format: [input, cmd, output]
  let tests = [['aAa', "s/A/\\='\\'/", ['a\a']],
	      \ ['bBb', "s/B/\\='\\\\'/", ['b\\b']],
	      \ ['cCc', "s/C/\\='\<C-V>\<C-M>'/", ["c\<C-V>", 'c']],
	      \ ['dDd', "s/D/\\='\\\<C-V>\<C-M>'/", ["d\\\<C-V>", 'd']],
	      \ ['eEe', "s/E/\\='\\\\\<C-V>\<C-M>'/", ["e\\\\\<C-V>", 'e']],
	      \ ['fFf', "s/F/\\='\r'/", ['f', 'f']],
	      \ ['gGg', "s/G/\\='\<C-V>\<C-J>'/", ["g\<C-V>", 'g']],
	      \ ['hHh', "s/H/\\='\\\<C-V>\<C-J>'/", ["h\\\<C-V>", 'h']],
	      \ ['iIi', "s/I/\\='\\\\\<C-V>\<C-J>'/", ["i\\\\\<C-V>", 'i']],
	      \ ['jJj', "s/J/\\='\n'/", ['j', 'j']],
	      \ ['kKk', 's/K/\="\r"/', ['k', 'k']],
	      \ ['lLl', 's/L/\="\n"/', ['l', 'l']]
	      \ ]
  call Run_SubCmd_Tests(tests)
endfunc

" Test for submatch() on :substitute.
func Test_sub_cmd_4()
  set magic&
  set cpo&

  " List entry format: [input, cmd, output]
  let tests = [ ['aAa', "s/A/\\=substitute(submatch(0), '.', '\\', '')/",
	      \				['a\a']],
	      \ ['bBb', "s/B/\\=substitute(submatch(0), '.', '\\', '')/",
	      \				['b\b']],
	      \ ['cCc', "s/C/\\=substitute(submatch(0), '.', '\<C-V>\<C-M>', '')/",
	      \				["c\<C-V>", 'c']],
	      \ ['dDd', "s/D/\\=substitute(submatch(0), '.', '\\\<C-V>\<C-M>', '')/",
	      \				["d\<C-V>", 'd']],
	      \ ['eEe', "s/E/\\=substitute(submatch(0), '.', '\\\\\<C-V>\<C-M>', '')/",
	      \				["e\\\<C-V>", 'e']],
	      \ ['fFf', "s/F/\\=substitute(submatch(0), '.', '\\r', '')/",
	      \				['f', 'f']],
	      \ ['gGg', 's/G/\=substitute(submatch(0), ".", "\<C-V>\<C-J>", "")/',
	      \				["g\<C-V>", 'g']],
	      \ ['hHh', 's/H/\=substitute(submatch(0), ".", "\\\<C-V>\<C-J>", "")/',
	      \				["h\<C-V>", 'h']],
	      \ ['iIi', 's/I/\=substitute(submatch(0), ".", "\\\\\<C-V>\<C-J>", "")/',
	      \				["i\\\<C-V>", 'i']],
	      \ ['jJj', "s/J/\\=substitute(submatch(0), '.', '\\n', '')/",
	      \				['j', 'j']],
	      \ ['kKk', "s/K/\\=substitute(submatch(0), '.', '\\r', '')/",
	      \				['k', 'k']],
	      \ ['lLl', "s/L/\\=substitute(submatch(0), '.', '\\n', '')/",
	      \				['l', 'l']],
	      \ ]
  call Run_SubCmd_Tests(tests)
endfunc

func Test_sub_cmd_5()
  set magic&
  set cpo&

  " List entry format: [input, cmd, output]
  let tests = [ ['A123456789', 's/A\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)/\=submatch(0) . submatch(9) . submatch(8) . submatch(7) . submatch(6) . submatch(5) . submatch(4) . submatch(3) . submatch(2) . submatch(1)/', ['A123456789987654321']],
	      \ ['B123456789', 's/B\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)/\=string([submatch(0, 1), submatch(9, 1), submatch(8, 1), submatch(7, 1), submatch(6, 1), submatch(5, 1), submatch(4, 1), submatch(3, 1), submatch(2, 1), submatch(1, 1)])/', ["[['B123456789'], ['9'], ['8'], ['7'], ['6'], ['5'], ['4'], ['3'], ['2'], ['1']]"]],
	      \ ]
  call Run_SubCmd_Tests(tests)
endfunc

" Test for *:s%* on :substitute.
func Test_sub_cmd_6()
  set magic&
  " Nvim: no "/" flag in 'cpoptions'.
  " set cpo+=/

  " List entry format: [input, cmd, output]
  let tests = [ ['A', 's/A/a/', ['a']],
	      \ ['B', 's/B/%/', ['a']],
	      \ ]
  " call Run_SubCmd_Tests(tests)

  set cpo-=/
  let tests = [ ['C', 's/C/c/', ['c']],
	      \ ['D', 's/D/%/', ['%']],
	      \ ]
  call Run_SubCmd_Tests(tests)

  set cpo&
endfunc

" Test for :s replacing \n with  line break.
func Test_sub_cmd_7()
  set magic&
  set cpo&

  " List entry format: [input, cmd, output]
  let tests = [ ["A\<C-V>\<C-M>A", 's/A./\=submatch(0)/', ['A', 'A']],
	      \ ["B\<C-V>\<C-J>B", 's/B./\=submatch(0)/', ['B', 'B']],
	      \ ["C\<C-V>\<C-J>C", 's/C./\=strtrans(string(submatch(0, 1)))/', [strtrans("['C\<C-J>']C")]],
	      \ ["D\<C-V>\<C-J>\nD", 's/D.\nD/\=strtrans(string(submatch(0, 1)))/', [strtrans("['D\<C-J>', 'D']")]],
	      \ ["E\<C-V>\<C-J>\n\<C-V>\<C-J>\n\<C-V>\<C-J>\n\<C-V>\<C-J>\n\<C-V>\<C-J>E", 's/E\_.\{-}E/\=strtrans(string(submatch(0, 1)))/', [strtrans("['E\<C-J>', '\<C-J>', '\<C-J>', '\<C-J>', '\<C-J>E']")]],
	      \ ]
  call Run_SubCmd_Tests(tests)

  exe "normal oQ\nQ\<Esc>k"
  call assert_fails('s/Q[^\n]Q/\=submatch(0)."foobar"/', 'E486')
  enew!
endfunc

func TitleString()
  let check = 'foo' =~ 'bar'
  return ""
endfunc

func Test_sub_cmd_8()
  set titlestring=%{TitleString()}

  enew!
  call append(0, ['', 'test_one', 'test_two'])
  call cursor(1,1)
  /^test_one/s/.*/\="foo\nbar"/
  call assert_equal('foo', getline(2))
  call assert_equal('bar', getline(3))
  call feedkeys(':/^test_two/s/.*/\="foo\nbar"/c', "t")
  call feedkeys("\<CR>y", "xt")
  call assert_equal('foo', getline(4))
  call assert_equal('bar', getline(5))

  enew!
  set titlestring&
endfunc

func Test_sub_cmd_9()
  new
  let input = ['1 aaa', '2 aaa', '3 aaa']
  call setline(1, input)
  func Foo()
    return submatch(0)
  endfunc
  %s/aaa/\=Foo()/gn
  call assert_equal(input, getline(1, '$'))
  call assert_equal(1, &modifiable)

  delfunc Foo
  bw!
endfunc

func Test_sub_highlight_zero_match()
  CheckRunVimInTerminal

  let lines =<< trim END
    call setline(1, ['one', 'two', 'three'])
  END
  call writefile(lines, 'XscriptSubHighlight', 'D')
  let buf = RunVimInTerminal('-S XscriptSubHighlight', #{rows: 8, cols: 60})
  call term_sendkeys(buf, ":%s/^/   /c\<CR>")
  call VerifyScreenDump(buf, 'Test_sub_highlight_zer_match_1', {})

  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
endfunc

func Test_nocatch_sub_failure_handling()
  " normal error results in all replacements
  func Foo()
    foobar
  endfunc
  new
  call setline(1, ['1 aaa', '2 aaa', '3 aaa'])
  " need silent! to avoid a delay when entering Insert mode
  silent! %s/aaa/\=Foo()/g
  call assert_equal(['1 0', '2 0', '3 0'], getline(1, 3))

  " Throw without try-catch causes abort after the first line.
  " We cannot test this, since it would stop executing the test script.

  " try/catch does not result in any changes
  func! Foo()
    throw 'error'
  endfunc
  call setline(1, ['1 aaa', '2 aaa', '3 aaa'])
  let error_caught = 0
  try
    %s/aaa/\=Foo()/g
  catch
    let error_caught = 1
  endtry
  call assert_equal(1, error_caught)
  call assert_equal(['1 aaa', '2 aaa', '3 aaa'], getline(1, 3))

  " Same, but using "n" flag so that "sandbox" gets set
  call setline(1, ['1 aaa', '2 aaa', '3 aaa'])
  let error_caught = 0
  try
    %s/aaa/\=Foo()/gn
  catch
    let error_caught = 1
  endtry
  call assert_equal(1, error_caught)
  call assert_equal(['1 aaa', '2 aaa', '3 aaa'], getline(1, 3))

  delfunc Foo
  bwipe!
endfunc

" Test ":s/pat/sub/" with different ~s in sub.
func Test_replace_with_tilde()
  new
  " Set the last replace string to empty
  s/^$//
  call append(0, ['- Bug in "vPPPP" on this text:'])
  normal gg
  s/u/~u~/
  call assert_equal('- Bug in "vPPPP" on this text:', getline(1))
  s/i/~u~/
  call assert_equal('- Bug uuun "vPPPP" on this text:', getline(1))
  s/o/~~~/
  call assert_equal('- Bug uuun "vPPPP" uuuuuuuuun this text:', getline(1))
  close!
endfunc

func Test_replace_keeppatterns()
  new
  a
foobar

substitute foo asdf

one two
.

  normal gg
  /^substitute
  s/foo/bar/
  call assert_equal('foo', @/)
  call assert_equal('substitute bar asdf', getline('.'))

  /^substitute
  keeppatterns s/asdf/xyz/
  call assert_equal('^substitute', @/)
  call assert_equal('substitute bar xyz', getline('.'))

  exe "normal /bar /e\<CR>"
  call assert_equal(15, col('.'))
  normal -
  keeppatterns /xyz
  call assert_equal('bar ', @/)
  call assert_equal('substitute bar xyz', getline('.'))
  exe "normal 0dn"
  call assert_equal('xyz', getline('.'))

  close!
endfunc

func Test_sub_beyond_end()
  new
  call setline(1, '#')
  let @/ = '^#\n\zs'
  s///e
  call assert_equal('#', getline(1))
  bwipe!
endfunc

" Test for repeating last substitution using :~ and :&r
func Test_repeat_last_sub()
  new
  call setline(1, ['blue green yellow orange white'])
  s/blue/red/
  let @/ = 'yellow'
  ~
  let @/ = 'white'
  :&r
  let @/ = 'green'
  s//gray
  call assert_equal('red gray red orange red', getline(1))
  close!
endfunc

" Test for Vi compatible substitution:
"     \/{string}/, \?{string}? and \&{string}&
func Test_sub_vi_compatibility()
  new
  call setline(1, ['blue green yellow orange blue'])
  let @/ = 'orange'
  s\/white/
  let @/ = 'blue'
  s\?amber?
  let @/ = 'white'
  s\&green&
  call assert_equal('amber green yellow white green', getline(1))
  close!
endfunc

" Test for substitute with the new text longer than the original text
func Test_sub_expand_text()
  new
  call setline(1, 'abcabcabcabcabcabcabcabc')
  s/b/\=repeat('B', 10)/g
  call assert_equal(repeat('aBBBBBBBBBBc', 8), getline(1))
  close!
endfunc

" Test for command failures when the last substitute pattern is not set.
func Test_sub_with_no_last_pat()
  let lines =<< trim [SCRIPT]
    call assert_fails('~', 'E33:')
    call assert_fails('s//abc/g', 'E35:')
    call assert_fails('s\/bar', 'E35:')
    call assert_fails('s\&bar&', 'E33:')
    call writefile(v:errors, 'Xresult')
    qall!
  [SCRIPT]
  call writefile(lines, 'Xscript', 'D')
  if RunVim([], [], '--clean -S Xscript')
    call assert_equal([], readfile('Xresult'))
  endif

  let lines =<< trim [SCRIPT]
    set cpo+=/
    call assert_fails('s/abc/%/', 'E33:')
    call writefile(v:errors, 'Xresult')
    qall!
  [SCRIPT]
  " Nvim: no "/" flag in 'cpoptions'.
  " call writefile(lines, 'Xscript')
  " if RunVim([], [], '--clean -S Xscript')
  "   call assert_equal([], readfile('Xresult'))
  " endif

  call delete('Xresult')
endfunc

func Test_substitute()
  call assert_equal('a１a２a３a', substitute('１２３', '\zs', 'a', 'g'))
  " Substitute with special keys
  call assert_equal("a\<End>c", substitute('abc', "a.c", "a\<End>c", ''))
endfunc

func Test_substitute_expr()
  let g:val = 'XXX'
  call assert_equal('XXX', substitute('yyy', 'y*', '\=g:val', ''))
  call assert_equal('XXX', substitute('yyy', 'y*', {-> g:val}, ''))
  call assert_equal("-\u1b \uf2-", substitute("-%1b %f2-", '%\(\x\x\)',
			   \ '\=nr2char("0x" . submatch(1))', 'g'))
  call assert_equal("-\u1b \uf2-", substitute("-%1b %f2-", '%\(\x\x\)',
			   \ {-> nr2char("0x" . submatch(1))}, 'g'))

  call assert_equal('231', substitute('123', '\(.\)\(.\)\(.\)',
	\ {-> submatch(2) . submatch(3) . submatch(1)}, ''))

  func Recurse()
    return substitute('yyy', 'y\(.\)y', {-> submatch(1)}, '')
  endfunc
  " recursive call works
  call assert_equal('-y-x-', substitute('xxx', 'x\(.\)x', {-> '-' . Recurse() . '-' . submatch(1) . '-'}, ''))

  call assert_fails("let s=submatch([])", 'E745:')
  call assert_fails("let s=submatch(2, [])", 'E745:')
endfunc

func Test_invalid_submatch()
  " This was causing invalid memory access in Vim-7.4.2232 and older
  call assert_fails("call substitute('x', '.', {-> submatch(10)}, '')", 'E935:')
  call assert_fails('eval submatch(-1)', 'E935:')
  call assert_equal('', submatch(0))
  call assert_equal('', submatch(1))
  call assert_equal([], submatch(0, 1))
  call assert_equal([], submatch(1, 1))
endfunc

func Test_submatch_list_concatenate()
  let pat = 'A\(.\)'
  let Rep = {-> string([submatch(0, 1)] + [[submatch(1)]])}
  call substitute('A1', pat, Rep, '')->assert_equal("[['A1'], ['1']]")
endfunc

func Test_substitute_expr_arg()
  call assert_equal('123456789-123456789=', substitute('123456789',
	\ '\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)',
	\ {m -> m[0] . '-' . m[1] . m[2] . m[3] . m[4] . m[5] . m[6] . m[7] . m[8] . m[9] . '='}, ''))

  call assert_equal('123456-123456=789', substitute('123456789',
	\ '\(.\)\(.\)\(.\)\(a*\)\(n*\)\(.\)\(.\)\(.\)\(x*\)',
	\ {m -> m[0] . '-' . m[1] . m[2] . m[3] . m[4] . m[5] . m[6] . m[7] . m[8] . m[9] . '='}, ''))

  call assert_equal('123456789-123456789x=', substitute('123456789',
	\ '\(.\)\(.\)\(.*\)',
	\ {m -> m[0] . '-' . m[1] . m[2] . m[3] . 'x' . m[4] . m[5] . m[6] . m[7] . m[8] . m[9] . '='}, ''))

  call assert_fails("call substitute('xxx', '.', {m -> string(add(m, 'x'))}, '')", 'E742:')
  call assert_fails("call substitute('xxx', '.', {m -> string(insert(m, 'x'))}, '')", 'E742:')
  call assert_fails("call substitute('xxx', '.', {m -> string(extend(m, ['x']))}, '')", 'E742:')
  call assert_fails("call substitute('xxx', '.', {m -> string(remove(m, 1))}, '')", 'E742:')
endfunc

" Test for using a function to supply the substitute string
func Test_substitute_using_func()
  func Xfunc()
    return '1234'
  endfunc
  call assert_equal('a1234f', substitute('abcdef', 'b..e',
        \ function("Xfunc"), ''))
  delfunc Xfunc
endfunc

" Test for using submatch() with a multiline match
func Test_substitute_multiline_submatch()
  new
  call setline(1, ['line1', 'line2', 'line3', 'line4'])
  %s/^line1\(\_.\+\)line4$/\=submatch(1)/
  call assert_equal(['', 'line2', 'line3', ''], getline(1, '$'))
  close!
endfunc

func Test_substitute_skipped_range()
  new
  if 0
    /1/5/2/2/\n
  endif
  call assert_equal([0, 1, 1, 0, 1], getcurpos())
  bwipe!
endfunc

" Test using the 'gdefault' option (when on, flag 'g' is default on).
func Test_substitute_gdefault()
  new

  " First check without 'gdefault'
  call setline(1, 'foo bar foo')
  s/foo/FOO/
  call assert_equal('FOO bar foo', getline(1))
  call setline(1, 'foo bar foo')
  s/foo/FOO/g
  call assert_equal('FOO bar FOO', getline(1))
  call setline(1, 'foo bar foo')
  s/foo/FOO/gg
  call assert_equal('FOO bar foo', getline(1))

  " Then check with 'gdefault'
  set gdefault
  call setline(1, 'foo bar foo')
  s/foo/FOO/
  call assert_equal('FOO bar FOO', getline(1))
  call setline(1, 'foo bar foo')
  s/foo/FOO/g
  call assert_equal('FOO bar foo', getline(1))
  call setline(1, 'foo bar foo')
  s/foo/FOO/gg
  call assert_equal('FOO bar FOO', getline(1))

  " Setting 'compatible' should reset 'gdefault'
  call assert_equal(1, &gdefault)
  " set compatible
  set nogdefault
  call assert_equal(0, &gdefault)
  set nocompatible
  call assert_equal(0, &gdefault)

  bw!
endfunc

" This was using "old_sub" after it was freed.
func Test_using_old_sub()
  " set compatible maxfuncdepth=10
  set maxfuncdepth=10
  new
  call setline(1, 'some text.')
  func Repl()
    ~
    s/
  endfunc
  silent! s/\%')/\=Repl()

  delfunc Repl
  bwipe!
  set nocompatible
endfunc

" This was switching windows in between computing the length and using it.
func Test_sub_change_window()
  silent! lfile
  sil! norm o0000000000000000000000000000000000000000000000000000
  func Repl()
    lopen
  endfunc
  silent!  s/\%')/\=Repl()
  bwipe!
  bwipe!
  delfunc Repl
endfunc

" This was undoign a change in between computing the length and using it.
func Do_Test_sub_undo_change()
  new
  norm o0000000000000000000000000000000000000000000000000000
  silent! s/\%')/\=Repl()
  bwipe!
endfunc

func Test_sub_undo_change()
  func Repl()
    silent! norm g-
  endfunc
  call Do_Test_sub_undo_change()

  func! Repl()
    silent earlier
  endfunc
  call Do_Test_sub_undo_change()

  delfunc Repl
endfunc

" This was opening a command line window from the expression
func Test_sub_open_cmdline_win()
  " the error only happens in a very specific setup, run a new Vim instance to
  " get a clean starting point.
  let lines =<< trim [SCRIPT]
    set vb t_vb=
    norm o0000000000000000000000000000000000000000000000000000
    func Replace()
      norm q/
    endfunc
    s/\%')/\=Replace()
    redir >Xresult
    messages
    redir END
    qall!
  [SCRIPT]
  call writefile(lines, 'Xscript', 'D')
  if RunVim([], [], '-u NONE -S Xscript')
    call assert_match('E565: Not allowed to change text or change window',
          \ readfile('Xresult')->join('XX'))
  endif

  call delete('Xresult')
endfunc

" This was editing a script file from the expression
func Test_sub_edit_scriptfile()
  new
  norm o0000000000000000000000000000000000000000000000000000
  func EditScript()
    silent! scr! Xfile
  endfunc
  s/\%')/\=EditScript()

  delfunc EditScript
  bwipe!
endfunc

" This was editing another file from the expression.
func Test_sub_expr_goto_other_file()
  call writefile([''], 'Xfileone', 'D')
  enew!
  call setline(1, ['a', 'b', 'c', 'd',
	\ 'Xfileone zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'])

  func g:SplitGotoFile()
    exe "sil! norm 0\<C-W>gf"
    return ''
  endfunc

  $
  s/\%')/\=g:SplitGotoFile()

  delfunc g:SplitGotoFile
  bwipe!
endfunc

func Test_recursive_expr_substitute()
  " this was reading invalid memory
  let lines =<< trim END
      func Repl(g, n)
        s
        r%:s000
      endfunc
      next 0
      let caught = 0
      s/\%')/\=Repl(0, 0)
      qall!
  END
  call writefile(lines, 'XexprSubst', 'D')
  call RunVim([], [], '--clean -S XexprSubst')
endfunc

" Test for the 2-letter and 3-letter :substitute commands
func Test_substitute_short_cmd()
  new
  call setline(1, ['one', 'one one one'])
  s/one/two
  call cursor(2, 1)

  " :sc
  call feedkeys(":sc\<CR>y", 'xt')
  call assert_equal('two one one', getline(2))

  " :scg
  call setline(2, 'one one one')
  call feedkeys(":scg\<CR>nyq", 'xt')
  call assert_equal('one two one', getline(2))

  " :sci
  call setline(2, 'ONE One onE')
  call feedkeys(":sci\<CR>y", 'xt')
  call assert_equal('two One onE', getline(2))

  " :scI
  set ignorecase
  call setline(2, 'ONE One one')
  call feedkeys(":scI\<CR>y", 'xt')
  call assert_equal('ONE One two', getline(2))
  set ignorecase&

  " :scn
  call setline(2, 'one one one')
  let t = execute('scn')->split("\n")
  call assert_equal(['1 match on 1 line'], t)
  call assert_equal('one one one', getline(2))

  " :scp
  call setline(2, "\tone one one")
  redir => output
  call feedkeys(":scp\<CR>y", 'xt')
  redir END
  call assert_equal('        two one one', output->split("\n")[-1])
  call assert_equal("\ttwo one one", getline(2))

  " :scl
  call setline(2, "\tone one one")
  redir => output
  call feedkeys(":scl\<CR>y", 'xt')
  redir END
  call assert_equal("^Itwo one one$", output->split("\n")[-1])
  call assert_equal("\ttwo one one", getline(2))

  " :sgc
  call setline(2, 'one one one one one')
  call feedkeys(":sgc\<CR>nyyq", 'xt')
  call assert_equal('one two two one one', getline(2))

  " :sg
  call setline(2, 'one one one')
  sg
  call assert_equal('two two two', getline(2))

  " :sgi
  call setline(2, 'ONE One onE')
  sgi
  call assert_equal('two two two', getline(2))

  " :sgI
  set ignorecase
  call setline(2, 'ONE One one')
  sgI
  call assert_equal('ONE One two', getline(2))
  set ignorecase&

  " :sgn
  call setline(2, 'one one one')
  let t = execute('sgn')->split("\n")
  call assert_equal(['3 matches on 1 line'], t)
  call assert_equal('one one one', getline(2))

  " :sgp
  call setline(2, "\tone one one")
  redir => output
  sgp
  redir END
  call assert_equal('        two two two', output->split("\n")[-1])
  call assert_equal("\ttwo two two", getline(2))

  " :sgl
  call setline(2, "\tone one one")
  redir => output
  sgl
  redir END
  call assert_equal("^Itwo two two$", output->split("\n")[-1])
  call assert_equal("\ttwo two two", getline(2))

  " :sgr
  call setline(2, "one one one")
  call cursor(2, 1)
  s/abc/xyz/e
  let @/ = 'one'
  sgr
  call assert_equal('xyz xyz xyz', getline(2))

  " :sic
  call cursor(1, 1)
  s/one/two/e
  call setline(2, "ONE One one")
  call cursor(2, 1)
  call feedkeys(":sic\<CR>y", 'xt')
  call assert_equal('two One one', getline(2))

  " :si
  call setline(2, "ONE One one")
  si
  call assert_equal('two One one', getline(2))

  " :siI
  call setline(2, "ONE One one")
  siI
  call assert_equal('ONE One two', getline(2))

  " :sin
  call setline(2, 'ONE One onE')
  let t = execute('sin')->split("\n")
  call assert_equal(['1 match on 1 line'], t)
  call assert_equal('ONE One onE', getline(2))

  " :sip
  call setline(2, "\tONE One onE")
  redir => output
  sip
  redir END
  call assert_equal('        two One onE', output->split("\n")[-1])
  call assert_equal("\ttwo One onE", getline(2))

  " :sir
  call setline(2, "ONE One onE")
  call cursor(2, 1)
  s/abc/xyz/e
  let @/ = 'one'
  sir
  call assert_equal('xyz One onE', getline(2))

  " :sIc
  call cursor(1, 1)
  s/one/two/e
  call setline(2, "ONE One one")
  call cursor(2, 1)
  call feedkeys(":sIc\<CR>y", 'xt')
  call assert_equal('ONE One two', getline(2))

  " :sIg
  call setline(2, "ONE one onE one")
  sIg
  call assert_equal('ONE two onE two', getline(2))

  " :sIi
  call setline(2, "ONE One one")
  sIi
  call assert_equal('two One one', getline(2))

  " :sI
  call setline(2, "ONE One one")
  sI
  call assert_equal('ONE One two', getline(2))

  " :sIn
  call setline(2, 'ONE One one')
  let t = execute('sIn')->split("\n")
  call assert_equal(['1 match on 1 line'], t)
  call assert_equal('ONE One one', getline(2))

  " :sIp
  call setline(2, "\tONE One one")
  redir => output
  sIp
  redir END
  call assert_equal('        ONE One two', output->split("\n")[-1])
  call assert_equal("\tONE One two", getline(2))

  " :sIl
  call setline(2, "\tONE onE one")
  redir => output
  sIl
  redir END
  call assert_equal("^IONE onE two$", output->split("\n")[-1])
  call assert_equal("\tONE onE two", getline(2))

  " :sIr
  call setline(2, "ONE one onE")
  call cursor(2, 1)
  s/abc/xyz/e
  let @/ = 'one'
  sIr
  call assert_equal('ONE xyz onE', getline(2))

  " :src
  call setline(2, "ONE one one")
  call cursor(2, 1)
  s/abc/xyz/e
  let @/ = 'one'
  call feedkeys(":src\<CR>y", 'xt')
  call assert_equal('ONE xyz one', getline(2))

  " :srg
  call setline(2, "one one one")
  call cursor(2, 1)
  s/abc/xyz/e
  let @/ = 'one'
  srg
  call assert_equal('xyz xyz xyz', getline(2))

  " :sri
  call setline(2, "ONE one onE")
  call cursor(2, 1)
  s/abc/xyz/e
  let @/ = 'one'
  sri
  call assert_equal('xyz one onE', getline(2))

  " :srI
  call setline(2, "ONE one onE")
  call cursor(2, 1)
  s/abc/xyz/e
  let @/ = 'one'
  srI
  call assert_equal('ONE xyz onE', getline(2))

  " :srn
  call setline(2, "ONE one onE")
  call cursor(2, 1)
  s/abc/xyz/e
  let @/ = 'one'
  let t = execute('srn')->split("\n")
  call assert_equal(['1 match on 1 line'], t)
  call assert_equal('ONE one onE', getline(2))

  " :srp
  call setline(2, "\tONE one onE")
  call cursor(2, 1)
  s/abc/xyz/e
  let @/ = 'one'
  redir => output
  srp
  redir END
  call assert_equal('        ONE xyz onE', output->split("\n")[-1])
  call assert_equal("\tONE xyz onE", getline(2))

  " :srl
  call setline(2, "\tONE one onE")
  call cursor(2, 1)
  s/abc/xyz/e
  let @/ = 'one'
  redir => output
  srl
  redir END
  call assert_equal("^IONE xyz onE$", output->split("\n")[-1])
  call assert_equal("\tONE xyz onE", getline(2))

  " :sr
  call setline(2, "ONE one onE")
  call cursor(2, 1)
  s/abc/xyz/e
  let @/ = 'one'
  sr
  call assert_equal('ONE xyz onE', getline(2))

  " :sce
  s/abc/xyz/e
  call assert_fails("sc", 'E486:')
  sce
  " :sge
  call assert_fails("sg", 'E486:')
  sge
  " :sie
  call assert_fails("si", 'E486:')
  sie
  " :sIe
  call assert_fails("sI", 'E486:')
  sIe

  bw!
endfunc

" Check handling expanding "~" resulting in extremely long text.
" FIXME: disabled, it takes too long to run on CI
"func Test_substitute_tilde_too_long()
"  enew!
"
"  s/.*/ixxx
"  s//~~~~~~~~~AAAAAAA@(
"
"  " Either fails with "out of memory" or "text too long".
"  " This can take a long time.
"  call assert_fails('sil! norm &&&&&&&&&', ['E1240:\|E342:'])
"
"  bwipe!
"endfunc

" This should be done last to reveal a memory leak when vim_regsub_both() is
" called to evaluate an expression but it is not used in a second call.
func Test_z_substitute_expr_leak()
  func SubExpr()
    ~n
  endfunc
  silent! s/\%')/\=SubExpr()
  delfunc SubExpr
endfunc

func Test_substitute_expr_switch_win()
  func R()
    wincmd x
    return 'XXXX'
  endfunc
  new Xfoobar
  let bufnr = bufnr('%')
  put ='abcdef'
  silent! s/\%')/\=R()
  call assert_fails(':%s/./\=R()/g', 'E565:')
  delfunc R
  exe bufnr .. "bw!"
endfunc

" recursive call of :s using test-replace special
func Test_substitute_expr_recursive()
  func Q()
    %s/./\='foobar'/gn
    return "foobar"
  endfunc
  func R()
    %s/./\=Q()/g
  endfunc
  new Xfoobar_UAF
  let bufnr = bufnr('%')
  put ='abcdef'
  silent! s/./\=R()/g
  call assert_fails(':%s/./\=R()/g', 'E565:')
  delfunc R
  delfunc Q
  exe bufnr .. "bw!"
endfunc

" Test for changing 'cpo' in a substitute expression
func Test_substitute_expr_cpo()
  func XSubExpr()
    set cpo=
    return 'x'
  endfunc

  let save_cpo = &cpo
  call assert_equal('xxx', substitute('abc', '.', '\=XSubExpr()', 'g'))
  call assert_equal(save_cpo, &cpo)

  delfunc XSubExpr
endfunc

" vim: shiftwidth=2 sts=2 expandtab
