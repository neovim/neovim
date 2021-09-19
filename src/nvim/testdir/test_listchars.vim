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

  " test nbsp
  normal ggdG
  set listchars=nbsp:X,trail:Y
  set list
  " Non-breaking space
  let nbsp = nr2char(0xa0)
  call append(0, [ ">".nbsp."<" ])

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

func Test_listchars_composing()
  enew!
  let oldencoding=&encoding
  set encoding=utf-8
  set ff=unix
  set list

  set listchars=eol:$,space:_
  call append(0, [
        \ "  \u3099	 \u309A"
        \ ])
  let expected = [
        \ "_ \u3099^I \u309A$"
        \ ]
  redraw!
  call cursor(1, 1)
  let got = ScreenLinesUtf8(1, virtcol('$'))
  bw!
  call assert_equal(expected, got)
  let &encoding=oldencoding
  set listchars& ff&
endfunction
