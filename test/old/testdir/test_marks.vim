
" Test that a deleted mark is restored after delete-undo-redo-undo.
func Test_Restore_DelMark()
  enew!
  call append(0, ["	textline A", "	textline B", "	textline C"])
  normal! 2gg
  set nocp viminfo+=nviminfo
  exe "normal! i\<C-G>u\<Esc>"
  exe "normal! maddu\<C-R>u"
  let pos = getpos("'a")
  call assert_equal(2, pos[1])
  call assert_equal(1, pos[2])
  enew!
endfunc

" Test that CTRL-A and CTRL-X updates last changed mark '[, '].
func Test_Incr_Marks()
  enew!
  call append(0, ["123 123 123", "123 123 123", "123 123 123"])
  normal! gg
  execute "normal! \<C-A>`[v`]rAjwvjw\<C-X>`[v`]rX"
  call assert_equal("AAA 123 123", getline(1))
  call assert_equal("123 XXXXXXX", getline(2))
  call assert_equal("XXX 123 123", getline(3))
  enew!
endfunc

func Test_previous_jump_mark()
  new
  call setline(1, ['']->repeat(6))
  normal Ggg
  call assert_equal(6, getpos("''")[1])
  normal jjjjj
  call assert_equal(6, getpos("''")[1])
  bwipe!
endfunc

func Test_setpos()
  new Xone
  let onebuf = bufnr('%')
  let onewin = win_getid()
  call setline(1, ['aaa', 'bbb', 'ccc'])
  new Xtwo
  let twobuf = bufnr('%')
  let twowin = win_getid()
  call setline(1, ['aaa', 'bbb', 'ccc'])

  " for the cursor the buffer number is ignored
  call setpos(".", [0, 2, 1, 0])
  call assert_equal([0, 2, 1, 0], getpos("."))
  call setpos(".", [onebuf, 3, 3, 0])
  call assert_equal([0, 3, 3, 0], getpos("."))

  call setpos("''", [0, 1, 3, 0])
  call assert_equal([0, 1, 3, 0], getpos("''"))
  call setpos("''", [onebuf, 2, 2, 0])
  call assert_equal([0, 2, 2, 0], getpos("''"))

  " buffer-local marks
  for mark in ["'a", "'\"", "'[", "']", "'<", "'>"]
    call win_gotoid(twowin)
    call setpos(mark, [0, 2, 1, 0])
    call assert_equal([0, 2, 1, 0], getpos(mark), "for mark " . mark)
    call setpos(mark, [onebuf, 1, 3, 0])
    call win_gotoid(onewin)
    call assert_equal([0, 1, 3, 0], getpos(mark), "for mark " . mark)
  endfor

  " global marks
  call win_gotoid(twowin)
  call setpos("'N", [0, 2, 1, 0])
  call assert_equal([twobuf, 2, 1, 0], getpos("'N"))
  call setpos("'N", [onebuf, 1, 3, 0])
  call assert_equal([onebuf, 1, 3, 0], getpos("'N"))

  " try invalid column and check virtcol()
  call win_gotoid(onewin)
  call setpos("'a", [0, 1, 2, 0])
  call assert_equal([0, 1, 2, 0], getpos("'a"))
  call setpos("'a", [0, 1, -5, 0])
  call assert_equal([0, 1, 2, 0], getpos("'a"))
  call setpos("'a", [0, 1, 0, 0])
  call assert_equal([0, 1, 1, 0], getpos("'a"))
  call setpos("'a", [0, 1, 4, 0])
  call assert_equal([0, 1, 4, 0], getpos("'a"))
  call assert_equal(4, virtcol("'a"))
  call setpos("'a", [0, 1, 5, 0])
  call assert_equal([0, 1, 5, 0], getpos("'a"))
  call assert_equal(4, virtcol("'a"))
  call setpos("'a", [0, 1, 21341234, 0])
  call assert_equal([0, 1, 21341234, 0], getpos("'a"))
  call assert_equal(4, virtcol("'a"))

  " Test with invalid buffer number, line number and column number
  call cursor(2, 2)
  call setpos('.', [-1, 1, 1, 0])
  call assert_equal([2, 2], [line('.'), col('.')])
  call setpos('.', [0, -1, 1, 0])
  call assert_equal([2, 2], [line('.'), col('.')])
  call setpos('.', [0, 1, -1, 0])
  call assert_equal([2, 2], [line('.'), col('.')])

  call assert_fails("call setpos('ab', [0, 1, 1, 0])", 'E474:')

  bwipe!
  call win_gotoid(twowin)
  bwipe!
endfunc

func Test_marks_cmd()
  new Xone
  call setline(1, ['aaa', 'bbb'])
  norm! maG$mB
  w!
  new Xtwo
  call setline(1, ['ccc', 'ddd'])
  norm! $mcGmD
  exe "norm! GVgg\<Esc>G"
  w!

  b Xone
  let a = split(execute('marks'), "\n")
  call assert_equal(9, len(a))
  call assert_equal(['mark line  col file/text',
        \ " '      2    0 bbb",
        \ ' a      1    0 aaa',
        \ ' B      2    2 bbb',
        \ ' D      2    0 Xtwo',
        \ ' "      1    0 aaa',
        \ ' [      1    0 aaa',
        \ ' ]      2    0 bbb',
        \ ' .      2    0 bbb'], a)

  b Xtwo
  let a = split(execute('marks'), "\n")
  call assert_equal(11, len(a))
  call assert_equal(['mark line  col file/text',
        \ " '      1    0 ccc",
        \ ' c      1    2 ccc',
        \ ' B      2    2 Xone',
        \ ' D      2    0 ddd',
        \ ' "      2    0 ddd',
        \ ' [      1    0 ccc',
        \ ' ]      2    0 ddd',
        \ ' .      2    0 ddd',
        \ ' <      1    0 ccc',
        \ ' >      2    0 ddd'], a)
  norm! Gdd
  w!
  let a = split(execute('marks <>'), "\n")
  call assert_equal(3, len(a))
  call assert_equal(['mark line  col file/text',
        \ ' <      1    0 ccc',
        \ ' >      2    0 -invalid-'], a)

  b Xone
  delmarks aB
  let a = split(execute('marks aBcD'), "\n")
  call assert_equal(2, len(a))
  call assert_equal('mark line  col file/text', a[0])
  call assert_equal(' D      2    0 Xtwo', a[1])

  b Xtwo
  delmarks cD
  call assert_fails('marks aBcD', 'E283:')

  call delete('Xone')
  call delete('Xtwo')
  %bwipe
endfunc

func Test_marks_cmd_multibyte()
  new Xone
  call setline(1, [repeat('á', &columns)])
  norm! ma

  let a = split(execute('marks a'), "\n")
  call assert_equal(2, len(a))
  let expected = ' a      1    0 ' . repeat('á', &columns - 16)
  call assert_equal(expected, a[1])

  bwipe!
endfunc

func Test_delmarks()
  new
  norm mx
  norm `x
  delmarks x
  call assert_fails('norm `x', 'E20:')

  " Deleting an already deleted mark should not fail.
  delmarks x

  " getpos() should return all zeros after deleting a filemark.
  norm mA
  delmarks A
  call assert_equal([0, 0, 0, 0], getpos("'A"))

  " Test deleting a range of marks.
  norm ma
  norm mb
  norm mc
  norm mz
  delmarks b-z
  norm `a
  call assert_fails('norm `b', 'E20:')
  call assert_fails('norm `c', 'E20:')
  call assert_fails('norm `z', 'E20:')
  call assert_fails('delmarks z-b', 'E475:')

  call assert_fails('delmarks', 'E471:')
  call assert_fails('delmarks /', 'E475:')

  " Test delmarks!
  norm mx
  norm `x
  delmarks!
  call assert_fails('norm `x', 'E20:')
  call assert_fails('delmarks! x', 'E474:')

  bwipe!
endfunc

func Test_mark_error()
  call assert_fails('mark', 'E471:')
  call assert_fails('mark xx', 'E488:')
  call assert_fails('mark _', 'E191:')
  call assert_beeps('normal! m~')

  call setpos("'k", [0, 100, 1, 0])
  call assert_fails("normal 'k", 'E19:')
endfunc

" Test for :lockmarks when pasting content
func Test_lockmarks_with_put()
  new
  call append(0, repeat(['sky is blue'], 4))
  normal gg
  1,2yank r
  put r
  normal G
  lockmarks put r
  call assert_equal(2, line("'["))
  call assert_equal(3, line("']"))

  bwipe!
endfunc

" Test for :k command to set a mark
func Test_marks_k_cmd()
  new
  call setline(1, ['foo', 'bar', 'baz', 'qux'])
  1,3kr
  call assert_equal([0, 3, 1, 0], getpos("'r"))
  close!
endfunc

" Test for file marks (A-Z)
func Test_file_mark()
  new Xone
  call setline(1, ['aaa', 'bbb'])
  norm! G$mB
  w!
  new Xtwo
  call setline(1, ['ccc', 'ddd'])
  norm! GmD
  w!

  enew
  normal! `B
  call assert_equal('Xone', bufname())
  call assert_equal([2, 3], [line('.'), col('.')])
  normal! 'D
  call assert_equal('Xtwo', bufname())
  call assert_equal([2, 1], [line('.'), col('.')])

  call delete('Xone')
  call delete('Xtwo')
endfunc

" Test for the getmarklist() function
func Test_getmarklist()
  new
  " global marks
  delmarks A-Z 0-9 \" ^.[]
  call assert_equal([], getmarklist())
  call setline(1, ['one', 'two', 'three'])
  mark A
  call cursor(3, 5)
  normal mN
  call assert_equal([{'file' : '', 'mark' : "'A", 'pos' : [bufnr(), 1, 1, 0]},
        \ {'file' : '', 'mark' : "'N", 'pos' : [bufnr(), 3, 5, 0]}],
        \ getmarklist())
  " buffer local marks
  delmarks!
  call assert_equal([{'mark' : "''", 'pos' : [bufnr(), 1, 1, 0]},
        \ {'mark' : "'\"", 'pos' : [bufnr(), 1, 1, 0]}], getmarklist(bufnr()))
  call cursor(2, 2)
  normal mr
  call assert_equal({'mark' : "'r", 'pos' : [bufnr(), 2, 2, 0]},
        \ bufnr()->getmarklist()[0])
  call assert_equal([], {}->getmarklist())
  normal! yy
  call assert_equal([
        \ {'mark': "'[", 'pos': [bufnr(), 2, 1, 0]},
        \ {'mark': "']", 'pos': [bufnr(), 2, v:maxcol, 0]},
        \ ], getmarklist(bufnr())[-2:])
  close!
endfunc

" This was using freed memory
func Test_jump_mark_autocmd()
  next 00
  edit 0
  sargument
  au BufEnter 0 all
  sil norm 

  au! BufEnter
  bwipe!
endfunc


" vim: shiftwidth=2 sts=2 expandtab
