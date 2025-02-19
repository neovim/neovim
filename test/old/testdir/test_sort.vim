" Tests for the "sort()" function and for the ":sort" command.

source check.vim

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

  call assert_equal(['A', 'O', 'P', 'a', 'o', 'p', 'Ä', 'Ô', 'ä', 'ô', 'Œ', 'œ'],
  \            sort(['A', 'O', 'P', 'a', 'o', 'p', 'Ä', 'Ô', 'ä', 'ô', 'œ', 'Œ']))

  call assert_equal(['A', 'a', 'o', 'O', 'p', 'P', 'Ä', 'Ô', 'ä', 'ô', 'Œ', 'œ'],
  \            sort(['A', 'a', 'o', 'O', 'œ', 'Œ', 'p', 'P', 'Ä', 'ä', 'ô', 'Ô'], 'i'))

  " This does not appear to work correctly on Mac.
  if !has('mac')
    if v:collate =~? '^\(en\|fr\)_ca.utf-\?8$'
      " with Canadian English capitals come before lower case.
      " 'Œ' is omitted because it can sort before or after 'œ'
      call assert_equal(['A', 'a', 'Ä', 'ä', 'O', 'o', 'Ô', 'ô', 'œ', 'P', 'p'],
      \            sort(['A', 'a', 'o', 'O', 'œ', 'p', 'P', 'Ä', 'ä', 'ô', 'Ô'], 'l'))
    elseif v:collate =~? '^\(en\|es\|de\|fr\|it\|nl\).*\.utf-\?8$'
      " With the following locales, the accentuated letters are ordered
      " similarly to the non-accentuated letters...
      call assert_equal(['a', 'A', 'ä', 'Ä', 'o', 'O', 'ô', 'Ô', 'œ', 'Œ', 'p', 'P'],
      \            sort(['A', 'a', 'o', 'O', 'œ', 'Œ', 'p', 'P', 'Ä', 'ä', 'ô', 'Ô'], 'l'))
    elseif v:collate =~? '^sv.*utf-\?8$'
      " ... whereas with a Swedish locale, the accentuated letters are ordered
      " after Z.
      call assert_equal(['a', 'A', 'o', 'O', 'p', 'P', 'ä', 'Ä', 'œ', 'œ', 'ô', 'Ô'],
      \            sort(['A', 'a', 'o', 'O', 'œ', 'œ', 'p', 'P', 'Ä', 'ä', 'ô', 'Ô'], 'l'))
    endif
  endif
endfunc

func Test_sort_null_string()
  " null strings are sorted as empty strings.
  call assert_equal(['', 'a', 'b'], sort(['b', v:_null_string, 'a']))
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
  call assert_equal([3997, 4996], sort([4996, 3997], 'Compare1'))
endfunc

func Test_sort_float()
  CheckFeature float
  call assert_equal([0.28, 3, 13.5], sort([13.5, 0.28, 3], 'f'))
endfunc

func Test_sort_nested()
  " test ability to call sort() from a compare function
  call assert_equal([1, 3, 5], sort([3, 1, 5], 'Compare1'))
endfunc

func Test_sort_default()
  CheckFeature float

  " docs say omitted, empty or zero argument sorts on string representation.
  call assert_equal(['2', 'A', 'AA', 'a', 1, 3.3], sort([3.3, 1, "2", "A", "a", "AA"]))
  call assert_equal(['2', 'A', 'AA', 'a', 1, 3.3], sort([3.3, 1, "2", "A", "a", "AA"], ''))
  call assert_equal(['2', 'A', 'AA', 'a', 1, 3.3], sort([3.3, 1, "2", "A", "a", "AA"], 0))
  call assert_equal(['2', 'A', 'a', 'AA', 1, 3.3], sort([3.3, 1, "2", "A", "a", "AA"], 1))
  call assert_fails('call sort([3.3, 1, "2"], 3)', "E474:")
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
	\ {
	\    'name' : 'sort one line buffer',
	\    'cmd' : 'sort',
	\    'input' : [
	\	'single line'
	\    ],
	\    'expected' : [
	\	'single line'
	\    ]
	\ },
	\ {
	\    'name' : 'sort ignoring case',
	\    'cmd' : '%sort i',
	\    'input' : [
	\	'BB',
	\	'Cc',
	\	'aa'
	\    ],
	\    'expected' : [
	\	'aa',
	\	'BB',
	\	'Cc'
	\    ]
	\ },
	\ ]

    " This does not appear to work correctly on Mac.
    if !has('mac')
      if v:collate =~? '^\(en\|fr\)_ca.utf-\?8$'
        " en_CA.utf-8 sorts capitals before lower case
        " 'Œ' is omitted because it can sort before or after 'œ'
        let tests += [
          \ {
          \    'name' : 'sort with locale ' .. v:collate,
          \    'cmd' : '%sort l',
          \    'input' : [
          \	'A',
          \	'E',
          \	'O',
          \	'À',
          \	'È',
          \	'É',
          \	'Ô',
          \	'Z',
          \	'a',
          \	'e',
          \	'o',
          \	'à',
          \	'è',
          \	'é',
          \	'ô',
          \	'œ',
          \	'z'
          \    ],
          \    'expected' : [
          \	'A',
          \	'a',
          \	'À',
          \	'à',
          \	'E',
          \	'e',
          \	'É',
          \	'é',
          \	'È',
          \	'è',
          \	'O',
          \	'o',
          \	'Ô',
          \	'ô',
          \	'œ',
          \	'Z',
          \	'z'
          \    ]
          \ },
          \ ]
      elseif v:collate =~? '^\(en\|es\|de\|fr\|it\|nl\).*\.utf-\?8$'
      " With these locales, the accentuated letters are ordered
      " similarly to the non-accentuated letters.
        let tests += [
          \ {
          \    'name' : 'sort with locale ' .. v:collate,
          \    'cmd' : '%sort l',
          \    'input' : [
          \	'A',
          \	'E',
          \	'O',
          \	'À',
          \	'È',
          \	'É',
          \	'Ô',
          \	'Œ',
          \	'Z',
          \	'a',
          \	'e',
          \	'o',
          \	'à',
          \	'è',
          \	'é',
          \	'ô',
          \	'œ',
          \	'z'
          \    ],
          \    'expected' : [
          \	'a',
          \	'A',
          \	'à',
          \	'À',
          \	'e',
          \	'E',
          \	'é',
          \	'É',
          \	'è',
          \	'È',
          \	'o',
          \	'O',
          \	'ô',
          \	'Ô',
          \	'œ',
          \	'Œ',
          \	'z',
          \	'Z'
          \    ]
          \ },
          \ ]
    endif
  endif
  if has('float')
    let tests += [
          \ {
          \    'name' : 'float',
          \    'cmd' : 'sort f',
          \    'input' : [
          \	'1.234',
          \	'0.88',
          \	'  +  123.456',
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
          \	'  +  123.456'
          \    ]
          \ },
          \ ]
  endif

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

  " Needs at least two lines for this test
  call setline(1, ['line1', 'line2'])
  call assert_fails('sort no', 'E474:')
  call assert_fails('sort c', 'E475:')
  call assert_fails('sort #pat%', 'E654:')
  call assert_fails('sort /\%(/', 'E53:')

  enew!
endfunc

func Test_sort_large_num()
  new
  a
-2147483648
-2147483647

-1
0
1
-2147483646
2147483646
2147483647
2147483647
-2147483648
abc

.
  " Numerical sort. Non-numeric lines are ordered before numerical lines.
  " Ordering of non-numerical is stable.
  sort n
  call assert_equal(['',
  \                  'abc',
  \                  '',
  \                  '-2147483648',
  \                  '-2147483648',
  \                  '-2147483647',
  \                  '-2147483646',
  \                  '-1',
  \                  '0',
  \                  '1',
  \                  '2147483646',
  \                  '2147483647',
  \                  '2147483647'], getline(1, '$'))
  bwipe!

  new
  a
-9223372036854775808
-9223372036854775807

-1
0
1
-9223372036854775806
9223372036854775806
9223372036854775807
9223372036854775807
-9223372036854775808
abc

.
  sort n
  call assert_equal(['',
  \                  'abc',
  \                  '',
  \                  '-9223372036854775808',
  \                  '-9223372036854775808',
  \                  '-9223372036854775807',
  \                  '-9223372036854775806',
  \                  '-1',
  \                  '0',
  \                  '1',
  \                  '9223372036854775806',
  \                  '9223372036854775807',
  \                  '9223372036854775807'], getline(1, '$'))
  bwipe!
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

" Test for a :sort command followed by another command
func Test_sort_followed_by_cmd()
  new
  let var = ''
  call setline(1, ['cc', 'aa', 'bb'])
  %sort | let var = "sortcmdtest"
  call assert_equal(var, "sortcmdtest")
  call assert_equal(['aa', 'bb', 'cc'], getline(1, '$'))
  " Test for :sort followed by a comment
  call setline(1, ['3b', '1c', '2a'])
  %sort /\d\+/ " sort alphabetically
  call assert_equal(['2a', '3b', '1c'], getline(1, '$'))
  close!
endfunc

" Test for :sort using last search pattern
func Test_sort_last_search_pat()
  new
  let @/ = '\d\+'
  call setline(1, ['3b', '1c', '2a'])
  sort //
  call assert_equal(['2a', '3b', '1c'], getline(1, '$'))
  close!
endfunc

" Test for :sort with no last search pattern
func Test_sort_with_no_last_search_pat()
  let lines =<< trim [SCRIPT]
    call setline(1, ['3b', '1c', '2a'])
    call assert_fails('sort //', 'E35:')
    call writefile(v:errors, 'Xresult')
    qall!
  [SCRIPT]
  call writefile(lines, 'Xscript', 'D')
  if RunVim([], [], '--clean -S Xscript')
    call assert_equal([], readfile('Xresult'))
  endif
  call delete('Xresult')
endfunc

" Test for retaining marks across a :sort
func Test_sort_with_marks()
  new
  call setline(1, ['cc', 'aa', 'bb'])
  call setpos("'c", [0, 1, 0, 0])
  call setpos("'a", [0, 2, 0, 0])
  call setpos("'b", [0, 3, 0, 0])
  %sort
  call assert_equal(['aa', 'bb', 'cc'], getline(1, '$'))
  call assert_equal(2, line("'a"))
  call assert_equal(3, line("'b"))
  call assert_equal(1, line("'c"))
  close!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
