" Tests for the jumplist functionality

" Tests for the getjumplist() function
func Test_getjumplist()
  if !has("jumplist")
    return
  endif

  %bwipe
  clearjumps
  call assert_equal([[], 0], getjumplist())
  call assert_equal([[], 0], getjumplist(1))
  call assert_equal([[], 0], getjumplist(1, 1))

  call assert_equal([], getjumplist(100))
  call assert_equal([], getjumplist(1, 100))

  let lines = []
  for i in range(1, 100)
    call add(lines, "Line " . i)
  endfor
  call writefile(lines, "Xtest")

  " Jump around and create a jump list
  edit Xtest
  let bnr = bufnr('%')
  normal 50%
  normal G
  normal gg

  let expected = [[
	      \ {'lnum': 1, 'bufnr': bnr, 'col': 0, 'coladd': 0},
	      \ {'lnum': 50, 'bufnr': bnr, 'col': 0, 'coladd': 0},
	      \ {'lnum': 100, 'bufnr': bnr, 'col': 0, 'coladd': 0}], 3]
  call assert_equal(expected, getjumplist())
  " jumplist doesn't change in between calls
  call assert_equal(expected, getjumplist())

  " Traverse the jump list and verify the results
  5
  exe "normal \<C-O>"
  call assert_equal(2, 1->getjumplist()[1])
  exe "normal 2\<C-O>"
  call assert_equal(0, getjumplist(1, 1)[1])
  exe "normal 3\<C-I>"
  call assert_equal(3, getjumplist()[1])
  exe "normal \<C-O>"
  normal 20%
  let expected = [[
	      \ {'lnum': 1, 'bufnr': bnr, 'col': 0, 'coladd': 0},
	      \ {'lnum': 50, 'bufnr': bnr, 'col': 0, 'coladd': 0},
	      \ {'lnum': 5, 'bufnr': bnr, 'col': 0, 'coladd': 0},
	      \ {'lnum': 100, 'bufnr': bnr, 'col': 0, 'coladd': 0}], 4]
  call assert_equal(expected, getjumplist())
  " jumplist doesn't change in between calls
  call assert_equal(expected, getjumplist())

  let l = getjumplist()
  call test_garbagecollect_now()
  call assert_equal(4, l[1])
  clearjumps
  call test_garbagecollect_now()
  call assert_equal(4, l[1])

  call delete("Xtest")
endfunc

func Test_jumplist_invalid()
  new
  clearjumps
  " put some randome text
  put ='a'
  let prev = bufnr('%')
  setl nomodified bufhidden=wipe
  e XXJumpListBuffer
  let bnr = bufnr('%')
  " 1) empty jumplist
  let expected = [[
   \ {'lnum': 2, 'bufnr': prev, 'col': 0, 'coladd': 0}], 1]
  call assert_equal(expected, getjumplist())
  let jumps = execute(':jumps')
  call assert_equal('>', jumps[-1:])
  " now jump back
  exe ":norm! \<c-o>"
  let expected = [[
    \ {'lnum': 2, 'bufnr': prev, 'col': 0, 'coladd': 0},
    \ {'lnum': 1, 'bufnr': bnr,  'col': 0, 'coladd': 0}], 0]
  call assert_equal(expected, getjumplist())
  let jumps = execute(':jumps')
  call assert_match('>  0     2    0 -invalid-', jumps)
endfunc

" Test for '' mark in an empty buffer

func Test_empty_buffer()
  new
  insert
a
b
c
d
.
  call assert_equal(1, line("''"))
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
