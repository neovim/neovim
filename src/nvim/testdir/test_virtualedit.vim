" Tests for 'virtualedit'.

func Test_yank_move_change()
  new
  call setline(1, [
	\ "func foo() error {",
	\ "\tif n, err := bar();",
	\ "\terr != nil {",
	\ "\t\treturn err",
	\ "\t}",
	\ "\tn = n * n",
	\ ])
  set virtualedit=all
  set ts=4
  function! MoveSelectionDown(count) abort
    normal! m`
    silent! exe "'<,'>move'>+".a:count
    norm! ``
  endfunction

  xmap ]e :<C-U>call MoveSelectionDown(v:count1)<CR>
  2
  normal 2gg
  normal J
  normal jVj
  normal ]e
  normal ce
  bwipe!
  set virtualedit=
  set ts=8
endfunc

func Test_paste_end_of_line()
  new
  set virtualedit=all
  call setline(1, ['456', '123'])
  normal! gg0"ay$
  exe "normal! 2G$lllA\<C-O>:normal! \"agP\r"
  call assert_equal('123456', getline(2))

  bwipe!
  set virtualedit=
endfunc

func Test_replace_end_of_line()
  new
  set virtualedit=all
  call setline(1, range(20))
  exe "normal! gg2jv10lr-"
  call assert_equal(["1", "-----------", "3"], getline(2,4))
  call setline(1, range(20))
  exe "normal! gg2jv10lr\<c-k>hh"
  call assert_equal(["1", "───────────", "3"], getline(2,4))

  bwipe!
  set virtualedit=
endfunc

func Test_edit_CTRL_G()
  new
  set virtualedit=insert
  call setline(1, ['123', '1', '12'])
  exe "normal! ggA\<c-g>jx\<c-g>jx"
  call assert_equal(['123', '1  x', '12 x'], getline(1,'$'))

  set virtualedit=all
  %d_
  call setline(1, ['1', '12'])
  exe "normal! ggllix\<c-g>jx"
  call assert_equal(['1 x', '12x'], getline(1,'$'))


  bwipe!
  set virtualedit=
endfunc

func Test_edit_change()
  new
  set virtualedit=all
  call setline(1, "\t⒌")
  normal Cx
  call assert_equal('x', getline(1))
  bwipe!
  set virtualedit=
endfunc

" Tests for pasting at the beginning, end and middle of a tab character
" in virtual edit mode.
func Test_paste_in_tab()
  new
  call append(0, '')
  set virtualedit=all

  " Tests for pasting a register with characterwise mode type
  call setreg('"', 'xyz', 'c')

  " paste (p) unnamed register at the beginning of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 0)
  normal p
  call assert_equal('a xyz      b', getline(1))

  " paste (P) unnamed register at the beginning of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 0)
  normal P
  call assert_equal("axyz\tb", getline(1))

  " paste (p) unnamed register at the end of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 6)
  normal p
  call assert_equal("a\txyzb", getline(1))

  " paste (P) unnamed register at the end of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 6)
  normal P
  call assert_equal('a      xyz b', getline(1))

  " Tests for pasting a register with blockwise mode type
  call setreg('"', 'xyz', 'b')

  " paste (p) unnamed register at the beginning of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 0)
  normal p
  call assert_equal('a xyz      b', getline(1))

  " paste (P) unnamed register at the beginning of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 0)
  normal P
  call assert_equal("axyz\tb", getline(1))

  " paste (p) unnamed register at the end of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 6)
  normal p
  call assert_equal("a\txyzb", getline(1))

  " paste (P) unnamed register at the end of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 6)
  normal P
  call assert_equal('a      xyz b', getline(1))

  " Tests for pasting with gp and gP in virtual edit mode

  " paste (gp) unnamed register at the beginning of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 0)
  normal gp
  call assert_equal('a xyz      b', getline(1))
  call assert_equal([0, 1, 12, 0, 12], getcurpos())

  " paste (gP) unnamed register at the beginning of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 0)
  normal gP
  call assert_equal("axyz\tb", getline(1))
  call assert_equal([0, 1, 5, 0, 5], getcurpos())

  " paste (gp) unnamed register at the end of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 6)
  normal gp
  call assert_equal("a\txyzb", getline(1))
  call assert_equal([0, 1, 6, 0, 12], getcurpos())

  " paste (gP) unnamed register at the end of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 6)
  normal gP
  call assert_equal('a      xyz b', getline(1))
  call assert_equal([0, 1, 12, 0, 12], getcurpos())

  " Tests for pasting a named register
  let @r = 'xyz'

  " paste (gp) named register in the middle of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 2)
  normal "rgp
  call assert_equal('a   xyz    b', getline(1))
  call assert_equal([0, 1, 8, 0, 8], getcurpos())

  " paste (gP) named register in the middle of a tab
  call setline(1, "a\tb")
  call cursor(1, 2, 2)
  normal "rgP
  call assert_equal('a  xyz     b', getline(1))
  call assert_equal([0, 1, 7, 0, 7], getcurpos())

  bwipe!
  set virtualedit=
endfunc

" Test for yanking a few spaces within a tab to a register
func Test_yank_in_tab()
  new
  let @r = ''
  call setline(1, "a\tb")
  set virtualedit=all
  call cursor(1, 2, 2)
  normal "ry5l
  call assert_equal('     ', @r)

  bwipe!
  set virtualedit=
endfunc

" Insert "keyword keyw", ESC, C CTRL-N, shows "keyword ykeyword".
" Repeating CTRL-N fixes it. (Mary Ellen Foster)
func Test_ve_completion()
  new
  set completeopt&vim
  set virtualedit=all
  exe "normal ikeyword keyw\<Esc>C\<C-N>"
  call assert_equal('keyword keyword', getline(1))
  bwipe!
  set virtualedit=
endfunc

" Using "C" then then <CR> moves the last remaining character to the next
" line.  (Mary Ellen Foster)
func Test_ve_del_to_eol()
  new
  set virtualedit=all
  call append(0, 'all your base are belong to us')
  call search('are', 'w')
  exe "normal C\<CR>are belong to vim"
  call assert_equal(['all your base ', 'are belong to vim'], getline(1, 2))
  bwipe!
  set virtualedit=
endfunc

" When past the end of a line that ends in a single character "b" skips
" that word.
func Test_ve_b_past_eol()
  new
  set virtualedit=all
  call append(0, '1 2 3 4 5 6')
  normal gg^$15lbC7
  call assert_equal('1 2 3 4 5 7', getline(1))
  bwipe!
  set virtualedit=
endfunc

" Make sure 'i', 'C', 'a', 'A' and 'D' works
func Test_ve_ins_del()
  new
  set virtualedit=all
  call append(0, ["'i'", "'C'", "'a'", "'A'", "'D'"])
  call cursor(1, 1)
  normal $4lix
  call assert_equal("'i'   x", getline(1))
  call cursor(2, 1)
  normal $4lCx
  call assert_equal("'C'   x", getline(2))
  call cursor(3, 1)
  normal $4lax
  call assert_equal("'a'    x", getline(3))
  call cursor(4, 1)
  normal $4lAx
  call assert_equal("'A'x", getline(4))
  call cursor(5, 1)
  normal $4lDix
  call assert_equal("'D'   x", getline(5))
  bwipe!
  set virtualedit=
endfunc

" Test for yank bug reported by Mark Waggoner.
func Test_yank_block()
  new
  set virtualedit=block
  call append(0, repeat(['this is a test'], 3))
  exe "normal gg^2w\<C-V>3jy"
  call assert_equal("a\na\na\n ", @")
  bwipe!
  set virtualedit=
endfunc

" Test "r" beyond the end of the line
func Test_replace_after_eol()
  new
  set virtualedit=all
  call append(0, '"r"')
  normal gg$5lrxa
  call assert_equal('"r"    x', getline(1))
  bwipe!
  set virtualedit=
endfunc

" Test "r" on a tab
" Note that for this test, 'ts' must be 8 (the default).
func Test_replace_on_tab()
  new
  set virtualedit=all
  call append(0, "'r'\t")
  normal gg^5lrxAy
  call assert_equal("'r'  x  y", getline(1))
  bwipe!
  set virtualedit=
endfunc

" Test to make sure 'x' can delete control characters
func Test_ve_del_ctrl_chars()
  new
  set virtualedit=all
  call append(0, "a\<C-V>b\<CR>sd")
  set display=uhex
  normal gg^xxxxxxi[text]
  set display=
  call assert_equal('[text]', getline(1))
  bwipe!
  set virtualedit=
endfunc

" Test for ^Y/^E due to bad w_virtcol value, reported by
" Roy <royl@netropolis.net>.
func Test_ins_copy_char()
  new
  set virtualedit=all
  call append(0, 'abcv8efi.him2kl')
  exe "normal gg^O\<Esc>3li\<C-E>\<Esc>4li\<C-E>\<Esc>4li\<C-E>   <--"
  exe "normal j^o\<Esc>4li\<C-Y>\<Esc>4li\<C-Y>\<Esc>4li\<C-Y>   <--"
  call assert_equal('   v   i   m   <--', getline(1))
  call assert_equal('    8   .   2   <--', getline(3))
  bwipe!
  set virtualedit=
endfunc

" Test for yanking and pasting using the small delete register
func Test_yank_paste_small_del_reg()
  new
  set virtualedit=all
  call append(0, "foo, bar")
  normal ggdewve"-p
  call assert_equal(', foo', getline(1))
  bwipe!
  set virtualedit=
endfunc

" After calling s:TryVirtualeditReplace(), line 1 will contain one of these
" two strings, depending on whether virtual editing is on or off.
let s:result_ve_on  = 'a      x'
let s:result_ve_off = 'x'

" Utility function for Test_global_local_virtualedit()
func s:TryVirtualeditReplace()
  call setline(1, 'a')
  normal gg7l
  normal rx
endfunc

" Test for :set and :setlocal
func Test_global_local_virtualedit()
  new

  " Verify that 'virtualedit' is initialized to empty, can be set globally to
  " all and to empty, and can be set locally to all and to empty.
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))
  set ve=all
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_on, getline(1))
  set ve=
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))
  setlocal ve=all
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_on, getline(1))
  setlocal ve=
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))

  " Verify that :set affects multiple windows.
  split
  set ve=all
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_on, getline(1))
  wincmd p
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_on, getline(1))
  set ve=
  wincmd p
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))
  bwipe!

  " Verify that :setlocal affects only the current window.
  new
  split
  setlocal ve=all
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_on, getline(1))
  wincmd p
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))
  bwipe!
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))

  " Verify that the buffer 'virtualedit' state follows the global value only
  " when empty and that "none" works as expected.
  "
  "          'virtualedit' State
  " +--------+--------------------------+
  " | Local  |          Global          |
  " |        |                          |
  " +--------+--------+--------+--------+
  " |        | ""     | "all"  | "none" |
  " +--------+--------+--------+--------+
  " | ""     |  off   |  on    |  off   |
  " | "all"  |  on    |  on    |  on    |
  " | "none" |  off   |  off   |  off   |
  " +--------+--------+--------+--------+
  new

  setglobal ve=
  setlocal ve=
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))
  setlocal ve=all
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_on, getline(1))
  setlocal ve=none
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))

  setglobal ve=all
  setlocal ve=
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_on, getline(1))
  setlocal ve=all
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_on, getline(1))
  setlocal ve=none
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))
  setlocal ve=NONE
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))

  setglobal ve=none
  setlocal ve=
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))
  setlocal ve=all
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_on, getline(1))
  setlocal ve=none
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))

  bwipe!

  " Verify that the 'virtualedit' state is copied to new windows.
  new
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))
  split
  setlocal ve=all
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_on, getline(1))
  split
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_on, getline(1))
  setlocal ve=
  split
  call s:TryVirtualeditReplace()
  call assert_equal(s:result_ve_off, getline(1))
  bwipe!

  setlocal virtualedit&
  set virtualedit&
endfunc

" vim: shiftwidth=2 sts=2 expandtab
