" Tests for the undo tree.
" Since this script is sourced we need to explicitly break changes up in
" undo-able pieces.  Do that by setting 'undolevels'.
" Also tests :earlier and :later.

source check.vim
source screendump.vim

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

func Test_undotree_bufnr()
  new
  let buf1 = bufnr()

  normal! Aabc
  set ul=100

  " Save undo tree without bufnr as ground truth for buffer 1
  let d1 = undotree()

  new
  let buf2 = bufnr()

  normal! Adef
  set ul=100

  normal! Aghi
  set ul=100

  " Save undo tree without bufnr as ground truth for buffer 2
  let d2 = undotree()

  " Check undotree() with bufnr argument
  let d = undotree(buf1)
  call assert_equal(d1, d)
  call assert_notequal(d2, d)

  let d = undotree(buf2)
  call assert_notequal(d1, d)
  call assert_equal(d2, d)

  " Switch buffers and check again
  wincmd p

  let d = undotree(buf1)
  call assert_equal(d1, d)

  let d = undotree(buf2)
  call assert_notequal(d1, d)
  call assert_equal(d2, d)

  " error cases
  call assert_fails('call undotree(-1)', 'E158:')
  call assert_fails('call undotree("nosuchbuf")', 'E158:')

  " after creating a buffer nosuchbuf, undotree('nosuchbuf') should
  " not error out
  new nosuchbuf
  let d = {'seq_last': 0, 'entries': [], 'time_cur': 0, 'save_last': 0, 'synced': 1, 'save_cur': 0, 'seq_cur': 0}
  call assert_equal(d, undotree("nosuchbuf"))
  " clean up
  bw nosuchbuf

  " Drop created windows
  set ul&
  new
  only!
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

  " Resetting the local 'undolevels' value to use the global value
  setlocal undolevels=5
  "setlocal undolevels<
  set undolevels<
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
  throw 'Skipped: Nvim does not support test_settime()'
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
  bwipe!
endfunc

func Test_undojoin_redo()
  new
  call setline(1, ['first line', 'second line'])
  call feedkeys("ixx\<Esc>", 'xt')
  call feedkeys(":undojoin | redo\<CR>", 'xt')
  call assert_equal('xxfirst line', getline(1))
  call assert_equal('second line', getline(2))
  bwipe!
endfunc

" undojoin not allowed after undo
func Test_undojoin_after_undo()
  new
  call feedkeys("ixx\<Esc>u", 'xt')
  call assert_fails(':undojoin', 'E790:')
  bwipe!
endfunc

" undojoin is a noop when no change yet, or when 'undolevels' is negative
func Test_undojoin_noop()
  new
  call feedkeys(":undojoin\<CR>", 'xt')
  call assert_equal([''], getline(1, '$'))
  setlocal undolevels=-1
  call feedkeys("ixx\<Esc>u", 'xt')
  call feedkeys(":undojoin\<CR>", 'xt')
  call assert_equal(['xx'], getline(1, '$'))
  bwipe!
endfunc

func Test_undo_write()
  call delete('Xtest')
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

  call assert_fails('earlier xyz', 'E475:')
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
  throw 'Skipped: Nvim does not support test_settime()'
  if has('win32')
    " FIXME: This test is flaky on MS-Windows.
    let g:test_is_flaky = 1
  endif

  " Issue #1254
  " create undofile with timestamps older than Vim startup time.
  let t0 = localtime() - 43200
  call test_settime(t0)
  new XfileEarlier
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
  new XfileEarlier
  rundo Xundofile
  earlier 1d
  call assert_equal('', getline(1))
  bwipe!
  call delete('XfileEarlier')
  call delete('Xundofile')
endfunc

func Test_wundo_errors()
  new
  call setline(1, 'hello')
  call assert_fails('wundo! Xdoesnotexist/Xundofile', 'E828:')
  bwipe!
endfunc

" Check that reading a truncated undo file doesn't hang.
func Test_undofile_truncated()
  new
  call setline(1, 'hello')
  set ul=100
  wundo Xundofile
  let contents = readfile('Xundofile', 'B')

  " try several sizes
  for size in range(20, 500, 33)
    call writefile(contents[0:size], 'Xundofile')
    call assert_fails('rundo Xundofile', 'E825:')
  endfor

  bwipe!
  call delete('Xundofile')
endfunc

func Test_rundo_errors()
  call assert_fails('rundo XfileDoesNotExist', 'E822:')

  call writefile(['abc'], 'Xundofile')
  call assert_fails('rundo Xundofile', 'E823:')

  call delete('Xundofile')
endfunc

func Test_undofile_next()
  set undofile
  new Xfoo.txt
  execute "norm ix\<c-g>uy\<c-g>uz\<Esc>"
  write
  bwipe

  next Xfoo.txt
  call assert_equal('xyz', getline(1))
  silent undo
  call assert_equal('xy', getline(1))
  silent undo
  call assert_equal('x', getline(1))
  bwipe!

  call delete('Xfoo.txt')
  call delete('.Xfoo.txt.un~')
  set undofile&
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

" This used to cause an illegal memory access
func Test_undo_append()
  new
  call feedkeys("axx\<Esc>v", 'xt')
  undo
  norm o
  quit
endfunc

func Test_undo_0()
  new
  set ul=100
  normal i1
  undo
  normal i2
  undo
  normal i3

  undo 0
  let d = undotree()
  call assert_equal('', getline(1))
  call assert_equal(0, d.seq_cur)

  redo
  let d = undotree()
  call assert_equal('3', getline(1))
  call assert_equal(3, d.seq_cur)

  undo 2
  undo 0
  let d = undotree()
  call assert_equal('', getline(1))
  call assert_equal(0, d.seq_cur)

  redo
  let d = undotree()
  call assert_equal('2', getline(1))
  call assert_equal(2, d.seq_cur)

  undo 1
  undo 0
  let d = undotree()
  call assert_equal('', getline(1))
  call assert_equal(0, d.seq_cur)

  redo
  let d = undotree()
  call assert_equal('1', getline(1))
  call assert_equal(1, d.seq_cur)

  bwipe!
endfunc

" undo or redo are noop if there is nothing to undo or redo
func Test_undo_redo_noop()
  new
  call assert_fails('undo 2', 'E830:')

  message clear
  undo
  let messages = split(execute('message'), "\n")
  call assert_equal('Already at oldest change', messages[-1])

  message clear
  redo
  let messages = split(execute('message'), "\n")
  call assert_equal('Already at newest change', messages[-1])

  bwipe!
endfunc

func Test_redo_empty_line()
  new
  exe "norm\x16r\x160"
  exe "norm."
  bwipe!
endfunc

funct Test_undofile()
  " Test undofile() without setting 'undodir'.
  if has('persistent_undo')
    call assert_equal(fnamemodify('.Xundofoo.un~', ':p'), undofile('Xundofoo'))
  else
    call assert_equal('', undofile('Xundofoo'))
  endif
  call assert_equal('', undofile(''))

  " Test undofile() with 'undodir' set to an existing directory.
  call mkdir('Xundodir')
  set undodir=Xundodir
  let cwd = getcwd()
  if has('win32')
    " Replace windows drive such as C:... into C%...
    let cwd = substitute(cwd, '^\([a-zA-Z]\):', '\1%', 'g')
  endif
  let cwd = substitute(cwd . '/Xundofoo', '/', '%', 'g')
  if has('persistent_undo')
    call assert_equal('Xundodir/' . cwd, undofile('Xundofoo'))
  else
    call assert_equal('', undofile('Xundofoo'))
  endif
  call assert_equal('', undofile(''))
  call delete('Xundodir', 'd')

  " Test undofile() with 'undodir' set to a non-existing directory.
  " call assert_equal('', 'Xundofoo'->undofile())

  if isdirectory('/tmp')
    set undodir=/tmp
    if has('osx')
      call assert_equal('/tmp/%private%tmp%file', undofile('///tmp/file'))
    else
      call assert_equal('/tmp/%tmp%file', undofile('///tmp/file'))
    endif
  endif

  set undodir&
endfunc

" Tests for the undo file
" Explicitly break changes up in undo-able pieces by setting 'undolevels'.
func Test_undofile_2()
  set undolevels=100 undofile
  edit Xtestfile
  call append(0, 'this is one line')
  call cursor(1, 1)

  " first a simple one-line change.
  set undolevels=100
  s/one/ONE/
  set undolevels=100
  write
  bwipe!
  edit Xtestfile
  undo
  call assert_equal('this is one line', getline(1))

  " change in original file fails check
  set noundofile
  edit! Xtestfile
  s/line/Line/
  write
  set undofile
  bwipe!
  edit Xtestfile
  undo
  call assert_equal('this is ONE Line', getline(1))

  " add 10 lines, delete 6 lines, undo 3
  set undofile
  call setbufline('%', 1, ['one', 'two', 'three', 'four', 'five', 'six',
	      \ 'seven', 'eight', 'nine', 'ten'])
  set undolevels=100
  normal 3Gdd
  set undolevels=100
  normal dd
  set undolevels=100
  normal dd
  set undolevels=100
  normal dd
  set undolevels=100
  normal dd
  set undolevels=100
  normal dd
  set undolevels=100
  write
  bwipe!
  edit Xtestfile
  normal uuu
  call assert_equal(['one', 'two', 'six', 'seven', 'eight', 'nine', 'ten'],
	      \ getline(1, '$'))

  " Test that reading the undofiles when setting undofile works
  set noundofile undolevels=0
  exe "normal i\n"
  undo
  edit! Xtestfile
  set undofile undolevels=100
  normal uuuuuu
  call assert_equal(['one', 'two', 'three', 'four', 'five', 'six', 'seven',
	      \ 'eight', 'nine', 'ten'], getline(1, '$'))

  bwipe!
  call delete('Xtestfile')
  let ufile = has('vms') ? '_un_Xtestfile' : '.Xtestfile.un~'
  call delete(ufile)
  set undofile& undolevels&
endfunc

" Test 'undofile' using a file encrypted with 'zip' crypt method
func Test_undofile_cryptmethod_zip()
  throw 'skipped: Nvim does not support cryptmethod'
  edit Xtestfile
  set undofile cryptmethod=zip
  call append(0, ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'])
  call cursor(5, 1)

  set undolevels=100
  normal kkkdd
  set undolevels=100
  normal dd
  set undolevels=100
  normal dd
  set undolevels=100
  " encrypt the file using key 'foobar'
  call feedkeys("foobar\nfoobar\n")
  X
  write!
  bwipe!

  call feedkeys("foobar\n")
  edit Xtestfile
  set key=
  normal uu
  call assert_equal(['monday', 'wednesday', 'thursday', 'friday', ''],
                    \ getline(1, '$'))

  bwipe!
  call delete('Xtestfile')
  let ufile = has('vms') ? '_un_Xtestfile' : '.Xtestfile.un~'
  call delete(ufile)
  set undofile& undolevels& cryptmethod&
endfunc

" Test 'undofile' using a file encrypted with 'blowfish' crypt method
func Test_undofile_cryptmethod_blowfish()
  throw 'skipped: Nvim does not support cryptmethod'
  edit Xtestfile
  set undofile cryptmethod=blowfish
  call append(0, ['jan', 'feb', 'mar', 'apr', 'jun'])
  call cursor(5, 1)

  set undolevels=100
  exe 'normal kk0ifoo '
  set undolevels=100
  normal dd
  set undolevels=100
  exe 'normal ibar '
  set undolevels=100
  " encrypt the file using key 'foobar'
  call feedkeys("foobar\nfoobar\n")
  X
  write!
  bwipe!

  call feedkeys("foobar\n")
  edit Xtestfile
  set key=
  call search('bar')
  call assert_equal('bar apr', getline('.'))
  undo
  call assert_equal('apr', getline('.'))
  undo
  call assert_equal('foo mar', getline('.'))
  undo
  call assert_equal('mar', getline('.'))

  bwipe!
  call delete('Xtestfile')
  let ufile = has('vms') ? '_un_Xtestfile' : '.Xtestfile.un~'
  call delete(ufile)
  set undofile& undolevels& cryptmethod&
endfunc

" Test 'undofile' using a file encrypted with 'blowfish2' crypt method
func Test_undofile_cryptmethod_blowfish2()
  throw 'skipped: Nvim does not support cryptmethod'
  edit Xtestfile
  set undofile cryptmethod=blowfish2
  call append(0, ['jan', 'feb', 'mar', 'apr', 'jun'])
  call cursor(5, 1)

  set undolevels=100
  exe 'normal kk0ifoo '
  set undolevels=100
  normal dd
  set undolevels=100
  exe 'normal ibar '
  set undolevels=100
  " encrypt the file using key 'foo2bar'
  call feedkeys("foo2bar\nfoo2bar\n")
  X
  write!
  bwipe!

  call feedkeys("foo2bar\n")
  edit Xtestfile
  set key=
  call search('bar')
  call assert_equal('bar apr', getline('.'))
  normal u
  call assert_equal('apr', getline('.'))
  normal u
  call assert_equal('foo mar', getline('.'))
  normal u
  call assert_equal('mar', getline('.'))

  bwipe!
  call delete('Xtestfile')
  let ufile = has('vms') ? '_un_Xtestfile' : '.Xtestfile.un~'
  call delete(ufile)
  set undofile& undolevels& cryptmethod&
endfunc

" Test for redoing with incrementing numbered registers
func Test_redo_repeat_numbered_register()
  new
  for [i, v] in [[1, 'one'], [2, 'two'], [3, 'three'],
        \ [4, 'four'], [5, 'five'], [6, 'six'],
        \ [7, 'seven'], [8, 'eight'], [9, 'nine']]
    exe 'let @' .. i .. '="' .. v .. '\n"'
  endfor
  call feedkeys('"1p.........', 'xt')
  call assert_equal(['', 'one', 'two', 'three', 'four', 'five', 'six',
        \ 'seven', 'eight', 'nine', 'nine'], getline(1, '$'))
  bwipe!
endfunc

" Test for redo in insert mode using CTRL-O with multibyte characters
func Test_redo_multibyte_in_insert_mode()
  new
  call feedkeys("a\<C-K>ft", 'xt')
  call feedkeys("uiHe\<C-O>.llo", 'xt')
  call assert_equal("He\ufb05llo", getline(1))
  bwipe!
endfunc

func Test_undo_mark()
  new
  " The undo is applied to the only line.
  call setline(1, 'hello')
  call feedkeys("ggyiw$p", 'xt')
  undo
  call assert_equal([0, 1, 1, 0], getpos("'["))
  call assert_equal([0, 1, 1, 0], getpos("']"))
  " The undo removes the last line.
  call feedkeys("Goaaaa\<Esc>", 'xt')
  call feedkeys("obbbb\<Esc>", 'xt')
  undo
  call assert_equal([0, 2, 1, 0], getpos("'["))
  call assert_equal([0, 2, 1, 0], getpos("']"))
  bwipe!
endfunc

func Test_undo_after_write()
  " use a terminal to make undo work like when text is typed
  CheckRunVimInTerminal

  let lines =<< trim END
      edit Xtestfile.txt
      set undolevels=100 undofile
      imap . <Cmd>write<CR>
      write
  END
  call writefile(lines, 'Xtest_undo_after_write', 'D')
  let buf = RunVimInTerminal('-S Xtest_undo_after_write', #{rows: 6})

  call term_sendkeys(buf, "Otest.\<CR>boo!!!\<Esc>")
  sleep 100m
  call term_sendkeys(buf, "u")
  call VerifyScreenDump(buf, 'Test_undo_after_write_1', {})

  call term_sendkeys(buf, "u")
  call VerifyScreenDump(buf, 'Test_undo_after_write_2', {})

  call StopVimInTerminal(buf)
  call delete('Xtestfile.txt')
  call delete('.Xtestfile.txt.un~')
endfunc

func Test_undo_range_normal()
  new
  call setline(1, ['asa', 'bsb'])
  let &l:undolevels = &l:undolevels
  %normal dfs
  call assert_equal(['a', 'b'], getline(1, '$'))
  undo
  call assert_equal(['asa', 'bsb'], getline(1, '$'))
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
