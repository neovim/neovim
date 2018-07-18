" Test for edit functions
"
if exists("+t_kD")
  let &t_kD="[3;*~"
endif

" Needed for testing basic rightleft: Test_edit_rightleft
source view_util.vim

" Needs to come first until the bug in getchar() is
" fixed: https://groups.google.com/d/msg/vim_dev/fXL9yme4H4c/bOR-U6_bAQAJ
func! Test_edit_00b()
  new
  call setline(1, ['abc '])
  inoreabbr <buffer> h here some more
  call cursor(1, 4)
  " <c-l> expands the abbreviation and ends insertmode
  call feedkeys(":set im\<cr> h\<c-l>:set noim\<cr>", 'tix')
  call assert_equal(['abc here some more '], getline(1,'$'))
  iunabbr <buffer> h
  bw!
endfunc

func! Test_edit_01()
  " set for Travis CI?
  "  set nocp noesckeys
  new
  " 1) empty buffer
  call assert_equal([''], getline(1,'$'))
  " 2) delete in an empty line
  call feedkeys("i\<del>\<esc>", 'tnix')
  call assert_equal([''], getline(1,'$'))
  %d
  " 3) delete one character
  call setline(1, 'a')
  call feedkeys("i\<del>\<esc>", 'tnix')
  call assert_equal([''], getline(1,'$'))
  %d
  " 4) delete a multibyte character
  if has("multi_byte")
    call setline(1, "\u0401")
    call feedkeys("i\<del>\<esc>", 'tnix')
    call assert_equal([''], getline(1,'$'))
    %d
  endif
  " 5.1) delete linebreak with 'bs' option containing eol
  let _bs=&bs
  set bs=eol
  call setline(1, ["abc def", "ghi jkl"])
  call cursor(1, 1)
  call feedkeys("A\<del>\<esc>", 'tnix')
  call assert_equal(['abc defghi jkl'], getline(1, 2))
  %d
  " 5.2) delete linebreak with backspace option w/out eol
  set bs=
  call setline(1, ["abc def", "ghi jkl"])
  call cursor(1, 1)
  call feedkeys("A\<del>\<esc>", 'tnix')
  call assert_equal(["abc def", "ghi jkl"], getline(1, 2))
  let &bs=_bs
  bw!
endfunc

func! Test_edit_02()
  " Change cursor position in InsertCharPre command
  new
  call setline(1, 'abc')
  call cursor(1, 1)
  fu! DoIt(...)
    call cursor(1, 4)
    if len(a:000)
      let v:char=a:1
    endif
  endfu
  au InsertCharPre <buffer> :call DoIt('y')
  call feedkeys("ix\<esc>", 'tnix')
  call assert_equal(['abcy'], getline(1, '$'))
  " Setting <Enter> in InsertCharPre
  au! InsertCharPre <buffer> :call DoIt("\n")
  call setline(1, 'abc')
  call cursor(1, 1)
  call feedkeys("ix\<esc>", 'tnix')
  call assert_equal(['abc', ''], getline(1, '$'))
  %d
  au! InsertCharPre
  " Change cursor position in InsertEnter command
  " 1) when setting v:char, keeps changed cursor position
  au! InsertEnter <buffer> :call DoIt('y')
  call setline(1, 'abc')
  call cursor(1, 1)
  call feedkeys("ix\<esc>", 'tnix')
  call assert_equal(['abxc'], getline(1, '$'))
  " 2) when not setting v:char, restores changed cursor position
  au! InsertEnter <buffer> :call DoIt()
  call setline(1, 'abc')
  call cursor(1, 1)
  call feedkeys("ix\<esc>", 'tnix')
  call assert_equal(['xabc'], getline(1, '$'))
  au! InsertEnter
  delfu DoIt
  bw!
endfunc

func! Test_edit_03()
  " Change cursor after <c-o> command to end of line
  new
  call setline(1, 'abc')
  call cursor(1, 1)
  call feedkeys("i\<c-o>$y\<esc>", 'tnix')
  call assert_equal(['abcy'], getline(1, '$'))
  %d
  call setline(1, 'abc')
  call cursor(1, 1)
  call feedkeys("i\<c-o>80|y\<esc>", 'tnix')
  call assert_equal(['abcy'], getline(1, '$'))
  %d
  call setline(1, 'abc')
  call feedkeys("Ad\<c-o>:s/$/efg/\<cr>hij", 'tnix')
  call assert_equal(['hijabcdefg'], getline(1, '$'))
  bw!
endfunc

func! Test_edit_04()
  " test for :stopinsert
  new
  call setline(1, 'abc')
  call cursor(1, 1)
  call feedkeys("i\<c-o>:stopinsert\<cr>$", 'tnix')
  call feedkeys("aX\<esc>", 'tnix')
  call assert_equal(['abcX'], getline(1, '$'))
  %d
  bw!
endfunc

func! Test_edit_05()
  " test for folds being opened
  new
  call setline(1, ['abcX', 'abcX', 'zzzZ'])
  call cursor(1, 1)
  set foldmethod=manual foldopen+=insert
  " create fold for those two lines
  norm! Vjzf
  call feedkeys("$ay\<esc>", 'tnix')
  call assert_equal(['abcXy', 'abcX', 'zzzZ'], getline(1, '$'))
  %d
  call setline(1, ['abcX', 'abcX', 'zzzZ'])
  call cursor(1, 1)
  set foldmethod=manual foldopen-=insert
  " create fold for those two lines
  norm! Vjzf
  call feedkeys("$ay\<esc>", 'tnix')
  call assert_equal(['abcXy', 'abcX', 'zzzZ'], getline(1, '$'))
  %d
  bw!
endfunc

func! Test_edit_06()
  " Test in diff mode
  if !has("diff") || !executable("diff")
    return
  endif
  new
  call setline(1, ['abc', 'xxx', 'yyy'])
  vnew
  call setline(1, ['abc', 'zzz', 'xxx', 'yyy'])
  wincmd p
  diffthis
  wincmd p
  diffthis
  wincmd p
  call cursor(2, 1)
  norm! zt
  call feedkeys("Ozzz\<esc>", 'tnix')
  call assert_equal(['abc', 'zzz', 'xxx', 'yyy'], getline(1,'$'))
  bw!
  bw!
endfunc

func! Test_edit_07()
  " 1) Test with completion <c-l> when popupmenu is visible
  new
  call setline(1, 'J')

  func! ListMonths()
    call complete(col('.')-1, ['January', 'February', 'March',
    \ 'April', 'May', 'June', 'July', 'August', 'September',
    \ 'October', 'November', 'December'])
    return ''
  endfunc
  inoremap <buffer> <F5> <C-R>=ListMonths()<CR>

  call feedkeys("A\<f5>\<c-p>". repeat("\<down>", 6)."\<c-l>\<down>\<c-l>\<cr>", 'tx')
  call assert_equal(['July'], getline(1,'$'))
  " 1) Test completion when InsertCharPre kicks in
  %d
  call setline(1, 'J')
  fu! DoIt()
    if v:char=='u'
      let v:char='an'
    endif
  endfu
  au InsertCharPre <buffer> :call DoIt()
  call feedkeys("A\<f5>\<c-p>u\<cr>\<c-l>\<cr>", 'tx')
  call assert_equal(["Jan\<c-l>",''], getline(1,'$'))
  %d
  call setline(1, 'J')
  call feedkeys("A\<f5>\<c-p>u\<down>\<c-l>\<cr>", 'tx')
  call assert_equal(["January"], getline(1,'$'))

  delfu ListMonths
  delfu DoIt
  iunmap <buffer> <f5>
  bw!
endfunc

func! Test_edit_08()
  throw 'skipped: moved to test/functional/legacy/edit_spec.lua'
  " reset insertmode from i_ctrl-r_=
  let g:bufnr = bufnr('%')
  new
  call setline(1, ['abc'])
  call cursor(1, 4)
  call feedkeys(":set im\<cr>ZZZ\<c-r>=setbufvar(g:bufnr,'&im', 0)\<cr>",'tnix')
  call assert_equal(['abZZZc'], getline(1,'$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
  call assert_false(0, '&im')
  bw!
  unlet g:bufnr
endfunc

func! Test_edit_09()
  " test i_CTRL-\ combinations
  new
  call setline(1, ['abc', 'def', 'ghi'])
  call cursor(1, 1)
  " 1) CTRL-\ CTLR-N
  call feedkeys(":set im\<cr>\<c-\>\<c-n>ccABC\<c-l>", 'txin')
  call assert_equal(['ABC', 'def', 'ghi'], getline(1,'$'))
  call setline(1, ['ABC', 'def', 'ghi'])
  " 2) CTRL-\ CTLR-G
  call feedkeys("j0\<c-\>\<c-g>ZZZ\<cr>\<c-l>", 'txin')
  call assert_equal(['ABC', 'ZZZ', 'def', 'ghi'], getline(1,'$'))
  call feedkeys("I\<c-\>\<c-g>YYY\<c-l>", 'txin')
  call assert_equal(['ABC', 'ZZZ', 'YYYdef', 'ghi'], getline(1,'$'))
  set noinsertmode
  " 3) CTRL-\ CTRL-O
  call setline(1, ['ABC', 'ZZZ', 'def', 'ghi'])
  call cursor(1, 1)
  call feedkeys("A\<c-o>ix", 'txin')
  call assert_equal(['ABxC', 'ZZZ', 'def', 'ghi'], getline(1,'$'))
  call feedkeys("A\<c-\>\<c-o>ix", 'txin')
  call assert_equal(['ABxCx', 'ZZZ', 'def', 'ghi'], getline(1,'$'))
  " 4) CTRL-\ a (should be inserted literally, not special after <c-\>
  call setline(1, ['ABC', 'ZZZ', 'def', 'ghi'])
  call cursor(1, 1)
  call feedkeys("A\<c-\>a", 'txin')
  call assert_equal(["ABC\<c-\>a", 'ZZZ', 'def', 'ghi'], getline(1, '$'))
  bw!
endfunc

func! Test_edit_10()
  " Test for starting selectmode
  new
  set selectmode=key keymodel=startsel
  call setline(1, ['abc', 'def', 'ghi'])
  call cursor(1, 4)
  call feedkeys("A\<s-home>start\<esc>", 'txin')
  call assert_equal(['startdef', 'ghi'], getline(1, '$'))
  set selectmode= keymodel=
  bw!
endfunc

func! Test_edit_11()
  " Test that indenting kicks in
  new
  set cindent
  call setline(1, ['{', '', ''])
  call cursor(2, 1)
  call feedkeys("i\<c-f>int c;\<esc>", 'tnix')
  call cursor(3, 1)
  call feedkeys("i/* comment */", 'tnix')
  call assert_equal(['{', "\<tab>int c;", "/* comment */"], getline(1, '$'))
  " added changed cindentkeys slightly
  set cindent cinkeys+=*/
  call setline(1, ['{', '', ''])
  call cursor(2, 1)
  call feedkeys("i\<c-f>int c;\<esc>", 'tnix')
  call cursor(3, 1)
  call feedkeys("i/* comment */", 'tnix')
  call assert_equal(['{', "\<tab>int c;", "\<tab>/* comment */"], getline(1, '$'))
  set cindent cinkeys+==end
  call feedkeys("oend\<cr>\<esc>", 'tnix')
  call assert_equal(['{', "\<tab>int c;", "\<tab>/* comment */", "\tend", ''], getline(1, '$'))
  set cinkeys-==end
  %d
  " Use indentexpr instead of cindenting
  func! Do_Indent()
    if v:lnum == 3
      return 3*shiftwidth()
    else
      return 2*shiftwidth()
    endif
  endfunc
  setl indentexpr=Do_Indent() indentkeys+=*/
  call setline(1, ['{', '', ''])
  call cursor(2, 1)
  call feedkeys("i\<c-f>int c;\<esc>", 'tnix')
  call cursor(3, 1)
  call feedkeys("i/* comment */", 'tnix')
  call assert_equal(['{', "\<tab>\<tab>int c;", "\<tab>\<tab>\<tab>/* comment */"], getline(1, '$'))
  set cinkeys&vim indentkeys&vim
  set nocindent indentexpr=
  delfu Do_Indent
  bw!
endfunc

func! Test_edit_12()
  " Test changing indent in replace mode
  new
  call setline(1, ["\tabc", "\tdef"])
  call cursor(2, 4)
  call feedkeys("R^\<c-d>", 'tnix')
  call assert_equal(["\tabc", "def"], getline(1, '$'))
  call assert_equal([0, 2, 2, 0], getpos('.'))
  %d
  call setline(1, ["\tabc", "\t\tdef"])
  call cursor(2, 2)
  call feedkeys("R^\<c-d>", 'tnix')
  call assert_equal(["\tabc", "def"], getline(1, '$'))
  call assert_equal([0, 2, 1, 0], getpos('.'))
  %d
  call setline(1, ["\tabc", "\t\tdef"])
  call cursor(2, 2)
  call feedkeys("R\<c-t>", 'tnix')
  call assert_equal(["\tabc", "\t\t\tdef"], getline(1, '$'))
  call assert_equal([0, 2, 2, 0], getpos('.'))
  bw!
  10vnew
  call setline(1, ["\tabc", "\t\tdef"])
  call cursor(2, 2)
  call feedkeys("R\<c-t>", 'tnix')
  call assert_equal(["\tabc", "\t\t\tdef"], getline(1, '$'))
  call assert_equal([0, 2, 2, 0], getpos('.'))
  %d
  set sw=4
  call setline(1, ["\tabc", "\t\tdef"])
  call cursor(2, 2)
  call feedkeys("R\<c-t>\<c-t>", 'tnix')
  call assert_equal(["\tabc", "\t\t\tdef"], getline(1, '$'))
  call assert_equal([0, 2, 2, 0], getpos('.'))
  %d
  call setline(1, ["\tabc", "\t\tdef"])
  call cursor(2, 2)
  call feedkeys("R\<c-t>\<c-t>", 'tnix')
  call assert_equal(["\tabc", "\t\t\tdef"], getline(1, '$'))
  call assert_equal([0, 2, 2, 0], getpos('.'))
  set et
  set sw& et&
  %d
  call setline(1, ["\t/*"])
  set formatoptions=croql
  call cursor(1, 3)
  call feedkeys("A\<cr>\<cr>/", 'tnix')
  call assert_equal(["\t/*", " *", " */"], getline(1, '$'))
  set formatoptions&
  bw!
endfunc

func! Test_edit_13()
  " Test smartindenting
  if exists("+smartindent")
    new
    set smartindent autoindent
    call setline(1, ["\tabc"])
    call feedkeys("A {\<cr>more\<cr>}\<esc>", 'tnix')
    call assert_equal(["\tabc {", "\t\tmore", "\t}"], getline(1, '$'))
    set smartindent& autoindent&
    bw!
  endif
endfunc

func! Test_edit_CR()
  " Test for <CR> in insert mode
  " basically only in quickfix mode ist tested, the rest
  " has been taken care of by other tests
  if !has("quickfix")
    return
  endif
  botright new
  call writefile(range(1, 10), 'Xqflist.txt')
  call setqflist([{'filename': 'Xqflist.txt', 'lnum': 2}])
  copen
  set modifiable
  call feedkeys("A\<cr>", 'tnix')
  call assert_equal('Xqflist.txt', bufname(''))
  call assert_equal(2, line('.'))
  cclose
  botright new
  call setloclist(0, [{'filename': 'Xqflist.txt', 'lnum': 10}])
  lopen
  set modifiable
  call feedkeys("A\<cr>", 'tnix')
  call assert_equal('Xqflist.txt', bufname(''))
  call assert_equal(10, line('.'))
  call feedkeys("A\<Enter>", 'tnix')
  call feedkeys("A\<kEnter>", 'tnix')
  call feedkeys("A\n", 'tnix')
  call feedkeys("A\r", 'tnix')
  call assert_equal(map(range(1, 10), 'string(v:val)') + ['', '', '', ''], getline(1, '$'))
  bw!
  lclose
  call delete('Xqflist.txt')
endfunc

func! Test_edit_CTRL_()
  " disabled for Windows builds, why?
  if !has("multi_byte") || !has("rightleft") || has("win32")
    return
  endif
  let _encoding=&encoding
  set encoding=utf-8
  " Test for CTRL-_
  new
  call setline(1, ['abc'])
  call cursor(1, 1)
  call feedkeys("i\<c-_>xyz\<esc>", 'tnix')
  call assert_equal(["\<C-_>xyzabc"], getline(1, '$'))
  call assert_false(&revins)
  set ari
  call setline(1, ['abc'])
  call cursor(1, 1)
  call feedkeys("i\<c-_>xyz\<esc>", 'tnix')
  call assert_equal(["æèñabc"], getline(1, '$'))
  call assert_true(&revins)
  call setline(1, ['abc'])
  call cursor(1, 1)
  call feedkeys("i\<c-_>xyz\<esc>", 'tnix')
  call assert_equal(["xyzabc"], getline(1, '$'))
  call assert_false(&revins)
  set noari
  let &encoding=_encoding
  bw!
endfunc

" needs to come first, to have the @. register empty
func! Test_edit_00a_CTRL_A()
  " Test pressing CTRL-A
  new
  call setline(1, repeat([''], 5))
  call cursor(1, 1)
  try
    call feedkeys("A\<NUL>", 'tnix')
  catch /^Vim\%((\a\+)\)\=:E29/
    call assert_true(1, 'E29 error caught')
  endtry
  call cursor(1, 1)
  call feedkeys("Afoobar \<esc>", 'tnix')
  call cursor(2, 1)
  call feedkeys("A\<c-a>more\<esc>", 'tnix')
  call cursor(3, 1)
  call feedkeys("A\<NUL>and more\<esc>", 'tnix')
  call assert_equal(['foobar ', 'foobar more', 'foobar morend more', '', ''], getline(1, '$'))
  bw!
endfunc

func! Test_edit_CTRL_EY()
  " Ctrl-E/ Ctrl-Y in insert mode completion to scroll
  10new
  call setline(1, range(1, 100))
  call cursor(30, 1)
  norm! z.
  call feedkeys("A\<c-x>\<c-e>\<c-e>\<c-e>\<c-e>\<c-e>", 'tnix')
  call assert_equal(30, winsaveview()['topline'])
  call assert_equal([0, 30, 2, 0], getpos('.'))
  call feedkeys("A\<c-x>\<c-e>\<c-e>\<c-e>\<c-e>\<c-e>", 'tnix')
  call feedkeys("A\<c-x>".repeat("\<c-y>", 10), 'tnix')
  call assert_equal(21, winsaveview()['topline'])
  call assert_equal([0, 30, 2, 0], getpos('.'))
  bw!
endfunc

func! Test_edit_CTRL_G()
  new
  call setline(1, ['foobar', 'foobar', 'foobar'])
  call cursor(2, 4)
  call feedkeys("ioooooooo\<c-g>k\<c-r>.\<esc>", 'tnix')
  call assert_equal(['foooooooooobar', 'foooooooooobar', 'foobar'], getline(1, '$'))
  call assert_equal([0, 1, 11, 0], getpos('.'))
  call feedkeys("i\<c-g>k\<esc>", 'tnix')
  call assert_equal([0, 1, 10, 0], getpos('.'))
  call cursor(2, 4)
  call feedkeys("i\<c-g>jzzzz\<esc>", 'tnix')
  call assert_equal(['foooooooooobar', 'foooooooooobar', 'foozzzzbar'], getline(1, '$'))
  call assert_equal([0, 3, 7, 0], getpos('.'))
  call feedkeys("i\<c-g>j\<esc>", 'tnix')
  call assert_equal([0, 3, 6, 0], getpos('.'))
  bw!
endfunc

func! Test_edit_CTRL_I()
  " Tab in completion mode
  let path=expand("%:p:h")
  new
  call setline(1, [path."/", ''])
  call feedkeys("Arunt\<c-x>\<c-f>\<tab>\<cr>\<esc>", 'tnix')
  call assert_match('runtest\.vim', getline(1))
  %d
  call writefile(['one', 'two', 'three'], 'Xinclude.txt')
  let include='#include Xinclude.txt'
  call setline(1, [include, ''])
  call cursor(2, 1)
  call feedkeys("A\<c-x>\<tab>\<cr>\<esc>", 'tnix')
  call assert_equal([include, 'one', ''], getline(1, '$'))
  call feedkeys("2ggC\<c-x>\<tab>\<down>\<cr>\<esc>", 'tnix')
  call assert_equal([include, 'two', ''], getline(1, '$'))
  call feedkeys("2ggC\<c-x>\<tab>\<down>\<down>\<cr>\<esc>", 'tnix')
  call assert_equal([include, 'three', ''], getline(1, '$'))
  call feedkeys("2ggC\<c-x>\<tab>\<down>\<down>\<down>\<cr>\<esc>", 'tnix')
  call assert_equal([include, '', ''], getline(1, '$'))
  call delete("Xinclude.txt")
  bw!
endfunc

func! Test_edit_CTRL_K()
  " Test pressing CTRL-K (basically only dictionary completion and digraphs
  " the rest is already covered
  call writefile(['A', 'AA', 'AAA', 'AAAA'], 'Xdictionary.txt')
  set dictionary=Xdictionary.txt
  new
  call setline(1, 'A')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-k>\<cr>\<esc>", 'tnix')
  call assert_equal(['AA', ''], getline(1, '$'))
  %d
  call setline(1, 'A')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-k>\<down>\<cr>\<esc>", 'tnix')
  call assert_equal(['AAA'], getline(1, '$'))
  %d
  call setline(1, 'A')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-k>\<down>\<down>\<cr>\<esc>", 'tnix')
  call assert_equal(['AAAA'], getline(1, '$'))
  %d
  call setline(1, 'A')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-k>\<down>\<down>\<down>\<cr>\<esc>", 'tnix')
  call assert_equal(['A'], getline(1, '$'))
  %d
  call setline(1, 'A')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-k>\<down>\<down>\<down>\<down>\<cr>\<esc>", 'tnix')
  call assert_equal(['AA'], getline(1, '$'))

  " press an unexecpted key after dictionary completion
  %d
  call setline(1, 'A')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-k>\<c-]>\<cr>\<esc>", 'tnix')
  call assert_equal(['AA', ''], getline(1, '$'))
  %d
  call setline(1, 'A')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-k>\<c-s>\<cr>\<esc>", 'tnix')
  call assert_equal(["AA\<c-s>", ''], getline(1, '$'))
  %d
  call setline(1, 'A')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-k>\<c-f>\<cr>\<esc>", 'tnix')
  call assert_equal(["AA\<c-f>", ''], getline(1, '$'))

  set dictionary=
  %d
  call setline(1, 'A')
  call cursor(1, 1)
  let v:testing = 1
  try
    call feedkeys("A\<c-x>\<c-k>\<esc>", 'tnix')
  catch
    " error sleeps 2 seconds, when v:testing is not set
    let v:testing = 0
  endtry
  call delete('Xdictionary.txt')

  if has("multi_byte") && !has("nvim")
    call test_override("char_avail", 1)
    set showcmd
    %d
    call feedkeys("A\<c-k>a:\<esc>", 'tnix')
    call assert_equal(['ä'], getline(1, '$'))
    call test_override("char_avail", 0)
    set noshowcmd
  endif
  bw!
endfunc

func! Test_edit_CTRL_L()
  " Test Ctrl-X Ctrl-L (line completion)
  new
  set complete=.
  call setline(1, ['one', 'two', 'three', '', '', '', ''])
  call cursor(4, 1)
  call feedkeys("A\<c-x>\<c-l>\<esc>", 'tnix')
  call assert_equal(['one', 'two', 'three', 'three', '', '', ''], getline(1, '$'))
  call feedkeys("cct\<c-x>\<c-l>\<c-n>\<esc>", 'tnix')
  call assert_equal(['one', 'two', 'three', 't', '', '', ''], getline(1, '$'))
  call feedkeys("cct\<c-x>\<c-l>\<c-n>\<c-n>\<esc>", 'tnix')
  call assert_equal(['one', 'two', 'three', 't', '', '', ''], getline(1, '$'))
  call feedkeys("cct\<c-x>\<c-l>\<c-n>\<c-n>\<c-n>\<esc>", 'tnix')
  call assert_equal(['one', 'two', 'three', 'two', '', '', ''], getline(1, '$'))
  call feedkeys("cct\<c-x>\<c-l>\<c-n>\<c-n>\<c-n>\<c-n>\<esc>", 'tnix')
  call assert_equal(['one', 'two', 'three', 'three', '', '', ''], getline(1, '$'))
  call feedkeys("cct\<c-x>\<c-l>\<c-p>\<esc>", 'tnix')
  call assert_equal(['one', 'two', 'three', 'two', '', '', ''], getline(1, '$'))
  call feedkeys("cct\<c-x>\<c-l>\<c-p>\<c-p>\<esc>", 'tnix')
  call assert_equal(['one', 'two', 'three', 't', '', '', ''], getline(1, '$'))
  call feedkeys("cct\<c-x>\<c-l>\<c-p>\<c-p>\<c-p>\<esc>", 'tnix')
  call assert_equal(['one', 'two', 'three', 'three', '', '', ''], getline(1, '$'))
  set complete=
  call cursor(5, 1)
  call feedkeys("A\<c-x>\<c-l>\<c-p>\<c-n>\<esc>", 'tnix')
  call assert_equal(['one', 'two', 'three', 'three', "\<c-l>\<c-p>\<c-n>", '', ''], getline(1, '$'))
  set complete&
  %d
  if has("conceal") && has("syntax") && !has("nvim")
    call setline(1, ['foo', 'bar', 'foobar'])
    call test_override("char_avail", 1)
    set conceallevel=2 concealcursor=n
    syn on
    syn match ErrorMsg "^bar"
    call matchadd("Conceal", 'oo', 10, -1, {'conceal': 'X'})
    func! DoIt()
      let g:change=1
    endfunc
    au! TextChangedI <buffer> :call DoIt()

    call cursor(2, 1)
    call assert_false(exists("g:change"))
    call feedkeys("A \<esc>", 'tnix')
    call assert_equal(['foo', 'bar ', 'foobar'], getline(1, '$'))
    call assert_equal(1, g:change)

    call test_override("char_avail", 0)
    call clearmatches()
    syn off
    au! TextChangedI
    delfu DoIt
    unlet! g:change
  endif
  bw!
endfunc

func! Test_edit_CTRL_N()
  " Check keyword completion
  new
  set complete=.
  call setline(1, ['INFER', 'loWER', '', '', ])
  call cursor(3, 1)
  call feedkeys("Ai\<c-n>\<cr>\<esc>", "tnix")
  call feedkeys("ILO\<c-n>\<cr>\<esc>", 'tnix')
  call assert_equal(['INFER', 'loWER', 'i', 'LO', '', ''], getline(1, '$'))
  %d
  call setline(1, ['INFER', 'loWER', '', '', ])
  call cursor(3, 1)
  set ignorecase infercase
  call feedkeys("Ii\<c-n>\<cr>\<esc>", "tnix")
  call feedkeys("ILO\<c-n>\<cr>\<esc>", 'tnix')
  call assert_equal(['INFER', 'loWER', 'infer', 'LOWER', '', ''], getline(1, '$'))

  set noignorecase noinfercase complete&
  bw!
endfunc

func! Test_edit_CTRL_O()
  " Check for CTRL-O in insert mode
  new
  inoreabbr <buffer> h here some more
  call setline(1, ['abc', 'def'])
  call cursor(1, 1)
  " Ctrl-O after an abbreviation
  exe "norm A h\<c-o>:set nu\<cr> text"
  call assert_equal(['abc here some more text', 'def'], getline(1, '$'))
  call assert_true(&nu)
  set nonu
  iunabbr <buffer> h
  " Ctrl-O at end of line with 've'=onemore
  call cursor(1, 1)
  call feedkeys("A\<c-o>:let g:a=getpos('.')\<cr>\<esc>", 'tnix')
  call assert_equal([0, 1, 23, 0], g:a)
  call cursor(1, 1)
  set ve=onemore
  call feedkeys("A\<c-o>:let g:a=getpos('.')\<cr>\<esc>", 'tnix')
  call assert_equal([0, 1, 24, 0], g:a)
  set ve=
  unlet! g:a
  bw!
endfunc

func! Test_edit_CTRL_R()
  throw 'skipped: Nvim does not support test_override()'
  " Insert Register
  new
  call test_override("ALL", 1)
  set showcmd
  call feedkeys("AFOOBAR eins zwei\<esc>", 'tnix')
  call feedkeys("O\<c-r>.", 'tnix')
  call feedkeys("O\<c-r>=10*500\<cr>\<esc>", 'tnix')
  call feedkeys("O\<c-r>=getreg('=', 1)\<cr>\<esc>", 'tnix')
  call assert_equal(["getreg('=', 1)", '5000', "FOOBAR eins zwei", "FOOBAR eins zwei"], getline(1, '$'))
  call test_override("ALL", 0)
  set noshowcmd
  bw!
endfunc

func! Test_edit_CTRL_S()
  " Test pressing CTRL-S (basically only spellfile completion)
  " the rest is already covered
  new
  if !has("spell")
    call setline(1, 'vim')
    call feedkeys("A\<c-x>ss\<cr>\<esc>", 'tnix')
    call assert_equal(['vims', ''], getline(1, '$'))
    bw!
    return
  endif
  call setline(1, 'vim')
  " spell option not yet set
  try
    call feedkeys("A\<c-x>\<c-s>\<cr>\<esc>", 'tnix')
  catch /^Vim\%((\a\+)\)\=:E756/
    call assert_true(1, 'error caught')
  endtry
  call assert_equal(['vim', ''], getline(1, '$'))
  %d
  setl spell spelllang=en
  call setline(1, 'vim')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-s>\<cr>\<esc>", 'tnix')
  call assert_equal(['Vim', ''], getline(1, '$'))
  %d
  call setline(1, 'vim')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-s>\<down>\<cr>\<esc>", 'tnix')
  call assert_equal(['Aim'], getline(1, '$'))
  %d
  call setline(1, 'vim')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-s>\<c-p>\<cr>\<esc>", 'tnix')
  call assert_equal(['vim', ''], getline(1, '$'))
  %d
  " empty buffer
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-s>\<c-p>\<cr>\<esc>", 'tnix')
  call assert_equal(['', ''], getline(1, '$'))
  setl nospell
  bw!
endfunc

func! Test_edit_CTRL_T()
  " Check for CTRL-T and CTRL-X CTRL-T in insert mode
  " 1) increase indent
  new
  call setline(1, "abc")
  call cursor(1, 1)
  call feedkeys("A\<c-t>xyz", 'tnix')
  call assert_equal(["\<tab>abcxyz"], getline(1, '$'))
  " 2) also when paste option is set
  set paste
  call setline(1, "abc")
  call cursor(1, 1)
  call feedkeys("A\<c-t>xyz", 'tnix')
  call assert_equal(["\<tab>abcxyz"], getline(1, '$'))
  set nopaste
  " CTRL-X CTRL-T (thesaurus complete)
  call writefile(['angry furious mad enraged'], 'Xthesaurus')
  set thesaurus=Xthesaurus
  call setline(1, 'mad')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-t>\<cr>\<esc>", 'tnix')
  call assert_equal(['mad', ''], getline(1, '$'))
  %d
  call setline(1, 'mad')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-t>\<c-n>\<cr>\<esc>", 'tnix')
  call assert_equal(['angry', ''], getline(1, '$'))
  %d
  call setline(1, 'mad')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-t>\<c-n>\<c-n>\<cr>\<esc>", 'tnix')
  call assert_equal(['furious', ''], getline(1, '$'))
  %d
  call setline(1, 'mad')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-t>\<c-n>\<c-n>\<c-n>\<cr>\<esc>", 'tnix')
  call assert_equal(['enraged', ''], getline(1, '$'))
  %d
  call setline(1, 'mad')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-t>\<c-n>\<c-n>\<c-n>\<c-n>\<cr>\<esc>", 'tnix')
  call assert_equal(['mad', ''], getline(1, '$'))
  %d
  call setline(1, 'mad')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-t>\<c-n>\<c-n>\<c-n>\<c-n>\<c-n>\<cr>\<esc>", 'tnix')
  call assert_equal(['mad', ''], getline(1, '$'))
  " Using <c-p> <c-n> when 'complete' is empty
  set complete=
  %d
  call setline(1, 'mad')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-t>\<c-n>\<cr>\<esc>", 'tnix')
  call assert_equal(['angry', ''], getline(1, '$'))
  %d
  call setline(1, 'mad')
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-t>\<c-p>\<cr>\<esc>", 'tnix')
  call assert_equal(['mad', ''], getline(1, '$'))
  set complete&

  set thesaurus=
  %d
  call setline(1, 'mad')
  call cursor(1, 1)
  let v:testing = 1
  try
    call feedkeys("A\<c-x>\<c-t>\<esc>", 'tnix')
  catch
    " error sleeps 2 seconds, when v:testing is not set
    let v:testing = 0
  endtry
  call assert_equal(['mad'], getline(1, '$'))
  call delete('Xthesaurus')
  bw!
endfunc

func! Test_edit_CTRL_U()
  " Test 'completefunc'
  new
  " -1, -2 and -3 are special return values
  let g:special=0
  fun! CompleteMonths(findstart, base)
    if a:findstart
      " locate the start of the word
      return g:special
    else
      " find months matching with "a:base"
      let res = []
      for m in split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec")
        if m =~ '^\c'.a:base
          call add(res, {'word': m, 'abbr': m.' Month', 'icase': 0})
        endif
      endfor
      return {'words': res, 'refresh': 'always'}
    endif
  endfun
  set completefunc=CompleteMonths
  call setline(1, ['', ''])
  call cursor(1, 1)
  call feedkeys("AX\<c-x>\<c-u>\<cr>\<esc>", 'tnix')
  call assert_equal(['X', '', ''], getline(1, '$'))
  %d
  let g:special=-1
  call feedkeys("AX\<c-x>\<c-u>\<cr>\<esc>", 'tnix')
  call assert_equal(['XJan', ''], getline(1, '$'))
  %d
  let g:special=-2
  call feedkeys("AX\<c-x>\<c-u>\<cr>\<esc>", 'tnix')
  call assert_equal(['X', ''], getline(1, '$'))
  %d
  let g:special=-3
  call feedkeys("AX\<c-x>\<c-u>\<cr>\<esc>", 'tnix')
  call assert_equal(['X', ''], getline(1, '$'))
  %d
  let g:special=0
  call feedkeys("AM\<c-x>\<c-u>\<cr>\<esc>", 'tnix')
  call assert_equal(['Mar', ''], getline(1, '$'))
  %d
  call feedkeys("AM\<c-x>\<c-u>\<c-n>\<cr>\<esc>", 'tnix')
  call assert_equal(['May', ''], getline(1, '$'))
  %d
  call feedkeys("AM\<c-x>\<c-u>\<c-n>\<c-n>\<cr>\<esc>", 'tnix')
  call assert_equal(['M', ''], getline(1, '$'))
  delfu CompleteMonths
  %d
  try
    call feedkeys("A\<c-x>\<c-u>", 'tnix')
    call assert_fails(1, 'unknown completion function')
  catch /^Vim\%((\a\+)\)\=:E117/
    call assert_true(1, 'E117 error caught')
  endtry
  set completefunc=
  bw!
endfunc

func! Test_edit_CTRL_Z()
  " Ctrl-Z when insertmode is not set inserts it literally
  new
  call setline(1, 'abc')
  call feedkeys("A\<c-z>\<esc>", 'tnix')
  call assert_equal(["abc\<c-z>"], getline(1,'$'))
  bw!
  " TODO: How to Test Ctrl-Z in insert mode, e.g. suspend?
endfunc

func! Test_edit_DROP()
  if !has("dnd")
    return
  endif
  new
  call setline(1, ['abc def ghi'])
  call cursor(1, 1)
  try
    call feedkeys("i\<Drop>\<Esc>", 'tnix')
    call assert_fails(1, 'Invalid register name')
  catch /^Vim\%((\a\+)\)\=:E353/
    call assert_true(1, 'error caught')
  endtry
  bw!
endfunc

func! Test_edit_CTRL_V()
  throw 'skipped: Nvim does not support test_override()'
  if has("ebcdic")
    return
  endif
  new
  call setline(1, ['abc'])
  call cursor(2, 1)
  " force some redraws
  set showmode showcmd
  "call test_override_char_avail(1)
  call test_override('ALL', 1)
  call feedkeys("A\<c-v>\<c-n>\<c-v>\<c-l>\<c-v>\<c-b>\<esc>", 'tnix')
  call assert_equal(["abc\x0e\x0c\x02"], getline(1, '$'))

  if has("rightleft") && exists("+rl")
    set rl
    call setline(1, ['abc'])
    call cursor(2, 1)
    call feedkeys("A\<c-v>\<c-n>\<c-v>\<c-l>\<c-v>\<c-b>\<esc>", 'tnix')
    call assert_equal(["abc\x0e\x0c\x02"], getline(1, '$'))
    set norl
  endif

  call test_override('ALL', 0)
  set noshowmode showcmd
  bw!
endfunc

func! Test_edit_F1()
  " Pressing <f1>
  new
  call feedkeys(":set im\<cr>\<f1>\<c-l>", 'tnix')
  set noinsertmode
  call assert_equal('help', &buftype)
  bw
  bw
endfunc

func! Test_edit_F21()
  " Pressing <f21>
  " sends a netbeans command
  if has("netbeans_intg")
    new
    " I have no idea what this is supposed to do :)
    call feedkeys("A\<F21>\<F1>\<esc>", 'tnix')
    bw
  endif
endfunc

func! Test_edit_HOME_END()
  " Test Home/End Keys
  new
  set foldopen+=hor
  call setline(1, ['abc', 'def'])
  call cursor(1, 1)
  call feedkeys("AX\<Home>Y\<esc>", 'tnix')
  call cursor(2, 1)
  call feedkeys("iZ\<End>Y\<esc>", 'tnix')
  call assert_equal(['YabcX', 'ZdefY'], getline(1, '$'))

  set foldopen-=hor
  bw!
endfunc

func! Test_edit_INS()
  " Test for Pressing <Insert>
  new
  call setline(1, ['abc', 'def'])
  call cursor(1, 1)
  call feedkeys("i\<Insert>ZYX>", 'tnix')
  call assert_equal(['ZYX>', 'def'], getline(1, '$'))
  call setline(1, ['abc', 'def'])
  call cursor(1, 1)
  call feedkeys("i\<Insert>Z\<Insert>YX>", 'tnix')
  call assert_equal(['ZYX>bc', 'def'], getline(1, '$'))
  bw!
endfunc

func! Test_edit_LEFT_RIGHT()
  " Left, Shift-Left, Right, Shift-Right
  new
  call setline(1, ['abc def ghi', 'ABC DEF GHI', 'ZZZ YYY XXX'])
  let _ww=&ww
  set ww=
  call cursor(2, 1)
  call feedkeys("i\<left>\<esc>", 'tnix')
  call assert_equal([0, 2, 1, 0], getpos('.'))
  " Is this a bug, <s-left> does not respect whichwrap option
  call feedkeys("i\<s-left>\<esc>", 'tnix')
  call assert_equal([0, 1, 8, 0], getpos('.'))
  call feedkeys("i". repeat("\<s-left>", 3). "\<esc>", 'tnix')
  call assert_equal([0, 1, 1, 0], getpos('.'))
  call feedkeys("i\<right>\<esc>", 'tnix')
  call assert_equal([0, 1, 1, 0], getpos('.'))
  call feedkeys("i\<right>\<right>\<esc>", 'tnix')
  call assert_equal([0, 1, 2, 0], getpos('.'))
  call feedkeys("A\<right>\<esc>", 'tnix')
  call assert_equal([0, 1, 11, 0], getpos('.'))
  call feedkeys("A\<s-right>\<esc>", 'tnix')
  call assert_equal([0, 2, 1, 0], getpos('.'))
  call feedkeys("i\<s-right>\<esc>", 'tnix')
  call assert_equal([0, 2, 4, 0], getpos('.'))
  call cursor(3, 11)
  call feedkeys("A\<right>\<esc>", 'tnix')
  call feedkeys("A\<s-right>\<esc>", 'tnix')
  call assert_equal([0, 3, 11, 0], getpos('.'))
  call cursor(2, 11)
  " <S-Right> does not respect 'whichwrap' option
  call feedkeys("A\<s-right>\<esc>", 'tnix')
  call assert_equal([0, 3, 1, 0], getpos('.'))
  " Check motion when 'whichwrap' contains cursor keys for insert mode
  set ww+=[,]
  call cursor(2, 1)
  call feedkeys("i\<left>\<esc>", 'tnix')
  call assert_equal([0, 1, 11, 0], getpos('.'))
  call cursor(2, 11)
  call feedkeys("A\<right>\<esc>", 'tnix')
  call assert_equal([0, 3, 1, 0], getpos('.'))
  call cursor(2, 11)
  call feedkeys("A\<s-right>\<esc>", 'tnix')
  call assert_equal([0, 3, 1, 0], getpos('.'))
  let &ww = _ww
  bw!
endfunc

func! Test_edit_MOUSE()
  " This is a simple test, since we not really using the mouse here
  if !has("mouse")
    return
  endif
  10new
  call setline(1, range(1, 100))
  call cursor(1, 1)
  set mouse=a
  call feedkeys("A\<ScrollWheelDown>\<esc>", 'tnix')
  call assert_equal([0, 4, 1, 0], getpos('.'))
  " This should move by one pageDown, but only moves
  " by one line when the test is run...
  call feedkeys("A\<S-ScrollWheelDown>\<esc>", 'tnix')
  call assert_equal([0, 5, 1, 0], getpos('.'))
  set nostartofline
  call feedkeys("A\<C-ScrollWheelDown>\<esc>", 'tnix')
  call assert_equal([0, 6, 1, 0], getpos('.'))
  call feedkeys("A\<LeftMouse>\<esc>", 'tnix')
  call assert_equal([0, 6, 1, 0], getpos('.'))
  call feedkeys("A\<RightMouse>\<esc>", 'tnix')
  call assert_equal([0, 6, 1, 0], getpos('.'))
  call cursor(1, 100)
  norm! zt
  " this should move by a screen up, but when the test
  " is run, it moves up to the top of the buffer...
  call feedkeys("A\<ScrollWheelUp>\<esc>", 'tnix')
  call assert_equal([0, 1, 1, 0], getpos('.'))
  call cursor(1, 30)
  norm! zt
  call feedkeys("A\<S-ScrollWheelUp>\<esc>", 'tnix')
  call assert_equal([0, 1, 1, 0], getpos('.'))
  call cursor(1, 30)
  norm! zt
  call feedkeys("A\<C-ScrollWheelUp>\<esc>", 'tnix')
  call assert_equal([0, 1, 1, 0], getpos('.'))
  %d
  call setline(1, repeat(["12345678901234567890"], 100))
  call cursor(2, 1)
  call feedkeys("A\<ScrollWheelRight>\<esc>", 'tnix')
  call assert_equal([0, 2, 20, 0], getpos('.'))
  call feedkeys("A\<ScrollWheelLeft>\<esc>", 'tnix')
  call assert_equal([0, 2, 20, 0], getpos('.'))
  call feedkeys("A\<S-ScrollWheelRight>\<esc>", 'tnix')
  call assert_equal([0, 2, 20, 0], getpos('.'))
  call feedkeys("A\<S-ScrollWheelLeft>\<esc>", 'tnix')
  call assert_equal([0, 2, 20, 0], getpos('.'))
  call feedkeys("A\<C-ScrollWheelRight>\<esc>", 'tnix')
  call assert_equal([0, 2, 20, 0], getpos('.'))
  call feedkeys("A\<C-ScrollWheelLeft>\<esc>", 'tnix')
  call assert_equal([0, 2, 20, 0], getpos('.'))
  set mouse& startofline
  bw!
endfunc

func! Test_edit_PAGEUP_PAGEDOWN()
  10new
  call setline(1, repeat(['abc def ghi'], 30))
  call cursor(1, 1)
  call feedkeys("i\<PageDown>\<esc>", 'tnix')
  call assert_equal([0, 9, 1, 0], getpos('.'))
  call feedkeys("i\<PageDown>\<esc>", 'tnix')
  call assert_equal([0, 17, 1, 0], getpos('.'))
  call feedkeys("i\<PageDown>\<esc>", 'tnix')
  call assert_equal([0, 25, 1, 0], getpos('.'))
  call feedkeys("i\<PageDown>\<esc>", 'tnix')
  call assert_equal([0, 30, 1, 0], getpos('.'))
  call feedkeys("i\<PageDown>\<esc>", 'tnix')
  call assert_equal([0, 30, 1, 0], getpos('.'))
  call feedkeys("A\<PageUp>\<esc>", 'tnix')
  call assert_equal([0, 29, 1, 0], getpos('.'))
  call feedkeys("A\<PageUp>\<esc>", 'tnix')
  call assert_equal([0, 21, 1, 0], getpos('.'))
  call feedkeys("A\<PageUp>\<esc>", 'tnix')
  call assert_equal([0, 13, 1, 0], getpos('.'))
  call feedkeys("A\<PageUp>\<esc>", 'tnix')
  call assert_equal([0, 5, 1, 0], getpos('.'))
  call feedkeys("A\<PageUp>\<esc>", 'tnix')
  call assert_equal([0, 5, 11, 0], getpos('.'))
  " <S-Up> is the same as <PageUp>
  " <S-Down> is the same as <PageDown>
  call cursor(1, 1)
  call feedkeys("i\<S-Down>\<esc>", 'tnix')
  call assert_equal([0, 9, 1, 0], getpos('.'))
  call feedkeys("i\<S-Down>\<esc>", 'tnix')
  call assert_equal([0, 17, 1, 0], getpos('.'))
  call feedkeys("i\<S-Down>\<esc>", 'tnix')
  call assert_equal([0, 25, 1, 0], getpos('.'))
  call feedkeys("i\<S-Down>\<esc>", 'tnix')
  call assert_equal([0, 30, 1, 0], getpos('.'))
  call feedkeys("i\<S-Down>\<esc>", 'tnix')
  call assert_equal([0, 30, 1, 0], getpos('.'))
  call feedkeys("A\<S-Up>\<esc>", 'tnix')
  call assert_equal([0, 29, 1, 0], getpos('.'))
  call feedkeys("A\<S-Up>\<esc>", 'tnix')
  call assert_equal([0, 21, 1, 0], getpos('.'))
  call feedkeys("A\<S-Up>\<esc>", 'tnix')
  call assert_equal([0, 13, 1, 0], getpos('.'))
  call feedkeys("A\<S-Up>\<esc>", 'tnix')
  call assert_equal([0, 5, 1, 0], getpos('.'))
  call feedkeys("A\<S-Up>\<esc>", 'tnix')
  call assert_equal([0, 5, 11, 0], getpos('.'))
  set nostartofline
  call cursor(30, 11)
  norm! zt
  call feedkeys("A\<PageUp>\<esc>", 'tnix')
  call assert_equal([0, 29, 11, 0], getpos('.'))
  call feedkeys("A\<PageUp>\<esc>", 'tnix')
  call assert_equal([0, 21, 11, 0], getpos('.'))
  call feedkeys("A\<PageUp>\<esc>", 'tnix')
  call assert_equal([0, 13, 11, 0], getpos('.'))
  call feedkeys("A\<PageUp>\<esc>", 'tnix')
  call assert_equal([0, 5, 11, 0], getpos('.'))
  call feedkeys("A\<PageUp>\<esc>", 'tnix')
  call assert_equal([0, 5, 11, 0], getpos('.'))
  call cursor(1, 1)
  call feedkeys("A\<PageDown>\<esc>", 'tnix')
  call assert_equal([0, 9, 11, 0], getpos('.'))
  call feedkeys("A\<PageDown>\<esc>", 'tnix')
  call assert_equal([0, 17, 11, 0], getpos('.'))
  call feedkeys("A\<PageDown>\<esc>", 'tnix')
  call assert_equal([0, 25, 11, 0], getpos('.'))
  call feedkeys("A\<PageDown>\<esc>", 'tnix')
  call assert_equal([0, 30, 11, 0], getpos('.'))
  call feedkeys("A\<PageDown>\<esc>", 'tnix')
  call assert_equal([0, 30, 11, 0], getpos('.'))
  " <S-Up> is the same as <PageUp>
  " <S-Down> is the same as <PageDown>
  call cursor(30, 11)
  norm! zt
  call feedkeys("A\<S-Up>\<esc>", 'tnix')
  call assert_equal([0, 29, 11, 0], getpos('.'))
  call feedkeys("A\<S-Up>\<esc>", 'tnix')
  call assert_equal([0, 21, 11, 0], getpos('.'))
  call feedkeys("A\<S-Up>\<esc>", 'tnix')
  call assert_equal([0, 13, 11, 0], getpos('.'))
  call feedkeys("A\<S-Up>\<esc>", 'tnix')
  call assert_equal([0, 5, 11, 0], getpos('.'))
  call feedkeys("A\<S-Up>\<esc>", 'tnix')
  call assert_equal([0, 5, 11, 0], getpos('.'))
  call cursor(1, 1)
  call feedkeys("A\<S-Down>\<esc>", 'tnix')
  call assert_equal([0, 9, 11, 0], getpos('.'))
  call feedkeys("A\<S-Down>\<esc>", 'tnix')
  call assert_equal([0, 17, 11, 0], getpos('.'))
  call feedkeys("A\<S-Down>\<esc>", 'tnix')
  call assert_equal([0, 25, 11, 0], getpos('.'))
  call feedkeys("A\<S-Down>\<esc>", 'tnix')
  call assert_equal([0, 30, 11, 0], getpos('.'))
  call feedkeys("A\<S-Down>\<esc>", 'tnix')
  call assert_equal([0, 30, 11, 0], getpos('.'))
  bw!
endfunc

func! Test_edit_forbidden()
  new
  " 1) edit in the sandbox is not allowed
  call setline(1, 'a')
  com! Sandbox :sandbox call feedkeys("i\<del>\<esc>", 'tnix')
  call assert_fails(':Sandbox', 'E48:')
  com! Sandbox :sandbox exe "norm! i\<del>"
  call assert_fails(':Sandbox', 'E48:')
  delcom Sandbox
  call assert_equal(['a'], getline(1,'$'))
  " 2) edit with textlock set
  fu! DoIt()
    call feedkeys("i\<del>\<esc>", 'tnix')
  endfu
  au InsertCharPre <buffer> :call DoIt()
  try
    call feedkeys("ix\<esc>", 'tnix')
    call assert_fails(1, 'textlock')
  catch /^Vim\%((\a\+)\)\=:E523/ " catch E523: not allowed here
  endtry
  " TODO: Might be a bug: should x really be inserted here
  call assert_equal(['xa'], getline(1, '$'))
  delfu DoIt
  try
    call feedkeys("ix\<esc>", 'tnix')
    call assert_fails(1, 'unknown function')
  catch /^Vim\%((\a\+)\)\=:E117/ " catch E117: unknown function
  endtry
  au! InsertCharPre
  " 3) edit when completion is shown
  fun! Complete(findstart, base)
    if a:findstart
      return col('.')
    else
      call feedkeys("i\<del>\<esc>", 'tnix')
      return []
    endif
  endfun
  set completefunc=Complete
  try
    call feedkeys("i\<c-x>\<c-u>\<esc>", 'tnix')
    call assert_fails(1, 'change in complete function')
  catch /^Vim\%((\a\+)\)\=:E523/ " catch E523
  endtry
  delfu Complete
  set completefunc=
  if has("rightleft") && exists("+fkmap")
    " 4) 'R' when 'fkmap' and 'revins' is set.
    set revins fkmap
    try
      normal Ri
      call assert_fails(1, "R with 'fkmap' and 'ri' set")
    catch
    finally
      set norevins nofkmap
    endtry
  endif
  bw!
endfunc

func! Test_edit_rightleft()
  " Cursor in rightleft mode moves differently
  if !exists("+rightleft")
    return
  endif
  call NewWindow(10, 20)
  call setline(1, ['abc', 'def', 'ghi'])
  call cursor(1, 2)
  set rightleft
  " Screen looks as expected
  let lines = ScreenLines([1, 4], winwidth(0))
  let expect = [
        \"                 cba",
        \"                 fed",
        \"                 ihg",
        \"                   ~"]
  call assert_equal(join(expect, "\n"), join(lines, "\n"))
  " 2) right moves to the left
  call feedkeys("i\<right>\<esc>x", 'txin')
  call assert_equal(['bc', 'def', 'ghi'], getline(1,'$'))
  call cursor(1, 2)
  call feedkeys("i\<s-right>\<esc>", 'txin')
  call cursor(1, 2)
  call feedkeys("i\<c-right>\<esc>", 'txin')
  " Screen looks as expected
  let lines = ScreenLines([1, 4], winwidth(0))
  let expect = [
        \"                  cb",
        \"                 fed",
        \"                 ihg",
        \"                   ~"]
  call assert_equal(join(expect, "\n"), join(lines, "\n"))
  " 2) left moves to the right
  call setline(1, ['abc', 'def', 'ghi'])
  call cursor(1, 2)
  call feedkeys("i\<left>\<esc>x", 'txin')
  call assert_equal(['ac', 'def', 'ghi'], getline(1,'$'))
  call cursor(1, 2)
  call feedkeys("i\<s-left>\<esc>", 'txin')
  call cursor(1, 2)
  call feedkeys("i\<c-left>\<esc>", 'txin')
  " Screen looks as expected
  let lines = ScreenLines([1, 4], winwidth(0))
  let expect = [
        \"                  ca",
        \"                 fed",
        \"                 ihg",
        \"                   ~"]
  call assert_equal(join(expect, "\n"), join(lines, "\n"))
  set norightleft
  bw!
endfunc

func Test_edit_quit()
  edit foo.txt
  split
  new
  call setline(1, 'hello')
  3wincmd w
  redraw!
  call assert_fails('1q', 'E37:')
  bwipe! foo.txt
  only
endfunc

func Test_edit_complete_very_long_name()
  if !has('unix')
    " Long directory names only work on Unix.
    return
  endif

  let dirname = getcwd() . "/Xdir"
  let longdirname = dirname . repeat('/' . repeat('d', 255), 4)
  try
    call mkdir(longdirname, 'p')
  catch /E739:/
    " Long directory name probably not supported.
    call delete(dirname, 'rf')
    return
  endtry

  " Try to get the Vim window position before setting 'columns'.
  let winposx = getwinposx()
  let winposy = getwinposy()
  let save_columns = &columns
  " Need at least about 1100 columns to reproduce the problem.
  set columns=2000
  call assert_equal(2000, &columns)
  set noswapfile

  let longfilename = longdirname . '/' . repeat('a', 255)
  call writefile(['Totum', 'Table'], longfilename)
  new
  exe "next Xfile " . longfilename
  exe "normal iT\<C-N>"

  bwipe!
  exe 'bwipe! ' . longfilename
  call delete(dirname, 'rf')
  let &columns = save_columns
  if winposx >= 0 && winposy >= 0
    exe 'winpos ' . winposx . ' ' . winposy
  endif
  set swapfile&
endfunc
