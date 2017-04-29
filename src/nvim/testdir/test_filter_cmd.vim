" Test the :filter command modifier

func Test_filter()
  edit Xdoesnotmatch
  edit Xwillmatch
  call assert_equal('"Xwillmatch"', substitute(execute('filter willma ls'), '[^"]*\(".*"\)[^"]*', '\1', ''))
endfunc

func Test_filter_fails()
  call assert_fails('filter', 'E471:')
  call assert_fails('filter pat', 'E476:')
  call assert_fails('filter /pat', 'E476:')
  call assert_fails('filter /pat/', 'E476:')
  call assert_fails('filter /pat/ asdf', 'E492:')
endfunc
