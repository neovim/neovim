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
