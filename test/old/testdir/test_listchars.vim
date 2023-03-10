" Tests for 'listchars' display with 'list' and :list

source check.vim
source view_util.vim
source screendump.vim

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
    call assert_equal([expected[i - 1]], ScreenLines(i, '$'->virtcol()))
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
  set listchars=eol:$  " Accommodate Nvim default
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
  set listchars=eol:$  " Accommodate Nvim default
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

  " Test leadmultispace + multispace
  normal ggdG
  set listchars=eol:$,multispace:yYzZ,nbsp:S
  set listchars+=leadmultispace:.-+*
  set list

  call append(0, [
	      \ '    ffff    ',
	      \ '  i i     gg',
	      \ ' h          ',
	      \ '          j ',
	      \ '    0  0    ',
	      \ ])

  let expected = [
	      \ '.-+*ffffyYzZ$',
	      \ '.-i iSyYzZgg$',
	      \ ' hyYzZyYzZyY$',
	      \ '.-+*.-+*.-j $',
	      \ '.-+*0yY0yYzZ$',
        \ '$'
	      \ ]
  redraw!
  call assert_equal('eol:$,multispace:yYzZ,nbsp:S,leadmultispace:.-+*', &listchars)
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, virtcol('$')))
  endfor

  call assert_equal(expected, split(execute("%list"), "\n"))

  " Test leadmultispace without multispace
  normal ggdG
  set listchars-=multispace:yYzZ
  set listchars+=space:+,trail:>,eol:$
  set list

  call append(0, [
	      \ '    ffff    ',
	      \ '  i i     gg',
	      \ ' h          ',
	      \ '          j ',
	      \ '    0  0    ',
	      \ ])

  let expected = [
	      \ '.-+*ffff>>>>$',
	      \ '.-i+i+++++gg$',
	      \ '+h>>>>>>>>>>$',
	      \ '.-+*.-+*.-j>$',
	      \ '.-+*0++0>>>>$',
        \ '$',
	      \ ]

  redraw!
  call assert_equal('eol:$,nbsp:S,leadmultispace:.-+*,space:+,trail:>,eol:$', &listchars)
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, virtcol('$')))
  endfor

  call assert_equal(expected, split(execute("%list"), "\n"))

  " Test leadmultispace only
  normal ggdG
  set listchars=eol:$  " Accommodate Nvim default
  set listchars=leadmultispace:.-+*
  set list

  call append(0, [
	      \ '    ffff    ',
	      \ '  i i     gg',
	      \ ' h          ',
	      \ '          j ',
	      \ '    0  0    ',
	      \ ])

  let expected = [
	      \ '.-+*ffff    ',
	      \ '.-i i     gg',
	      \ ' h          ',
	      \ '.-+*.-+*.-j ',
	      \ '.-+*0  0    ',
        \ ' ',
	      \ ]
  redraw!
  call assert_equal('leadmultispace:.-+*', &listchars)
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, 12))
  endfor
  call assert_equal(expected, split(execute("%list"), "\n"))

  " Test leadmultispace and lead and space
  normal ggdG
  set listchars=eol:$  " Accommodate Nvim default
  set listchars+=lead:<,space:-
  set listchars+=leadmultispace:.-+*
  set list

  call append(0, [
	      \ '    ffff    ',
	      \ '  i i     gg',
	      \ ' h          ',
	      \ '          j ',
	      \ '    0  0    ',
	      \ ])

  let expected = [
	      \ '.-+*ffff----$',
	      \ '.-i-i-----gg$',
	      \ '<h----------$',
	      \ '.-+*.-+*.-j-$',
	      \ '.-+*0--0----$',
        \ '$',
	      \ ]
  redraw!
  call assert_equal('eol:$,lead:<,space:-,leadmultispace:.-+*', &listchars)
  for i in range(1, 5)
    call cursor(i, 1)
    call assert_equal([expected[i - 1]], ScreenLines(i, virtcol('$')))
  endfor
  call assert_equal(expected, split(execute("%list"), "\n"))

  " the last occurrence of 'multispace:' is used
  set listchars=eol:$  " Accommodate Nvim default
  set listchars+=multispace:yYzZ
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
  call assert_equal('eol:$,multispace:yYzZ,space:x,multispace:XyY', &listchars)
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

  set listchars=eol:\\u21d4,space:\\u2423,multispace:≡\\u2262\\U00002263,nbsp:\\U00002260,tab:←↔\\u2192
  redraw!
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

  set listchars=eol:$  " Accommodate Nvim default
  set list
  set ambiwidth=double

  " No colon
  call assert_fails('set listchars=x', 'E474:')
  call assert_fails('set listchars=x', 'E474:')
  call assert_fails('set listchars=multispace', 'E474:')
  call assert_fails('set listchars=leadmultispace', 'E474:')

  " Too short
  call assert_fails('set listchars=space:', 'E474:')
  call assert_fails('set listchars=tab:x', 'E474:')
  call assert_fails('set listchars=multispace:', 'E474:')
  call assert_fails('set listchars=leadmultispace:', 'E474:')

  " One occurrence too short
  call assert_fails('set listchars=space:,space:x', 'E474:')
  call assert_fails('set listchars=space:x,space:', 'E474:')
  call assert_fails('set listchars=tab:x,tab:xx', 'E474:')
  call assert_fails('set listchars=tab:xx,tab:x', 'E474:')
  call assert_fails('set listchars=multispace:,multispace:x', 'E474:')
  call assert_fails('set listchars=multispace:x,multispace:', 'E474:')
  call assert_fails('set listchars=leadmultispace:,leadmultispace:x', 'E474:')
  call assert_fails('set listchars=leadmultispace:x,leadmultispace:', 'E474:')

  " Too long
  call assert_fails('set listchars=space:xx', 'E474:')
  call assert_fails('set listchars=tab:xxxx', 'E474:')

  " Has double-width character
  call assert_fails('set listchars=space:·', 'E474:')
  call assert_fails('set listchars=tab:·x', 'E474:')
  call assert_fails('set listchars=tab:x·', 'E474:')
  call assert_fails('set listchars=tab:xx·', 'E474:')
  call assert_fails('set listchars=multispace:·', 'E474:')
  call assert_fails('set listchars=multispace:xxx·', 'E474:')
  call assert_fails('set listchars=leadmultispace:·', 'E474:')
  call assert_fails('set listchars=leadmultispace:xxx·', 'E474:')

  " Has control character
  call assert_fails("set listchars=space:\x01", 'E474:')
  call assert_fails("set listchars=tab:\x01x", 'E474:')
  call assert_fails("set listchars=tab:x\x01", 'E474:')
  call assert_fails("set listchars=tab:xx\x01", 'E474:')
  call assert_fails("set listchars=multispace:\x01", 'E474:')
  call assert_fails("set listchars=multispace:xxx\x01", 'E474:')
  call assert_fails('set listchars=space:\\x01', 'E474:')
  call assert_fails('set listchars=tab:\\x01x', 'E474:')
  call assert_fails('set listchars=tab:x\\x01', 'E474:')
  call assert_fails('set listchars=tab:xx\\x01', 'E474:')
  call assert_fails('set listchars=multispace:\\x01', 'E474:')
  call assert_fails('set listchars=multispace:xxx\\x01', 'E474:')
  call assert_fails("set listchars=leadmultispace:\x01", 'E474:')
  call assert_fails('set listchars=leadmultispace:\\x01', 'E474:')
  call assert_fails("set listchars=leadmultispace:xxx\x01", 'E474:')
  call assert_fails('set listchars=leadmultispace:xxx\\x01', 'E474:')

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

" Check for the value of the 'listchars' option
func s:CheckListCharsValue(expected)
  call assert_equal(a:expected, &listchars)
  call assert_equal(a:expected, getwinvar(0, '&listchars'))
endfunc

" Test for using a window local value for 'listchars'
func Test_listchars_window_local()
  %bw!
  set list listchars&
  let l:default_listchars = &listchars  " Accommodate Nvim default
  new
  " set a local value for 'listchars'
  setlocal listchars=tab:+-,eol:#
  call s:CheckListCharsValue('tab:+-,eol:#')
  " When local value is reset, global value should be used
  setlocal listchars=
  call s:CheckListCharsValue(l:default_listchars)  " Accommodate Nvim default
  " Use 'setlocal <' to copy global value
  setlocal listchars=space:.,extends:>
  setlocal listchars<
  call s:CheckListCharsValue(l:default_listchars)  " Accommodate Nvim default
  " Use 'set <' to copy global value
  setlocal listchars=space:.,extends:>
  set listchars<
  call s:CheckListCharsValue(l:default_listchars)  " Accommodate Nvim default
  " Changing global setting should not change the local setting
  setlocal listchars=space:.,extends:>
  setglobal listchars=tab:+-,eol:#
  call s:CheckListCharsValue('space:.,extends:>')
  " when split opening a new window, local value should be copied
  split
  call s:CheckListCharsValue('space:.,extends:>')
  " clearing local value in one window should not change the other window
  set listchars&
  call s:CheckListCharsValue(l:default_listchars)  " Accommodate Nvim default
  close
  call s:CheckListCharsValue('space:.,extends:>')

  " use different values for 'listchars' items in two different windows
  call setline(1, ["\t  one  two  "])
  setlocal listchars=tab:<->,lead:_,space:.,trail:@,eol:#
  split
  setlocal listchars=tab:[.],lead:#,space:_,trail:.,eol:&
  split
  set listchars=tab:+-+,lead:^,space:>,trail:<,eol:%
  call assert_equal(['+------+^^one>>two<<%'], ScreenLines(1, virtcol('$')))
  close
  call assert_equal(['[......]##one__two..&'], ScreenLines(1, virtcol('$')))
  close
  call assert_equal(['<------>__one..two@@#'], ScreenLines(1, virtcol('$')))
  " changing the global setting should not change the local value
  setglobal listchars=tab:[.],lead:#,space:_,trail:.,eol:&
  call assert_equal(['<------>__one..two@@#'], ScreenLines(1, virtcol('$')))
  set listchars<
  call assert_equal(['[......]##one__two..&'], ScreenLines(1, virtcol('$')))

  " Using setglobal in a window with local setting should not affect the
  " window. But should impact other windows using the global setting.
  enew! | only
  call setline(1, ["\t  one  two  "])
  set listchars=tab:[.],lead:#,space:_,trail:.,eol:&
  split
  setlocal listchars=tab:+-+,lead:^,space:>,trail:<,eol:%
  split
  setlocal listchars=tab:<->,lead:_,space:.,trail:@,eol:#
  setglobal listchars=tab:{.},lead:-,space:=,trail:#,eol:$
  call assert_equal(['<------>__one..two@@#'], ScreenLines(1, virtcol('$')))
  close
  call assert_equal(['+------+^^one>>two<<%'], ScreenLines(1, virtcol('$')))
  close
  call assert_equal(['{......}--one==two##$'], ScreenLines(1, virtcol('$')))

  " Setting the global setting to the default value should not impact a window
  " using a local setting.
  split
  setlocal listchars=tab:<->,lead:_,space:.,trail:@,eol:#
  setglobal listchars=eol:$  " Accommodate Nvim default
  call assert_equal(['<------>__one..two@@#'], ScreenLines(1, virtcol('$')))
  close
  call assert_equal(['^I  one  two  $'], ScreenLines(1, virtcol('$')))

  " Setting the local setting to the default value should not impact a window
  " using a global setting.
  set listchars=tab:{.},lead:-,space:=,trail:#,eol:$
  split
  setlocal listchars=tab:<->,lead:_,space:.,trail:@,eol:#
  call assert_equal(['<------>__one..two@@#'], ScreenLines(1, virtcol('$')))
  setlocal listchars=eol:$  " Accommodate Nvim default
  call assert_equal(['^I  one  two  $'], ScreenLines(1, virtcol('$')))
  close
  call assert_equal(['{......}--one==two##$'], ScreenLines(1, virtcol('$')))

  " Using set in a window with a local setting should change it to use the
  " global setting and also impact other windows using the global setting.
  split
  setlocal listchars=tab:<->,lead:_,space:.,trail:@,eol:#
  call assert_equal(['<------>__one..two@@#'], ScreenLines(1, virtcol('$')))
  set listchars=tab:+-+,lead:^,space:>,trail:<,eol:%
  call assert_equal(['+------+^^one>>two<<%'], ScreenLines(1, virtcol('$')))
  close
  call assert_equal(['+------+^^one>>two<<%'], ScreenLines(1, virtcol('$')))

  " Setting invalid value for a local setting should not impact the local and
  " global settings.
  split
  setlocal listchars=tab:<->,lead:_,space:.,trail:@,eol:#
  let cmd = 'setlocal listchars=tab:{.},lead:-,space:=,trail:#,eol:$,x'
  call assert_fails(cmd, 'E474:')
  call assert_equal(['<------>__one..two@@#'], ScreenLines(1, virtcol('$')))
  close
  call assert_equal(['+------+^^one>>two<<%'], ScreenLines(1, virtcol('$')))

  " Setting invalid value for a global setting should not impact the local and
  " global settings.
  split
  setlocal listchars=tab:<->,lead:_,space:.,trail:@,eol:#
  let cmd = 'setglobal listchars=tab:{.},lead:-,space:=,trail:#,eol:$,x'
  call assert_fails(cmd, 'E474:')
  call assert_equal(['<------>__one..two@@#'], ScreenLines(1, virtcol('$')))
  close
  call assert_equal(['+------+^^one>>two<<%'], ScreenLines(1, virtcol('$')))

  " Closing window with local lcs-multispace should not cause a memory leak.
  setlocal listchars=multispace:---+
  split
  call s:CheckListCharsValue('multispace:---+')
  close

  %bw!
  set list& listchars&
endfunc

func Test_listchars_foldcolumn()
  CheckScreendump

  let lines =<< trim END
      call setline(1, ['aaa', '', 'a', 'aaaaaa'])
      vsplit
      vsplit
      windo set signcolumn=yes foldcolumn=1 winminwidth=0 nowrap list listchars=extends:>,precedes:<
  END
  call writefile(lines, 'XTest_listchars')

  let buf = RunVimInTerminal('-S XTest_listchars', {'rows': 10, 'cols': 60})

  call term_sendkeys(buf, "13\<C-W>>")
  call VerifyScreenDump(buf, 'Test_listchars_01', {})
  call term_sendkeys(buf, "\<C-W>>")
  call VerifyScreenDump(buf, 'Test_listchars_02', {})
  call term_sendkeys(buf, "\<C-W>>")
  call VerifyScreenDump(buf, 'Test_listchars_03', {})
  call term_sendkeys(buf, "\<C-W>>")
  call VerifyScreenDump(buf, 'Test_listchars_04', {})
  call term_sendkeys(buf, "\<C-W>>")
  call VerifyScreenDump(buf, 'Test_listchars_05', {})
  call term_sendkeys(buf, "\<C-W>h")
  call term_sendkeys(buf, ":set nowrap foldcolumn=4\<CR>")
  call term_sendkeys(buf, "15\<C-W><")
  call VerifyScreenDump(buf, 'Test_listchars_06', {})
  call term_sendkeys(buf, "4\<C-W><")
  call VerifyScreenDump(buf, 'Test_listchars_07', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('XTest_listchars')
endfunc


" vim: shiftwidth=2 sts=2 expandtab
