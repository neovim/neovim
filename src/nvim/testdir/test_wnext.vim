" Test :wnext :wNext and :wprevious

func Test_wnext()
  args X1 X2

  call setline(1, '1')
  wnext
  call assert_equal(['1'], readfile('X1'))
  call assert_equal('X2', bufname('%'))

  call setline(1, '2')
  call assert_fails('wnext', 'E165:')
  call assert_equal(['2'], readfile('X2'))
  call assert_equal('X2', bufname('%'))

  " Test :wnext with a single file.
  args X1
  call assert_equal('X1', bufname('%'))
  call assert_fails('wnext', 'E163:')

  " Test :wnext with a count.
  args X1 X2 X3
  call assert_equal('X1', bufname('%'))
  2wnext
  call assert_equal('X3', bufname('%'))

  " Test :wnext {file}.
  args X1 X2 X3
  wnext X4
  call assert_equal(['1'], readfile('X4'))
  call assert_equal('X2', bufname('%'))
  call assert_fails('wnext X4', 'E13:')
  call assert_equal(['1'], readfile('X4'))
  wnext! X4
  call assert_equal(['2'], readfile('X4'))
  call assert_equal('X3', bufname('%'))

  args X1 X2
  " Commented out as, E13 occurs on Windows instead of E17
  "call assert_fails('wnext .', 'E17:')
  call assert_fails('wnext! .', 'E502:')

  %bwipe!
  call delete('X1')
  call delete('X2')
  call delete('X3')
  call delete('X4')
endfunc

func Test_wprevious()
  args X1 X2

  next
  call assert_equal('X2', bufname('%'))
  call setline(1, '2')
  wprevious
  call assert_equal(['2'], readfile('X2'))
  call assert_equal('X1', bufname('%'))

  call setline(1, '1')
  call assert_fails('wprevious', 'E164:')
  call assert_fails('wNext', 'E164:')

  " Test :wprevious with a single file.
  args X1
  call assert_fails('wprevious', 'E163:')
  call assert_fails('wNext', 'E163:')

  " Test :wprevious with a count.
  args X1 X2 X3
  2next
  call setline(1, '3')
  call assert_equal('X3', bufname('%'))
  2wprevious
  call assert_equal('X1', bufname('%'))
  call assert_equal(['3'], readfile('X3'))

  " Test :wprevious {file}
  args X1 X2 X3
  2next
  call assert_equal('X3', bufname('%'))
  wprevious X4
  call assert_equal(['3'], readfile('X4'))
  call assert_equal('X2', bufname('%'))
  call assert_fails('wprevious X4', 'E13:')
  call assert_equal(['3'], readfile('X4'))
  wprevious! X4
  call assert_equal(['2'], readfile('X4'))
  call assert_equal('X1', bufname('%'))

  args X1 X2
  " Commented out as, E13 occurs on Windows instead of E17
  "call assert_fails('wprevious .', 'E17:')
  call assert_fails('wprevious! .', 'E502:')

  %bwipe!
  call delete('X1')
  call delete('X2')
  call delete('X3')
  call delete('X4')
endfunc
