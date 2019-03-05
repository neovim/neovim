" Tests for multi-line regexps with ":s".

function! Test_multiline_subst()
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
endfunction

function! Test_substitute_variants()
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
	\ { 'cmd': ':s/t/r/cn', 'exp': ln },
	\ { 'cmd': ':s/t/r/cp', 'exp': 'Tesring string', 'prompt': 'y' },
	\ { 'cmd': ':s/t/r/cl', 'exp': 'Tesring string', 'prompt': 'y' },
	\ { 'cmd': ':s/t/r/gc', 'exp': 'Tesring srring', 'prompt': 'a' },
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
endfunction

func Test_substitute_repeat()
  " This caused an invalid memory access.
  split Xfile
  s/^/x
  call feedkeys("Qsc\<CR>y", 'tx')
  bwipe!
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
	      \ ['V', 's/V/\U\lVvV\u\Ev/', ['vVVv']]
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
	      \ ['V', 's/V/\U\lVvV\u\Ev/', ['vVVv']]
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

" Test for submatch() on :substitue.
func Test_sub_cmd_4()
  set magic&
  set cpo&

  " List entry format: [input, cmd, output]
  let tests = [ ['aAa', "s/A/\\=substitute(submatch(0), '.', '\\', '')/",
	      \ 			['a\a']],
	      \ ['bBb', "s/B/\\=substitute(submatch(0), '.', '\\', '')/",
	      \   			['b\b']],
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
  throw "skipped: Nvim removed POSIX-related 'cpoptions' flags"
  set magic&
  set cpo+=/

  " List entry format: [input, cmd, output]
  let tests = [ ['A', 's/A/a/', ['a']],
	      \ ['B', 's/B/%/', ['a']],
	      \ ]
  call Run_SubCmd_Tests(tests)

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

  bwipe!
endfunc

func Test_substitute_errors()
  new
  call setline(1, 'foobar')

  call assert_fails('s/FOO/bar/', 'E486:')
  call assert_fails('s/foo/bar/@', 'E488:')
  call assert_fails('s/\(/bar/', 'E476:')

  setl nomodifiable
  call assert_fails('s/foo/bar/', 'E21:')

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
		\ 'submatch(8, 1), submatch(7, 1), submatch(6, 1), ' .
		\ 'submatch(5, 1), submatch(4, 1), submatch(3, 1), ' .
		\ 'submatch(2, 1), submatch(1, 1)])',
		\ ''))
endfunc

func Test_sub_replace_6()
  set magic&
  " set cpo+=/
  call assert_equal('a', substitute('A', 'A', 'a', ''))
  call assert_equal('%', substitute('B', 'B', '%', ''))
  " set cpo-=/
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
