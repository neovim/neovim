
" Test that a deleted mark is restored after delete-undo-redo-undo.
function! Test_Restore_DelMark()
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
endfunction

" Test that CTRL-A and CTRL-X updates last changed mark '[, '].
function! Test_Incr_Marks()
  enew!
  call append(0, ["123 123 123", "123 123 123", "123 123 123"])
  normal! gg
  execute "normal! \<C-A>`[v`]rAjwvjw\<C-X>`[v`]rX"
  call assert_equal("AAA 123 123", getline(1))
  call assert_equal("123 XXXXXXX", getline(2))
  call assert_equal("XXX 123 123", getline(3))
  enew!
endfunction

func Test_setpos()
  new one
  let onebuf = bufnr('%')
  let onewin = win_getid()
  call setline(1, ['aaa', 'bbb', 'ccc'])
  new two
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

  call win_gotoid(onewin)
  bwipe!
  call win_gotoid(twowin)
  bwipe!
endfunc
