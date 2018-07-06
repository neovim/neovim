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

" Tests for tag search with !_TAG_FILE_ENCODING.
" Depends on the test83-tags2 and test83-tags3 files.
func Test_tag_file_encoding()
  throw 'skipped: Nvim removed test83-tags2, test83-tags3'
  if has('vms')
    return
  endif

  if !has('iconv') || iconv("\x82\x60", "cp932", "utf-8") != "\uff21"
    return
  endif

  let save_enc = &encoding
  set encoding=utf8

  let content = ['text for tags1', 'abcdefghijklmnopqrs']
  call writefile(content, 'Xtags1.txt')
  let content = ['text for tags2', 'ＡＢＣ']
  call writefile(content, 'Xtags2.txt')
  let content = ['text for tags3', 'ＡＢＣ']
  call writefile(content, 'Xtags3.txt')
  let content = ['!_TAG_FILE_ENCODING	utf-8	//', 'abcdefghijklmnopqrs	Xtags1.txt	/abcdefghijklmnopqrs']
  call writefile(content, 'Xtags1')

  " case1:
  new
  set tags=Xtags1
  tag abcdefghijklmnopqrs
  call assert_equal('Xtags1.txt', expand('%:t'))
  call assert_equal('abcdefghijklmnopqrs', getline('.'))
  close

  " case2:
  new
  set tags=test83-tags2
  tag /.ＢＣ
  call assert_equal('Xtags2.txt', expand('%:t'))
  call assert_equal('ＡＢＣ', getline('.'))
  close

  " case3:
  new
  set tags=test83-tags3
  tag abc50
  call assert_equal('Xtags3.txt', expand('%:t'))
  call assert_equal('ＡＢＣ', getline('.'))
  close

  set tags&
  let &encoding = save_enc
  call delete('Xtags1.txt')
  call delete('Xtags2.txt')
  call delete('Xtags3.txt')
  call delete('Xtags1')
endfunc

func Test_tagjump_etags()
  if !has('emacs_tags')
    return
  endif
  call writefile([
        \ "void foo() {}",
        \ "int main(int argc, char **argv)",
        \ "{",
        \ "\tfoo();",
        \ "\treturn 0;",
        \ "}",
        \ ], 'Xmain.c')

  call writefile([
	\ "\x0c",
        \ "Xmain.c,64",
        \ "void foo() {}\x7ffoo\x011,0",
        \ "int main(int argc, char **argv)\x7fmain\x012,14",
	\ ], 'Xtags')
  set tags=Xtags
  ta foo
  call assert_equal('void foo() {}', getline('.'))

  call delete('Xtags')
  call delete('Xmain.c')
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
