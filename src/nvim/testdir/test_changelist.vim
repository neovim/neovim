" Tests for the changelist functionality

" Tests for the getchangelist() function
func Test_getchangelist()
  if !has("jumplist")
    return
  endif

  bwipe!
  enew
  call assert_equal([], getchangelist(10))
  call assert_equal([[], 0], getchangelist('%'))

  call writefile(['line1', 'line2', 'line3'], 'Xfile1.txt')
  call writefile(['line1', 'line2', 'line3'], 'Xfile2.txt')

  edit Xfile1.txt
  exe "normal 1Goline\<C-G>u1.1"
  exe "normal 3Goline\<C-G>u2.1"
  exe "normal 5Goline\<C-G>u3.1"
  normal g;
  call assert_equal([[
	      \ {'lnum' : 2, 'col' : 4, 'coladd' : 0},
	      \ {'lnum' : 4, 'col' : 4, 'coladd' : 0},
	      \ {'lnum' : 6, 'col' : 4, 'coladd' : 0}], 2],
	      \ getchangelist('%'))

  hide edit Xfile2.txt
  exe "normal 1GOline\<C-G>u1.0"
  exe "normal 2Goline\<C-G>u2.0"
  call assert_equal([[
	      \ {'lnum' : 1, 'col' : 6, 'coladd' : 0},
	      \ {'lnum' : 3, 'col' : 6, 'coladd' : 0}], 2],
	      \ getchangelist('%'))
  hide enew

  call assert_equal([[
	      \ {'lnum' : 2, 'col' : 4, 'coladd' : 0},
	      \ {'lnum' : 4, 'col' : 4, 'coladd' : 0},
	      \ {'lnum' : 6, 'col' : 4, 'coladd' : 0}], 3], getchangelist(2))
  call assert_equal([[
	      \ {'lnum' : 1, 'col' : 6, 'coladd' : 0},
	      \ {'lnum' : 3, 'col' : 6, 'coladd' : 0}], 2], getchangelist(3))

  bwipe!
  call delete('Xfile1.txt')
  call delete('Xfile2.txt')
endfunc
