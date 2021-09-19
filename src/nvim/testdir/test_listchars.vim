" Tests for 'listchars' display with 'list' and :list

source view_util.vim

func Test_listchars()
  enew!
  set ff=unix
  set list

  set listchars+=tab:>-,space:.,trail:<
  call append(0, [
	      \ '	aa	',
	      \ '  bb	  ',
	      \ '   cccc	 ',
	      \ 'dd        ee  	',
	      \ ' '
	      \ ])
  let expected = [
	      \ '>-------aa>-----$',
	      \ '..bb>---<<$',
	      \ '...cccc><$',
	      \ 'dd........ee<<>-$',
	      \ '<$'
	      \ ]
  redraw!
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, virtcol('$')))
  endfor

  set listchars-=trail:<
  let expected = [
	      \ '>-------aa>-----$',
	      \ '..bb>---..$',
	      \ '...cccc>.$',
	      \ 'dd........ee..>-$',
	      \ '.$'
	      \ ]
  redraw!
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, virtcol('$')))
  endfor

  " tab with 3rd character.
  set listchars-=tab:>-
  set listchars+=tab:<=>,trail:-
  let expected = [
	      \ '<======>aa<====>$',
	      \ '..bb<==>--$',
	      \ '...cccc>-$',
	      \ 'dd........ee--<>$',
	      \ '-$'
	      \ ]
  redraw!
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, virtcol('$')))
  endfor

  " tab with 3rd character and linebreak set
  set listchars-=tab:<=>
  set listchars+=tab:<·>
  set linebreak
  let expected = [
	      \ '<······>aa<····>$',
	      \ '..bb<··>--$',
	      \ '...cccc>-$',
	      \ 'dd........ee--<>$',
	      \ '-$'
	      \ ]
  redraw!
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, virtcol('$')))
  endfor
  set nolinebreak
  set listchars-=tab:<·>
  set listchars+=tab:<=>

  set listchars-=trail:-
  let expected = [
	      \ '<======>aa<====>$',
	      \ '..bb<==>..$',
	      \ '...cccc>.$',
	      \ 'dd........ee..<>$',
	      \ '.$'
	      \ ]
  redraw!
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, virtcol('$')))
  endfor

  set listchars-=tab:<=>
  set listchars+=tab:>-
  set listchars+=trail:<
  set nolist
  normal ggdG
  call append(0, [
	      \ '  fff	  ',
	      \ '	gg	',
	      \ '     h	',
	      \ 'iii    	  ',
	      \ ])
  let l = split(execute("%list"), "\n")
  call assert_equal([
	      \ '..fff>--<<$',
	      \ '>-------gg>-----$',
	      \ '.....h>-$',
	      \ 'iii<<<<><<$', '$'], l)

  " Test lead and trail
  normal ggdG
  set listchars=eol:$
  set listchars+=lead:>,trail:<,space:x
  set list

  call append(0, [
	      \ '    ffff    ',
	      \ '          gg',
	      \ 'h           ',
	      \ '            ',
	      \ '    0  0    ',
	      \ ])

  let expected = [
	      \ '>>>>ffff<<<<$',
	      \ '>>>>>>>>>>gg$',
	      \ 'h<<<<<<<<<<<$',
	      \ '<<<<<<<<<<<<$',
	      \ '>>>>0xx0<<<<$',
              \ '$'
	      \ ]
  redraw!
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, virtcol('$')))
  endfor

  call assert_equal(expected, split(execute("%list"), "\n"))

  " Test multispace
  normal ggdG
  set listchars=eol:$
  set listchars+=multispace:yYzZ
  set list

  call append(0, [
	      \ '    ffff    ',
	      \ '  i i     gg',
	      \ ' h          ',
	      \ '          j ',
	      \ '    0  0    ',
	      \ ])

  let expected = [
	      \ 'yYzZffffyYzZ$',
	      \ 'yYi iyYzZygg$',
	      \ ' hyYzZyYzZyY$',
	      \ 'yYzZyYzZyYj $',
	      \ 'yYzZ0yY0yYzZ$',
              \ '$'
	      \ ]
  redraw!
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, virtcol('$')))
  endfor

  call assert_equal(expected, split(execute("%list"), "\n"))

  " the last occurrence of 'multispace:' is used
  set listchars+=space:x,multispace:XyY

  let expected = [
	      \ 'XyYXffffXyYX$',
	      \ 'XyixiXyYXygg$',
	      \ 'xhXyYXyYXyYX$',
	      \ 'XyYXyYXyYXjx$',
	      \ 'XyYX0Xy0XyYX$',
              \ '$'
	      \ ]
  redraw!
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, virtcol('$')))
  endfor

  call assert_equal(expected, split(execute("%list"), "\n"))

  set listchars+=lead:>,trail:<

  let expected = [
	      \ '>>>>ffff<<<<$',
	      \ '>>ixiXyYXygg$',
	      \ '>h<<<<<<<<<<$',
	      \ '>>>>>>>>>>j<$',
	      \ '>>>>0Xy0<<<<$',
              \ '$'
	      \ ]
  redraw!
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, virtcol('$')))
  endfor

  call assert_equal(expected, split(execute("%list"), "\n"))

  " removing 'multispace:'
  set listchars-=multispace:XyY
  set listchars-=multispace:yYzZ

  let expected = [
	      \ '>>>>ffff<<<<$',
	      \ '>>ixixxxxxgg$',
	      \ '>h<<<<<<<<<<$',
	      \ '>>>>>>>>>>j<$',
	      \ '>>>>0xx0<<<<$',
              \ '$'
	      \ ]
  redraw!
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, virtcol('$')))
  endfor

  call assert_equal(expected, split(execute("%list"), "\n"))

  " test nbsp
  normal ggdG
  set listchars=nbsp:X,trail:Y
  set list
  " Non-breaking space
  let nbsp = nr2char(0xa0)
  call append(0, [ ">" .. nbsp .. "<" ])

  let expected = '>X< '

  redraw!
  call cursor(1, 1)
  call assert_equal([expected], ScreenLines(1, virtcol('$')))

  set listchars=nbsp:X
  redraw!
  call cursor(1, 1)
  call assert_equal([expected], ScreenLines(1, virtcol('$')))

  " test extends
  normal ggdG
  set listchars=extends:Z
  set nowrap
  set nolist
  call append(0, [ repeat('A', &columns + 1) ])

  let expected = repeat('A', &columns)

  redraw!
  call cursor(1, 1)
  call assert_equal([expected], ScreenLines(1, &columns))

  set list
  let expected = expected[:-2] . 'Z'
  redraw!
  call cursor(1, 1)
  call assert_equal([expected], ScreenLines(1, &columns))

  enew!
  set listchars& ff&
endfunc

" Test that unicode listchars characters get properly inserted
func Test_listchars_unicode()
  enew!
  let oldencoding=&encoding
  set encoding=utf-8
  set ff=unix

  set listchars=eol:⇔,space:␣,multispace:≡≢≣,nbsp:≠,tab:←↔→
  set list

  let nbsp = nr2char(0xa0)
  call append(0, ["        a\tb c" .. nbsp .. "d  "])
  let expected = ['≡≢≣≡≢≣≡≢a←↔↔↔↔↔→b␣c≠d≡≢⇔']
  redraw!
  call cursor(1, 1)
  call assert_equal(expected, ScreenLines(1, virtcol('$')))

  set listchars+=lead:⇨,trail:⇦
  let expected = ['⇨⇨⇨⇨⇨⇨⇨⇨a←↔↔↔↔↔→b␣c≠d⇦⇦⇔']
  redraw!
  call cursor(1, 1)
  call assert_equal(expected, ScreenLines(1, virtcol('$')))

  let &encoding=oldencoding
  enew!
  set listchars& ff&
endfunction

func Test_listchars_invalid()
  enew!
  set ff=unix

  set listchars=eol:$
  set list
  set ambiwidth=double

  " No colon
  call assert_fails('set listchars=x', 'E474:')
  call assert_fails('set listchars=x', 'E474:')
  call assert_fails('set listchars=multispace', 'E474:')

  " Too short
  call assert_fails('set listchars=space:', 'E474:')
  call assert_fails('set listchars=tab:x', 'E474:')
  call assert_fails('set listchars=multispace:', 'E474:')

  " One occurrence too short
  call assert_fails('set listchars=space:,space:x', 'E474:')
  call assert_fails('set listchars=space:x,space:', 'E474:')
  call assert_fails('set listchars=tab:x,tab:xx', 'E474:')
  call assert_fails('set listchars=tab:xx,tab:x', 'E474:')
  call assert_fails('set listchars=multispace:,multispace:x', 'E474:')
  call assert_fails('set listchars=multispace:x,multispace:', 'E474:')

  " Too long
  call assert_fails('set listchars=space:xx', 'E474:')
  call assert_fails('set listchars=tab:xxxx', 'E474:')

  " Has non-single width character
  call assert_fails('set listchars=space:·', 'E474:')
  call assert_fails('set listchars=tab:·x', 'E474:')
  call assert_fails('set listchars=tab:x·', 'E474:')
  call assert_fails('set listchars=tab:xx·', 'E474:')
  call assert_fails('set listchars=multispace:·', 'E474:')
  call assert_fails('set listchars=multispace:xxx·', 'E474:')

  enew!
  set ambiwidth& listchars& ff&
endfunction

" Tests that space characters following composing character won't get replaced
" by listchars.
func Test_listchars_composing()
  enew!
  let oldencoding=&encoding
  set encoding=utf-8
  set ff=unix
  set list

  set listchars=eol:$,space:_,nbsp:=
  
  let nbsp1 = nr2char(0xa0)
  let nbsp2 = nr2char(0x202f)
  call append(0, [
        \ "  \u3099\t \u309A" .. nbsp1 .. nbsp1 .. "\u0302" .. nbsp2 .. nbsp2 .. "\u0302",
        \ ])
  let expected = [
        \ "_ \u3099^I \u309A=" .. nbsp1 .. "\u0302=" .. nbsp2 .. "\u0302$"
        \ ]
  redraw!
  call cursor(1, 1)
  call assert_equal(expected, ScreenLines(1, virtcol('$')))
  let &encoding=oldencoding
  enew!
  set listchars& ff&
endfunction
