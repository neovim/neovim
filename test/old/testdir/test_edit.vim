" Test for edit functions

if exists("+t_kD")
  let &t_kD="[3;*~"
endif

source check.vim
source screendump.vim
source view_util.vim

" Needs to come first until the bug in getchar() is
" fixed: https://groups.google.com/d/msg/vim_dev/fXL9yme4H4c/bOR-U6_bAQAJ
func Test_edit_00b()
  new
  call setline(1, ['abc '])
  inoreabbr <buffer> h here some more
  call cursor(1, 4)
  " <esc> expands the abbreviation and ends insert mode
  " call feedkeys(":set im\<cr> h\<c-l>:set noim\<cr>", 'tix')
  call feedkeys("i h\<esc>", 'tix')
  call assert_equal(['abc here some more '], getline(1,'$'))
  iunabbr <buffer> h
  bw!
endfunc

func Test_edit_01()
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
  call setline(1, "\u0401")
  call feedkeys("i\<del>\<esc>", 'tnix')
  call assert_equal([''], getline(1,'$'))
  %d
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

func Test_edit_02()
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

func Test_edit_03()
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

func Test_edit_04()
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

func Test_edit_05()
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

func Test_edit_06()
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

func Test_edit_07()
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
  call assert_equal(["Jan\<c-l>",''], 1->getline('$'))
  %d
  call setline(1, 'J')
  call feedkeys("A\<f5>\<c-p>u\<down>\<c-l>\<cr>", 'tx')
  call assert_equal(["January"], 1->getline('$'))

  delfu ListMonths
  delfu DoIt
  iunmap <buffer> <f5>
  bw!
endfunc

func Test_edit_08()
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

func Test_edit_09()
  " test i_CTRL-\ combinations
  new
  call setline(1, ['abc', 'def', 'ghi'])
  call cursor(1, 1)
  " 1) CTRL-\ CTLR-N
  " call feedkeys(":set im\<cr>\<c-\>\<c-n>ccABC\<c-l>", 'txin')
  call feedkeys("i\<c-\>\<c-n>ccABC\<esc>", 'txin')
  call assert_equal(['ABC', 'def', 'ghi'], getline(1,'$'))
  call setline(1, ['ABC', 'def', 'ghi'])
  " 2) CTRL-\ CTLR-G
  " CTRL-\ CTRL-G goes to Insert mode when 'insertmode' is set, but
  " 'insertmode' is now removed so skip this test
  " call feedkeys("j0\<c-\>\<c-g>ZZZ\<cr>\<esc>", 'txin')
  " call assert_equal(['ABC', 'ZZZ', 'def', 'ghi'], getline(1,'$'))
  " call feedkeys("I\<c-\>\<c-g>YYY\<c-l>", 'txin')
  " call assert_equal(['ABC', 'ZZZ', 'YYYdef', 'ghi'], getline(1,'$'))
  " set noinsertmode
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

func Test_edit_11()
  " Test that indenting kicks in
  new
  set cindent
  call setline(1, ['{', '', ''])
  call cursor(2, 1)
  call feedkeys("i\<c-f>int c;\<esc>", 'tnix')
  call cursor(3, 1)
  call feedkeys("\<Insert>/* comment */", 'tnix')
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

func Test_edit_11_indentexpr()
  " Test that indenting kicks in
  new
  " Use indentexpr instead of cindenting
  func! Do_Indent()
    let pline=prevnonblank(v:lnum)
    if empty(getline(v:lnum))
      if getline(pline) =~ 'if\|then'
        return shiftwidth()
      else
        return 0
      endif
    else
        return 0
    endif
  endfunc
  setl indentexpr=Do_Indent() indentkeys+=0=then,0=fi
  call setline(1, ['if [ $this ]'])
  call cursor(1, 1)
  call feedkeys("othen\<cr>that\<cr>fi", 'tnix')
  call assert_equal(['if [ $this ]', "then", "\<tab>that", "fi"], getline(1, '$'))
  set cinkeys&vim indentkeys&vim
  set nocindent indentexpr=
  delfu Do_Indent

  " Using a script-local function
  func s:NewIndentExpr()
  endfunc
  set indentexpr=s:NewIndentExpr()
  call assert_equal(expand('<SID>') .. 'NewIndentExpr()', &indentexpr)
  call assert_equal(expand('<SID>') .. 'NewIndentExpr()', &g:indentexpr)
  set indentexpr=<SID>NewIndentExpr()
  call assert_equal(expand('<SID>') .. 'NewIndentExpr()', &indentexpr)
  call assert_equal(expand('<SID>') .. 'NewIndentExpr()', &g:indentexpr)
  setlocal indentexpr=
  setglobal indentexpr=s:NewIndentExpr()
  call assert_equal(expand('<SID>') .. 'NewIndentExpr()', &g:indentexpr)
  call assert_equal('', &indentexpr)
  new
  call assert_equal(expand('<SID>') .. 'NewIndentExpr()', &indentexpr)
  bw!
  setglobal indentexpr=<SID>NewIndentExpr()
  call assert_equal(expand('<SID>') .. 'NewIndentExpr()', &g:indentexpr)
  call assert_equal('', &indentexpr)
  new
  call assert_equal(expand('<SID>') .. 'NewIndentExpr()', &indentexpr)
  bw!
  set indentexpr&

  bw!
endfunc

" Test changing indent in replace mode
func Test_edit_12()
  new
  call setline(1, ["\tabc", "\tdef"])
  call cursor(2, 4)
  call feedkeys("R^\<c-d>", 'tnix')
  call assert_equal(["\tabc", "def"], getline(1, '$'))
  call assert_equal([0, 2, 2, 0], '.'->getpos())
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
  set sw&

  " In replace mode, after hitting enter in a line with tab characters,
  " pressing backspace should restore the tab characters.
  %d
  setlocal autoindent backspace=2
  call setline(1, "\tone\t\ttwo")
  exe "normal ggRred\<CR>six" .. repeat("\<BS>", 8)
  call assert_equal(["\tone\t\ttwo"], getline(1, '$'))
  bw!
endfunc

func Test_edit_13()
  " Test smartindenting
  new
  set smartindent autoindent
  call setline(1, ["\tabc"])
  call feedkeys("A {\<cr>more\<cr>}\<esc>", 'tnix')
  call assert_equal(["\tabc {", "\t\tmore", "\t}"], getline(1, '$'))
  set smartindent& autoindent&
  bwipe!

  " Test autoindent removing indent of blank line.
  new
  call setline(1, '    foo bar baz')
  set autoindent
  exe "normal 0eea\<CR>\<CR>\<Esc>"
  call assert_equal("    foo bar", getline(1))
  call assert_equal("", getline(2))
  call assert_equal("    baz", getline(3))
  set autoindent&

  " pressing <C-U> to erase line should keep the indent with 'autoindent'
  set backspace=2 autoindent
  %d
  exe "normal i\tone\<CR>three\<C-U>two"
  call assert_equal(["\tone", "\ttwo"], getline(1, '$'))
  set backspace& autoindent&

  bwipe!
endfunc

" Test for autoindent removing indent when insert mode is stopped.  Some parts
" of the code is exercised only when interactive mode is used. So use Vim in a
" terminal.
func Test_autoindent_remove_indent()
  CheckRunVimInTerminal
  let buf = RunVimInTerminal('-N Xarifile', {'rows': 6, 'cols' : 20})
  call TermWait(buf)
  call term_sendkeys(buf, ":set autoindent\n")
  " leaving insert mode in a new line with indent added by autoindent, should
  " remove the indent.
  call term_sendkeys(buf, "i\<Tab>foo\<CR>\<Esc>")
  " Need to delay for some time, otherwise the code in getchar.c will not be
  " exercised.
  call TermWait(buf, 50)
  " when a line is wrapped and the cursor is at the start of the second line,
  " leaving insert mode, should move the cursor back to the first line.
  call term_sendkeys(buf, "o" .. repeat('x', 20) .. "\<Esc>")
  " Need to delay for some time, otherwise the code in getchar.c will not be
  " exercised.
  call TermWait(buf, 50)
  call term_sendkeys(buf, ":w\n")
  call TermWait(buf)
  call StopVimInTerminal(buf)
  call assert_equal(["\tfoo", '', repeat('x', 20)], readfile('Xarifile'))
  call delete('Xarifile')
endfunc

func Test_edit_CR()
  " Test for <CR> in insert mode
  " basically only in quickfix mode it's tested, the rest
  " has been taken care of by other tests
  CheckFeature quickfix
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

func Test_edit_CTRL_()
  " disabled for Windows builds, why?
  if !has("rightleft") || has("win32")
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
  " call assert_equal(["æèñabc"], getline(1, '$'))
  call assert_equal(["zyxabc"], getline(1, '$'))
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
func Test_edit_00a_CTRL_A()
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

func Test_edit_CTRL_EY()
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

func Test_edit_CTRL_G()
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
  call assert_nobeep("normal! i\<c-g>\<esc>")
  bw!
endfunc

func Test_edit_CTRL_I()
  " Tab in completion mode
  let path=expand("%:p:h")
  new
  call setline(1, [path. "/", ''])
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

func Test_edit_CTRL_K()
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

  " press an unexpected key after dictionary completion
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

  if exists('*test_override')
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

func Test_edit_CTRL_L()
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
  call assert_equal(['one', 'two', 'three', 'two', '', '', ''], getline(1, '$'))
  call feedkeys("cct\<c-x>\<c-l>\<c-n>\<c-n>\<c-n>\<esc>", 'tnix')
  call assert_equal(['one', 'two', 'three', 'three', '', '', ''], getline(1, '$'))
  call feedkeys("cct\<c-x>\<c-l>\<c-n>\<c-n>\<c-n>\<c-n>\<esc>", 'tnix')
  call assert_equal(['one', 'two', 'three', 't', '', '', ''], getline(1, '$'))
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

func Test_edit_CTRL_N()
  " Check keyword completion
  " for e in ['latin1', 'utf-8']
  for e in ['utf-8']
    exe 'set encoding=' .. e
    new
    set complete=.
    call setline(1, ['INFER', 'loWER', '', '', ])
    call cursor(3, 1)
    call feedkeys("Ai\<c-n>\<cr>\<esc>", "tnix")
    call feedkeys("ILO\<c-n>\<cr>\<esc>", 'tnix')
    call assert_equal(['INFER', 'loWER', 'i', 'LO', '', ''], getline(1, '$'), e)
    %d
    call setline(1, ['INFER', 'loWER', '', '', ])
    call cursor(3, 1)
    set ignorecase infercase
    call feedkeys("Ii\<c-n>\<cr>\<esc>", "tnix")
    call feedkeys("ILO\<c-n>\<cr>\<esc>", 'tnix')
    call assert_equal(['INFER', 'loWER', 'infer', 'LOWER', '', ''], getline(1, '$'), e)
    set noignorecase noinfercase
    %d
    call setline(1, ['one word', 'two word'])
    exe "normal! Goo\<C-P>\<C-X>\<C-P>"
    call assert_equal('one word', getline(3))
    %d
    set complete&
    bw!
  endfor
endfunc

func Test_edit_CTRL_O()
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

func Test_edit_CTRL_R()
  " Insert Register
  new
  " call test_override("ALL", 1)
  set showcmd
  call feedkeys("AFOOBAR eins zwei\<esc>", 'tnix')
  call feedkeys("O\<c-r>.", 'tnix')
  call feedkeys("O\<c-r>=10*500\<cr>\<esc>", 'tnix')
  call feedkeys("O\<c-r>=getreg('=', 1)\<cr>\<esc>", 'tnix')
  call assert_equal(["getreg('=', 1)", '5000', "FOOBAR eins zwei", "FOOBAR eins zwei"], getline(1, '$'))
  " call test_override("ALL", 0)
  set noshowcmd
  bw!
endfunc

func Test_edit_CTRL_S()
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

func Test_edit_CTRL_T()
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

" Test thesaurus completion with different encodings
func Test_thesaurus_complete_with_encoding()
  call writefile(['angry furious mad enraged'], 'Xthesaurus')
  set thesaurus=Xthesaurus
  " for e in ['latin1', 'utf-8']
  for e in ['utf-8']
    exe 'set encoding=' .. e
    new
    call setline(1, 'mad')
    call cursor(1, 1)
    call feedkeys("A\<c-x>\<c-t>\<cr>\<esc>", 'tnix')
    call assert_equal(['mad', ''], getline(1, '$'))
    bw!
  endfor
  set thesaurus=
  call delete('Xthesaurus')
endfunc

" Test 'thesaurusfunc'
func MyThesaurus(findstart, base)
  let mythesaurus = [
        \ #{word: "happy",
        \   synonyms: "cheerful,blissful,flying high,looking good,peppy"},
        \ #{word: "kind",
        \   synonyms: "amiable,bleeding-heart,heart in right place"}]
  if a:findstart
    " locate the start of the word
    let line = getline('.')
    let start = col('.') - 1
    while start > 0 && line[start - 1] =~ '\a'
      let start -= 1
    endwhile
    return start
  else
    " find strings matching with "a:base"
    let res = []
    for w in mythesaurus
      if w.word =~ '^' . a:base
        call add(res, w.word)
        call extend(res, split(w.synonyms, ","))
      endif
    endfor
    return res
  endif
endfunc

func Test_thesaurus_func()
  new
  set thesaurus=notused
  set thesaurusfunc=NotUsed
  setlocal thesaurusfunc=MyThesaurus
  call setline(1, "an ki")
  call cursor(1, 1)
  call feedkeys("A\<c-x>\<c-t>\<c-n>\<cr>\<esc>", 'tnix')
  call assert_equal(['an amiable', ''], getline(1, '$'))

  setlocal thesaurusfunc=NonExistingFunc
  call assert_fails("normal $a\<C-X>\<C-T>", 'E117:')

  setlocal thesaurusfunc=
  set thesaurusfunc=NonExistingFunc
  call assert_fails("normal $a\<C-X>\<C-T>", 'E117:')
  %bw!

  set thesaurusfunc=
  set thesaurus=
endfunc

func Test_edit_CTRL_U()
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

func Test_edit_completefunc_delete()
  func CompleteFunc(findstart, base)
    if a:findstart == 1
      return col('.') - 1
    endif
    normal dd
    return ['a', 'b']
  endfunc
  new
  set completefunc=CompleteFunc
  call setline(1, ['', 'abcd', ''])
  2d
  call assert_fails("normal 2G$a\<C-X>\<C-U>", 'E565:')
  bwipe!
endfunc

func Test_edit_CTRL_Z()
  " Ctrl-Z when insertmode is not set inserts it literally
  new
  call setline(1, 'abc')
  call feedkeys("A\<c-z>\<esc>", 'tnix')
  call assert_equal(["abc\<c-z>"], getline(1,'$'))
  bw!
  " TODO: How to Test Ctrl-Z in insert mode, e.g. suspend?
endfunc

func Test_edit_DROP()
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

func Test_edit_CTRL_V()
  new
  call setline(1, ['abc'])
  call cursor(2, 1)

  " force some redraws
  set showmode showcmd
  " call test_override('char_avail', 1)

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

  set noshowmode showcmd
  " call test_override('char_avail', 0)

  " No modifiers should be applied to the char typed using i_CTRL-V_digit.
  call feedkeys(":append\<CR>\<C-V>76c\<C-V>76\<C-F2>\<C-V>u3c0j\<C-V>u3c0\<M-F3>\<CR>.\<CR>", 'tnix')
  call assert_equal('LcL<C-F2>πjπ<M-F3>', getline(2))

  if has('osx')
    " A char with a modifier should not be a valid char for i_CTRL-V_digit.
    call feedkeys("o\<C-V>\<D-j>\<C-V>\<D-1>\<C-V>\<D-o>\<C-V>\<D-x>\<C-V>\<D-u>", 'tnix')
    call assert_equal('<D-j><D-1><D-o><D-x><D-u>', getline(3))
  endif

  bw!
endfunc

func Test_edit_F1()
  CheckFeature quickfix

  " Pressing <f1>
  new
  " call feedkeys(":set im\<cr>\<f1>\<c-l>", 'tnix')
  call feedkeys("i\<f1>\<esc>", 'tnix')
  set noinsertmode
  call assert_equal('help', &buftype)
  bw
  bw
endfunc

func Test_edit_F21()
  " Pressing <f21>
  " sends a netbeans command
  if has("netbeans_intg")
    new
    " I have no idea what this is supposed to do :)
    call feedkeys("A\<F21>\<F1>\<esc>", 'tnix')
    bw
  endif
endfunc

func Test_edit_HOME_END()
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

func Test_edit_INS()
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

func Test_edit_LEFT_RIGHT()
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

func Test_edit_MOUSE()
  " This is a simple test, since we're not really using the mouse here
  CheckFeature mouse
  10new
  call setline(1, range(1, 100))
  call cursor(1, 1)
  call assert_equal(1, line('w0'))
  call assert_equal(10, line('w$'))
  set mouse=a
  " One scroll event moves three lines.
  call feedkeys("A\<ScrollWheelDown>\<esc>", 'tnix')
  call assert_equal(4, line('w0'))
  call assert_equal(13, line('w$'))
  " This should move by one page down.
  call feedkeys("A\<S-ScrollWheelDown>\<esc>", 'tnix')
  call assert_equal(14, line('w0'))
  set nostartofline
  " Another page down.
  call feedkeys("A\<C-ScrollWheelDown>\<esc>", 'tnix')
  call assert_equal(24, line('w0'))

  call assert_equal([0, 24, 2, 0], getpos('.'))
  call Ntest_setmouse(4, 3)
  call feedkeys("A\<LeftMouse>\<esc>", 'tnix')
  call assert_equal([0, 27, 2, 0], getpos('.'))
  set mousemodel=extend
  call Ntest_setmouse(5, 3)
  call feedkeys("A\<RightMouse>\<esc>\<esc>", 'tnix')
  call assert_equal([0, 28, 2, 0], getpos('.'))
  set mousemodel&
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

func Test_edit_PAGEUP_PAGEDOWN()
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
  call assert_equal([0, 10, 1, 0], getpos('.'))
  call feedkeys("A\<PageUp>\<esc>", 'tnix')
  call assert_equal([0, 10, 11, 0], getpos('.'))
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
  call assert_equal([0, 10, 1, 0], getpos('.'))
  call feedkeys("A\<S-Up>\<esc>", 'tnix')
  call assert_equal([0, 10, 11, 0], getpos('.'))
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
  call assert_equal([0, 10, 11, 0], getpos('.'))
  call feedkeys("A\<PageUp>\<esc>", 'tnix')
  call assert_equal([0, 10, 11, 0], getpos('.'))
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
  call assert_equal([0, 10, 11, 0], getpos('.'))
  call feedkeys("A\<S-Up>\<esc>", 'tnix')
  call assert_equal([0, 10, 11, 0], getpos('.'))
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

func Test_edit_forbidden()
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
  catch /^Vim\%((\a\+)\)\=:E565/ " catch E565: not allowed here
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
  catch /^Vim\%((\a\+)\)\=:E565/ " catch E565
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

func Test_edit_rightleft()
  " Cursor in rightleft mode moves differently
  CheckFeature rightleft
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
  %d _
  " call test_override('redraw_flag', 1)
  " call test_override('char_avail', 1)
  call feedkeys("a\<C-V>x41", "xt")
  redraw!
  call assert_equal(repeat(' ', 19) .. 'A', Screenline(1))
  " call test_override('ALL', 0)
  set norightleft
  bw!
endfunc

func Test_edit_complete_very_long_name()
  " Long directory names only work on Unix.
  CheckUnix

  let dirname = getcwd() . "/Xlongdir"
  let longdirname = dirname . repeat('/' . repeat('d', 255), 4)
  try
    call mkdir(longdirname, 'p')
  catch /E739:/
    " Long directory name probably not supported.
    call delete(dirname, 'rf')
    return
  endtry

  " Try to get the Vim window position before setting 'columns', so that we can
  " move the window back to where it was.
  let winposx = getwinposx()
  let winposy = getwinposy()

  if winposx >= 0 && winposy >= 0 && !has('gui_running')
    " We did get the window position, but xterm may report the wrong numbers.
    " Move the window to the reported position and compute any offset.
    exe 'winpos ' . winposx . ' ' . winposy
    sleep 100m
    let x = getwinposx()
    if x >= 0
      let winposx += winposx - x
    endif
    let y = getwinposy()
    if y >= 0
      let winposy += winposy - y
    endif
  endif

  let save_columns = &columns
  " Need at least about 1100 columns to reproduce the problem.
  set columns=2000
  set noswapfile

  let longfilename = longdirname . '/' . repeat('a', 255)
  call writefile(['Totum', 'Table'], longfilename)
  new
  exe "next Xnofile " . longfilename
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

func Test_edit_backtick()
  next a\`b c
  call assert_equal('a`b', expand('%'))
  next
  call assert_equal('c', expand('%'))
  call assert_equal('a\`b c', expand('##'))
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

func Test_edit_alt()
  " Keeping the cursor line didn't happen when the first line has indent.
  new
  call setline(1, ['  one', 'two', 'three'])
  w XAltFile
  $
  call assert_equal(3, line('.'))
  e Xother
  e #
  call assert_equal(3, line('.'))

  bwipe XAltFile
  call delete('XAltFile')
endfunc

func Test_edit_InsertLeave()
  new
  au InsertLeavePre * let g:did_au_pre = 1
  au InsertLeave * let g:did_au = 1
  let g:did_au_pre = 0
  let g:did_au = 0
  call feedkeys("afoo\<Esc>", 'tx')
  call assert_equal(1, g:did_au_pre)
  call assert_equal(1, g:did_au)
  call assert_equal('foo', getline(1))

  let g:did_au_pre = 0
  let g:did_au = 0
  call feedkeys("Sbar\<C-C>", 'tx')
  call assert_equal(1, g:did_au_pre)
  call assert_equal(0, g:did_au)
  call assert_equal('bar', getline(1))

  inoremap x xx<Esc>
  let g:did_au_pre = 0
  let g:did_au = 0
  call feedkeys("Saax", 'tx')
  call assert_equal(1, g:did_au_pre)
  call assert_equal(1, g:did_au)
  call assert_equal('aaxx', getline(1))

  inoremap x xx<C-C>
  let g:did_au_pre = 0
  let g:did_au = 0
  call feedkeys("Sbbx", 'tx')
  call assert_equal(1, g:did_au_pre)
  call assert_equal(0, g:did_au)
  call assert_equal('bbxx', getline(1))

  bwipe!
  au! InsertLeave InsertLeavePre
  iunmap x
endfunc

func Test_edit_InsertLeave_undo()
  new XtestUndo
  set undofile
  au InsertLeave * wall
  exe "normal ofoo\<Esc>"
  call assert_equal(2, line('$'))
  normal u
  call assert_equal(1, line('$'))

  bwipe!
  au! InsertLeave
  call delete('XtestUndo')
  call delete(undofile('XtestUndo'))
  set undofile&
endfunc

" Test for inserting characters using CTRL-V followed by a number.
func Test_edit_special_chars()
  new

  let t = "o\<C-V>65\<C-V>x42\<C-V>o103 \<C-V>33a\<C-V>xfg\<C-V>o78\<Esc>"

  exe "normal " . t
  call assert_equal("ABC !a\<C-O>g\<C-G>8", getline(2))

  close!
endfunc

func Test_edit_startinsert()
  new
  set backspace+=start
  call setline(1, 'foobar')
  call feedkeys("A\<C-U>\<Esc>", 'xt')
  call assert_equal('', getline(1))

  call setline(1, 'foobar')
  call feedkeys(":startinsert!\<CR>\<C-U>\<Esc>", 'xt')
  call assert_equal('', getline(1))

  set backspace&
  bwipe!
endfunc

" Test for :startreplace and :startgreplace
func Test_edit_startreplace()
  new
  call setline(1, 'abc')
  call feedkeys("l:startreplace\<CR>xyz\e", 'xt')
  call assert_equal('axyz', getline(1))
  call feedkeys("0:startreplace!\<CR>abc\e", 'xt')
  call assert_equal('axyzabc', getline(1))
  call setline(1, "a\tb")
  call feedkeys("0l:startgreplace\<CR>xyz\e", 'xt')
  call assert_equal("axyz\tb", getline(1))
  call feedkeys("0i\<C-R>=execute('startreplace')\<CR>12\e", 'xt')
  call assert_equal("12axyz\tb", getline(1))
  close!
endfunc

func Test_edit_noesckeys()
  CheckNotGui
  new

  " <Left> moves cursor when 'esckeys' is set
  exe "set t_kl=\<Esc>OD"
  " set esckeys
  call feedkeys("axyz\<Esc>ODX", "xt")
  " call assert_equal("xyXz", getline(1))

  " <Left> exits Insert mode when 'esckeys' is off
  " set noesckeys
  call setline(1, '')
  call feedkeys("axyz\<Esc>ODX", "xt")
  call assert_equal(["DX", "xyz"], getline(1, 2))

  bwipe!
  " set esckeys
endfunc

" Test for running an invalid ex command in insert mode using CTRL-O
func Test_edit_ctrl_o_invalid_cmd()
  new
  set showmode showcmd
  " Avoid a sleep of 3 seconds. Zero might have side effects.
  " call test_override('ui_delay', 50)
  let caught_e492 = 0
  try
    call feedkeys("i\<C-O>:invalid\<CR>abc\<Esc>", "xt")
  catch /E492:/
    let caught_e492 = 1
  endtry
  call assert_equal(1, caught_e492)
  call assert_equal('abc', getline(1))
  set showmode& showcmd&
  " call test_override('ui_delay', 0)
  close!
endfunc

" Test for editing a file with a very long name
func Test_edit_illegal_filename()
  CheckEnglish
  new
  redir => msg
  exe 'edit ' . repeat('f', 5000)
  redir END
  call assert_match("Illegal file name$", split(msg, "\n")[0])
  close!
endfunc

" Test for editing a directory
func Test_edit_is_a_directory()
  CheckEnglish
  let dirname = getcwd() . "/Xeditdir"
  call mkdir(dirname, 'p')

  new
  redir => msg
  exe 'edit' dirname
  redir END
  call assert_match("is a directory$", split(msg, "\n")[0])
  bwipe!

  let dirname .= '/'

  new
  redir => msg
  exe 'edit' dirname
  redir END
  call assert_match("is a directory$", split(msg, "\n")[0])
  bwipe!

  call delete(dirname, 'rf')
endfunc

" Test for editing a file using invalid file encoding
func Test_edit_invalid_encoding()
  CheckEnglish
  call writefile([], 'Xinvfile')
  redir => msg
  new ++enc=axbyc Xinvfile
  redir END
  call assert_match('\[NOT converted\]', msg)
  call delete('Xinvfile')
  close!
endfunc

" Test for the "charconvert" option
func Test_edit_charconvert()
  CheckEnglish
  call writefile(['one', 'two'], 'Xccfile')

  " set 'charconvert' to a non-existing function
  set charconvert=NonExitingFunc()
  new
  let caught_e117 = v:false
  try
    redir => msg
    edit ++enc=axbyc Xccfile
  catch /E117:/
    let caught_e117 = v:true
  finally
    redir END
  endtry
  call assert_true(caught_e117)
  call assert_equal(['one', 'two'], getline(1, '$'))
  call assert_match("Conversion with 'charconvert' failed", msg)
  close!
  set charconvert&

  " 'charconvert' function doesn't create an output file
  func Cconv1()
  endfunc
  set charconvert=Cconv1()
  new
  redir => msg
  edit ++enc=axbyc Xccfile
  redir END
  call assert_equal(['one', 'two'], getline(1, '$'))
  call assert_match("can't read output of 'charconvert'", msg)
  close!
  delfunc Cconv1
  set charconvert&

  " 'charconvert' function to convert to upper case
  func Cconv2()
    let data = readfile(v:fname_in)
    call map(data, 'toupper(v:val)')
    call writefile(data, v:fname_out)
  endfunc
  set charconvert=Cconv2()
  new Xccfile
  write ++enc=ucase Xccfile1
  call assert_equal(['ONE', 'TWO'], readfile('Xccfile1'))
  call delete('Xccfile1')
  close!
  delfunc Cconv2
  set charconvert&

  " 'charconvert' function removes the input file
  func Cconv3()
    call delete(v:fname_in)
  endfunc
  set charconvert=Cconv3()
  new
  call assert_fails('edit ++enc=lcase Xccfile', 'E202:')
  call assert_equal([''], getline(1, '$'))
  close!
  delfunc Cconv3
  set charconvert&

  call delete('Xccfile')
endfunc

" Test for editing a file without read permission
func Test_edit_file_no_read_perm()
  CheckUnix
  CheckNotRoot

  call writefile(['one', 'two'], 'Xnrpfile')
  call setfperm('Xnrpfile', '-w-------')
  new
  redir => msg
  edit Xnrpfile
  redir END
  call assert_equal(1, &readonly)
  call assert_equal([''], getline(1, '$'))
  call assert_match('\[Permission Denied\]', msg)
  close!
  call delete('Xnrpfile')
endfunc

" Using :edit without leaving 'insertmode' should not cause Insert mode to be
" re-entered immediately after <C-L>
func Test_edit_insertmode_ex_edit()
  CheckRunVimInTerminal

  let lines =<< trim END
    set insertmode noruler
    inoremap <C-B> <Cmd>edit Xfoo<CR>
  END
  call writefile(lines, 'Xtest_edit_insertmode_ex_edit')

  let buf = RunVimInTerminal('-S Xtest_edit_insertmode_ex_edit', #{rows: 6})
  " Somehow this can be very slow with valgrind. A separate TermWait() works
  " better than a longer time with WaitForAssert() (why?)
  call TermWait(buf, 1000)
  call WaitForAssert({-> assert_match('^-- INSERT --\s*$', term_getline(buf, 6))})
  call term_sendkeys(buf, "\<C-B>\<C-L>")
  call WaitForAssert({-> assert_notmatch('^-- INSERT --\s*$', term_getline(buf, 6))})

  " clean up
  call StopVimInTerminal(buf)
  call delete('Xtest_edit_insertmode_ex_edit')
endfunc

" Pressing escape in 'insertmode' should beep
" FIXME: Execute this later, when using valgrind it makes the next test
" Test_edit_insertmode_ex_edit() fail.
func Test_z_edit_insertmode_esc_beeps()
  new
  " set insertmode
  " call assert_beeps("call feedkeys(\"one\<Esc>\", 'xt')")
  set insertmode&
  " unsupported "CTRL-G l" command should beep in insert mode.
  call assert_beeps("normal i\<C-G>l")
  bwipe!
endfunc

" Test for 'hkmap' and 'hkmapp'
func Test_edit_hkmap()
  throw "Skipped: Nvim does not support 'hkmap'"
  CheckFeature rightleft
  if has('win32') && !has('gui')
    " Test fails on the MS-Windows terminal version
    return
  endif
  new

  set revins hkmap
  let str = 'abcdefghijklmnopqrstuvwxyz'
  let str ..= 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  let str ..= '`/'',.;'
  call feedkeys('i' .. str, 'xt')
  let expected = "óõú,.;"
  let expected ..= "ZYXWVUTSRQPONMLKJIHGFEDCBA"
  let expected ..= "æèñ'äåàãø/ôíîöêìçïéòë÷âáðù"
  call assert_equal(expected, getline(1))

  %d
  set revins hkmap hkmapp
  let str = 'abcdefghijklmnopqrstuvwxyz'
  let str ..= 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  call feedkeys('i' .. str, 'xt')
  let expected = "õYXWVUTSRQóOïíLKJIHGFEDêBA"
  let expected ..= "öòXùåèúæø'ôñðîì÷çéäâóǟãëáà"
  call assert_equal(expected, getline(1))

  set revins& hkmap& hkmapp&
  close!
endfunc

" Test for 'allowrevins' and using CTRL-_ in insert mode
func Test_edit_allowrevins()
  CheckFeature rightleft
  new
  set allowrevins
  call feedkeys("iABC\<C-_>DEF\<C-_>GHI", 'xt')
  call assert_equal('ABCFEDGHI', getline(1))
  set allowrevins&
  close!
endfunc

" Test for inserting a register in insert mode using CTRL-R
func Test_edit_insert_reg()
  throw 'Skipped: use test/functional/legacy/edit_spec.lua'
  new
  let g:Line = ''
  func SaveFirstLine()
    let g:Line = Screenline(1)
    return 'r'
  endfunc
  inoremap <expr> <buffer> <F2> SaveFirstLine()
  call test_override('redraw_flag', 1)
  call test_override('char_avail', 1)
  let @r = 'sample'
  call feedkeys("a\<C-R>=SaveFirstLine()\<CR>", "xt")
  call assert_equal('"', g:Line)

  " Test for inserting an null and an empty list
  call feedkeys("a\<C-R>=test_null_list()\<CR>", "xt")
  call feedkeys("a\<C-R>=[]\<CR>", "xt")
  call assert_equal(['r'], getbufline('', 1, '$'))
  call test_override('ALL', 0)
  close!
endfunc

" Test for positioning cursor after CTRL-R expression failed
func Test_edit_ctrl_r_failed()
  CheckRunVimInTerminal

  let buf = RunVimInTerminal('', #{rows: 6, cols: 60})

  " trying to insert a blob produces an error
  call term_sendkeys(buf, "i\<C-R>=0z\<CR>")

  " ending Insert mode should put the cursor back on the ':'
  call term_sendkeys(buf, ":\<Esc>")
  call VerifyScreenDump(buf, 'Test_edit_ctlr_r_failed_1', {})

  call StopVimInTerminal(buf)
endfunc

" When a character is inserted at the last position of the last line in a
" window, the window contents should be scrolled one line up. If the top line
" is part of a fold, then the entire fold should be scrolled up.
func Test_edit_lastline_scroll()
  new
  let h = winheight(0)
  let lines = ['one', 'two', 'three']
  let lines += repeat(['vim'], h - 4)
  call setline(1, lines)
  call setline(h, repeat('x', winwidth(0) - 1))
  call feedkeys("GAx", 'xt')
  redraw!
  call assert_equal(h - 1, winline())
  call assert_equal(2, line('w0'))

  " scroll with a fold
  1,2fold
  normal gg
  call setline(h + 1, repeat('x', winwidth(0) - 1))
  call feedkeys("GAx", 'xt')
  redraw!
  call assert_equal(h - 1, winline())
  call assert_equal(3, line('w0'))

  close!
endfunc

func Test_edit_browse()
  " in the GUI this opens a file picker, we only test the terminal behavior
  CheckNotGui

  " ":browse xxx" checks for the FileExplorer augroup and assumes editing "."
  " works then.
  augroup FileExplorer
    au!
  augroup END

  " When the CASE_INSENSITIVE_FILENAME is defined this used to cause a crash.
  browse enew
  bwipe!

  browse split
  bwipe!
endfunc

func Test_read_invalid()
  " set encoding=latin1
  " This was not properly checking for going past the end.
  call assert_fails('r`=', 'E484')
  set encoding=utf-8
endfunc

" Test for the 'revins' option
func Test_edit_revins()
  CheckFeature rightleft
  new
  set revins
  exe "normal! ione\ttwo three"
  call assert_equal("eerht owt\teno", getline(1))
  call setline(1, "one\ttwo three")
  normal! gg$bi a
  call assert_equal("one\ttwo a three", getline(1))
  exe "normal! $bi\<BS>\<BS>"
  call assert_equal("one\ttwo a ree", getline(1))
  exe "normal! 0wi\<C-W>"
  call assert_equal("one\t a ree", getline(1))
  exe "normal! 0wi\<C-U>"
  call assert_equal("one\t ", getline(1))
  " newline in insert mode starts at the end of the line
  call setline(1, 'one two three')
  exe "normal! wi\nfour"
  call assert_equal(['one two three', 'ruof'], getline(1, '$'))
  set backspace=indent,eol,start
  exe "normal! ggA\<BS>:"
  call assert_equal(['one two three:ruof'], getline(1, '$'))
  set revins& backspace&
  bw!
endfunc

" Test for getting the character of the line below after "p"
func Test_edit_put_CTRL_E()
  " set encoding=latin1
  new
  let @" = ''
  sil! norm orggRx
  sil! norm pr
  call assert_equal(['r', 'r'], getline(1, 2))
  bwipe!
  set encoding=utf-8
endfunc

" Test toggling of input method. See :help i_CTRL-^
func Test_edit_CTRL_hat()
  CheckFeature xim

  " FIXME: test fails with Motif GUI.
  "        test also fails when running in the GUI.
  CheckFeature gui_gtk
  CheckNotGui

  new

  call assert_equal(0, &iminsert)
  call feedkeys("i\<C-^>", 'xt')
  call assert_equal(2, &iminsert)
  call feedkeys("i\<C-^>", 'xt')
  call assert_equal(0, &iminsert)

  bwipe!
endfunc

" Weird long file name was going over the end of NameBuff
func Test_edit_overlong_file_name()
  CheckUnix

  file 0000000000000000000000000000
  file %%%%%%%%%%%%%%%%%%%%%%%%%%
  file %%%%%%
  set readonly
  set ls=2

  redraw!
  set noreadonly ls&
  bwipe!
endfunc

func Test_edit_Ctrl_RSB()
  new
  let g:triggered = []
  autocmd InsertCharPre <buffer> let g:triggered += [v:char]

  " i_CTRL-] should not trigger InsertCharPre
  exe "normal! A\<C-]>"
  call assert_equal([], g:triggered)

  " i_CTRL-] should expand abbreviations but not trigger InsertCharPre
  inoreabbr <buffer> f foo
  exe "normal! Af\<C-]>a"
  call assert_equal(['f', 'f', 'o', 'o', 'a'], g:triggered)
  call assert_equal('fooa', getline(1))

  " CTRL-] followed by i_CTRL-V should not expand abbreviations
  " i_CTRL-V doesn't trigger InsertCharPre
  call setline(1, '')
  exe "normal! Af\<C-V>\<C-]>"
  call assert_equal("f\<C-]>", getline(1))

  let g:triggered = []
  call setline(1, '')

  " Also test assigning to v:char
  autocmd InsertCharPre <buffer> let v:char = 'f'
  exe "normal! Ag\<C-]>h"
  call assert_equal(['g', 'f', 'o', 'o', 'h'], g:triggered)
  call assert_equal('ffff', getline(1))

  autocmd! InsertCharPre
  unlet g:triggered
  bwipe!
endfunc

func s:check_backspace(expected)
  let g:actual = []
  inoremap <buffer> <F2> <Cmd>let g:actual += [getline('.')]<CR>
  set backspace=indent,eol,start

  exe "normal i" .. repeat("\<BS>\<F2>", len(a:expected))
  call assert_equal(a:expected, g:actual)

  set backspace&
  iunmap <buffer> <F2>
  unlet g:actual
endfunc

" Test that backspace works with 'smarttab' and mixed Tabs and spaces.
func Test_edit_backspace_smarttab_mixed()
  set smarttab
  call NewWindow(1, 30)
  setlocal tabstop=4 shiftwidth=4

  call setline(1, "\t    \t         \t a")
  normal! $
  call s:check_backspace([
        \ "\t    \t         \ta",
        \ "\t    \t        a",
        \ "\t    \t    a",
        \ "\t    \ta",
        \ "\t    a",
        \ "\ta",
        \ "a",
        \ ])

  call CloseWindow()
  set smarttab&
endfunc

" Test that backspace works with 'smarttab' and 'varsofttabstop'.
func Test_edit_backspace_smarttab_varsofttabstop()
  CheckFeature vartabs

  set smarttab
  call NewWindow(1, 30)
  setlocal tabstop=8 varsofttabstop=6,2,5,3

  call setline(1, "a\t    \t a")
  normal! $
  call s:check_backspace([
        \ "a\t    \ta",
        \ "a\t     a",
        \ "a\ta",
        \ "a     a",
        \ "aa",
        \ "a",
        \ ])

  call CloseWindow()
  set smarttab&
endfunc

" Test that backspace works with 'smarttab' when a Tab is shown as "^I".
func Test_edit_backspace_smarttab_list()
  set smarttab
  call NewWindow(1, 30)
  setlocal tabstop=4 shiftwidth=4 list listchars=

  call setline(1, "\t    \t         \t a")
  normal! $
  call s:check_backspace([
        \ "\t    \t        a",
        \ "\t    \t    a",
        \ "\t    \ta",
        \ "\t  a",
        \ "a",
        \ ])

  call CloseWindow()
  set smarttab&
endfunc

" Test that backspace works with 'smarttab' and 'breakindent'.
func Test_edit_backspace_smarttab_breakindent()
  CheckFeature linebreak

  set smarttab
  call NewWindow(3, 17)
  setlocal tabstop=4 shiftwidth=4 breakindent breakindentopt=min:5

  call setline(1, "\t    \t         \t a")
  normal! $
  call s:check_backspace([
        \ "\t    \t         \ta",
        \ "\t    \t        a",
        \ "\t    \t    a",
        \ "\t    \ta",
        \ "\t    a",
        \ "\ta",
        \ "a",
        \ ])

  call CloseWindow()
  set smarttab&
endfunc

" Test that backspace works with 'smarttab' and virtual text.
func Test_edit_backspace_smarttab_virtual_text()
  CheckFeature textprop

  set smarttab
  call NewWindow(1, 50)
  setlocal tabstop=4 shiftwidth=4

  call setline(1, "\t    \t         \t a")
  call prop_type_add('theprop', {})
  call prop_add(1, 3, {'type': 'theprop', 'text': 'text'})
  normal! $
  call s:check_backspace([
        \ "\t    \t         \ta",
        \ "\t    \t        a",
        \ "\t    \t    a",
        \ "\t    \ta",
        \ "\t    a",
        \ "\ta",
        \ "a",
        \ ])

  call CloseWindow()
  call prop_type_delete('theprop')
  set smarttab&
endfunc

" vim: shiftwidth=2 sts=2 expandtab
