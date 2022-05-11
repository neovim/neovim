" Tests for Vim buffer

source check.vim

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
