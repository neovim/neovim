
" This is a test if a URL is recognized by "gf", with the cursor before and
" after the "://".  Also test ":\\".
func Test_gf_url()
  enew!
  call append(0, [
      \ "first test for URL://machine.name/tmp/vimtest2a and other text",
      \ "second test for URL://machine.name/tmp/vimtest2b. And other text",
      \ "third test for URL:\\\\machine.name\\vimtest2c and other text",
      \ "fourth test for URL:\\\\machine.name\\tmp\\vimtest2d, and other text"
      \ ])
  call cursor(1,1)
  call search("^first")
  call search("tmp")
  call assert_equal("URL://machine.name/tmp/vimtest2a", expand("<cfile>"))
  call search("^second")
  call search("URL")
  call assert_equal("URL://machine.name/tmp/vimtest2b", expand("<cfile>"))
  if has("ebcdic")
      set isf=@,240-249,/,.,-,_,+,,,$,:,~,\
  else
      set isf=@,48-57,/,.,-,_,+,,,$,:,~,\
  endif
  call search("^third")
  call search("name")
  call assert_equal("URL:\\\\machine.name\\vimtest2c", expand("<cfile>"))
  call search("^fourth")
  call search("URL")
  call assert_equal("URL:\\\\machine.name\\tmp\\vimtest2d", expand("<cfile>"))

  set isf&vim
  enew!
endfunc

func Test_gF()
  new
  call setline(1, ['111', '222', '333', '444'])
  w! Xfile
  close
  new
  set isfname-=:
  call setline(1, ['one', 'Xfile:3', 'three'])
  2
  call assert_fails('normal gF', 'E37:')
  call assert_equal(2, getcurpos()[1])
  w! Xfile2
  normal gF
  call assert_equal('Xfile', bufname('%'))
  call assert_equal(3, getcurpos()[1])

  set isfname&
  call delete('Xfile')
  call delete('Xfile2')
  bwipe Xfile
  bwipe Xfile2
endfunc
