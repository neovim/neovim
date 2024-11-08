" Tests for tagjump (tags and special searches)

source check.vim
source screendump.vim

" SEGV occurs in older versions.  (At least 7.4.1748 or older)
func Test_ptag_with_notagstack()
  CheckFeature quickfix

  set notagstack
  call assert_fails('ptag does_not_exist_tag_name', 'E433')
  set tagstack&vim
endfunc

func Test_ptjump()
  CheckFeature quickfix

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ 'Xtags')
  call writefile(['one', 'two', 'three'], 'Xfile')

  %bw!
  ptjump two
  call assert_equal(2, winnr())
  wincmd p
  call assert_equal(1, &previewwindow)
  call assert_equal('Xfile', expand("%:p:t"))
  call assert_equal(2, line('.'))
  call assert_equal(2, winnr('$'))
  call assert_equal(1, winnr())
  close
  call setline(1, ['one', 'two', 'three'])
  exe "normal 3G\<C-W>g}"
  call assert_equal(2, winnr())
  wincmd p
  call assert_equal(1, &previewwindow)
  call assert_equal('Xfile', expand("%:p:t"))
  call assert_equal(3, line('.'))
  call assert_equal(2, winnr('$'))
  call assert_equal(1, winnr())
  close
  exe "normal 3G5\<C-W>\<C-G>}"
  wincmd p
  call assert_equal(5, winheight(0))
  close

  call delete('Xtags')
  call delete('Xfile')
  set tags&
endfunc

func Test_cancel_ptjump()
  CheckFeature quickfix

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
  set tags&
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
  CheckFeature quickfix

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
  set tags&
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

  " invalid tag search pattern
  call assert_fails('tag /\%(/', 'E426:')

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

  set nohidden
  set tags&
  enew!
  call delete('Xtags')
  call delete('Xtest.c')
  call delete("Xtest.dir", "rf")
  %bwipe!
endfunc

" Tests for tag search with !_TAG_FILE_ENCODING.
func Test_tag_file_encoding()
  if has('vms')
    throw 'Skipped: does not work on VMS'
  endif

  if !has('iconv') || iconv("\x82\x60", "cp932", "utf-8") != "\uff21"
    throw 'Skipped: iconv does not work'
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
  let content = ['!_TAG_FILE_ENCODING	cp932	//',
        \ "\x82`\x82a\x82b	Xtags2.txt	/\x82`\x82a\x82b"]
  call writefile(content, 'Xtags')
  set tags=Xtags
  tag /.ＢＣ
  call assert_equal('Xtags2.txt', expand('%:t'))
  call assert_equal('ＡＢＣ', getline('.'))
  call delete('Xtags')
  close

  " case3:
  new
  let contents = [
      \ "!_TAG_FILE_SORTED	1	//",
      \ "!_TAG_FILE_ENCODING	cp932	//"]
  for i in range(1, 100)
      call add(contents, 'abc' .. i
            \ .. "	Xtags3.txt	/\x82`\x82a\x82b")
  endfor
  call writefile(contents, 'Xtags')
  set tags=Xtags
  tag abc50
  call assert_equal('Xtags3.txt', expand('%:t'))
  call assert_equal('ＡＢＣ', getline('.'))
  call delete('Xtags')
  close

  set tags&
  let &encoding = save_enc
  call delete('Xtags1.txt')
  call delete('Xtags2.txt')
  call delete('Xtags3.txt')
  call delete('Xtags1')
endfunc

" Test for emacs-style tags file (TAGS)
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

  " Test for including another tags file
  call writefile([
        \ "\x0c",
        \ "Xmain.c,64",
        \ "void foo() {}\x7ffoo\x011,0",
        \ "\x0c",
        \ "Xnonexisting,include",
        \ "\x0c",
        \ "Xtags2,include"
        \ ], 'Xtags')
  call writefile([
        \ "\x0c",
        \ "Xmain.c,64",
        \ "int main(int argc, char **argv)\x7fmain\x012,14",
        \ ], 'Xtags2')
  tag main
  call assert_equal(2, line('.'))
  call assert_fails('tag bar', 'E426:')

  " corrupted tag line
  call writefile([
        \ "\x0c",
        \ "Xmain.c,8",
        \ "int main"
        \ ], 'Xtags', 'b')
  call assert_fails('tag foo', 'E426:')

  " invalid line number
  call writefile([
	\ "\x0c",
        \ "Xmain.c,64",
        \ "void foo() {}\x7ffoo\x0abc,0",
	\ ], 'Xtags')
  call assert_fails('tag foo', 'E426:')

  " invalid tag name
  call writefile([
	\ "\x0c",
        \ "Xmain.c,64",
        \ ";;;;\x7f1,0",
	\ ], 'Xtags')
  call assert_fails('tag foo', 'E431:')

  " end of file after a CTRL-L line
  call writefile([
	\ "\x0c",
        \ "Xmain.c,64",
        \ "void foo() {}\x7ffoo\x011,0",
	\ "\x0c",
	\ ], 'Xtags')
  call assert_fails('tag main', 'E426:')

  " error in an included tags file
  call writefile([
        \ "\x0c",
        \ "Xtags2,include"
        \ ], 'Xtags')
  call writefile([
        \ "\x0c",
        \ "Xmain.c,64",
        \ "void foo() {}",
        \ ], 'Xtags2')
  call assert_fails('tag foo', 'E431:')

  call delete('Xtags')
  call delete('Xtags2')
  call delete('Xmain.c')
  set tags&
  bwipe!
endfunc

" Test for getting and modifying the tag stack
func Test_getsettagstack()
  call writefile(['line1', 'line2', 'line3'], 'Xfile1')
  call writefile(['line1', 'line2', 'line3'], 'Xfile2')
  call writefile(['line1', 'line2', 'line3'], 'Xfile3')

  enew | only
  call settagstack(1, {'items' : []})
  call assert_equal(0, gettagstack(1).length)
  call assert_equal([], 1->gettagstack().items)
  " Error cases
  call assert_equal({}, gettagstack(100))
  call assert_equal(-1, settagstack(100, {'items' : []}))
  call assert_fails('call settagstack(1, [1, 10])', 'E1206:')
  call assert_fails("call settagstack(1, {'items' : 10})", 'E714:')
  call assert_fails("call settagstack(1, {'items' : []}, 10)", 'E1174:')
  call assert_fails("call settagstack(1, {'items' : []}, 'b')", 'E962:')
  call assert_equal(-1, settagstack(0, v:_null_dict))

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile1\t1",
        \ "three\tXfile3\t3",
        \ "two\tXfile2\t2"],
        \ 'Xtags')

  let stk = []
  call add(stk, {'bufnr' : bufnr('%'), 'tagname' : 'one',
	\ 'from' : [bufnr('%'), line('.'), col('.'), 0], 'matchnr' : 1})
  tag one
  call add(stk, {'bufnr' : bufnr('%'), 'tagname' : 'two',
	\ 'from' : [bufnr('%'), line('.'), col('.'), 0], 'matchnr' : 1})
  tag two
  call add(stk, {'bufnr' : bufnr('%'), 'tagname' : 'three',
	\ 'from' : [bufnr('%'), line('.'), col('.'), 0], 'matchnr' : 1})
  tag three
  call assert_equal(3, gettagstack(1).length)
  call assert_equal(stk, gettagstack(1).items)
  " Check for default - current window
  call assert_equal(3, gettagstack().length)
  call assert_equal(stk, gettagstack().items)

  " Try to set current index to invalid values
  call settagstack(1, {'curidx' : -1})
  call assert_equal(1, gettagstack().curidx)
  eval {'curidx' : 50}->settagstack(1)
  call assert_equal(4, gettagstack().curidx)

  " Try pushing invalid items onto the stack
  call settagstack(1, {'items' : []})
  call settagstack(1, {'items' : ["plate"]}, 'a')
  call assert_equal(0, gettagstack().length)
  call assert_equal([], gettagstack().items)
  call settagstack(1, {'items' : [{"tagname" : "abc"}]}, 'a')
  call assert_equal(0, gettagstack().length)
  call assert_equal([], gettagstack().items)
  call settagstack(1, {'items' : [{"from" : 100}]}, 'a')
  call assert_equal(0, gettagstack().length)
  call assert_equal([], gettagstack().items)
  call settagstack(1, {'items' : [{"from" : [2, 1, 0, 0]}]}, 'a')
  call assert_equal(0, gettagstack().length)
  call assert_equal([], gettagstack().items)

  " Push one item at a time to the stack
  call settagstack(1, {'items' : []})
  call settagstack(1, {'items' : [stk[0]]}, 'a')
  call settagstack(1, {'items' : [stk[1]]}, 'a')
  call settagstack(1, {'items' : [stk[2]]}, 'a')
  call settagstack(1, {'curidx' : 4})
  call assert_equal({'length' : 3, 'curidx' : 4, 'items' : stk},
        \ gettagstack(1))

  " Try pushing items onto a full stack
  for i in range(7)
    call settagstack(1, {'items' : stk}, 'a')
  endfor
  call assert_equal(20, gettagstack().length)
  call settagstack(1,
        \ {'items' : [{'tagname' : 'abc', 'from' : [1, 10, 1, 0]}]}, 'a')
  call assert_equal('abc', gettagstack().items[19].tagname)

  " truncate the tag stack
  call settagstack(1,
        \ {'curidx' : 9,
        \  'items' : [{'tagname' : 'abc', 'from' : [1, 10, 1, 0]}]}, 't')
  let t = gettagstack()
  call assert_equal(9, t.length)
  call assert_equal(10, t.curidx)

  " truncate the tag stack without pushing any new items
  call settagstack(1, {'curidx' : 5}, 't')
  let t = gettagstack()
  call assert_equal(4, t.length)
  call assert_equal(5, t.curidx)

  " truncate an empty tag stack and push new items
  call settagstack(1, {'items' : []})
  call settagstack(1,
        \ {'items' : [{'tagname' : 'abc', 'from' : [1, 10, 1, 0]}]}, 't')
  let t = gettagstack()
  call assert_equal(1, t.length)
  call assert_equal(2, t.curidx)

  " Tag with multiple matches
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "two\tXfile1\t1",
        \ "two\tXfile2\t3",
        \ "two\tXfile3\t2"],
        \ 'Xtags')
  call settagstack(1, {'items' : []})
  tag two
  tnext
  tnext
  call assert_equal(1, gettagstack().length)
  call assert_equal(3, gettagstack().items[0].matchnr)

  call settagstack(1, {'items' : []})
  call delete('Xfile1')
  call delete('Xfile2')
  call delete('Xfile3')
  call delete('Xtags')
  set tags&
endfunc

func Test_tag_with_count()
  call writefile([
	\ 'test	Xtest.h	/^void test();$/;"	p	typeref:typename:void	signature:()',
	\ ], 'Xtags')
  call writefile([
	\ 'main	Xtest.c	/^int main()$/;"	f	typeref:typename:int	signature:()',
	\ 'test	Xtest.c	/^void test()$/;"	f	typeref:typename:void	signature:()',
	\ ], 'Ytags')
  cal writefile([
	\ 'int main()',
	\ 'void test()',
	\ ], 'Xtest.c')
  cal writefile([
	\ 'void test();',
	\ ], 'Xtest.h')
  set tags=Xtags,Ytags

  new Xtest.c
  let tl = taglist('test', 'Xtest.c')
  call assert_equal(tl[0].filename, 'Xtest.c')
  call assert_equal(tl[1].filename, 'Xtest.h')

  tag test
  call assert_equal(bufname('%'), 'Xtest.c')
  1tag test
  call assert_equal(bufname('%'), 'Xtest.c')
  2tag test
  call assert_equal(bufname('%'), 'Xtest.h')

  set tags&
  call delete('Xtags')
  call delete('Ytags')
  bwipe Xtest.h
  bwipe Xtest.c
  call delete('Xtest.h')
  call delete('Xtest.c')
endfunc

func Test_tagnr_recall()
  call writefile([
	\ 'test	Xtest.h	/^void test();$/;"	p',
	\ 'main	Xtest.c	/^int main()$/;"	f',
	\ 'test	Xtest.c	/^void test()$/;"	f',
	\ ], 'Xtags')
  cal writefile([
	\ 'int main()',
	\ 'void test()',
	\ ], 'Xtest.c')
  cal writefile([
	\ 'void test();',
	\ ], 'Xtest.h')
  set tags=Xtags

  new Xtest.c
  let tl = taglist('test', 'Xtest.c')
  call assert_equal(tl[0].filename, 'Xtest.c')
  call assert_equal(tl[1].filename, 'Xtest.h')

  2tag test
  call assert_equal(bufname('%'), 'Xtest.h')
  pop
  call assert_equal(bufname('%'), 'Xtest.c')
  tag
  call assert_equal(bufname('%'), 'Xtest.h')

  set tags&
  call delete('Xtags')
  bwipe Xtest.h
  bwipe Xtest.c
  call delete('Xtest.h')
  call delete('Xtest.c')
endfunc

func Test_tag_line_toolong()
  call writefile([
	\ '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678	django/contrib/admin/templates/admin/edit_inline/stacked.html	16;"	j	line:16	language:HTML'
	\ ], 'Xtags')
  set tags=Xtags
  let old_vbs = &verbose
  set verbose=5
  " ":tjump" should give "tag not found" not "Format error in tags file"
  call assert_fails('tj /foo', 'E426')
  try
    tj /foo
  catch /^Vim\%((\a\+)\)\=:E431/
    call assert_report(v:exception)
  catch /.*/
  endtry
  call assert_equal('Searching tags file Xtags', split(execute('messages'), '\n')[-1])

  call writefile([
	\ '123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567	django/contrib/admin/templates/admin/edit_inline/stacked.html	16;"	j	line:16	language:HTML'
	\ ], 'Xtags')
  call assert_fails('tj /foo', 'E426')
  try
    tj /foo
  catch /^Vim\%((\a\+)\)\=:E431/
    call assert_report(v:exception)
  catch /.*/
  endtry
  call assert_equal('Searching tags file Xtags', split(execute('messages'), '\n')[-1])

  " binary search works in file with long line
  call writefile([
        \ 'asdfasfd	nowhere	16',
	\ 'foobar	Xsomewhere	3; " 12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567',
        \ 'zasdfasfd	nowhere	16',
	\ ], 'Xtags')
  call writefile([
        \ 'one',
        \ 'two',
        \ 'trhee',
        \ 'four',
        \ ], 'Xsomewhere')
  tag foobar
  call assert_equal('Xsomewhere', expand('%'))
  call assert_equal(3, getcurpos()[1])

  " expansion on command line works with long lines when &wildoptions contains
  " 'tagfile'
  set wildoptions=tagfile
  call writefile([
	\ 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa	file	/^pattern$/;"	f'
	\ ], 'Xtags')
  call feedkeys(":tag \<Tab>", 'tx')
  " Should not crash
  call assert_true(v:true)

  call delete('Xtags')
  call delete('Xsomewhere')
  set tags&
  let &verbose = old_vbs
endfunc

" Check that using :tselect does not run into the hit-enter prompt.
" Requires a terminal to trigger that prompt.
func Test_tselect()
  CheckScreendump

  call writefile([
	\ 'main	Xtest.h	/^void test();$/;"	f',
	\ 'main	Xtest.c	/^int main()$/;"	f',
	\ 'main	Xtest.x	/^void test()$/;"	f',
	\ ], 'Xtags')
  cal writefile([
	\ 'int main()',
	\ 'void test()',
	\ ], 'Xtest.c')

  let lines =<< trim [SCRIPT]
    set tags=Xtags
  [SCRIPT]
  call writefile(lines, 'XTest_tselect')
  let buf = RunVimInTerminal('-S XTest_tselect', {'rows': 10, 'cols': 50})

  call TermWait(buf, 50)
  call term_sendkeys(buf, ":tselect main\<CR>2\<CR>")
  call VerifyScreenDump(buf, 'Test_tselect_1', {})

  call StopVimInTerminal(buf)
  call delete('Xtags')
  call delete('Xtest.c')
  call delete('XTest_tselect')
endfunc

func Test_tagline()
  call writefile([
	\ 'provision	Xtest.py	/^    def provision(self, **kwargs):$/;"	m	line:1	language:Python class:Foo',
	\ 'provision	Xtest.py	/^    def provision(self, **kwargs):$/;"	m	line:3	language:Python class:Bar',
	\], 'Xtags')
  call writefile([
	\ '    def provision(self, **kwargs):',
	\ '        pass',
	\ '    def provision(self, **kwargs):',
	\ '        pass',
	\], 'Xtest.py')

  set tags=Xtags

  1tag provision
  call assert_equal(line('.'), 1)
  2tag provision
  call assert_equal(line('.'), 3)

  call delete('Xtags')
  call delete('Xtest.py')
  set tags&
endfunc

" Test for expanding environment variable in a tag file name
func Test_tag_envvar()
  call writefile(["Func1\t$FOO\t/^Func1/"], 'Xtags')
  set tags=Xtags

  let $FOO='TagTestEnv'

  let caught_exception = v:false
  try
    tag Func1
  catch /E429:/
    call assert_match('E429:.*"TagTestEnv".*', v:exception)
    let caught_exception = v:true
  endtry
  call assert_true(caught_exception)

  set tags&
  call delete('Xtags')
  unlet $FOO
endfunc

" Test for :ptag
func Test_tag_preview()
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "second\tXfile1\t2",
        \ "third\tXfile1\t3",],
        \ 'Xtags')
  set tags=Xtags
  call writefile(['first', 'second', 'third'], 'Xfile1')

  enew | only
  ptag third
  call assert_equal(2, winnr())
  call assert_equal(2, winnr('$'))
  call assert_equal(1, getwinvar(1, '&previewwindow'))
  call assert_equal(0, getwinvar(2, '&previewwindow'))
  wincmd P
  call assert_equal(3, line('.'))

  " jump to the tag again
  wincmd w
  ptag third
  wincmd P
  call assert_equal(3, line('.'))

  " jump to the newer tag
  wincmd w
  ptag
  wincmd P
  call assert_equal(3, line('.'))

  " close the preview window
  pclose
  call assert_equal(1, winnr('$'))

  call delete('Xfile1')
  call delete('Xtags')
  set tags&
endfunc

" Tests for guessing the tag location
func Test_tag_guess()
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "func1\tXfoo\t/^int func1(int x)/",
        \ "func2\tXfoo\t/^int func2(int y)/",
        \ "func3\tXfoo\t/^func3/",
        \ "func4\tXfoo\t/^func4/"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]

    int FUNC1  (int x) { }
    int
    func2   (int y) { }
    int * func3 () { }

  [CODE]
  call writefile(code, 'Xfoo')

  let v:statusmsg = ''
  ta func1
  call assert_match('E435:', v:statusmsg)
  call assert_equal(2, line('.'))
  let v:statusmsg = ''
  ta func2
  call assert_match('E435:', v:statusmsg)
  call assert_equal(4, line('.'))
  let v:statusmsg = ''
  ta func3
  call assert_match('E435:', v:statusmsg)
  call assert_equal(5, line('.'))
  call assert_fails('ta func4', 'E434:')

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
endfunc

" Test for an unsorted tags file
func Test_tag_sort()
  let l = [
        \ "first\tXfoo\t1",
        \ "ten\tXfoo\t3",
        \ "six\tXfoo\t2"]
  call writefile(l, 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int six() {}
    int ten() {}
  [CODE]
  call writefile(code, 'Xfoo')

  call assert_fails('tag first', 'E432:')

  " When multiple tag files are not sorted, then message should be displayed
  " multiple times
  call writefile(l, 'Xtags2')
  set tags=Xtags,Xtags2
  call assert_fails('tag first', ['E432:', 'E432:'])

  call delete('Xtags')
  call delete('Xtags2')
  call delete('Xfoo')
  set tags&
  %bwipe
endfunc

" Test for an unsorted tags file
func Test_tag_fold()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "!_TAG_FILE_SORTED\t2\t/0=unsorted, 1=sorted, 2=foldcase/",
        \ "first\tXfoo\t1",
        \ "second\tXfoo\t2",
        \ "third\tXfoo\t3"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int second() {}
    int third() {}
  [CODE]
  call writefile(code, 'Xfoo')

  enew
  tag second
  call assert_equal('Xfoo', bufname(''))
  call assert_equal(2, line('.'))

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
  %bwipe
endfunc

" Test for the :ltag command
func Test_ltag()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "first\tXfoo\t1",
        \ "second\tXfoo\t/^int second() {}$/",
        \ "third\tXfoo\t3"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int second() {}
    int third() {}
  [CODE]
  call writefile(code, 'Xfoo')

  enew
  call setloclist(0, [], 'f')
  ltag third
  call assert_equal('Xfoo', bufname(''))
  call assert_equal(3, line('.'))
  call assert_equal([{'lnum': 3, 'end_lnum': 0, 'bufnr': bufnr('Xfoo'),
        \ 'col': 0, 'end_col': 0, 'pattern': '', 'valid': 1, 'vcol': 0,
        \ 'nr': 0, 'type': '', 'module': '', 'text': 'third'}], getloclist(0))

  ltag second
  call assert_equal(2, line('.'))
  call assert_equal([{'lnum': 0, 'end_lnum': 0, 'bufnr': bufnr('Xfoo'),
        \ 'col': 0, 'end_col': 0, 'pattern': '^\Vint second() {}\$',
        \ 'valid': 1, 'vcol': 0, 'nr': 0, 'type': '', 'module': '',
        \ 'text': 'second'}], getloclist(0))

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
  %bwipe
endfunc

" Test for setting the last search pattern to the tag search pattern
" when cpoptions has 't'
func Test_tag_last_search_pat()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "first\tXfoo\t/^int first() {}/",
        \ "second\tXfoo\t/^int second() {}/",
        \ "third\tXfoo\t/^int third() {}/"],
        \ 'Xtags', 'D')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int second() {}
    int third() {}
  [CODE]
  call writefile(code, 'Xfoo', 'D')

  enew
  let save_cpo = &cpo
  set cpo+=t
  let @/ = ''
  tag second
  call assert_equal('^int second() {}', @/)
  let &cpo = save_cpo

  set tags&
  %bwipe
endfunc

" Tag stack tests
func Test_tag_stack()
  let l = []
  for i in range(10, 31)
    let l += ["var" .. i .. "\tXfoo\t/^int var" .. i .. ";$/"]
  endfor
  call writefile(l, 'Xtags', 'D')
  set tags=Xtags

  let l = []
  for i in range(10, 31)
    let l += ["int var" .. i .. ";"]
  endfor
  call writefile(l, 'Xfoo', 'D')

  enew
  " Jump to a tag when the tag stack is full. Oldest entry should be removed.
  for i in range(10, 30)
    exe "tag var" .. i
  endfor
  let t = gettagstack()
  call assert_equal(20, t.length)
  call assert_equal('var11', t.items[0].tagname)
  let full = deepcopy(t.items)
  tag var31
  let t = gettagstack()
  call assert_equal('var12', t.items[0].tagname)
  call assert_equal('var31', t.items[19].tagname)

  " Jump to a tag when the tag stack is full, but with user data this time.
  call foreach(full, {i, item -> extend(item, {'user_data': $'udata{i}'})})
  call settagstack(0, {'items': full})
  let t = gettagstack()
  call assert_equal(20, t.length)
  call assert_equal('var11', t.items[0].tagname)
  call assert_equal('udata0', t.items[0].user_data)
  tag var31
  let t = gettagstack()
  call assert_equal('var12', t.items[0].tagname)
  call assert_equal('udata1', t.items[0].user_data)
  call assert_equal('var31', t.items[19].tagname)
  call assert_false(has_key(t.items[19], 'user_data'))

  " Use tnext with a single match
  call assert_fails('tnext', 'E427:')

  " Jump to newest entry from the top of the stack
  call assert_fails('tag', 'E556:')

  " Pop with zero count from the top of the stack
  call assert_fails('0pop', 'E556:')

  " Pop from an unsaved buffer
  enew!
  call append(1, "sample text")
  call assert_fails('pop', 'E37:')
  call assert_equal(21, gettagstack().curidx)
  enew!

  " Pop all the entries in the tag stack
  call assert_fails('30pop', 'E555:')

  " Pop with a count when already at the bottom of the stack
  call assert_fails('exe "normal 4\<C-T>"', 'E555:')
  call assert_equal(1, gettagstack().curidx)

  " Jump to newest entry from the bottom of the stack with zero count
  call assert_fails('0tag', 'E555:')

  " Pop the tag stack when it is empty
  call settagstack(1, {'items' : []})
  call assert_fails('pop', 'E73:')

  " References to wiped buffer are deleted.
  for i in range(10, 20)
    edit Xtest
    exe "tag var" .. i
  endfor
  edit Xtest

  let t = gettagstack()
  call assert_equal(11, t.length)
  call assert_equal(12, t.curidx)

  bwipe!

  let t = gettagstack()
  call assert_equal(0, t.length)
  call assert_equal(1, t.curidx)

  " References to wiped buffer are deleted with multiple tabpages.
  let w1 = win_getid()
  call settagstack(1, {'items' : []})
  for i in range(10, 20) | edit Xtest | exe "tag var" .. i | endfor
  enew

  new
  let w2 = win_getid()
  call settagstack(1, {'items' : []})
  for i in range(10, 20) | edit Xtest | exe "tag var" .. i | endfor
  enew

  tabnew
  let w3 = win_getid()
  call settagstack(1, {'items' : []})
  for i in range(10, 20) | edit Xtest | exe "tag var" .. i | endfor
  enew

  new
  let w4 = win_getid()
  call settagstack(1, {'items' : []})
  for i in range(10, 20) | edit Xtest | exe "tag var" .. i | endfor
  enew

  for w in [w1, w2, w3, w4]
    let t = gettagstack(w)
    call assert_equal(11, t.length)
    call assert_equal(12, t.curidx)
  endfor

  bwipe! Xtest

  for w in [w1, w2, w3, w4]
    let t = gettagstack(w)
    call assert_equal(0, t.length)
    call assert_equal(1, t.curidx)
  endfor

  %bwipe!
  set tags&
endfunc

" Test for browsing multiple matching tags
func Test_tag_multimatch()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "first\tXfoo\t1",
        \ "first\tXfoo\t2",
        \ "first\tXfoo\t3"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int first() {}
    int first() {}
  [CODE]
  call writefile(code, 'Xfoo')

  call settagstack(1, {'items' : []})
  tag first
  tlast
  call assert_equal(3, line('.'))
  call assert_fails('tnext', 'E428:')
  tfirst
  call assert_equal(1, line('.'))
  call assert_fails('tprev', 'E425:')

  tlast
  call feedkeys("5\<CR>", 't')
  tselect first
  call assert_equal(2, gettagstack().curidx)

  set ignorecase
  tag FIRST
  tnext
  call assert_equal(2, line('.'))
  tlast
  tprev
  call assert_equal(2, line('.'))
  tNext
  call assert_equal(1, line('.'))
  set ignorecase&

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
  %bwipe
endfunc

" Test for previewing multiple matching tags
func Test_preview_tag_multimatch()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "first\tXfoo\t1",
        \ "first\tXfoo\t2",
        \ "first\tXfoo\t3"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int first() {}
    int first() {}
  [CODE]
  call writefile(code, 'Xfoo')

  enew | only
  ptag first
  ptlast
  wincmd P
  call assert_equal(3, line('.'))
  wincmd w
  call assert_fails('ptnext', 'E428:')
  ptprev
  wincmd P
  call assert_equal(2, line('.'))
  wincmd w
  ptfirst
  wincmd P
  call assert_equal(1, line('.'))
  wincmd w
  call assert_fails('ptprev', 'E425:')
  ptnext
  wincmd P
  call assert_equal(2, line('.'))
  wincmd w
  ptlast
  call feedkeys("5\<CR>", 't')
  ptselect first
  wincmd P
  call assert_equal(3, line('.'))

  pclose

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
  %bwipe
endfunc

" Test for jumping to multiple matching tags across multiple :tags commands
func Test_tnext_multimatch()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "first\tXfoo1\t1",
        \ "first\tXfoo2\t1",
        \ "first\tXfoo3\t1"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
  [CODE]
  call writefile(code, 'Xfoo1')
  call writefile(code, 'Xfoo2')
  call writefile(code, 'Xfoo3')

  tag first
  tag first
  pop
  tnext
  tnext
  call assert_fails('tnext', 'E428:')

  call delete('Xtags')
  call delete('Xfoo1')
  call delete('Xfoo2')
  call delete('Xfoo3')
  set tags&
  %bwipe
endfunc

" Test for jumping to multiple matching tags in non-existing files
func Test_multimatch_non_existing_files()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "first\tXfoo1\t1",
        \ "first\tXfoo2\t1",
        \ "first\tXfoo3\t1"],
        \ 'Xtags')
  set tags=Xtags

  call settagstack(1, {'items' : []})
  call assert_fails('tag first', 'E429:')
  call assert_equal(3, gettagstack().items[0].matchnr)

  call delete('Xtags')
  set tags&
  %bwipe
endfunc

func Test_tselect_listing()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "first\tXfoo\t1" .. ';"' .. "\tv\ttyperef:typename:int\tfile:",
        \ "first\tXfoo\t2" .. ';"' .. "\tkind:v\ttyperef:typename:char\tfile:"],
        \ 'Xtags')
  set tags=Xtags

  let code =<< trim [CODE]
    static int first;
    static char first;
  [CODE]
  call writefile(code, 'Xfoo')

  call feedkeys("\<CR>", "t")
  let l = split(execute("tselect first"), "\n")
  let expected =<< [DATA]
  # pri kind tag               file
  1 FS  v    first             Xfoo
               typeref:typename:int 
               1
  2 FS  v    first             Xfoo
               typeref:typename:char 
               2
Type number and <Enter> (q or empty cancels): 
[DATA]
  call assert_equal(expected, l)

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
  %bwipe
endfunc

" Test for :isearch, :ilist, :ijump and :isplit commands
" Test for [i, ]i, [I, ]I, [ CTRL-I, ] CTRL-I and CTRL-W i commands
func Test_inc_search()
  new
  call setline(1, ['1:foo', '2:foo', 'foo', '3:foo', '4:foo', '==='])
  call cursor(3, 1)

  " Test for [i and ]i
  call assert_equal('1:foo', execute('normal [i'))
  call assert_equal('2:foo', execute('normal 2[i'))
  call assert_fails('normal 3[i', 'E387:')
  call assert_equal('3:foo', execute('normal ]i'))
  call assert_equal('4:foo', execute('normal 2]i'))
  call assert_fails('normal 3]i', 'E389:')
  call assert_fails('normal G]i', 'E349:')
  call assert_fails('normal [i', 'E349:')
  call cursor(3, 1)

  " Test for :isearch
  call assert_equal('1:foo', execute('isearch foo'))
  call assert_equal('3:foo', execute('isearch 4 /foo/'))
  call assert_fails('isearch 3 foo', 'E387:')
  call assert_equal('3:foo', execute('+1,$isearch foo'))
  call assert_fails('1,.-1isearch 3 foo', 'E389:')
  call assert_fails('isearch bar', 'E389:')
  call assert_fails('isearch /foo/3', 'E488:')

  " Test for [I and ]I
  call assert_equal([
        \ '  1:    1 1:foo',
        \ '  2:    2 2:foo',
        \ '  3:    3 foo',
        \ '  4:    4 3:foo',
        \ '  5:    5 4:foo'], split(execute('normal [I'), "\n"))
  call assert_equal([
        \ '  1:    4 3:foo',
        \ '  2:    5 4:foo'], split(execute('normal ]I'), "\n"))
  call assert_fails('normal G]I', 'E349:')
  call assert_fails('normal [I', 'E349:')
  call cursor(3, 1)

  " Test for :ilist
  call assert_equal([
        \ '  1:    1 1:foo',
        \ '  2:    2 2:foo',
        \ '  3:    3 foo',
        \ '  4:    4 3:foo',
        \ '  5:    5 4:foo'], split(execute('ilist foo'), "\n"))
  call assert_equal([
        \ '  1:    4 3:foo',
        \ '  2:    5 4:foo'], split(execute('+1,$ilist /foo/'), "\n"))
  call assert_fails('ilist bar', 'E389:')

  " Test for [ CTRL-I and ] CTRL-I
  exe "normal [\t"
  call assert_equal([1, 3], [line('.'), col('.')])
  exe "normal 2j4[\t"
  call assert_equal([4, 3], [line('.'), col('.')])
  call assert_fails("normal k3[\t", 'E387:')
  call assert_fails("normal 6[\t", 'E389:')
  exe "normal ]\t"
  call assert_equal([4, 3], [line('.'), col('.')])
  exe "normal k2]\t"
  call assert_equal([5, 3], [line('.'), col('.')])
  call assert_fails("normal 2k3]\t", 'E389:')
  call assert_fails("normal G[\t", 'E349:')
  call assert_fails("normal ]\t", 'E349:')
  call cursor(3, 1)

  " Test for :ijump
  call cursor(3, 1)
  ijump foo
  call assert_equal([1, 3], [line('.'), col('.')])
  call cursor(3, 1)
  ijump 4 /foo/
  call assert_equal([4, 3], [line('.'), col('.')])
  call cursor(3, 1)
  call assert_fails('ijump 3 foo', 'E387:')
  +,$ijump 2 foo
  call assert_equal([5, 3], [line('.'), col('.')])
  call assert_fails('ijump bar', 'E389:')

  " Test for CTRL-W i
  call cursor(3, 1)
  wincmd i
  call assert_equal([1, 3, 3], [line('.'), col('.'), winnr('$')])
  close
  5wincmd i
  call assert_equal([5, 3, 3], [line('.'), col('.'), winnr('$')])
  close
  call assert_fails('3wincmd i', 'E387:')
  call assert_fails('6wincmd i', 'E389:')
  call assert_fails("normal G\<C-W>i", 'E349:')
  call cursor(3, 1)

  " Test for :isplit
  isplit foo
  call assert_equal([1, 3, 3], [line('.'), col('.'), winnr('$')])
  close
  isplit 5 /foo/
  call assert_equal([5, 3, 3], [line('.'), col('.'), winnr('$')])
  close
  call assert_fails('isplit 3 foo', 'E387:')
  call assert_fails('isplit 6 foo', 'E389:')
  call assert_fails('isplit bar', 'E389:')

  close!
endfunc

" this was using a line from ml_get() freed by the regexp
func Test_isearch_copy_line()
  new
  norm o
  norm 0
  0norm o
  sil! norm bc0
  sil! isearch \%')
  bwipe!
endfunc

" Test for :dsearch, :dlist, :djump and :dsplit commands
" Test for [d, ]d, [D, ]D, [ CTRL-D, ] CTRL-D and CTRL-W d commands
func Test_macro_search()
  new
  call setline(1, ['#define FOO 1', '#define FOO 2', '#define FOO 3',
        \ '#define FOO 4', '#define FOO 5'])
  call cursor(3, 9)

  " Test for [d and ]d
  call assert_equal('#define FOO 1', execute('normal [d'))
  call assert_equal('#define FOO 2', execute('normal 2[d'))
  call assert_fails('normal 3[d', 'E387:')
  call assert_equal('#define FOO 4', execute('normal ]d'))
  call assert_equal('#define FOO 5', execute('normal 2]d'))
  call assert_fails('normal 3]d', 'E388:')

  " Test for :dsearch
  call assert_equal('#define FOO 1', execute('dsearch FOO'))
  call assert_equal('#define FOO 5', execute('dsearch 5 /FOO/'))
  call assert_fails('dsearch 3 FOO', 'E387:')
  call assert_equal('#define FOO 4', execute('+1,$dsearch FOO'))
  call assert_fails('1,.-1dsearch 3 FOO', 'E388:')
  call assert_fails('dsearch BAR', 'E388:')

  " Test for [D and ]D
  call assert_equal([
        \ '  1:    1 #define FOO 1',
        \ '  2:    2 #define FOO 2',
        \ '  3:    3 #define FOO 3',
        \ '  4:    4 #define FOO 4',
        \ '  5:    5 #define FOO 5'], split(execute('normal [D'), "\n"))
  call assert_equal([
        \ '  1:    4 #define FOO 4',
        \ '  2:    5 #define FOO 5'], split(execute('normal ]D'), "\n"))

  " Test for :dlist
  call assert_equal([
        \ '  1:    1 #define FOO 1',
        \ '  2:    2 #define FOO 2',
        \ '  3:    3 #define FOO 3',
        \ '  4:    4 #define FOO 4',
        \ '  5:    5 #define FOO 5'], split(execute('dlist FOO'), "\n"))
  call assert_equal([
        \ '  1:    4 #define FOO 4',
        \ '  2:    5 #define FOO 5'], split(execute('+1,$dlist /FOO/'), "\n"))
  call assert_fails('dlist BAR', 'E388:')

  " Test for [ CTRL-D and ] CTRL-D
  exe "normal [\<C-D>"
  call assert_equal([1, 9], [line('.'), col('.')])
  exe "normal 2j4[\<C-D>"
  call assert_equal([4, 9], [line('.'), col('.')])
  call assert_fails("normal k3[\<C-D>", 'E387:')
  call assert_fails("normal 6[\<C-D>", 'E388:')
  exe "normal ]\<C-D>"
  call assert_equal([4, 9], [line('.'), col('.')])
  exe "normal k2]\<C-D>"
  call assert_equal([5, 9], [line('.'), col('.')])
  call assert_fails("normal 2k3]\<C-D>", 'E388:')

  " Test for :djump
  call cursor(3, 9)
  djump FOO
  call assert_equal([1, 9], [line('.'), col('.')])
  call cursor(3, 9)
  djump 4 /FOO/
  call assert_equal([4, 9], [line('.'), col('.')])
  call cursor(3, 9)
  call assert_fails('djump 3 FOO', 'E387:')
  +,$djump 2 FOO
  call assert_equal([5, 9], [line('.'), col('.')])
  call assert_fails('djump BAR', 'E388:')

  " Test for CTRL-W d
  call cursor(3, 9)
  wincmd d
  call assert_equal([1, 9, 3], [line('.'), col('.'), winnr('$')])
  close
  5wincmd d
  call assert_equal([5, 9, 3], [line('.'), col('.'), winnr('$')])
  close
  call assert_fails('3wincmd d', 'E387:')
  call assert_fails('6wincmd d', 'E388:')
  new
  call assert_fails("normal \<C-W>d", 'E349:')
  call assert_fails("normal \<C-W>\<C-D>", 'E349:')
  close

  " Test for :dsplit
  dsplit FOO
  call assert_equal([1, 9, 3], [line('.'), col('.'), winnr('$')])
  close
  dsplit 5 /FOO/
  call assert_equal([5, 9, 3], [line('.'), col('.'), winnr('$')])
  close
  call assert_fails('dsplit 3 FOO', 'E387:')
  call assert_fails('dsplit 6 FOO', 'E388:')
  call assert_fails('dsplit BAR', 'E388:')

  close!
endfunc

func Test_define_search()
  " this was accessing freed memory
  new
  call setline(1, ['first line', '', '#define something 0'])
  sil norm o0
  sil! norm 
  bwipe!

  new somefile
  call setline(1, ['first line', '', '#define something 0'])
  sil norm 0o0
  sil! norm ]d
  bwipe!
endfunc

" Test for [*, [/, ]* and ]/
func Test_comment_search()
  new
  call setline(1, ['', '/*', ' *', ' *', ' */'])
  normal! 4gg[/
  call assert_equal([2, 1], [line('.'), col('.')])
  normal! 3gg[*
  call assert_equal([2, 1], [line('.'), col('.')])
  normal! 3gg]/
  call assert_equal([5, 3], [line('.'), col('.')])
  normal! 3gg]*
  call assert_equal([5, 3], [line('.'), col('.')])
  %d
  call setline(1, ['', '/*', ' *', ' *'])
  call assert_beeps('normal! 3gg]/')
  %d
  call setline(1, ['', ' *', ' *', ' */'])
  call assert_beeps('normal! 4gg[/')
  %d
  call setline(1, '        /* comment */')
  normal! 15|[/
  call assert_equal(9, col('.'))
  normal! 15|]/
  call assert_equal(21, col('.'))
  call setline(1, '         comment */')
  call assert_beeps('normal! 15|[/')
  call setline(1, '        /* comment')
  call assert_beeps('normal! 15|]/')
  close!
endfunc

" Test for the 'taglength' option
func Test_tag_length()
  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "tame\tXfile1\t1;",
        \ "tape\tXfile2\t1;"], 'Xtags')
  call writefile(['tame'], 'Xfile1')
  call writefile(['tape'], 'Xfile2')

  " Jumping to the tag 'tape', should instead jump to 'tame'
  new
  set taglength=2
  tag tape
  call assert_equal('Xfile1', @%)
  " Tag search should jump to the right tag
  enew
  tag /^tape$
  call assert_equal('Xfile2', @%)

  call delete('Xtags')
  call delete('Xfile1')
  call delete('Xfile2')
  set tags& taglength&
endfunc

" Tests for errors in a tags file
func Test_tagfile_errors()
  set tags=Xtags

  " missing search pattern or line number for a tag
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "foo\tXfile\t"], 'Xtags', 'b')
  call writefile(['foo'], 'Xfile')

  enew
  tag foo
  call assert_equal('', @%)
  let caught_431 = v:false
  try
    eval taglist('.*')
  catch /:E431:/
    let caught_431 = v:true
  endtry
  call assert_equal(v:true, caught_431)

  " tag name and file name are not separated by a tab
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "foo Xfile 1"], 'Xtags')
  call assert_fails('tag foo', 'E431:')

  " file name and search pattern are not separated by a tab
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "foo\tXfile 1;"], 'Xtags')
  call assert_fails('tag foo', 'E431:')

  call delete('Xtags')
  call delete('Xfile')
  set tags&
endfunc

" When :stag fails to open the file, should close the new window
func Test_stag_close_window_on_error()
  new | only
  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "foo\tXfile\t1"], 'Xtags')
  call writefile(['foo'], 'Xfile')
  call writefile([], '.Xfile.swp')
  " Remove the catch-all that runtest.vim adds
  au! SwapExists
  augroup StagTest
    au!
    autocmd SwapExists Xfile let v:swapchoice='q'
  augroup END

  stag foo
  call assert_equal(1, winnr('$'))
  call assert_equal('', @%)

  augroup StagTest
    au!
  augroup END
  call delete('Xfile')
  call delete('.Xfile.swp')
  set tags&
endfunc

" Test for 'tagbsearch' (binary search)
func Test_tagbsearch()
  " If a tags file header says the tags are sorted, but the tags are actually
  " unsorted, then binary search should fail and linear search should work.
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "!_TAG_FILE_SORTED\t1\t/0=unsorted, 1=sorted, 2=foldcase/",
        \ "third\tXfoo\t3",
        \ "second\tXfoo\t2",
        \ "first\tXfoo\t1"],
        \ 'Xtags', 'D')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int second() {}
    int third() {}
  [CODE]
  call writefile(code, 'Xfoo', 'D')

  enew
  set tagbsearch
  call assert_fails('tag first', 'E426:')
  call assert_equal('', bufname())
  call assert_fails('tag second', 'E426:')
  call assert_equal('', bufname())
  tag third
  call assert_equal('Xfoo', bufname())
  call assert_equal(3, line('.'))
  %bw!

  set notagbsearch
  tag first
  call assert_equal('Xfoo', bufname())
  call assert_equal(1, line('.'))
  enew
  tag second
  call assert_equal('Xfoo', bufname())
  call assert_equal(2, line('.'))
  enew
  tag third
  call assert_equal('Xfoo', bufname())
  call assert_equal(3, line('.'))
  %bw!

  " If a tags file header says the tags are unsorted, but the tags are
  " actually sorted, then binary search should work.
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "!_TAG_FILE_SORTED\t0\t/0=unsorted, 1=sorted, 2=foldcase/",
        \ "first\tXfoo\t1",
        \ "second\tXfoo\t2",
        \ "third\tXfoo\t3"],
        \ 'Xtags')

  set tagbsearch
  tag first
  call assert_equal('Xfoo', bufname())
  call assert_equal(1, line('.'))
  enew
  tag second
  call assert_equal('Xfoo', bufname())
  call assert_equal(2, line('.'))
  enew
  tag third
  call assert_equal('Xfoo', bufname())
  call assert_equal(3, line('.'))
  %bw!

  " Binary search fails on EOF
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "!_TAG_FILE_SORTED\t1\t/0=unsorted, 1=sorted, 2=foldcase/",
        \ "bar\tXfoo\t1",
        \ "foo\tXfoo\t2"],
        \ 'Xtags')
  call assert_fails('tag bbb', 'E426:')

  set tags& tagbsearch&
endfunc

" Test tag guessing with very short names
func Test_tag_guess_short()
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "y\tXf\t/^y()/"],
        \ 'Xt', 'D')
  set tags=Xt cpoptions+=t
  call writefile(['', 'int * y () {}', ''], 'Xf', 'D')

  let v:statusmsg = ''
  let @/ = ''
  ta y
  call assert_match('E435:', v:statusmsg)
  call assert_equal(2, line('.'))
  call assert_match('<y', @/)

  set tags& cpoptions-=t
endfunc

" vim: shiftwidth=2 sts=2 expandtab
