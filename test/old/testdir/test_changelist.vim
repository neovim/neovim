" Tests for the changelist functionality

" When splitting a window the changelist position is wrong.
" Test the changelist position after splitting a window.
" Test for the bug fixed by 7.4.386
func Test_changelist()
  let save_ul = &ul
  enew!
  call append('$', ['1', '2'])
  exe "normal i\<C-G>u"
  exe "normal Gkylpa\<C-G>u"
  set ul=100
  exe "normal Gylpa\<C-G>u"
  set ul=100
  normal gg
  vsplit
  normal g;
  call assert_equal([3, 2], [line('.'), col('.')])
  normal g;
  call assert_equal([2, 2], [line('.'), col('.')])
  call assert_fails('normal g;', 'E662:')
  new
  call assert_fails('normal g;', 'E664:')
  %bwipe!
  let &ul = save_ul
endfunc

" Moving a split should not change its changelist index.
func Test_changelist_index_move_split()
  exe "norm! iabc\<C-G>u\ndef\<C-G>u\nghi"
  vsplit
  normal 99g;
  call assert_equal(0, getchangelist('%')[1])
  wincmd L
  call assert_equal(0, getchangelist('%')[1])
endfunc

" Tests for the getchangelist() function
func Test_changelist_index()
  edit Xfile1.txt
  exe "normal iabc\<C-G>u\ndef\<C-G>u\nghi"
  call assert_equal(3, getchangelist('%')[1])
  " Move one step back in the changelist.
  normal 2g;

  hide edit Xfile2.txt
  exe "normal iabcd\<C-G>u\ndefg\<C-G>u\nghij"
  call assert_equal(3, getchangelist('%')[1])
  " Move to the beginning of the changelist.
  normal 99g;

  " Check the changelist indices.
  call assert_equal(0, getchangelist('%')[1])
  call assert_equal(1, getchangelist('#')[1])

  bwipe!
  call delete('Xfile1.txt')
  call delete('Xfile2.txt')
endfunc

func Test_getchangelist()
  bwipe!
  enew
  call assert_equal([], 10->getchangelist())
  call assert_equal([[], 0], getchangelist())

  call writefile(['line1', 'line2', 'line3'], 'Xfile1.txt')
  call writefile(['line1', 'line2', 'line3'], 'Xfile2.txt')

  edit Xfile1.txt
  let buf_1 = bufnr()
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
  let buf_2 = bufnr()
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
	      \ {'lnum' : 6, 'col' : 4, 'coladd' : 0}], 2],
	      \ getchangelist(buf_1))
  call assert_equal([[
	      \ {'lnum' : 1, 'col' : 6, 'coladd' : 0},
	      \ {'lnum' : 3, 'col' : 6, 'coladd' : 0}], 2],
	      \ getchangelist(buf_2))

  bwipe!
  call delete('Xfile1.txt')
  call delete('Xfile2.txt')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
