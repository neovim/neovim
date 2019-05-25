" Tests for regexp in latin1 encoding
set encoding=latin1
scriptencoding latin1

func s:equivalence_test()
  let str = "AÀÁÂÃÄÅ B C D EÈÉÊË F G H IÌÍÎÏ J K L M NÑ OÒÓÔÕÖØ P Q R S T UÙÚÛÜ V W X Yİ Z aàáâãäå b c d eèéêë f g h iìíîï j k l m nñ oòóôõöø p q r s t uùúûü v w x yıÿ z"
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
  set re=1
  call s:equivalence_test()
endfunc

func Test_equivalence_re2()
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
