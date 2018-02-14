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
