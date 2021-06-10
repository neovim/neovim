" Tests for regexp in latin1 encoding

" set encoding=latin1
scriptencoding latin1

source check.vim

func s:equivalence_test()
  let str = "AÀÁÂÃÄÅ B C D EÈÉÊË F G H IÌÍÎÏ J K L M NÑ OÒÓÔÕÖØ P Q R S T UÙÚÛÜ V W X YÝ Z aàáâãäå b c d eèéêë f g h iìíîï j k l m nñ oòóôõöø p q r s t uùúûü v w x yýÿ z"
  let groups = split(str)
  for group1 in groups
      for c in split(group1, '\zs')
	" next statement confirms that equivalence class matches every
	" character in group
        call assert_match('^[[=' . c . '=]]*$', group1)
        for group2 in groups
          if group2 != group1
	    " next statement converts that equivalence class doesn't match
	    " a character in any other group
            call assert_equal(-1, match(group2, '[[=' . c . '=]]'))
          endif
        endfor
      endfor
  endfor
endfunc

func Test_equivalence_re1()
  throw 'skipped: Nvim does not support enc=latin1'
  set re=1
  call s:equivalence_test()
endfunc

func Test_equivalence_re2()
  throw 'skipped: Nvim does not support enc=latin1'
  set re=2
  call s:equivalence_test()
endfunc

func Test_range_with_newline()
  new
  call setline(1, "a")
  call assert_equal(0, search("[ -*\\n- ]"))
  call assert_equal(0, search("[ -*\\t-\\n]"))
  bwipe!
endfunc

func Test_pattern_compile_speed()
  CheckOption spellcapcheck
  CheckFunction reltimefloat

  let start = reltime()
  " this used to be very slow, not it should be about a second
  set spc=\\v(((((Nxxxxxxx&&xxxx){179})+)+)+){179}
  call assert_inrange(0.01, 10.0, reltimefloat(reltime(start)))
  set spc=
endfunc

func Test_get_equi_class()
  new
  " Incomplete equivalence class caused invalid memory access
  s/^/[[=
  call assert_equal(1, search(getline(1)))
  s/.*/[[.
  call assert_equal(1, search(getline(1)))
endfunc

func Test_rex_init()
  set noincsearch
  set re=1
  new
  setlocal iskeyword=a-z
  call setline(1, ['abc', 'ABC'])
  call assert_equal(1, search('[[:keyword:]]'))
  new
  setlocal iskeyword=A-Z
  call setline(1, ['abc', 'ABC'])
  call assert_equal(2, search('[[:keyword:]]'))
  bwipe!
  bwipe!
  set re=0
endfunc

func Test_backref()
  new
  call setline(1, ['one', 'two', 'three', 'four', 'five'])
  call assert_equal(3, search('\%#=1\(e\)\1'))
  call assert_equal(3, search('\%#=2\(e\)\1'))
  call assert_fails('call search("\\%#=1\\(e\\1\\)")', 'E65:')
  call assert_fails('call search("\\%#=2\\(e\\1\\)")', 'E65:')
  bwipe!
endfunc

func Test_multi_failure()
  set re=1
  call assert_fails('/a**', 'E61:')
  call assert_fails('/a*\+', 'E62:')
  call assert_fails('/a\{a}', 'E554:')
  set re=2
  call assert_fails('/a**', 'E871:')
  call assert_fails('/a*\+', 'E871:')
  call assert_fails('/a\{a}', 'E870:')
  set re=0
endfunc

func Test_recursive_addstate()
  throw 'skipped: TODO: '
  " This will call addstate() recursively until it runs into the limit.
  let lnum = search('\v((){328}){389}')
  call assert_equal(0, lnum)
endfunc

func Test_out_of_memory()
  new
  s/^/,n
  " This will be slow...
  call assert_fails('call search("\\v((n||<)+);")', 'E363:')
endfunc

" Tests for regexp patterns without multi-byte support.
func Test_regexp_single_line_pat()
  " tl is a List of Lists with:
  "    regexp engine
  "    regexp pattern
  "    text to test the pattern on
  "    expected match (optional)
  "    expected submatch 1 (optional)
  "    expected submatch 2 (optional)
  "    etc.
  "  When there is no match use only the first two items.
  let tl = []

  call add(tl, [2, 'ab', 'aab', 'ab'])
  call add(tl, [2, 'b', 'abcdef', 'b'])
  call add(tl, [2, 'bc*', 'abccccdef', 'bcccc'])
  call add(tl, [2, 'bc\{-}', 'abccccdef', 'b'])
  call add(tl, [2, 'bc\{-}\(d\)', 'abccccdef', 'bccccd', 'd'])
  call add(tl, [2, 'bc*', 'abbdef', 'b'])
  call add(tl, [2, 'c*', 'ccc', 'ccc'])
  call add(tl, [2, 'bc*', 'abdef', 'b'])
  call add(tl, [2, 'c*', 'abdef', ''])
  call add(tl, [2, 'bc\+', 'abccccdef', 'bcccc'])
  call add(tl, [2, 'bc\+', 'abdef']) " no match

  " operator \|
  call add(tl, [2, 'a\|ab', 'cabd', 'a']) " alternation is ordered

  call add(tl, [2, 'c\?', 'ccb', 'c'])
  call add(tl, [2, 'bc\?', 'abd', 'b'])
  call add(tl, [2, 'bc\?', 'abccd', 'bc'])

  call add(tl, [2, '\va{1}', 'ab', 'a'])

  call add(tl, [2, '\va{2}', 'aa', 'aa'])
  call add(tl, [2, '\va{2}', 'caad', 'aa'])
  call add(tl, [2, '\va{2}', 'aba'])
  call add(tl, [2, '\va{2}', 'ab'])
  call add(tl, [2, '\va{2}', 'abaa', 'aa'])
  call add(tl, [2, '\va{2}', 'aaa', 'aa'])

  call add(tl, [2, '\vb{1}', 'abca', 'b'])
  call add(tl, [2, '\vba{2}', 'abaa', 'baa'])
  call add(tl, [2, '\vba{3}', 'aabaac'])

  call add(tl, [2, '\v(ab){1}', 'ab', 'ab', 'ab'])
  call add(tl, [2, '\v(ab){1}', 'dabc', 'ab', 'ab'])
  call add(tl, [2, '\v(ab){1}', 'acb'])

  call add(tl, [2, '\v(ab){0,2}', 'acb', "", ""])
  call add(tl, [2, '\v(ab){0,2}', 'ab', 'ab', 'ab'])
  call add(tl, [2, '\v(ab){1,2}', 'ab', 'ab', 'ab'])
  call add(tl, [2, '\v(ab){1,2}', 'ababc', 'abab', 'ab'])
  call add(tl, [2, '\v(ab){2,4}', 'ababcab', 'abab', 'ab'])
  call add(tl, [2, '\v(ab){2,4}', 'abcababa', 'abab', 'ab'])

  call add(tl, [2, '\v(ab){2}', 'abab', 'abab', 'ab'])
  call add(tl, [2, '\v(ab){2}', 'cdababe', 'abab', 'ab'])
  call add(tl, [2, '\v(ab){2}', 'abac'])
  call add(tl, [2, '\v(ab){2}', 'abacabab', 'abab', 'ab'])
  call add(tl, [2, '\v((ab){2}){2}', 'abababab', 'abababab', 'abab', 'ab'])
  call add(tl, [2, '\v((ab){2}){2}', 'abacabababab', 'abababab', 'abab', 'ab'])

  call add(tl, [2, '\v(a{1}){1}', 'a', 'a', 'a'])
  call add(tl, [2, '\v(a{2}){1}', 'aa', 'aa', 'aa'])
  call add(tl, [2, '\v(a{2}){1}', 'aaac', 'aa', 'aa'])
  call add(tl, [2, '\v(a{2}){1}', 'daaac', 'aa', 'aa'])
  call add(tl, [2, '\v(a{1}){2}', 'daaac', 'aa', 'a'])
  call add(tl, [2, '\v(a{1}){2}', 'aaa', 'aa', 'a'])
  call add(tl, [2, '\v(a{2})+', 'adaac', 'aa', 'aa'])
  call add(tl, [2, '\v(a{2})+', 'aa', 'aa', 'aa'])
  call add(tl, [2, '\v(a{2}){1}', 'aa', 'aa', 'aa'])
  call add(tl, [2, '\v(a{1}){2}', 'aa', 'aa', 'a'])
  call add(tl, [2, '\v(a{1}){1}', 'a', 'a', 'a'])
  call add(tl, [2, '\v(a{2}){2}', 'aaaa', 'aaaa', 'aa'])
  call add(tl, [2, '\v(a{2}){2}', 'aaabaaaa', 'aaaa', 'aa'])

  call add(tl, [2, '\v(a+){2}', 'dadaac', 'aa', 'a'])
  call add(tl, [2, '\v(a{3}){2}', 'aaaaaaa', 'aaaaaa', 'aaa'])

  call add(tl, [2, '\v(a{1,2}){2}', 'daaac', 'aaa', 'a'])
  call add(tl, [2, '\v(a{1,3}){2}', 'daaaac', 'aaaa', 'a'])
  call add(tl, [2, '\v(a{1,3}){2}', 'daaaaac', 'aaaaa', 'aa'])
  call add(tl, [2, '\v(a{1,3}){3}', 'daac'])
  call add(tl, [2, '\v(a{1,2}){2}', 'dac'])
  call add(tl, [2, '\v(a+)+', 'daac', 'aa', 'aa'])
  call add(tl, [2, '\v(a+)+', 'aaa', 'aaa', 'aaa'])
  call add(tl, [2, '\v(a+){1,2}', 'aaa', 'aaa', 'aaa'])
  call add(tl, [2, '\v(a+)(a+)', 'aaa', 'aaa', 'aa', 'a'])
  call add(tl, [2, '\v(a{3})+', 'daaaac', 'aaa', 'aaa'])
  call add(tl, [2, '\v(a|b|c)+', 'aacb', 'aacb', 'b'])
  call add(tl, [2, '\v(a|b|c){2}', 'abcb', 'ab', 'b'])
  call add(tl, [2, '\v(abc){2}', 'abcabd', ])
  call add(tl, [2, '\v(abc){2}', 'abdabcabc','abcabc', 'abc'])

  call add(tl, [2, 'a*', 'cc', ''])
  call add(tl, [2, '\v(a*)+', 'cc', ''])
  call add(tl, [2, '\v((ab)+)+', 'ab', 'ab', 'ab', 'ab'])
  call add(tl, [2, '\v(((ab)+)+)+', 'ab', 'ab', 'ab', 'ab', 'ab'])
  call add(tl, [2, '\v(((ab)+)+)+', 'dababc', 'abab', 'abab', 'abab', 'ab'])
  call add(tl, [2, '\v(a{0,2})+', 'cc', ''])
  call add(tl, [2, '\v(a*)+', '', ''])
  call add(tl, [2, '\v((a*)+)+', '', ''])
  call add(tl, [2, '\v((ab)*)+', '', ''])
  call add(tl, [2, '\va{1,3}', 'aab', 'aa'])
  call add(tl, [2, '\va{2,3}', 'abaa', 'aa'])

  call add(tl, [2, '\v((ab)+|c*)+', 'abcccaba', 'abcccab', '', 'ab'])
  call add(tl, [2, '\v(a{2})|(b{3})', 'bbabbbb', 'bbb', '', 'bbb'])
  call add(tl, [2, '\va{2}|b{2}', 'abab'])
  call add(tl, [2, '\v(a)+|(c)+', 'bbacbaacbbb', 'a', 'a'])
  call add(tl, [2, '\vab{2,3}c', 'aabbccccccccccccc', 'abbc'])
  call add(tl, [2, '\vab{2,3}c', 'aabbbccccccccccccc', 'abbbc'])
  call add(tl, [2, '\vab{2,3}cd{2,3}e', 'aabbbcddee', 'abbbcdde'])
  call add(tl, [2, '\va(bc){2}d', 'aabcbfbc' ])
  call add(tl, [2, '\va*a{2}', 'a', ])
  call add(tl, [2, '\va*a{2}', 'aa', 'aa' ])
  call add(tl, [2, '\va*a{2}', 'aaa', 'aaa' ])
  call add(tl, [2, '\va*a{2}', 'bbbabcc', ])
  call add(tl, [2, '\va*b*|a*c*', 'a', 'a'])
  call add(tl, [2, '\va{1}b{1}|a{1}b{1}', ''])

  " submatches
  call add(tl, [2, '\v(a)', 'ab', 'a', 'a'])
  call add(tl, [2, '\v(a)(b)', 'ab', 'ab', 'a', 'b'])
  call add(tl, [2, '\v(ab)(b)(c)', 'abbc', 'abbc', 'ab', 'b', 'c'])
  call add(tl, [2, '\v((a)(b))', 'ab', 'ab', 'ab', 'a', 'b'])
  call add(tl, [2, '\v(a)|(b)', 'ab', 'a', 'a'])

  call add(tl, [2, '\v(a*)+', 'aaaa', 'aaaa', ''])
  call add(tl, [2, 'x', 'abcdef'])

  "
  " Simple tests
  "

  " Search single groups
  call add(tl, [2, 'ab', 'aab', 'ab'])
  call add(tl, [2, 'ab', 'baced'])
  call add(tl, [2, 'ab', '                    ab           ', 'ab'])

  " Search multi-modifiers
  call add(tl, [2, 'x*', 'xcd', 'x'])
  call add(tl, [2, 'x*', 'xxxxxxxxxxxxxxxxsofijiojgf', 'xxxxxxxxxxxxxxxx'])
  " empty match is good
  call add(tl, [2, 'x*', 'abcdoij', ''])
  " no match here
  call add(tl, [2, 'x\+', 'abcdoin'])
  call add(tl, [2, 'x\+', 'abcdeoijdfxxiuhfij', 'xx'])
  call add(tl, [2, 'x\+', 'xxxxx', 'xxxxx'])
  call add(tl, [2, 'x\+', 'abc x siufhiush xxxxxxxxx', 'x'])
  call add(tl, [2, 'x\=', 'x sdfoij', 'x'])
  call add(tl, [2, 'x\=', 'abc sfoij', '']) " empty match is good
  call add(tl, [2, 'x\=', 'xxxxxxxxx c', 'x'])
  call add(tl, [2, 'x\?', 'x sdfoij', 'x'])
  " empty match is good
  call add(tl, [2, 'x\?', 'abc sfoij', ''])
  call add(tl, [2, 'x\?', 'xxxxxxxxxx c', 'x'])

  call add(tl, [2, 'a\{0,0}', 'abcdfdoij', ''])
  " same thing as 'a?'
  call add(tl, [2, 'a\{0,1}', 'asiubid axxxaaa', 'a'])
  " same thing as 'a\{0,1}'
  call add(tl, [2, 'a\{1,0}', 'asiubid axxxaaa', 'a'])
  call add(tl, [2, 'a\{3,6}', 'aa siofuh'])
  call add(tl, [2, 'a\{3,6}', 'aaaaa asfoij afaa', 'aaaaa'])
  call add(tl, [2, 'a\{3,6}', 'aaaaaaaa', 'aaaaaa'])
  call add(tl, [2, 'a\{0}', 'asoiuj', ''])
  call add(tl, [2, 'a\{2}', 'aaaa', 'aa'])
  call add(tl, [2, 'a\{2}', 'iuash fiusahfliusah fiushfilushfi uhsaifuh askfj nasfvius afg aaaa sfiuhuhiushf', 'aa'])
  call add(tl, [2, 'a\{2}', 'abcdefghijklmnopqrestuvwxyz1234567890'])
  " same thing as 'a*'
  call add(tl, [2, 'a\{0,}', 'oij sdigfusnf', ''])
  call add(tl, [2, 'a\{0,}', 'aaaaa aa', 'aaaaa'])
  call add(tl, [2, 'a\{2,}', 'sdfiougjdsafg'])
  call add(tl, [2, 'a\{2,}', 'aaaaasfoij ', 'aaaaa'])
  call add(tl, [2, 'a\{5,}', 'xxaaaaxxx '])
  call add(tl, [2, 'a\{5,}', 'xxaaaaaxxx ', 'aaaaa'])
  call add(tl, [2, 'a\{,0}', 'oidfguih iuhi hiu aaaa', ''])
  call add(tl, [2, 'a\{,5}', 'abcd', 'a'])
  call add(tl, [2, 'a\{,5}', 'aaaaaaaaaa', 'aaaaa'])
  " leading star as normal char when \{} follows
  call add(tl, [2, '^*\{4,}$', '***'])
  call add(tl, [2, '^*\{4,}$', '****', '****'])
  call add(tl, [2, '^*\{4,}$', '*****', '*****'])
  " same thing as 'a*'
  call add(tl, [2, 'a\{}', 'bbbcddiuhfcd', ''])
  call add(tl, [2, 'a\{}', 'aaaaioudfh coisf jda', 'aaaa'])

  call add(tl, [2, 'a\{-0,0}', 'abcdfdoij', ''])
  " anti-greedy version of 'a?'
  call add(tl, [2, 'a\{-0,1}', 'asiubid axxxaaa', ''])
  call add(tl, [2, 'a\{-3,6}', 'aa siofuh'])
  call add(tl, [2, 'a\{-3,6}', 'aaaaa asfoij afaa', 'aaa'])
  call add(tl, [2, 'a\{-3,6}', 'aaaaaaaa', 'aaa'])
  call add(tl, [2, 'a\{-0}', 'asoiuj', ''])
  call add(tl, [2, 'a\{-2}', 'aaaa', 'aa'])
  call add(tl, [2, 'a\{-2}', 'abcdefghijklmnopqrestuvwxyz1234567890'])
  call add(tl, [2, 'a\{-0,}', 'oij sdigfusnf', ''])
  call add(tl, [2, 'a\{-0,}', 'aaaaa aa', ''])
  call add(tl, [2, 'a\{-2,}', 'sdfiougjdsafg'])
  call add(tl, [2, 'a\{-2,}', 'aaaaasfoij ', 'aa'])
  call add(tl, [2, 'a\{-,0}', 'oidfguih iuhi hiu aaaa', ''])
  call add(tl, [2, 'a\{-,5}', 'abcd', ''])
  call add(tl, [2, 'a\{-,5}', 'aaaaaaaaaa', ''])
  " anti-greedy version of 'a*'
  call add(tl, [2, 'a\{-}', 'bbbcddiuhfcd', ''])
  call add(tl, [2, 'a\{-}', 'aaaaioudfh coisf jda', ''])

  " Test groups of characters and submatches
  call add(tl, [2, '\(abc\)*', 'abcabcabc', 'abcabcabc', 'abc'])
  call add(tl, [2, '\(ab\)\+', 'abababaaaaa', 'ababab', 'ab'])
  call add(tl, [2, '\(abaaaaa\)*cd', 'cd', 'cd', ''])
  call add(tl, [2, '\(test1\)\? \(test2\)\?', 'test1 test3', 'test1 ', 'test1', ''])
  call add(tl, [2, '\(test1\)\= \(test2\) \(test4443\)\=', ' test2 test4443 yupiiiiiiiiiii', ' test2 test4443', '', 'test2', 'test4443'])
  call add(tl, [2, '\(\(sub1\) hello \(sub 2\)\)', 'asterix sub1 hello sub 2 obelix', 'sub1 hello sub 2', 'sub1 hello sub 2', 'sub1', 'sub 2'])
  call add(tl, [2, '\(\(\(yyxxzz\)\)\)', 'abcdddsfiusfyyzzxxyyxxzz', 'yyxxzz', 'yyxxzz', 'yyxxzz', 'yyxxzz'])
  call add(tl, [2, '\v((ab)+|c+)+', 'abcccaba', 'abcccab', 'ab', 'ab'])
  call add(tl, [2, '\v((ab)|c*)+', 'abcccaba', 'abcccab', '', 'ab'])
  call add(tl, [2, '\v(a(c*)+b)+', 'acbababaaa', 'acbabab', 'ab', ''])
  call add(tl, [2, '\v(a|b*)+', 'aaaa', 'aaaa', ''])
  call add(tl, [2, '\p*', 'aá 	', 'aá '])

  " Test greedy-ness and lazy-ness
  call add(tl, [2, 'a\{-2,7}','aaaaaaaaaaaaa', 'aa'])
  call add(tl, [2, 'a\{-2,7}x','aaaaaaaaax', 'aaaaaaax'])
  call add(tl, [2, 'a\{2,7}','aaaaaaaaaaaaaaaaaaaa', 'aaaaaaa'])
  call add(tl, [2, 'a\{2,7}x','aaaaaaaaax', 'aaaaaaax'])
  call add(tl, [2, '\vx(.{-,8})yz(.*)','xayxayzxayzxayz','xayxayzxayzxayz','ayxa','xayzxayz'])
  call add(tl, [2, '\vx(.*)yz(.*)','xayxayzxayzxayz','xayxayzxayzxayz', 'ayxayzxayzxa',''])
  call add(tl, [2, '\v(a{1,2}){-2,3}','aaaaaaa','aaaa','aa'])
  call add(tl, [2, '\v(a{-1,3})+', 'aa', 'aa', 'a'])
  call add(tl, [2, '^\s\{-}\zs\( x\|x$\)', ' x', ' x', ' x'])
  call add(tl, [2, '^\s\{-}\zs\(x\| x$\)', ' x', ' x', ' x'])
  call add(tl, [2, '^\s\{-}\ze\(x\| x$\)', ' x', '', ' x'])
  call add(tl, [2, '^\(\s\{-}\)\(x\| x$\)', ' x', ' x', '', ' x'])

  " Test Character classes
  call add(tl, [2, '\d\+e\d\d','test 10e23 fd','10e23'])

  " Test collections and character range []
  call add(tl, [2, '\v[a]', 'abcd', 'a'])
  call add(tl, [2, 'a[bcd]', 'abcd', 'ab'])
  call add(tl, [2, 'a[b-d]', 'acbd', 'ac'])
  call add(tl, [2, '[a-d][e-f][x-x]d', 'cexdxx', 'cexd'])
  call add(tl, [2, '\v[[:alpha:]]+', 'abcdefghijklmnopqrstuvwxyz6','abcdefghijklmnopqrstuvwxyz'])
  call add(tl, [2, '[[:alpha:]\+]', '6x8','x'])
  call add(tl, [2, '[^abc]\+','abcabcabc'])
  call add(tl, [2, '[^abc]','defghiasijvoinasoiunbvb','d'])
  call add(tl, [2, '[^abc]\+','ddddddda','ddddddd'])
  call add(tl, [2, '[^a-d]\+','aaaAAAZIHFNCddd','AAAZIHFNC'])
  call add(tl, [2, '[a-f]*','iiiiiiii',''])
  call add(tl, [2, '[a-f]*','abcdefgh','abcdef'])
  call add(tl, [2, '[^a-f]\+','abcdefgh','gh'])
  call add(tl, [2, '[a-c]\{-3,6}','abcabc','abc'])
  call add(tl, [2, '[^[:alpha:]]\+','abcccadfoij7787ysf287yrnccdu','7787'])
  call add(tl, [2, '[-a]', '-', '-'])
  call add(tl, [2, '[a-]', '-', '-'])
  call add(tl, [2, '[a-f]*\c','ABCDEFGH','ABCDEF'])
  call add(tl, [2, '[abc][xyz]\c','-af-AF-BY--','BY'])
  " filename regexp
  call add(tl, [2, '[-./[:alnum:]_~]\+', 'log13.file', 'log13.file'])
  " special chars
  call add(tl, [2, '[\]\^\-\\]\+', '\^\\\-\---^', '\^\\\-\---^'])
  " collation elem
  call add(tl, [2, '[[.a.]]\+', 'aa', 'aa'])
  " middle of regexp
  call add(tl, [2, 'abc[0-9]*ddd', 'siuhabc ii'])
  call add(tl, [2, 'abc[0-9]*ddd', 'adf abc44482ddd oijs', 'abc44482ddd'])
  call add(tl, [2, '\_[0-9]\+', 'asfi9888u', '9888'])
  call add(tl, [2, '[0-9\n]\+', 'asfi9888u', '9888'])
  call add(tl, [2, '\_[0-9]\+', "asfi\n9888u", "\n9888"])
  call add(tl, [2, '\_f', "  \na ", "\n"])
  call add(tl, [2, '\_f\+', "  \na ", "\na"])
  call add(tl, [2, '[0-9A-Za-z-_.]\+', " @0_a.A-{ ", "0_a.A-"])

  " Test start/end of line, start/end of file
  call add(tl, [2, '^a.', "a_\nb ", "a_"])
  call add(tl, [2, '^a.', "b a \na_"])
  call add(tl, [2, '.a$', " a\n "])
  call add(tl, [2, '.a$', " a b\n_a", "_a"])
  call add(tl, [2, '\%^a.', "a a\na", "a "])
  call add(tl, [2, '\%^a', " a \na "])
  call add(tl, [2, '.a\%$', " a\n "])
  call add(tl, [2, '.a\%$', " a\n_a", "_a"])

  " Test recognition of character classes
  call add(tl, [2, '[0-7]\+', 'x0123456789x', '01234567'])
  call add(tl, [2, '[^0-7]\+', '0a;X+% 897', 'a;X+% 89'])
  call add(tl, [2, '[0-9]\+', 'x0123456789x', '0123456789'])
  call add(tl, [2, '[^0-9]\+', '0a;X+% 9', 'a;X+% '])
  call add(tl, [2, '[0-9a-fA-F]\+', 'x0189abcdefg', '0189abcdef'])
  call add(tl, [2, '[^0-9A-Fa-f]\+', '0189g;X+% ab', 'g;X+% '])
  call add(tl, [2, '[a-z_A-Z0-9]\+', ';+aso_SfOij ', 'aso_SfOij'])
  call add(tl, [2, '[^a-z_A-Z0-9]\+', 'aSo_;+% sfOij', ';+% '])
  call add(tl, [2, '[a-z_A-Z]\+', '0abyz_ABYZ;', 'abyz_ABYZ'])
  call add(tl, [2, '[^a-z_A-Z]\+', 'abAB_09;+% yzYZ', '09;+% '])
  call add(tl, [2, '[a-z]\+', '0abcxyz1', 'abcxyz'])
  call add(tl, [2, '[a-z]\+', 'AabxyzZ', 'abxyz'])
  call add(tl, [2, '[^a-z]\+', 'a;X09+% x', ';X09+% '])
  call add(tl, [2, '[^a-z]\+', 'abX0;%yz', 'X0;%'])
  call add(tl, [2, '[a-zA-Z]\+', '0abABxzXZ9', 'abABxzXZ'])
  call add(tl, [2, '[^a-zA-Z]\+', 'ab09_;+ XZ', '09_;+ '])
  call add(tl, [2, '[A-Z]\+', 'aABXYZz', 'ABXYZ'])
  call add(tl, [2, '[^A-Z]\+', 'ABx0;%YZ', 'x0;%'])
  call add(tl, [2, '[a-z]\+\c', '0abxyzABXYZ;', 'abxyzABXYZ'])
  call add(tl, [2, '[A-Z]\+\c', '0abABxzXZ9', 'abABxzXZ'])
  call add(tl, [2, '\c[^a-z]\+', 'ab09_;+ XZ', '09_;+ '])
  call add(tl, [2, '\c[^A-Z]\+', 'ab09_;+ XZ', '09_;+ '])
  call add(tl, [2, '\C[^A-Z]\+', 'ABCOIJDEOIFNSD jsfoij sa', ' jsfoij sa'])

  " Tests for \z features
  " match ends at \ze
  call add(tl, [2, 'xx \ze test', 'xx '])
  call add(tl, [2, 'abc\zeend', 'oij abcend', 'abc'])
  call add(tl, [2, 'aa\zebb\|aaxx', ' aabb ', 'aa'])
  call add(tl, [2, 'aa\zebb\|aaxx', ' aaxx ', 'aaxx'])
  call add(tl, [2, 'aabb\|aa\zebb', ' aabb ', 'aabb'])
  call add(tl, [2, 'aa\zebb\|aaebb', ' aabb ', 'aa'])
  " match starts at \zs
  call add(tl, [2, 'abc\zsdd', 'ddabcddxyzt', 'dd'])
  call add(tl, [2, 'aa \zsax', ' ax'])
  call add(tl, [2, 'abc \zsmatch\ze abc', 'abc abc abc match abc abc', 'match'])
  call add(tl, [2, '\v(a \zsif .*){2}', 'a if then a if last', 'if last', 'a if last'])
  call add(tl, [2, '\>\zs.', 'aword. ', '.'])
  call add(tl, [2, '\s\+\ze\[/\|\s\zs\s\+', 'is   [a t', '  '])

  " Tests for \@= and \& features
  call add(tl, [2, 'abc\@=', 'abc', 'ab'])
  call add(tl, [2, 'abc\@=cd', 'abcd', 'abcd'])
  call add(tl, [2, 'abc\@=', 'ababc', 'ab'])
  " will never match, no matter the input text
  call add(tl, [2, 'abcd\@=e', 'abcd'])
  " will never match
  call add(tl, [2, 'abcd\@=e', 'any text in here ... '])
  call add(tl, [2, '\v(abc)@=..', 'xabcd', 'ab', 'abc'])
  call add(tl, [2, '\(.*John\)\@=.*Bob', 'here is John, and here is B'])
  call add(tl, [2, '\(John.*\)\@=.*Bob', 'John is Bobs friend', 'John is Bob', 'John is Bobs friend'])
  call add(tl, [2, '\<\S\+\())\)\@=', '$((i=i+1))', 'i=i+1', '))'])
  call add(tl, [2, '.*John\&.*Bob', 'here is John, and here is B'])
  call add(tl, [2, '.*John\&.*Bob', 'John is Bobs friend', 'John is Bob'])
  call add(tl, [2, '\v(test1)@=.*yep', 'this is a test1, yep it is', 'test1, yep', 'test1'])
  call add(tl, [2, 'foo\(bar\)\@!', 'foobar'])
  call add(tl, [2, 'foo\(bar\)\@!', 'foo bar', 'foo'])
  call add(tl, [2, 'if \(\(then\)\@!.\)*$', ' if then else'])
  call add(tl, [2, 'if \(\(then\)\@!.\)*$', ' if else ', 'if else ', ' '])
  call add(tl, [2, '\(foo\)\@!bar', 'foobar', 'bar'])
  call add(tl, [2, '\(foo\)\@!...bar', 'foobar'])
  call add(tl, [2, '^\%(.*bar\)\@!.*\zsfoo', ' bar foo '])
  call add(tl, [2, '^\%(.*bar\)\@!.*\zsfoo', ' foo bar '])
  call add(tl, [2, '^\%(.*bar\)\@!.*\zsfoo', ' foo xxx ', 'foo'])
  call add(tl, [2, '[ ]\@!\p\%([ ]\@!\p\)*:', 'implicit mappings:', 'mappings:'])
  call add(tl, [2, '[ ]\@!\p\([ ]\@!\p\)*:', 'implicit mappings:', 'mappings:', 's'])
  call add(tl, [2, 'm\k\+_\@=\%(_\@!\k\)\@<=\k\+e', 'mx__xe', 'mx__xe'])
  call add(tl, [2, '\%(\U\@<=S\k*\|S\l\)R', 'SuR', 'SuR'])

  " Combining different tests and features
  call add(tl, [2, '[[:alpha:]]\{-2,6}', '787abcdiuhsasiuhb4', 'ab'])
  call add(tl, [2, '', 'abcd', ''])
  call add(tl, [2, '\v(())', 'any possible text', ''])
  call add(tl, [2, '\v%(ab(xyz)c)', '   abxyzc ', 'abxyzc', 'xyz'])
  call add(tl, [2, '\v(test|)empty', 'tesempty', 'empty', ''])
  call add(tl, [2, '\v(a|aa)(a|aa)', 'aaa', 'aa', 'a', 'a'])

  " \%u and friends
  call add(tl, [2, '\%d32', 'yes no', ' '])
  call add(tl, [2, '\%o40', 'yes no', ' '])
  call add(tl, [2, '\%x20', 'yes no', ' '])
  call add(tl, [2, '\%u0020', 'yes no', ' '])
  call add(tl, [2, '\%U00000020', 'yes no', ' '])
  call add(tl, [2, '\%d0', "yes\x0ano", "\x0a"])

  "" \%[abc]
  call add(tl, [2, 'foo\%[bar]', 'fobar'])
  call add(tl, [2, 'foo\%[bar]', 'foobar', 'foobar'])
  call add(tl, [2, 'foo\%[bar]', 'fooxx', 'foo'])
  call add(tl, [2, 'foo\%[bar]', 'foobxx', 'foob'])
  call add(tl, [2, 'foo\%[bar]', 'foobaxx', 'fooba'])
  call add(tl, [2, 'foo\%[bar]', 'foobarxx', 'foobar'])
  call add(tl, [2, 'foo\%[bar]x', 'foobxx', 'foobx'])
  call add(tl, [2, 'foo\%[bar]x', 'foobarxx', 'foobarx'])
  call add(tl, [2, '\%[bar]x', 'barxx', 'barx'])
  call add(tl, [2, '\%[bar]x', 'bxx', 'bx'])
  call add(tl, [2, '\%[bar]x', 'xxx', 'x'])
  call add(tl, [2, 'b\%[[ao]r]', 'bar bor', 'bar'])
  call add(tl, [2, 'b\%[[]]r]', 'b]r bor', 'b]r'])
  call add(tl, [2, '@\%[\w\-]*', '<http://john.net/pandoc/>[@pandoc]', '@pandoc'])

  " Alternatives, must use first longest match
  call add(tl, [2, 'goo\|go', 'google', 'goo'])
  call add(tl, [2, '\<goo\|\<go', 'google', 'goo'])
  call add(tl, [2, '\<goo\|go', 'google', 'goo'])

  " Back references
  call add(tl, [2, '\(\i\+\) \1', ' abc abc', 'abc abc', 'abc'])
  call add(tl, [2, '\(\i\+\) \1', 'xgoo goox', 'goo goo', 'goo'])
  call add(tl, [2, '\(a\)\(b\)\(c\)\(dd\)\(e\)\(f\)\(g\)\(h\)\(i\)\1\2\3\4\5\6\7\8\9', 'xabcddefghiabcddefghix', 'abcddefghiabcddefghi', 'a', 'b', 'c', 'dd', 'e', 'f', 'g', 'h', 'i'])
  call add(tl, [2, '\(\d*\)a \1b', ' a b ', 'a b', ''])
  call add(tl, [2, '^.\(.\).\_..\1.', "aaa\naaa\nb", "aaa\naaa", 'a'])
  call add(tl, [2, '^.*\.\(.*\)/.\+\(\1\)\@<!$', 'foo.bat/foo.com', 'foo.bat/foo.com', 'bat'])
  call add(tl, [2, '^.*\.\(.*\)/.\+\(\1\)\@<!$', 'foo.bat/foo.bat'])
  call add(tl, [2, '^.*\.\(.*\)/.\+\(\1\)\@<=$', 'foo.bat/foo.bat', 'foo.bat/foo.bat', 'bat', 'bat'])
  call add(tl, [2, '\\\@<!\${\(\d\+\%(:.\{-}\)\?\\\@<!\)}', '2013-06-27${0}', '${0}', '0'])
  call add(tl, [2, '^\(a*\)\1$', 'aaaaaaaa', 'aaaaaaaa', 'aaaa'])
  call add(tl, [2, '^\(a\{-2,}\)\1\+$', 'aaaaaaaaa', 'aaaaaaaaa', 'aaa'])

  " Look-behind with limit
  call add(tl, [2, '<\@<=span.', 'xxspanxx<spanyyy', 'spany'])
  call add(tl, [2, '<\@1<=span.', 'xxspanxx<spanyyy', 'spany'])
  call add(tl, [2, '<\@2<=span.', 'xxspanxx<spanyyy', 'spany'])
  call add(tl, [2, '\(<<\)\@<=span.', 'xxspanxxxx<spanxx<<spanyyy', 'spany', '<<'])
  call add(tl, [2, '\(<<\)\@1<=span.', 'xxspanxxxx<spanxx<<spanyyy'])
  call add(tl, [2, '\(<<\)\@2<=span.', 'xxspanxxxx<spanxx<<spanyyy', 'spany', '<<'])
  call add(tl, [2, '\(foo\)\@<!bar.', 'xx foobar1 xbar2 xx', 'bar2'])

  " look-behind match in front of a zero-width item
  call add(tl, [2, '\v\C%(<Last Changed:\s+)@<=.*$', '" test header'])
  call add(tl, [2, '\v\C%(<Last Changed:\s+)@<=.*$', '" Last Changed: 1970', '1970'])
  call add(tl, [2, '\(foo\)\@<=\>', 'foobar'])
  call add(tl, [2, '\(foo\)\@<=\>', 'barfoo', '', 'foo'])
  call add(tl, [2, '\(foo\)\@<=.*', 'foobar', 'bar', 'foo'])

  " complicated look-behind match
  call add(tl, [2, '\(r\@<=\|\w\@<!\)\/', 'x = /word/;', '/'])
  call add(tl, [2, '^[a-z]\+\ze \&\(asdf\)\@<!', 'foo bar', 'foo'])

  "" \@>
  call add(tl, [2, '\(a*\)\@>a', 'aaaa'])
  call add(tl, [2, '\(a*\)\@>b', 'aaab', 'aaab', 'aaa'])
  call add(tl, [2, '^\(.\{-}b\)\@>.', '  abcbd', '  abc', '  ab'])
  call add(tl, [2, '\(.\{-}\)\(\)\@>$', 'abc', 'abc', 'abc', ''])
  " TODO: BT engine does not restore submatch after failure
  call add(tl, [1, '\(a*\)\@>a\|a\+', 'aaaa', 'aaaa'])

  " "\_" prepended negated collection matches EOL
  call add(tl, [2, '\_[^8-9]\+', "asfi\n9888", "asfi\n"])
  call add(tl, [2, '\_[^a]\+', "asfi\n9888", "sfi\n9888"])

  " Requiring lots of states.
  call add(tl, [2, '[0-9a-zA-Z]\{8}-\([0-9a-zA-Z]\{4}-\)\{3}[0-9a-zA-Z]\{12}', " 12345678-1234-1234-1234-123456789012 ", "12345678-1234-1234-1234-123456789012", "1234-"])

  " Skip adding state twice
  call add(tl, [2, '^\%(\%(^\s*#\s*if\>\|#\s*if\)\)\(\%>1c.*$\)\@=', "#if FOO", "#if", ' FOO'])

  " Test \%V atom
  call add(tl, [2, '\%>70vGesamt', 'Jean-Michel Charlier & Victor Hubinon\Gesamtausgabe [Salleck]    Buck Danny {Jean-Michel Charlier & Victor Hubinon}\Gesamtausgabe', 'Gesamt'])

  " Run the tests
  for t in tl
    let re = t[0]
    let pat = t[1]
    let text = t[2]
    let matchidx = 3
    for engine in [0, 1, 2]
      if engine == 2 && re == 0 || engine == 1 && re == 1
        continue
      endif
      let &regexpengine = engine
      try
        let l = matchlist(text, pat)
      catch
        call assert_report('Error ' . engine . ': pat: \"' . pat
              \ . '\", text: \"' . text . '\", caused an exception: \"'
              \ . v:exception . '\"')
      endtry
      " check the match itself
      if len(l) == 0 && len(t) > matchidx
        call assert_report('Error ' . engine . ': pat: \"' . pat
              \ . '\", text: \"' . text . '\", did not match, expected: \"'
              \ . t[matchidx] . '\"')
      elseif len(l) > 0 && len(t) == matchidx
        call assert_report('Error ' . engine . ': pat: \"' . pat
              \ . '\", text: \"' . text . '\", match: \"' . l[0]
              \ . '\", expected no match')
      elseif len(t) > matchidx && l[0] != t[matchidx]
        call assert_report('Error ' . engine . ': pat: \"' . pat
              \ . '\", text: \"' . text . '\", match: \"' . l[0]
              \ . '\", expected: \"' . t[matchidx] . '\"')
      else
        " Test passed
      endif

      " check all the nine submatches
      if len(l) > 0
        for i in range(1, 9)
          if len(t) <= matchidx + i
            let e = ''
          else
            let e = t[matchidx + i]
          endif
          if l[i] != e
            call assert_report('Error ' . engine . ': pat: \"' . pat
                  \ . '\", text: \"' . text . '\", submatch ' . i . ': \"'
                  \ . l[i] . '\", expected: \"' . e . '\"')
          endif
        endfor
        unlet i
      endif
    endfor
  endfor

  unlet t tl e l
endfunc

" Tests for multi-line regexp patterns without multi-byte support.
func Test_regexp_multiline_pat()
  let tl = []

  " back references
  call add(tl, [2, '^.\(.\).\_..\1.', ['aaa', 'aaa', 'b'], ['XX', 'b']])
  call add(tl, [2, '\v.*\/(.*)\n.*\/\1$', ['./Dir1/Dir2/zyxwvuts.txt', './Dir1/Dir2/abcdefgh.bat', '', './Dir1/Dir2/file1.txt', './OtherDir1/OtherDir2/file1.txt'], ['./Dir1/Dir2/zyxwvuts.txt', './Dir1/Dir2/abcdefgh.bat', '', 'XX']])

  " line breaks
  call add(tl, [2, '\S.*\nx', ['abc', 'def', 'ghi', 'xjk', 'lmn'], ['abc', 'def', 'XXjk', 'lmn']])

  " Check that \_[0-9] matching EOL does not break a following \>
  call add(tl, [2, '\<\(\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\.\)\{3\}\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\>', ['', 'localnet/192.168.0.1', ''], ['', 'localnet/XX', '']])

  " Check a pattern with a line break and ^ and $
  call add(tl, [2, 'a\n^b$\n^c', ['a', 'b', 'c'], ['XX']])

  call add(tl, [2, '\(^.\+\n\)\1', [' dog', ' dog', 'asdf'], ['XXasdf']])

  " Run the multi-line tests
  for t in tl
    let re = t[0]
    let pat = t[1]
    let before = t[2]
    let after = t[3]
    for engine in [0, 1, 2]
      if engine == 2 && re == 0 || engine == 1 && re ==1
        continue
      endif
      let &regexpengine = engine
      new
      call setline(1, before)
      exe '%s/' . pat . '/XX/'
      let result = getline(1, '$')
      q!
      if result != after
        call assert_report('Error: pat: \"' . pat . '\", text: \"'
              \ . string(before) . '\", expected: \"' . string(after)
              \ . '\", got: \"' . string(result) . '\"')
      else
        " Test passed
      endif
    endfor
  endfor
  unlet t tl
endfunc

" Check that using a pattern on two lines doesn't get messed up by using
" matchstr() with \ze in between.
func Test_matchstr_with_ze()
  new
  call append(0, ['Substitute here:', '<T="">Ta 5</Title>',
        \ '<T="">Ac 7</Title>'])
  call cursor(1, 1)
  set re=0

  .+1,.+2s/""/\='"' . matchstr(getline("."), '\d\+\ze<') . '"'
  call assert_equal(['Substitute here:', '<T="5">Ta 5</Title>',
        \ '<T="7">Ac 7</Title>', ''], getline(1, '$'))

  bwipe!
endfunc

" Check a pattern with a look beind crossing a line boundary
func Test_lookbehind_across_line()
  new
  call append(0, ['Behind:', 'asdfasd<yyy', 'xxstart1', 'asdfasd<yy',
        \ 'xxxstart2', 'asdfasd<yy', 'xxstart3'])
  call cursor(1, 1)
  call search('\(<\_[xy]\+\)\@3<=start')
  call assert_equal([0, 7, 3, 0], getpos('.'))
  bwipe!
endfunc

" Check matching Visual area
func Test_matching_visual_area()
  new
  call append(0, ['Visual:', 'thexe the thexethe', 'andaxand andaxand',
        \ 'oooxofor foroxooo', 'oooxofor foroxooo'])
  call cursor(1, 1)
  exe "normal jfxvfx:s/\\%Ve/E/g\<CR>"
  exe "normal jV:s/\\%Va/A/g\<CR>"
  exe "normal jfx\<C-V>fxj:s/\\%Vo/O/g\<CR>"
  call assert_equal(['Visual:', 'thexE thE thExethe', 'AndAxAnd AndAxAnd',
        \ 'oooxOfOr fOrOxooo', 'oooxOfOr fOrOxooo', ''], getline(1, '$'))
  bwipe!
endfunc

" Check matching marks
func Test_matching_marks()
  new
  call append(0, ['', '', '', 'Marks:', 'asdfSasdfsadfEasdf', 'asdfSas',
        \ 'dfsadfEasdf', '', '', '', '', ''])
  call cursor(4, 1)
  exe "normal jfSmsfEme:.-4,.+6s/.\\%>'s.*\\%<'e../here/\<CR>"
  exe "normal jfSmsj0fEme:.-4,.+6s/.\\%>'s\\_.*\\%<'e../again/\<CR>"
  call assert_equal(['', '', '', 'Marks:', 'asdfhereasdf', 'asdfagainasdf',
        \ '', '', '', '', '', ''], getline(1, '$'))
  bwipe!
endfunc

" Check patterns matching cursor position.
func s:curpos_test()
  new
  call setline(1, ['ffooooo', 'boboooo', 'zoooooo', 'koooooo', 'moooooo',
        \ "\t\t\tfoo", 'abababababababfoo', 'bababababababafoo', '********_',
        \ '        xxxxxxxxxxxx    xxxx xxxxxx xxxxxxx x xxxxxxxxx xx xxxxxx xxxxxx xxxxx xxxxxxx xx xxxx xxxxxxxx xxxx xxxxxxxxxxx xxx xxxxxxx xxxxxxxxx xx xxxxxx xx xxxxxxx xxxxxxxxxxxxxxxx xxxxxxxxx  xxx xxxxxxxx xxxxxxxxx xxxx xxx xxxx xxx xxx xxxxx xxxxxxxxxxxx xxxx xxxxxxxxx xxxxxxxxxxx xx xxxxx xxx xxxxxxxx xxxxxx xxx xxx xxxxxxxxx xxxxxxx x xxxxxxxxx xx xxxxxx xxxxxxx  xxxxxxxxxxxxxxxxxx xxxxxxx xxxxxxx xxx xxx xxxxxxxx xxxxxxx  xxxx xxx xxxxxx xxxxx xxxxx xx xxxxxx xxxxxxx xxx xxxxxxxxxxxx xxxx xxxxxxxxx xxxxxx xxxxxx xxxxx xxx xxxxxxx xxxxxxxxxxxxxxxx xxxxxxxxx  xxxxxxxxxx xxxx xx xxxxxxxx xxx xxxxxxxxxxx xxxxx'])
  call setpos('.', [0, 1, 0, 0])
  s/\%>3c.//g
  call setpos('.', [0, 2, 4, 0])
  s/\%#.*$//g
  call setpos('.', [0, 3, 0, 0])
  s/\%<3c./_/g
  %s/\%4l\%>5c./_/g
  %s/\%6l\%>25v./_/g
  %s/\%>6l\%3c./!/g
  %s/\%>7l\%12c./?/g
  %s/\%>7l\%<9l\%>5v\%<8v./#/g
  $s/\%(|\u.*\)\@<=[^|\t]\+$//ge
  call assert_equal(['ffo', 'bob', '__ooooo', 'koooo__', 'moooooo',
        \ '			f__', 'ab!babababababfoo',
        \ 'ba!ab##abab?bafoo', '**!*****_',
        \ '  !     xxx?xxxxxxxx    xxxx xxxxxx xxxxxxx x xxxxxxxxx xx xxxxxx xxxxxx xxxxx xxxxxxx xx xxxx xxxxxxxx xxxx xxxxxxxxxxx xxx xxxxxxx xxxxxxxxx xx xxxxxx xx xxxxxxx xxxxxxxxxxxxxxxx xxxxxxxxx  xxx xxxxxxxx xxxxxxxxx xxxx xxx xxxx xxx xxx xxxxx xxxxxxxxxxxx xxxx xxxxxxxxx xxxxxxxxxxx xx xxxxx xxx xxxxxxxx xxxxxx xxx xxx xxxxxxxxx xxxxxxx x xxxxxxxxx xx xxxxxx xxxxxxx  xxxxxxxxxxxxxxxxxx xxxxxxx xxxxxxx xxx xxx xxxxxxxx xxxxxxx  xxxx xxx xxxxxx xxxxx xxxxx xx xxxxxx xxxxxxx xxx xxxxxxxxxxxx xxxx xxxxxxxxx xxxxxx xxxxxx xxxxx xxx xxxxxxx xxxxxxxxxxxxxxxx xxxxxxxxx  xxxxxxxxxx xxxx xx xxxxxxxx xxx xxxxxxxxxxx xxxxx'],
        \ getline(1, '$'))
  bwipe!
endfunc

func Test_matching_curpos()
  set re=0
  call s:curpos_test()
  set re=1
  call s:curpos_test()
  set re=2
  call s:curpos_test()
  set re&
endfunc

" Test for matching the start and end of a buffer
func Test_start_end_of_buffer_match()
  new
  call setline(1, repeat(['vim edit'], 20))
  /\%^
  call assert_equal([0, 1, 1, 0], getpos('.'))
  exe "normal 50%/\\%^..\<CR>"
  call assert_equal([0, 1, 1, 0], getpos('.'))
  exe "normal 50%/\\%$\<CR>"
  call assert_equal([0, 20, 8, 0], getpos('.'))
  exe "normal 6gg/..\\%$\<CR>"
  call assert_equal([0, 20, 7, 0], getpos('.'))
  bwipe!
endfunc

func Test_ze_before_zs()
  call assert_equal('', matchstr(' ', '\%#=1\ze \zs'))
  call assert_equal('', matchstr(' ', '\%#=2\ze \zs'))
  call assert_equal(repeat([''], 10), matchlist(' ', '\%#=1\ze \zs'))
  call assert_equal(repeat([''], 10), matchlist(' ', '\%#=2\ze \zs'))
endfunc

" Check for detecting error
func Test_regexp_error()
  set regexpengine=2
  call assert_fails("call matchlist('x x', ' \\ze*')", 'E888:')
  call assert_fails("call matchlist('x x', ' \\zs*')", 'E888:')
  set re&
endfunc

" vim: shiftwidth=2 sts=2 expandtab
