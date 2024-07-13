" Tests for put commands, e.g. ":put", "p", "gp", "P", "gP", etc.

source check.vim
source screendump.vim

func Test_put_block()
  new
  call feedkeys("i\<C-V>u2500\<CR>x\<ESC>", 'x')
  call feedkeys("\<C-V>y", 'x')
  call feedkeys("gg0p", 'x')
  call assert_equal("\u2500x", getline(1))
  bwipe!
endfunc

func Test_put_block_unicode()
  new
  call setreg('a', "À\nÀÀ\naaaaaaaaaaaa", "\<C-V>")
  call setline(1, [' 1', ' 2', ' 3'])
  exe "norm! \<C-V>jj\"ap"
  let expected = ['À           1', 'ÀÀ          2', 'aaaaaaaaaaaa3']
  call assert_equal(expected, getline(1, 3))
  bw!
endfunc

func Test_put_char_block()
  new
  call setline(1, ['Line 1', 'Line 2'])
  f Xfile_put
  " visually select both lines and put the cursor at the top of the visual
  " selection and then put the buffer name over it
  exe "norm! G0\<c-v>ke\"%p"
  call assert_equal(['Xfile_put 1', 'Xfile_put 2'], getline(1,2))
  bw!
endfunc

func Test_put_char_block2()
  new
  call setreg('a', ' one ', 'v')
  call setline(1, ['Line 1', '', 'Line 3', ''])
  " visually select the first 3 lines and put register a over it
  exe "norm! ggl\<c-v>2j2l\"ap"
  call assert_equal(['L one  1', '', 'L one  3', ''], getline(1, 4))
  " clean up
  bw!
endfunc

func Test_put_lines()
  new
  let a = [ getreg('a'), getregtype('a') ]
  call setline(1, ['Line 1', 'Line2', 'Line 3', ''])
  exe 'norm! gg"add"AddG""p'
  call assert_equal(['Line 3', '', 'Line 1', 'Line2'], getline(1, '$'))
  " clean up
  bw!
  eval a[0]->setreg('a', a[1])
endfunc

func Test_put_expr()
  new
  call setline(1, repeat(['A'], 6))
  exec "1norm! \"=line('.')\<cr>p"
  norm! j0.
  norm! j0.
  exec "4norm! \"=\<cr>P"
  norm! j0.
  norm! j0.
  call assert_equal(['A1','A2','A3','4A','5A','6A'], getline(1, '$'))
  bw!
endfunc

func Test_put_fails_when_nomodifiable()
  new
  setlocal nomodifiable

  normal! yy
  call assert_fails(':put', 'E21')
  call assert_fails(':put!', 'E21')
  call assert_fails(':normal! p', 'E21')
  call assert_fails(':normal! gp', 'E21')
  call assert_fails(':normal! P', 'E21')
  call assert_fails(':normal! gP', 'E21')

  if has('mouse')
    set mouse=n
    call assert_fails('execute "normal! \<MiddleMouse>"', 'E21')
    set mouse&
  endif

  bwipeout!
endfunc

" A bug was discovered where the Normal mode put commands (e.g., "p") would
" output duplicate error messages when invoked in a non-modifiable buffer.
func Test_put_p_errmsg_nodup()
  new
  setlocal nomodifiable

  normal! yy

  func Capture_p_error()
    redir => s:p_err
    normal! p
    redir END
  endfunc

  silent! call Capture_p_error()

  " Error message output within a function should be three lines (the function
  " name, the line number, and the error message).
  call assert_equal(3, count(s:p_err, "\n"))

  delfunction Capture_p_error
  bwipeout!
endfunc

func Test_put_p_indent_visual()
  new
  call setline(1, ['select this text', 'select that text'])
  " yank "that" from the second line
  normal 2Gwvey
  " select "this" in the first line and put
  normal k0wve[p
  call assert_equal('select that text', getline(1))
  call assert_equal('select that text', getline(2))
  bwipe!
endfunc

" Test for deleting all the contents of a buffer with a put
func Test_put_visual_delete_all_lines()
  new
  call setline(1, ['one', 'two', 'three'])
  let @r = ''
  normal! VG"rgp
  call assert_equal(1, line('$'))
  close!
endfunc

func Test_gp_with_count_leaves_cursor_at_end()
  new
  call setline(1, '<---->')
  call setreg('@', "foo\nbar", 'c')
  normal 1G3|3gp
  call assert_equal([0, 4, 4, 0], getpos("."))
  call assert_equal(['<--foo', 'barfoo', 'barfoo', 'bar-->'], getline(1, '$'))
  call assert_equal([0, 4, 3, 0], getpos("']"))

  bwipe!
endfunc

func Test_p_with_count_leaves_mark_at_end()
  new
  call setline(1, '<---->')
  call setreg('@', "start\nend", 'c')
  normal 1G3|3p
  call assert_equal([0, 1, 4, 0], getpos("."))
  call assert_equal(['<--start', 'endstart', 'endstart', 'end-->'], getline(1, '$'))
  call assert_equal([0, 4, 3, 0], getpos("']"))

  bwipe!
endfunc

func Test_very_large_count()
  new
  " total put-length (21474837 * 100) brings 32 bit int overflow
  let @" = repeat('x', 100)
  call assert_fails('norm 21474837p', 'E1240:')
  bwipe!
endfunc

func Test_very_large_count_64bit()
  new
  let @" = repeat('x', 100)
  call assert_fails('norm 999999999p', 'E1240:')
  bwipe!
endfunc

func Test_very_large_count_block()
  new
  " total put-length (21474837 * 100) brings 32 bit int overflow
  call setline(1, repeat('x', 100))
  exe "norm \<C-V>99ly"
  call assert_fails('norm 21474837p', 'E1240:')
  bwipe!
endfunc

func Test_very_large_count_block_64bit()
  new
  call setline(1, repeat('x', 100))
  exe "norm \<C-V>$y"
  call assert_fails('norm 999999999p', 'E1240:')
  bwipe!
endfunc

func Test_put_above_first_line()
  new
  let @" = 'text'
  silent! normal 0o00
  0put
  call assert_equal('text', getline(1))
  bwipe!
endfunc

func Test_multibyte_op_end_mark()
  new
  call setline(1, 'тест')
  normal viwdp
  call assert_equal([0, 1, 7, 0], getpos("'>"))
  call assert_equal([0, 1, 7, 0], getpos("']"))

  normal Vyp
  call assert_equal([0, 1, v:maxcol, 0], getpos("'>"))
  call assert_equal([0, 2, 7, 0], getpos("']"))
  bwipe!
endfunc

" this was putting a mark before the start of a line
func Test_put_empty_register()
  new
  norm yy
  norm [Pi00ggv)s0
  sil! norm [P
  bwipe!
endfunc

" this was putting the end mark after the end of the line
func Test_put_visual_mode()
  edit! SomeNewBuffer
  set selection=exclusive
  exe "norm o\t"
  m0
  sil! norm pp

  bwipe!
  set selection&
endfunc

func Test_put_visual_block_mode()
  enew
  exe "norm 0R\<CR>\<C-C>V"
  sil exe "norm \<C-V>c	\<MiddleDrag>"
  set ve=all
  sil norm vz=p

  bwipe!
  set ve=
endfunc

func Test_put_other_window()
  CheckRunVimInTerminal

  let lines =<< trim END
      40vsplit
      0put ='some text at the top'
      put ='  one more text'
      put ='  two more text'
      put ='  three more text'
      put ='  four more text'
  END
  call writefile(lines, 'Xtest_put_other', 'D')
  let buf = RunVimInTerminal('-S Xtest_put_other', #{rows: 10})

  call VerifyScreenDump(buf, 'Test_put_other_window_1', {})

  call StopVimInTerminal(buf)
endfunc

func Test_put_in_last_displayed_line()
  CheckRunVimInTerminal

  let lines =<< trim END
      vim9script
      autocmd CursorMoved * eval line('w$')
      @a = 'x'->repeat(&columns * 2 - 2)
      range(&lines)->setline(1)
      feedkeys('G"ap')
  END
  call writefile(lines, 'Xtest_put_last_line', 'D')
  let buf = RunVimInTerminal('-S Xtest_put_last_line', #{rows: 10})

  call VerifyScreenDump(buf, 'Test_put_in_last_displayed_line_1', {})

  call StopVimInTerminal(buf)
endfunc

func Test_put_visual_replace_whole_fold()
  new
  let lines = repeat(['{{{1', 'foo', 'bar', ''], 2)
  call setline(1, lines)
  setlocal foldmethod=marker
  call setreg('"', 'baz')
  call setreg('1', '')
  normal! Vp
  call assert_equal("{{{1\nfoo\nbar\n\n", getreg('1'))
  call assert_equal(['baz', '{{{1', 'foo', 'bar', ''], getline(1, '$'))

  bwipe!
endfunc

func Test_put_visual_replace_fold_marker()
  new
  let lines = repeat(['{{{1', 'foo', 'bar', ''], 4)
  call setline(1, lines)
  setlocal foldmethod=marker
  normal! Gkzo
  call setreg('"', '{{{1')
  call setreg('1', '')
  normal! Vp
  call assert_equal("{{{1\n", getreg('1'))
  call assert_equal(lines, getline(1, '$'))

  bwipe!
endfunc

func Test_put_dict()
  new
  let d = #{a: #{b: 'abc'}, c: [1, 2], d: 0z10}
  put! =d
  call assert_equal(["{'a': {'b': 'abc'}, 'c': [1, 2], 'd': 0z10}", ''],
        \ getline(1, '$'))
  bw!
endfunc

func Test_put_list()
  new
  let l = ['a', 'b', 'c']
  put! =l
  call assert_equal(['a', 'b', 'c', ''], getline(1, '$'))
  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
