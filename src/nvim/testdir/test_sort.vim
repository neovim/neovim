" Tests for the "sort()" function and for the ":sort" command.

func Compare1(a, b) abort
    call sort(range(3), 'Compare2')
    return a:a - a:b
endfunc

func Compare2(a, b) abort
    return a:a - a:b
endfunc

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

func Test_sort_float()
  call assert_equal([0.28, 3, 13.5], sort([13.5, 0.28, 3], 'f'))
endfunc

func Test_sort_nested()
  " test ability to call sort() from a compare function
  call assert_equal([1, 3, 5], sort([3, 1, 5], 'Compare1'))
endfunc

func Test_sort_default()
  " docs say omitted, empty or zero argument sorts on string representation.
  call assert_equal(['2', 'A', 'AA', 'a', 1, 3.3], sort([3.3, 1, "2", "A", "a", "AA"]))
  call assert_equal(['2', 'A', 'AA', 'a', 1, 3.3], sort([3.3, 1, "2", "A", "a", "AA"], ''))
  call assert_equal(['2', 'A', 'AA', 'a', 1, 3.3], sort([3.3, 1, "2", "A", "a", "AA"], 0))
  call assert_equal(['2', 'A', 'a', 'AA', 1, 3.3], sort([3.3, 1, "2", "A", "a", "AA"], 1))
  call assert_fails('call sort([3.3, 1, "2"], 3)', "E474")
endfunc

" Tests for the ":sort" command.
func Test_sort_cmd()
  let tests = [
	\ {
	\    'name' : 'Alphabetical sort',
	\    'cmd' : '%sort',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b'
	\    ],
	\    'expected' : [
	\	' 123b',
	\	'a',
	\	'a122',
	\	'a123',
	\	'a321',
	\	'ab',
	\	'abc',
	\	'b123',
	\	'b321',
	\	'b321',
	\	'b321b',
	\	'b322b',
	\	'c123d',
	\	'c321d'
	\    ]
	\ },
	\ {
	\    'name' : 'Numeric sort',
	\    'cmd' : '%sort n',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'a',
	\	'x-22',
	\	'b321',
	\	'b123',
	\	'',
	\	'c123d',
	\	'-24',
	\	' 123b',
	\	'c321d',
	\	'0',
	\	'b322b',
	\	'b321',
	\	'b321b'
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	'-24',
	\	'x-22',
	\	'0',
	\	'a122',
	\	'a123',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'a321',
	\	'b321',
	\	'c321d',
	\	'b321',
	\	'b321b',
	\	'b322b'
	\    ]
	\ },
	\ {
	\    'name' : 'Hexadecimal sort',
	\    'cmd' : '%sort x',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b'
	\    ],
	\    'expected' : [
	\	'a',
	\	'ab',
	\	'abc',
	\	' 123b',
	\	'a122',
	\	'a123',
	\	'a321',
	\	'b123',
	\	'b321',
	\	'b321',
	\	'b321b',
	\	'b322b',
	\	'c123d',
	\	'c321d'
	\    ]
	\ },
	\ {
	\    'name' : 'Alphabetical unique sort',
	\    'cmd' : '%sort u',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b'
	\    ],
	\    'expected' : [
	\	' 123b',
	\	'a',
	\	'a122',
	\	'a123',
	\	'a321',
	\	'ab',
	\	'abc',
	\	'b123',
	\	'b321',
	\	'b321b',
	\	'b322b',
	\	'c123d',
	\	'c321d'
	\    ]
	\ },
	\ {
	\    'name' : 'Alphabetical reverse sort',
	\    'cmd' : '%sort!',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b'
	\    ],
	\    'expected' : [
	\	'c321d',
	\	'c123d',
	\	'b322b',
	\	'b321b',
	\	'b321',
	\	'b321',
	\	'b123',
	\	'abc',
	\	'ab',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'a',
	\	' 123b',
	\    ]
	\ },
	\ {
	\    'name' : 'Numeric reverse sort',
	\    'cmd' : '%sort! n',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b'
	\    ],
	\    'expected' : [
	\	'b322b',
	\	'b321b',
	\	'b321',
	\	'c321d',
	\	'b321',
	\	'a321',
	\	' 123b',
	\	'c123d',
	\	'b123',
	\	'a123',
	\	'a122',
	\	'a',
	\	'ab',
	\	'abc'
	\    ]
	\ },
	\ {
	\    'name' : 'Unique reverse sort',
	\    'cmd' : 'sort! u',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b'
	\    ],
	\    'expected' : [
	\	'c321d',
	\	'c123d',
	\	'b322b',
	\	'b321b',
	\	'b321',
	\	'b123',
	\	'abc',
	\	'ab',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'a',
	\	' 123b',
	\    ]
	\ },
	\ {
	\    'name' : 'Octal sort',
	\    'cmd' : 'sort o',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	'',
	\	'a122',
	\	'a123',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'a321',
	\	'b321',
	\	'c321d',
	\	'b321',
	\	'b321b',
	\	'b322b'
	\    ]
	\ },
	\ {
	\    'name' : 'Reverse hexadecimal sort',
	\    'cmd' : 'sort! x',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'c321d',
	\	'c123d',
	\	'b322b',
	\	'b321b',
	\	'b321',
	\	'b321',
	\	'b123',
	\	'a321',
	\	'a123',
	\	'a122',
	\	' 123b',
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	''
	\    ]
	\ },
	\ {
	\    'name' : 'Alpha (skip first character) sort',
	\    'cmd' : 'sort/./',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'a',
	\	'',
	\	'',
	\	'a122',
	\	'a123',
	\	'b123',
	\	' 123b',
	\	'c123d',
	\	'a321',
	\	'b321',
	\	'b321',
	\	'b321b',
	\	'c321d',
	\	'b322b',
	\	'ab',
	\	'abc'
	\    ]
	\ },
	\ {
	\    'name' : 'Alpha (skip first 2 characters) sort',
	\    'cmd' : 'sort/../',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'ab',
	\	'a',
	\	'',
	\	'',
	\	'a321',
	\	'b321',
	\	'b321',
	\	'b321b',
	\	'c321d',
	\	'a122',
	\	'b322b',
	\	'a123',
	\	'b123',
	\	' 123b',
	\	'c123d',
	\	'abc'
	\    ]
	\ },
	\ {
	\    'name' : 'alpha, unique, skip first 2 characters',
	\    'cmd' : 'sort/../u',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'ab',
	\	'a',
	\	'',
	\	'a321',
	\	'b321',
	\	'b321b',
	\	'c321d',
	\	'a122',
	\	'b322b',
	\	'a123',
	\	'b123',
	\	' 123b',
	\	'c123d',
	\	'abc'
	\    ]
	\ },
	\ {
	\    'name' : 'numeric, skip first character',
	\    'cmd' : 'sort/./n',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	'',
	\	'a122',
	\	'a123',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'a321',
	\	'b321',
	\	'c321d',
	\	'b321',
	\	'b321b',
	\	'b322b'
	\    ]
	\ },
	\ {
	\    'name' : 'alpha, sort on first character',
	\    'cmd' : 'sort/./r',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'',
	\	'',
	\	' 123b',
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'c123d',
	\	'c321d'
	\    ]
	\ },
	\ {
	\    'name' : 'alpha, sort on first 2 characters',
	\    'cmd' : 'sort/../r',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'a',
	\	'',
	\	'',
	\	' 123b',
	\	'a123',
	\	'a122',
	\	'a321',
	\	'abc',
	\	'ab',
	\	'b123',
	\	'b321',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'c123d',
	\	'c321d'
	\    ]
	\ },
	\ {
	\    'name' : 'numeric, sort on first character',
	\    'cmd' : 'sort/./rn',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ]
	\ },
	\ {
	\    'name' : 'alpha, skip past first digit',
	\    'cmd' : 'sort/\d/',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	'',
	\	'a321',
	\	'b321',
	\	'b321',
	\	'b321b',
	\	'c321d',
	\	'a122',
	\	'b322b',
	\	'a123',
	\	'b123',
	\	' 123b',
	\	'c123d'
	\    ]
	\ },
	\ {
	\    'name' : 'alpha, sort on first digit',
	\    'cmd' : 'sort/\d/r',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	'',
	\	'a123',
	\	'a122',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'a321',
	\	'b321',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b'
	\    ]
	\ },
	\ {
	\    'name' : 'numeric, skip past first digit',
	\    'cmd' : 'sort/\d/n',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	'',
	\	'a321',
	\	'b321',
	\	'c321d',
	\	'b321',
	\	'b321b',
	\	'a122',
	\	'b322b',
	\	'a123',
	\	'b123',
	\	'c123d',
	\	' 123b'
	\    ]
	\ },
	\ {
	\    'name' : 'numeric, sort on first digit',
	\    'cmd' : 'sort/\d/rn',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	'',
	\	'a123',
	\	'a122',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'a321',
	\	'b321',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b'
	\    ]
	\ },
	\ {
	\    'name' : 'alpha, skip past first 2 digits',
	\    'cmd' : 'sort/\d\d/',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	'',
	\	'a321',
	\	'b321',
	\	'b321',
	\	'b321b',
	\	'c321d',
	\	'a122',
	\	'b322b',
	\	'a123',
	\	'b123',
	\	' 123b',
	\	'c123d'
	\    ]
	\ },
	\ {
	\    'name' : 'numeric, skip past first 2 digits',
	\    'cmd' : 'sort/\d\d/n',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	'',
	\	'a321',
	\	'b321',
	\	'c321d',
	\	'b321',
	\	'b321b',
	\	'a122',
	\	'b322b',
	\	'a123',
	\	'b123',
	\	'c123d',
	\	' 123b'
	\    ]
	\ },
	\ {
	\    'name' : 'hexadecimal, skip past first 2 digits',
	\    'cmd' : 'sort/\d\d/x',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	'',
	\	'a321',
	\	'b321',
	\	'b321',
	\	'a122',
	\	'a123',
	\	'b123',
	\	'b321b',
	\	'c321d',
	\	'b322b',
	\	' 123b',
	\	'c123d'
	\    ]
	\ },
	\ {
	\    'name' : 'alpha, sort on first 2 digits',
	\    'cmd' : 'sort/\d\d/r',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	'',
	\	'a123',
	\	'a122',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'a321',
	\	'b321',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b'
	\    ]
	\ },
	\ {
	\    'name' : 'numeric, sort on first 2 digits',
	\    'cmd' : 'sort/\d\d/rn',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	'',
	\	'a123',
	\	'a122',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'a321',
	\	'b321',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b'
	\    ]
	\ },
	\ {
	\    'name' : 'hexadecimal, sort on first 2 digits',
	\    'cmd' : 'sort/\d\d/rx',
	\    'input' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'a321',
	\	'a123',
	\	'a122',
	\	'b321',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'abc',
	\	'ab',
	\	'a',
	\	'',
	\	'',
	\	'a123',
	\	'a122',
	\	'b123',
	\	'c123d',
	\	' 123b',
	\	'a321',
	\	'b321',
	\	'c321d',
	\	'b322b',
	\	'b321',
	\	'b321b'
	\    ]
	\ },
	\ {
	\    'name' : 'binary',
	\    'cmd' : 'sort b',
	\    'input' : [
	\	'0b111000',
	\	'0b101100',
	\	'0b101001',
	\	'0b101001',
	\	'0b101000',
	\	'0b000000',
	\	'0b001000',
	\	'0b010000',
	\	'0b101000',
	\	'0b100000',
	\	'0b101010',
	\	'0b100010',
	\	'0b100100',
	\	'0b100010',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'',
	\	'',
	\	'0b000000',
	\	'0b001000',
	\	'0b010000',
	\	'0b100000',
	\	'0b100010',
	\	'0b100010',
	\	'0b100100',
	\	'0b101000',
	\	'0b101000',
	\	'0b101001',
	\	'0b101001',
	\	'0b101010',
	\	'0b101100',
	\	'0b111000'
	\    ]
	\ },
	\ {
	\    'name' : 'binary with leading characters',
	\    'cmd' : 'sort b',
	\    'input' : [
	\	'0b100010',
	\	'0b010000',
	\	' 0b101001',
	\	'b0b101100',
	\	'0b100010',
	\	' 0b100100',
	\	'a0b001000',
	\	'0b101000',
	\	'0b101000',
	\	'a0b101001',
	\	'ab0b100000',
	\	'0b101010',
	\	'0b000000',
	\	'b0b111000',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'',
	\	'',
	\	'0b000000',
	\	'a0b001000',
	\	'0b010000',
	\	'ab0b100000',
	\	'0b100010',
	\	'0b100010',
	\	' 0b100100',
	\	'0b101000',
	\	'0b101000',
	\	' 0b101001',
	\	'a0b101001',
	\	'0b101010',
	\	'b0b101100',
	\	'b0b111000'
	\    ]
	\ },
	\ {
	\    'name' : 'float',
	\    'cmd' : 'sort f',
	\    'input' : [
	\	'1.234',
	\	'0.88',
	\	'123.456',
	\	'1.15e-6',
	\	'-1.1e3',
	\	'-1.01e3',
	\	'',
	\	''
	\    ],
	\    'expected' : [
	\	'',
	\	'',
	\	'-1.1e3',
	\	'-1.01e3',
	\	'1.15e-6',
	\	'0.88',
	\	'1.234',
	\	'123.456'
	\    ]
	\ },
	\ {
	\    'name' : 'alphabetical, sorted input',
	\    'cmd' : 'sort',
	\    'input' : [
	\	'a',
	\	'b',
	\	'c',
	\    ],
	\    'expected' : [
	\	'a',
	\	'b',
	\	'c',
	\    ]
	\ },
	\ {
	\    'name' : 'alphabetical, sorted input, unique at end',
	\    'cmd' : 'sort u',
	\    'input' : [
	\	'aa',
	\	'bb',
	\	'cc',
	\	'cc',
	\    ],
	\    'expected' : [
	\	'aa',
	\	'bb',
	\	'cc',
	\    ]
	\ },
	\ ]

  for t in tests
    enew!
    call append(0, t.input)
    $delete _
    setlocal nomodified
    execute t.cmd

    call assert_equal(t.expected, getline(1, '$'), t.name)

    " Previously, the ":sort" command would set 'modified' even if the buffer
    " contents did not change.  Here, we check that this problem is fixed.
    if t.input == t.expected
      call assert_false(&modified, t.name . ': &mod is not correct')
    else
      call assert_true(&modified, t.name . ': &mod is not correct')
    endif
  endfor

  call assert_fails('sort no', 'E474')

  enew!
endfunc

func Test_sort_cmd_report()
    enew!
    call append(0, repeat([1], 3) + repeat([2], 3) + repeat([3], 3))
    $delete _
    setlocal nomodified
    let res = execute('%sort u')

    call assert_equal([1,2,3], map(getline(1, '$'), 'v:val+0'))
    call assert_match("6 fewer lines", res)
    enew!
    call append(0, repeat([1], 3) + repeat([2], 3) + repeat([3], 3))
    $delete _
    setlocal nomodified report=10
    let res = execute('%sort u')

    call assert_equal([1,2,3], map(getline(1, '$'), 'v:val+0'))
    call assert_equal("", res)
    enew!
    call append(0, repeat([1], 3) + repeat([2], 3) + repeat([3], 3))
    $delete _
    setl report&vim
    setlocal nomodified
    let res = execute('1g/^/%sort u')

    call assert_equal([1,2,3], map(getline(1, '$'), 'v:val+0'))
    " the output comes from the :g command, not from the :sort
    call assert_match("6 fewer lines", res)
    enew!
  endfunc
