" Tests for tagjump (tags and special searches)

" SEGV occurs in older versions.  (At least 7.4.1748 or older)
func Test_ptag_with_notagstack()
  set notagstack
  call assert_fails('ptag does_not_exist_tag_name', 'E426')
  set tagstack&vim
endfunc

func Test_cancel_ptjump()
  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "word\tfile1\tcmd1",
        \ "word\tfile2\tcmd2"],
        \ 'Xtags')

  only!
  call feedkeys(":ptjump word\<CR>\<CR>", "xt")
  help
  call assert_equal(2, winnr('$'))

  call delete('Xtags')
  quit
endfunc

func Test_static_tagjump()
  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile1\t/^one/;\"\tf\tfile:\tsignature:(void)",
        \ "word\tXfile2\tcmd2"],
        \ 'Xtags')
  new Xfile1
  call setline(1, ['empty', 'one()', 'empty'])
  write
  tag one
  call assert_equal(2, line('.'))

  bwipe!
  set tags&
  call delete('Xtags')
  call delete('Xfile1')
endfunc

func Test_duplicate_tagjump()
  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "thesame\tXfile1\t1;\"\td\tfile:",
        \ "thesame\tXfile1\t2;\"\td\tfile:",
        \ "thesame\tXfile1\t3;\"\td\tfile:",
        \ ],
        \ 'Xtags')
  new Xfile1
  call setline(1, ['thesame one', 'thesame two', 'thesame three'])
  write
  tag thesame
  call assert_equal(1, line('.'))
  tnext
  call assert_equal(2, line('.'))
  tnext
  call assert_equal(3, line('.'))

  bwipe!
  set tags&
  call delete('Xtags')
  call delete('Xfile1')
endfunc

func Test_tagjump_switchbuf()
  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "second\tXfile1\t2",
        \ "third\tXfile1\t3",],
        \ 'Xtags')
  call writefile(['first', 'second', 'third'], 'Xfile1')

  enew | only
  set switchbuf=
  stag second
  call assert_equal(2, winnr('$'))
  call assert_equal(2, line('.'))
  stag third
  call assert_equal(3, winnr('$'))
  call assert_equal(3, line('.'))

  enew | only
  set switchbuf=useopen
  stag second
  call assert_equal(2, winnr('$'))
  call assert_equal(2, line('.'))
  stag third
  call assert_equal(2, winnr('$'))
  call assert_equal(3, line('.'))

  enew | only
  set switchbuf=usetab
  tab stag second
  call assert_equal(2, tabpagenr('$'))
  call assert_equal(2, line('.'))
  1tabnext | stag third
  call assert_equal(2, tabpagenr('$'))
  call assert_equal(3, line('.'))

  tabclose!
  enew | only
  call delete('Xfile1')
  call delete('Xtags')
  set switchbuf&vim
endfunc

" Tests for [ CTRL-I and CTRL-W CTRL-I commands
function Test_keyword_jump()
  call writefile(["#include Xinclude", "",
	      \ "",
	      \ "/* test text test tex start here",
	      \ "		some text",
	      \ "		test text",
	      \ "		start OK if found this line",
	      \ "	start found wrong line",
	      \ "test text"], 'Xtestfile')
  call writefile(["/* test text test tex start here",
	      \ "		some text",
	      \ "		test text",
	      \ "		start OK if found this line",
	      \ "	start found wrong line",
	      \ "test text"], 'Xinclude')
  new Xtestfile
  call cursor(1,1)
  call search("start")
  exe "normal! 5[\<C-I>"
  call assert_equal("		start OK if found this line", getline('.'))
  call cursor(1,1)
  call search("start")
  exe "normal! 5\<C-W>\<C-I>"
  call assert_equal("		start OK if found this line", getline('.'))
  enew! | only
  call delete('Xtestfile')
  call delete('Xinclude')
endfunction

" Test for jumping to a tag with 'hidden' set, with symbolic link in path of
" tag.  This only works for Unix, because of the symbolic link.
func Test_tag_symbolic()
  if !has('unix')
    return
  endif
  set hidden
  call delete("Xtest.dir", "rf")
  call system("ln -s . Xtest.dir")
  " Create a tags file with the current directory name inserted.
  call writefile([
        \ "SECTION_OFF	" . getcwd() . "/Xtest.dir/Xtest.c	/^#define  SECTION_OFF  3$/",
        \ '',
        \ ], 'Xtags')
  call writefile(['#define  SECTION_OFF  3',
        \ '#define  NUM_SECTIONS 3'], 'Xtest.c')

  " Try jumping to a tag, but with a path that contains a symbolic link.  When
  " wrong, this will give the ATTENTION message.  The next space will then be
  " eaten by hit-return, instead of moving the cursor to 'd'.
  set tags=Xtags
  enew!
  call append(0, 'SECTION_OFF')
  call cursor(1,1)
  exe "normal \<C-]> "
  call assert_equal('Xtest.c', expand('%:t'))
  call assert_equal(2, col('.'))

  set hidden&
  set tags&
  enew!
  call delete('Xtags')
  call delete('Xtest.c')
  call delete("Xtest.dir", "rf")
  %bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
