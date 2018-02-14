" Tests for regexp in latin1 encoding
set encoding=latin1
scriptencoding latin1

func s:equivalence_test()
  let str = "A������ B C D E���� F G H I���� J K L M N� O������ P Q R S T U���� V W X Y� Z a������ b c d e���� f g h i���� j k l m n� o������ p q r s t u���� v w x y�� z"
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
