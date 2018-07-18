" Test the :source! command
if !has('multi_byte')
  finish
endif

func Test_source_utf8()
  " check that sourcing a script with 0x80 as second byte works
  new
  call setline(1, [':%s/àx/--à1234--/g', ':%s/Àx/--À1234--/g'])
  write! Xscript
  bwipe!
  new
  call setline(1, [' àx ', ' Àx '])
  source! Xscript | echo
  call assert_equal(' --à1234-- ', getline(1))
  call assert_equal(' --À1234-- ', getline(2))
  bwipe!
  call delete('Xscript')
endfunc

func Test_source_latin()
  " check that sourcing a latin1 script with a 0xc0 byte works
  new
  call setline(1, ["call feedkeys('r')", "call feedkeys('\xc0', 'xt')"])
  write! Xscript
  bwipe!
  new
  call setline(1, ['xxx'])
  source Xscript
  call assert_equal("\u00c0xx", getline(1))
  bwipe!
  call delete('Xscript')
endfunc

" Test for sourcing a file with CTRL-V's at the end of the line
func Test_source_ctrl_v()
    call writefile(['map __1 afirst',
		\ 'map __2 asecond',
		\ 'map __3 athird',
		\ 'map __4 afourth',
		\ 'map __5 afifth',
		\ "map __1 asd\<C-V>",
		\ "map __2 asd\<C-V>\<C-V>",
		\ "map __3 asd\<C-V>\<C-V>",
		\ "map __4 asd\<C-V>\<C-V>\<C-V>",
		\ "map __5 asd\<C-V>\<C-V>\<C-V>",
		\ ], 'Xtestfile')
  source Xtestfile
  enew!
  exe "normal __1\<Esc>\<Esc>__2\<Esc>__3\<Esc>\<Esc>__4\<Esc>__5\<Esc>"
  exe "%s/\<C-J>/0/g"
  call assert_equal(['sd',
	      \ "map __2 asd\<Esc>secondsd\<Esc>sd0map __5 asd0fifth"],
	      \ getline(1, 2))

  enew!
  call delete('Xtestfile')
  unmap __1
  unmap __2
  unmap __3
  unmap __4
  unmap __5
endfunc
