" Tests for the undo tree.
" Since this script is sourced we need to explicitly break changes up in
" undo-able pieces.  Do that by setting 'undolevels'.
" Also tests :earlier and :later.

func Test_undotree()
  new

  normal! Aabc
  set ul=100
  let d = undotree()
  call assert_equal(1, d.seq_last)
  call assert_equal(1, d.seq_cur)
  call assert_equal(0, d.save_last)
  call assert_equal(0, d.save_cur)
  call assert_equal(1, len(d.entries))
  call assert_equal(1, d.entries[0].newhead)
  call assert_equal(1, d.entries[0].seq)
  call assert_true(d.entries[0].time <= d.time_cur)

  normal! Adef
  set ul=100
  let d = undotree()
  call assert_equal(2, d.seq_last)
  call assert_equal(2, d.seq_cur)
  call assert_equal(0, d.save_last)
  call assert_equal(0, d.save_cur)
  call assert_equal(2, len(d.entries))
  call assert_equal(1, d.entries[0].seq)
  call assert_equal(1, d.entries[1].newhead)
  call assert_equal(2, d.entries[1].seq)
  call assert_true(d.entries[1].time <= d.time_cur)

  undo
  set ul=100
  let d = undotree()
  call assert_equal(2, d.seq_last)
  call assert_equal(1, d.seq_cur)
  call assert_equal(0, d.save_last)
  call assert_equal(0, d.save_cur)
  call assert_equal(2, len(d.entries))
  call assert_equal(1, d.entries[0].seq)
  call assert_equal(1, d.entries[1].curhead)
  call assert_equal(1, d.entries[1].newhead)
  call assert_equal(2, d.entries[1].seq)
  call assert_true(d.entries[1].time == d.time_cur)

  normal! Aghi
  set ul=100
  let d = undotree()
  call assert_equal(3, d.seq_last)
  call assert_equal(3, d.seq_cur)
  call assert_equal(0, d.save_last)
  call assert_equal(0, d.save_cur)
  call assert_equal(2, len(d.entries))
  call assert_equal(1, d.entries[0].seq)
  call assert_equal(2, d.entries[1].alt[0].seq)
  call assert_equal(1, d.entries[1].newhead)
  call assert_equal(3, d.entries[1].seq)
  call assert_true(d.entries[1].time <= d.time_cur)

  undo
  set ul=100
  let d = undotree()
  call assert_equal(3, d.seq_last)
  call assert_equal(1, d.seq_cur)
  call assert_equal(0, d.save_last)
  call assert_equal(0, d.save_cur)
  call assert_equal(2, len(d.entries))
  call assert_equal(1, d.entries[0].seq)
  call assert_equal(2, d.entries[1].alt[0].seq)
  call assert_equal(1, d.entries[1].curhead)
  call assert_equal(1, d.entries[1].newhead)
  call assert_equal(3, d.entries[1].seq)
  call assert_true(d.entries[1].time == d.time_cur)

  w! Xtest
  let d = undotree()
  call assert_equal(1, d.save_cur)
  call assert_equal(1, d.save_last)
  call delete('Xtest')
  bwipe! Xtest
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
  throw 'skipped: Nvim does not support test_settime()'

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

func Test_undolist()
  new
  set ul=100

  let a = execute('undolist')
  call assert_equal("\nNothing to undo", a)

  " 1 leaf (2 changes).
  call feedkeys('achange1', 'xt')
  call feedkeys('achange2', 'xt')
  let a = execute('undolist')
  call assert_match("^\nnumber changes  when  *saved\n *2  *2 .*$", a)

  " 2 leaves.
  call feedkeys('u', 'xt')
  call feedkeys('achange3\<Esc>', 'xt')
  let a = execute('undolist')
  call assert_match("^\nnumber changes  when  *saved\n *2  *2  *.*\n *3  *2 .*$", a)
  close!
endfunc

func Test_U_command()
  new
  set ul=100
  call feedkeys("achange1\<Esc>", 'xt')
  call feedkeys("achange2\<Esc>", 'xt')
  norm! U
  call assert_equal('', getline(1))
  norm! U
  call assert_equal('change1change2', getline(1))
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

func Test_undofile_earlier()
  throw 'skipped: Nvim does not support test_settime()'

  let t0 = localtime() - 43200
  call test_settime(t0)
  new Xfile
  call feedkeys("ione\<Esc>", 'xt')
  set ul=100
  call test_settime(t0 + 1)
  call feedkeys("otwo\<Esc>", 'xt')
  set ul=100
  call test_settime(t0 + 2)
  call feedkeys("othree\<Esc>", 'xt')
  set ul=100
  w
  wundo Xundofile
  bwipe!
  " restore normal timestamps.
  call test_settime(0)
  new Xfile
  rundo Xundofile
  earlier 1d
  call assert_equal('', getline(1))
  bwipe!
  call delete('Xfile')
  call delete('Xundofile')
endfunc

" Test for undo working properly when executing commands from a register.
" Also test this in an empty buffer.
func Test_cmd_in_reg_undo()
  enew!
  let @a = "Ox\<Esc>jAy\<Esc>kdd"
  edit +/^$ test_undo.vim
  normal @au
  call assert_equal(0, &modified)
  return
  new
  normal @au
  call assert_equal(0, &modified)
  only!
  let @a = ''
endfunc

func Test_redo_empty_line()
  new
  exe "norm\x16r\x160"
  exe "norm."
  bwipe!
endfunc

" This used to cause an illegal memory access
func Test_undo_append()
  new
  call feedkeys("axx\<Esc>v", 'xt')
  undo
  norm o
  quit
endfunc

funct Test_undofile()
  " Test undofile() without setting 'undodir'.
  if has('persistent_undo')
    call assert_equal(fnamemodify('.Xundofoo.un~', ':p'), undofile('Xundofoo'))
  else
    call assert_equal('', undofile('Xundofoo'))
  endif
  call assert_equal('', undofile(''))

  " Test undofile() with 'undodir' set to to an existing directory.
  call mkdir('Xundodir')
  set undodir=Xundodir
  let cwd = getcwd()
  if has('win32')
    " Replace windows drive such as C:... into C%...
    let cwd = substitute(cwd, '^\([A-Z]\):', '\1%', 'g')
  endif
  let pathsep = has('win32') ? '\' : '/'
  let cwd = substitute(cwd . pathsep . 'Xundofoo', pathsep, '%', 'g')
  if has('persistent_undo')
    call assert_equal('Xundodir' . pathsep . cwd, undofile('Xundofoo'))
  else
    call assert_equal('', undofile('Xundofoo'))
  endif
  call assert_equal('', undofile(''))
  call delete('Xundodir', 'd')

  " Test undofile() with 'undodir' set to a non-existing directory.
  " call assert_equal('', undofile('Xundofoo'))

  set undodir&
endfunc
