" Test sort()

func Test_sort_strings()
  " numbers compared as strings
  call assert_equal([1, 2, 3], sort([3, 2, 1]))
  call assert_equal([13, 28, 3], sort([3, 28, 13]))
endfunc

func Test_sort_numeric()
  call assert_equal([1, 2, 3], sort([3, 2, 1], 'n'))
  call assert_equal([3, 13, 28], sort([13, 28, 3], 'n'))
  " strings are not sorted
  call assert_equal(['13', '28', '3'], sort(['13', '28', '3'], 'n'))
endfunc

func Test_sort_numbers()
  call assert_equal([3, 13, 28], sort([13, 28, 3], 'N'))
  call assert_equal(['3', '13', '28'], sort(['13', '28', '3'], 'N'))
endfunc
