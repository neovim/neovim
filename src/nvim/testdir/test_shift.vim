" Test shifting lines with :> and :<

source check.vim

func Test_ex_shift_right()
  set shiftwidth=2

  " shift right current line.
  call setline(1, range(1, 5))
  2
  >
  3
  >>
  call assert_equal(['1',
        \            '  2',
        \            '    3',
        \            '4',
        \            '5'], getline(1, '$'))

  " shift right with range.
  call setline(1, range(1, 4))
  2,3>>
  call assert_equal(['1',
        \            '    2',
        \            '    3',
        \            '4',
        \            '5'], getline(1, '$'))

  " shift right with range and count.
  call setline(1, range(1, 4))
  2>3
  call assert_equal(['1',
        \            '  2',
        \            '  3',
        \            '  4',
        \            '5'], getline(1, '$'))

  bw!
  set shiftwidth&
endfunc

func Test_ex_shift_left()
  set shiftwidth=2

  call setline(1, range(1, 5))
  %>>>

  " left shift current line.
  2<
  3<<
  4<<<<<
  call assert_equal(['      1',
        \            '    2',
        \            '  3',
        \            '4',
        \            '      5'], getline(1, '$'))

  " shift right with range.
  call setline(1, range(1, 5))
  %>>>
  2,3<<
  call assert_equal(['      1',
        \            '  2',
        \            '  3',
        \            '      4',
        \            '      5'], getline(1, '$'))

  " shift right with range and count.
  call setline(1, range(1, 5))
  %>>>
  2<<3
  call assert_equal(['      1',
     \               '  2',
     \               '  3',
     \               '  4',
     \               '      5'], getline(1, '$'))

  bw!
  set shiftwidth&
endfunc

func Test_ex_shift_rightleft()
  CheckFeature rightleft

  set shiftwidth=2 rightleft

  call setline(1, range(1, 4))
  2,3<<
  call assert_equal(['1',
        \             '    2',
        \             '    3',
        \             '4'], getline(1, '$'))

  3,4>
  call assert_equal(['1',
        \            '    2',
        \            '  3',
        \            '4'], getline(1, '$'))

  bw!
  set rightleft& shiftwidth&
endfunc

func Test_ex_shift_errors()
  call assert_fails('><', 'E488:')
  call assert_fails('<>', 'E488:')

  call assert_fails('>!', 'E477:')
  call assert_fails('<!', 'E477:')

  " call assert_fails('2,1>', 'E493:')
  call assert_fails('execute "2,1>"', 'E493:')
  " call assert_fails('2,1<', 'E493:')
  call assert_fails('execute "2,1<"', 'E493:')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
