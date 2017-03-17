" Tests for the undo tree.
" Since this script is sourced we need to explicitly break changes up in
" undo-able pieces.  Do that by setting 'undolevels'.
" Also tests :earlier and :later.

func Test_undotree()
  exe "normal Aabc\<Esc>"
  set ul=100
  exe "normal Adef\<Esc>"
  set ul=100
  undo
  let d = undotree()
  call assert_true(d.seq_last > 0)
  call assert_true(d.seq_cur > 0)
  call assert_true(d.seq_cur < d.seq_last)
  call assert_true(len(d.entries) > 0)
  " TODO: check more members of d

  w! Xtest
  call assert_equal(d.save_last + 1, undotree().save_last)
  call delete('Xtest')
  bwipe Xtest
endfunc

func FillBuffer()
  for i in range(1,13)
    put=i
    " Set 'undolevels' to split undo. 
    exe "setg ul=" . &g:ul
  endfor
endfunc

func Test_global_local_undolevels()
  new one
  set undolevels=5
  call FillBuffer()
  " will only undo the last 5 changes, end up with 13 - (5 + 1) = 7 lines
  earlier 10
  call assert_equal(5, &g:undolevels)
  call assert_equal(-123456, &l:undolevels)
  call assert_equal('7', getline('$'))

  new two
  setlocal undolevels=2
  call FillBuffer()
  " will only undo the last 2 changes, end up with 13 - (2 + 1) = 10 lines
  earlier 10
  call assert_equal(5, &g:undolevels)
  call assert_equal(2, &l:undolevels)
  call assert_equal('10', getline('$'))

  setlocal ul=10
  call assert_equal(5, &g:undolevels)
  call assert_equal(10, &l:undolevels)

  " Setting local value in "two" must not change local value in "one"
  wincmd p
  call assert_equal(5, &g:undolevels)
  call assert_equal(-123456, &l:undolevels)

  new three
  setglobal ul=50
  call assert_equal(50, &g:undolevels)
  call assert_equal(-123456, &l:undolevels)

  " Drop created windows
  set ul&
  new
  only!
endfunc

func BackOne(expected)
  call feedkeys('g-', 'xt')
  call assert_equal(a:expected, getline(1))
endfunc

func Test_undo_del_chars()
  " Setup a buffer without creating undo entries
  new
  set ul=-1
  call setline(1, ['123-456'])
  set ul=100
  1
  call test_settime(100)

  " Delete three characters and undo with g-
  call feedkeys('x', 'xt')
  call feedkeys('x', 'xt')
  call feedkeys('x', 'xt')
  call assert_equal('-456', getline(1))
  call BackOne('3-456')
  call BackOne('23-456')
  call BackOne('123-456')
  call assert_fails("BackOne('123-456')")

  :" Delete three other characters and go back in time with g-
  call feedkeys('$x', 'xt')
  call feedkeys('x', 'xt')
  call feedkeys('x', 'xt')
  call assert_equal('123-', getline(1))
  call test_settime(101)

  call BackOne('123-4')
  call BackOne('123-45')
  " skips '123-456' because it's older
  call BackOne('-456')
  call BackOne('3-456')
  call BackOne('23-456')
  call BackOne('123-456')
  call assert_fails("BackOne('123-456')")
  normal 10g+
  call assert_equal('123-', getline(1))

  :" Jump two seconds and go some seconds forward and backward
  call test_settime(103)
  call feedkeys("Aa\<Esc>", 'xt')
  call feedkeys("Ab\<Esc>", 'xt')
  call feedkeys("Ac\<Esc>", 'xt')
  call assert_equal('123-abc', getline(1))
  earlier 1s
  call assert_equal('123-', getline(1))
  earlier 3s
  call assert_equal('123-456', getline(1))
  later 1s
  call assert_equal('123-', getline(1))
  later 1h
  call assert_equal('123-abc', getline(1))

  close!
endfunc

func Test_undojoin()
  new
  call feedkeys("Goaaaa\<Esc>", 'xt')
  call feedkeys("obbbb\<Esc>", 'xt')
  call assert_equal(['aaaa', 'bbbb'], getline(2, '$'))
  call feedkeys("u", 'xt')
  call assert_equal(['aaaa'], getline(2, '$'))
  call feedkeys("obbbb\<Esc>", 'xt')
  undojoin
  " Note: next change must not be as if typed
  call feedkeys("occcc\<Esc>", 'x')
  call assert_equal(['aaaa', 'bbbb', 'cccc'], getline(2, '$'))
  call feedkeys("u", 'xt')
  call assert_equal(['aaaa'], getline(2, '$'))
  close!
endfunc

func Test_undo_write()
  split Xtest
  call feedkeys("ione one one\<Esc>", 'xt')
  w!
  call feedkeys("otwo\<Esc>", 'xt')
  call feedkeys("otwo\<Esc>", 'xt')
  w
  call feedkeys("othree\<Esc>", 'xt')
  call assert_equal(['one one one', 'two', 'two', 'three'], getline(1, '$'))
  earlier 1f
  call assert_equal(['one one one', 'two', 'two'], getline(1, '$'))
  earlier 1f
  call assert_equal(['one one one'], getline(1, '$'))
  earlier 1f
  call assert_equal([''], getline(1, '$'))
  later 1f
  call assert_equal(['one one one'], getline(1, '$'))
  later 1f
  call assert_equal(['one one one', 'two', 'two'], getline(1, '$'))
  later 1f
  call assert_equal(['one one one', 'two', 'two', 'three'], getline(1, '$'))

  close!
  call delete('Xtest')
  bwipe! Xtest
endfunc

func Test_insert_expr()
  new
  " calling setline() triggers undo sync
  call feedkeys("oa\<Esc>", 'xt')
  call feedkeys("ob\<Esc>", 'xt')
  set ul=100
  call feedkeys("o1\<Esc>a2\<C-R>=setline('.','1234')\<CR>\<CR>\<Esc>", 'x')
  call assert_equal(['a', 'b', '120', '34'], getline(2, '$'))
  call feedkeys("u", 'x')
  call assert_equal(['a', 'b', '12'], getline(2, '$'))
  call feedkeys("u", 'x')
  call assert_equal(['a', 'b'], getline(2, '$'))

  call feedkeys("oc\<Esc>", 'xt')
  set ul=100
  call feedkeys("o1\<Esc>a2\<C-R>=setline('.','1234')\<CR>\<CR>\<Esc>", 'x')
  call assert_equal(['a', 'b', 'c', '120', '34'], getline(2, '$'))
  call feedkeys("u", 'x')
  call assert_equal(['a', 'b', 'c', '12'], getline(2, '$'))

  call feedkeys("od\<Esc>", 'xt')
  set ul=100
  call feedkeys("o1\<Esc>a2\<C-R>=string(123)\<CR>\<Esc>", 'x')
  call assert_equal(['a', 'b', 'c', '12', 'd', '12123'], getline(2, '$'))
  call feedkeys("u", 'x')
  call assert_equal(['a', 'b', 'c', '12', 'd'], getline(2, '$'))

  close!
endfunc
