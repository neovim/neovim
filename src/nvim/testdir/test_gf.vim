
" This is a test if a URL is recognized by "gf", with the cursor before and
" after the "://".  Also test ":\\".
func Test_gf_url()
  enew!
  call append(0, [
      \ "first test for URL://machine.name/tmp/vimtest2a and other text",
      \ "second test for URL://machine.name/tmp/vimtest2b. And other text",
      \ "third test for URL:\\\\machine.name\\vimtest2c and other text",
      \ "fourth test for URL:\\\\machine.name\\tmp\\vimtest2d, and other text",
      \ "fifth test for URL://machine.name/tmp?q=vim&opt=yes and other text",
      \ "sixth test for URL://machine.name:1234?q=vim and other text",
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
      set isf=@,48-57,/,.,-,_,+,,,$,~,\
  endif
  call search("^third")
  call search("name")
  call assert_equal("URL:\\\\machine.name\\vimtest2c", expand("<cfile>"))
  call search("^fourth")
  call search("URL")
  call assert_equal("URL:\\\\machine.name\\tmp\\vimtest2d", expand("<cfile>"))

  call search("^fifth")
  call search("URL")
  call assert_equal("URL://machine.name/tmp?q=vim&opt=yes", expand("<cfile>"))

  call search("^sixth")
  call search("URL")
  call assert_equal("URL://machine.name:1234?q=vim", expand("<cfile>"))

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

" Test for invoking 'gf' on a ${VAR} variable
func Test_gf()
  if has("ebcdic")
    set isfname=@,240-249,/,.,-,_,+,,,$,:,~,{,}
  else
    set isfname=@,48-57,/,.,-,_,+,,,$,:,~,{,}
  endif

  call writefile(["Test for gf command"], "Xtest1")
  if has("unix")
    call writefile(["    ${CDIR}/Xtest1"], "Xtestgf")
  else
    call writefile(["    $TDIR/Xtest1"], "Xtestgf")
  endif
  new Xtestgf
  if has("unix")
    let $CDIR = "."
    /CDIR
  else
    if has("amiga")
      let $TDIR = "/testdir"
    else
      let $TDIR = "."
    endif
    /TDIR
  endif

  normal gf
  call assert_equal('Xtest1', fnamemodify(bufname(''), ":t"))
  close!

  call delete('Xtest1')
  call delete('Xtestgf')
endfunc

func Test_gf_visual()
  call writefile([], "Xtest_gf_visual")
  new
  call setline(1, 'XXXtest_gf_visualXXX')
  set hidden

  " Visually select Xtest_gf_visual and use gf to go to that file
  norm! ttvtXgf
  call assert_equal('Xtest_gf_visual', bufname('%'))

  bwipe!
  call delete('Xtest_gf_visual')
  set hidden&
endfunc

func Test_gf_error()
  new
  call assert_fails('normal gf', 'E446:')
  call assert_fails('normal gF', 'E446:')
  call setline(1, '/doesnotexist')
  call assert_fails('normal gf', 'E447:')
  call assert_fails('normal gF', 'E447:')
  bwipe!
endfunc
