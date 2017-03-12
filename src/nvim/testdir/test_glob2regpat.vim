" Test glob2regpat()

func Test_invalid()
  call assert_fails('call glob2regpat(1.33)', 'E806:')
endfunc

func Test_valid()
  call assert_equal('^foo\.', glob2regpat('foo.*'))
  call assert_equal('\.vim$', glob2regpat('*.vim'))
endfunc
