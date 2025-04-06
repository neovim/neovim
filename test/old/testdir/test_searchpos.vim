" Tests for searchpos()

func Test_searchpos()
  new one
  0put ='1a3'
  1put ='123xyz'
  call cursor(1, 1)
  call assert_equal([1, 1, 2], searchpos('\%(\([a-z]\)\|\_.\)\{-}xyz', 'pcW'))
  call cursor(1, 2)
  call assert_equal([2, 1, 1], '\%(\([a-z]\)\|\_.\)\{-}xyz'->searchpos('pcW'))
  set cpo-=c
  call cursor(1, 2)
  call assert_equal([1, 2, 2], searchpos('\%(\([a-z]\)\|\_.\)\{-}xyz', 'pcW'))
  call cursor(1, 3)
  call assert_equal([1, 3, 1], searchpos('\%(\([a-z]\)\|\_.\)\{-}xyz', 'pcW'))

  " Now with \zs, first match is in column 0, "a" is matched.
  call cursor(1, 3)
  call assert_equal([2, 4, 2], searchpos('\%(\([a-z]\)\|\_.\)\{-}\zsxyz', 'pcW'))
  " With z flag start at cursor column, don't see the "a".
  call cursor(1, 3)
  call assert_equal([2, 4, 1], searchpos('\%(\([a-z]\)\|\_.\)\{-}\zsxyz', 'pcWz'))

  set cpo+=c
  " close the window
  q!

endfunc

" vim: shiftwidth=2 sts=2 expandtab
