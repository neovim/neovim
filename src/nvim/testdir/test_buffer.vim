" Tests for Vim buffer

source check.vim

" Test for the :bunload command with an offset
func Test_bunload_with_offset()
  %bwipe!
  call writefile(['B1'], 'b1')
  call writefile(['B2'], 'b2')
  call writefile(['B3'], 'b3')
  call writefile(['B4'], 'b4')

  " Load four buffers. Unload the second and third buffers and then
  " execute .+3bunload to unload the last buffer.
  edit b1
  new b2
  new b3
  new b4

  bunload b2
  bunload b3
  exe bufwinnr('b1') . 'wincmd w'
  .+3bunload
  call assert_equal(0, getbufinfo('b4')[0].loaded)
  call assert_equal('b1',
        \ fnamemodify(getbufinfo({'bufloaded' : 1})[0].name, ':t'))

  " Load four buffers. Unload the third and fourth buffers. Execute .+3bunload
  " and check whether the second buffer is unloaded.
  ball
  bunload b3
  bunload b4
  exe bufwinnr('b1') . 'wincmd w'
  .+3bunload
  call assert_equal(0, getbufinfo('b2')[0].loaded)
  call assert_equal('b1',
        \ fnamemodify(getbufinfo({'bufloaded' : 1})[0].name, ':t'))

  " Load four buffers. Unload the second and third buffers and from the last
  " buffer execute .-3bunload to unload the first buffer.
  ball
  bunload b2
  bunload b3
  exe bufwinnr('b4') . 'wincmd w'
  .-3bunload
  call assert_equal(0, getbufinfo('b1')[0].loaded)
  call assert_equal('b4',
        \ fnamemodify(getbufinfo({'bufloaded' : 1})[0].name, ':t'))

  " Load four buffers. Unload the first and second buffers. Execute .-3bunload
  " from the last buffer and check whether the third buffer is unloaded.
  ball
  bunload b1
  bunload b2
  exe bufwinnr('b4') . 'wincmd w'
  .-3bunload
  call assert_equal(0, getbufinfo('b3')[0].loaded)
  call assert_equal('b4',
        \ fnamemodify(getbufinfo({'bufloaded' : 1})[0].name, ':t'))

  %bwipe!
  call delete('b1')
  call delete('b2')
  call delete('b3')
  call delete('b4')

  call assert_fails('1,4bunload', 'E16:')
  call assert_fails(',100bunload', 'E16:')

  " Use a try-catch for this test. When assert_fails() is used for this
  " test, the command fails with E515: instead of E90:
  let caught_E90 = 0
  try
    $bunload
  catch /E90:/
    let caught_E90 = 1
  endtry
  call assert_equal(1, caught_E90)
  call assert_fails('$bunload', 'E515:')
endfunc

" Test for :buffer, :bnext, :bprevious, :brewind, :blast and :bmodified
" commands
func Test_buflist_browse()
  %bwipe!
  call assert_fails('buffer 1000', 'E86:')

  call writefile(['foo1', 'foo2', 'foo3', 'foo4'], 'Xfile1')
  call writefile(['bar1', 'bar2', 'bar3', 'bar4'], 'Xfile2')
  call writefile(['baz1', 'baz2', 'baz3', 'baz4'], 'Xfile3')
  edit Xfile1
  let b1 = bufnr()
  edit Xfile2
  let b2 = bufnr()
  edit +/baz4 Xfile3
  let b3 = bufnr()

  call assert_fails('buffer ' .. b1 .. ' abc', 'E488:')
  call assert_equal(b3, bufnr())
  call assert_equal(4, line('.'))
  exe 'buffer +/bar2 ' .. b2
  call assert_equal(b2, bufnr())
  call assert_equal(2, line('.'))
  exe 'buffer +/bar1'
  call assert_equal(b2, bufnr())
  call assert_equal(1, line('.'))

  brewind +
  call assert_equal(b1, bufnr())
  call assert_equal(4, line('.'))

  blast +/baz2
  call assert_equal(b3, bufnr())
  call assert_equal(2, line('.'))

  bprevious +/bar4
  call assert_equal(b2, bufnr())
  call assert_equal(4, line('.'))

  bnext +/baz3
  call assert_equal(b3, bufnr())
  call assert_equal(3, line('.'))

  call assert_fails('bmodified', 'E84:')
  call setbufvar(b2, '&modified', 1)
  exe 'bmodified +/bar3'
  call assert_equal(b2, bufnr())
  call assert_equal(3, line('.'))

  " With no listed buffers in the list, :bnext and :bprev should fail
  %bwipe!
  set nobuflisted
  call assert_fails('bnext', 'E85:')
  call assert_fails('bprev', 'E85:')
  set buflisted

  call assert_fails('sandbox bnext', 'E48:')

  call delete('Xfile1')
  call delete('Xfile2')
  call delete('Xfile3')
  %bwipe!
endfunc

" Test for :bdelete
func Test_bdelete_cmd()
  %bwipe!
  call assert_fails('bdelete 5', 'E516:')
  call assert_fails('1,1bdelete 1 2', 'E488:')

  " Deleting a unlisted and unloaded buffer
  edit Xfile1
  let bnr = bufnr()
  set nobuflisted
  enew
  call assert_fails('bdelete ' .. bnr, 'E516:')
  %bwipe!
endfunc

func Test_buffer_error()
  new foo1
  new foo2

  call assert_fails('buffer foo', 'E93:')
  call assert_fails('buffer bar', 'E94:')
  call assert_fails('buffer 0', 'E939:')

  %bwipe
endfunc

func Test_badd_options()
  new SomeNewBuffer
  setlocal numberwidth=3
  wincmd p
  badd +1 SomeNewBuffer
  new SomeNewBuffer
  call assert_equal(3, &numberwidth)
  close
  close
  bwipe! SomeNewBuffer
endfunc

func Test_balt()
  new SomeNewBuffer
  balt +3 OtherBuffer
  e #
  call assert_equal('OtherBuffer', bufname())
endfunc

" Test for buffer match URL(scheme) check
" scheme is alpha and inner hyphen only.
func Test_buffer_scheme()
  CheckMSWindows

  set noshellslash
  %bwipe!
  let bufnames = [
    \ #{id: 'b0', name: 'test://xyz/foo/b0'    , match: 1},
    \ #{id: 'b1', name: 'test+abc://xyz/foo/b1', match: 0},
    \ #{id: 'b2', name: 'test_abc://xyz/foo/b2', match: 0},
    \ #{id: 'b3', name: 'test-abc://xyz/foo/b3', match: 1},
    \ #{id: 'b4', name: '-test://xyz/foo/b4'   , match: 0},
    \ #{id: 'b5', name: 'test-://xyz/foo/b5'   , match: 0},
    \]
  for buf in bufnames
    new `=buf.name`
    if buf.match
      call assert_equal(buf.name,    getbufinfo(buf.id)[0].name)
    else
      " slashes will have become backslashes
      call assert_notequal(buf.name, getbufinfo(buf.id)[0].name)
    endif
    bwipe
  endfor

  set shellslash&
endfunc

" this was using a NULL pointer after failing to use the pattern
func Test_buf_pattern_invalid()
  vsplit 0000000
  silent! buf [0--]\&\zs*\zs*e
  bwipe!

  vsplit 00000000000000000000000000
  silent! buf [0--]\&\zs*\zs*e
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
