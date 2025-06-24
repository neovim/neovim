" Tests for the ":uniq" command.

source check.vim

" Tests for the ":uniq" command.
func Test_uniq_cmd()
  let tests = [
        \ {
        \    'name' : 'Alphabetical uniq #1',
        \    'cmd' : '%uniq',
        \    'input' : [
        \       'abc',
        \       'ab',
        \       'a',
        \       'a321',
        \       'a123',
        \       'a123',
        \       'a123',
        \       'a123',
        \       'a122',
        \       'a123',
        \       'b321',
        \       'c123d',
        \       ' 123b',
        \       'c321d',
        \       'b322b',
        \       'b321',
        \       'b321b'
        \    ],
        \    'expected' : [
        \       'abc',
        \       'ab',
        \       'a',
        \       'a321',
        \       'a123',
        \       'a122',
        \       'a123',
        \       'b321',
        \       'c123d',
        \       ' 123b',
        \       'c321d',
        \       'b322b',
        \       'b321',
        \       'b321b'
        \    ]
        \ },
        \ {
        \    'name' : 'Alphabetical uniq #2',
        \    'cmd' : '%uniq',
        \    'input' : [
        \       'abc',
        \       'abc',
        \       'abc',
        \       'ab',
        \       'a',
        \       'a321',
        \       'a122',
        \       'b321',
        \       'a123',
        \       'a123',
        \       'c123d',
        \       ' 123b',
        \       'c321d',
        \       'b322b',
        \       'b321',
        \       'b321b'
        \    ],
        \    'expected' : [
        \       'abc',
        \       'ab',
        \       'a',
        \       'a321',
        \       'a122',
        \       'b321',
        \       'a123',
        \       'c123d',
        \       ' 123b',
        \       'c321d',
        \       'b322b',
        \       'b321',
        \       'b321b'
        \    ]
        \ },
        \ {
        \    'name' : 'alphabetical, uniqed input',
        \    'cmd' : 'uniq',
        \    'input' : [
        \       'a',
        \       'b',
        \       'c',
        \    ],
        \    'expected' : [
        \       'a',
        \       'b',
        \       'c',
        \    ]
        \ },
        \ {
        \    'name' : 'alphabetical, uniqed input, unique at end',
        \    'cmd' : 'uniq',
        \    'input' : [
        \       'aa',
        \       'bb',
        \       'cc',
        \       'cc',
        \    ],
        \    'expected' : [
        \       'aa',
        \       'bb',
        \       'cc',
        \    ]
        \ },
        \ {
        \    'name' : 'uniq one line buffer',
        \    'cmd' : 'uniq',
        \    'input' : [
        \       'single line'
        \    ],
        \    'expected' : [
        \       'single line'
        \    ]
        \ },
        \ {
        \    'name' : 'uniq ignoring case',
        \    'cmd' : '%uniq i',
        \    'input' : [
        \       'BB',
        \       'Cc',
        \       'cc',
        \       'Cc',
        \       'aa'
        \    ],
        \    'expected' : [
        \       'BB',
        \       'Cc',
        \       'aa'
        \    ]
        \ },
        \ {
        \    'name' : 'uniq not uniqued #1',
        \    'cmd' : '%uniq!',
        \    'input' : [
        \       'aa',
        \       'cc',
        \       'cc',
        \       'cc',
        \       'bb',
        \       'aa',
        \       'yyy',
        \       'yyy',
        \       'zz'
        \    ],
        \    'expected' : [
        \       'cc',
        \       'yyy',
        \    ]
        \ },
        \ {
        \    'name' : 'uniq not uniqued #2',
        \    'cmd' : '%uniq!',
        \    'input' : [
        \       'aa',
        \       'aa',
        \       'bb',
        \       'cc',
        \       'cc',
        \       'cc',
        \       'yyy',
        \       'yyy',
        \       'zz'
        \    ],
        \    'expected' : [
        \       'aa',
        \       'cc',
        \       'yyy',
        \    ]
        \ },
        \ {
        \    'name' : 'uniq not uniqued ("u" is ignored)',
        \    'cmd' : '%uniq! u',
        \    'input' : [
        \       'aa',
        \       'cc',
        \       'cc',
        \       'cc',
        \       'bb',
        \       'aa',
        \       'yyy',
        \       'yyy',
        \       'zz'
        \    ],
        \    'expected' : [
        \       'cc',
        \       'yyy',
        \    ]
        \ },
        \ {
        \    'name' : 'uniq not uniqued, ignoring case',
        \    'cmd' : '%uniq! i',
        \    'input' : [
        \       'aa',
        \       'cc',
        \       'cc',
        \       'Cc',
        \       'bb',
        \       'aa',
        \       'yyy',
        \       'yyy',
        \       'zz'
        \    ],
        \    'expected' : [
        \       'cc',
        \       'yyy',
        \    ]
        \ },
        \ {
        \    'name' : 'uniq only unique #1',
        \    'cmd' : '%uniq u',
        \    'input' : [
        \       'aa',
        \       'cc',
        \       'cc',
        \       'cc',
        \       'bb',
        \       'aa',
        \       'yyy',
        \       'yyy',
        \       'zz'
        \    ],
        \    'expected' : [
        \       'aa',
        \       'bb',
        \       'aa',
        \       'zz'
        \    ]
        \ },
        \ {
        \    'name' : 'uniq only unique #2',
        \    'cmd' : '%uniq u',
        \    'input' : [
        \       'aa',
        \       'aa',
        \       'bb',
        \       'cc',
        \       'cc',
        \       'cc',
        \       'yyy',
        \       'yyy',
        \       'zz'
        \    ],
        \    'expected' : [
        \       'bb',
        \       'zz'
        \    ]
        \ },
        \ {
        \    'name' : 'uniq only unique, ignoring case',
        \    'cmd' : '%uniq ui',
        \    'input' : [
        \       'aa',
        \       'cc',
        \       'Cc',
        \       'cc',
        \       'bb',
        \       'aa',
        \       'yyy',
        \       'yyy',
        \       'zz'
        \    ],
        \    'expected' : [
        \       'aa',
        \       'bb',
        \       'aa',
        \       'zz'
        \    ]
        \ },
        \ {
        \    'name' : 'uniq on first 2 charscters',
        \    'cmd' : '%uniq r /^../',
        \    'input' : [
        \       'aa',
        \       'cc',
        \       'cc1',
        \       'cc2',
        \       'bb',
        \       'aa',
        \       'yyy',
        \       'yyy2',
        \       'zz'
        \    ],
        \    'expected' : [
        \       'aa',
        \       'cc',
        \       'bb',
        \       'aa',
        \       'yyy',
        \       'zz'
        \    ]
        \ },
        \ {
        \    'name' : 'uniq on after 2 charscters',
        \    'cmd' : '%uniq /^../',
        \    'input' : [
        \       '11aa',
        \       '11cc',
        \       '13cc',
        \       '13cc',
        \       '13bb',
        \       '13aa',
        \       '12yyy',
        \       '11yyy',
        \       '11zz'
        \    ],
        \    'expected' : [
        \       '11aa',
        \       '11cc',
        \       '13bb',
        \       '13aa',
        \       '12yyy',
        \       '11zz'
        \    ]
        \ },
        \ {
        \    'name' : 'uniq on first 2 charscters, not uniqued',
        \    'cmd' : '%uniq! r /^../',
        \    'input' : [
        \       'aa',
        \       'cc',
        \       'cc1',
        \       'cc2',
        \       'bb',
        \       'aa',
        \       'yyy',
        \       'yyy2',
        \       'zz'
        \    ],
        \    'expected' : [
        \       'cc',
        \       'yyy'
        \    ]
        \ },
        \ {
        \    'name' : 'uniq on after 2 charscters, not uniqued',
        \    'cmd' : '%uniq! /^../',
        \    'input' : [
        \       '11aa',
        \       '11cc',
        \       '13cc',
        \       '13cc',
        \       '13bb',
        \       '13aa',
        \       '12yyy',
        \       '11yyy',
        \       '11zz'
        \    ],
        \    'expected' : [
        \       '11cc',
        \       '12yyy'
        \    ]
        \ },
        \ {
        \    'name' : 'uniq on first 2 charscters, only unique',
        \    'cmd' : '%uniq ru /^../',
        \    'input' : [
        \       'aa',
        \       'cc',
        \       'cc1',
        \       'cc2',
        \       'bb',
        \       'aa',
        \       'yyy',
        \       'yyy2',
        \       'zz'
        \    ],
        \    'expected' : [
        \       'aa',
        \       'bb',
        \       'aa',
        \       'zz'
        \    ]
        \ },
        \ {
        \    'name' : 'uniq on after 2 charscters, only unique',
        \    'cmd' : '%uniq u /^../',
        \    'input' : [
        \       '11aa',
        \       '11cc',
        \       '13cc',
        \       '13cc',
        \       '13bb',
        \       '13aa',
        \       '12yyy',
        \       '11yyy',
        \       '11zz'
        \    ],
        \    'expected' : [
        \       '11aa',
        \       '13bb',
        \       '13aa',
        \       '11zz'
        \    ]
        \ }
        \ ]

    " This does not appear to work correctly on Mac.
    if !has('mac')
      if v:collate =~? '^\(en\|fr\)_ca.utf-\?8$'
        " en_CA.utf-8 uniqs capitals before lower case
        " 'Œ' is omitted because it can uniq before or after 'œ'
        let tests += [
          \ {
          \    'name' : 'uniq with locale ' .. v:collate,
          \    'cmd' : '%uniq l',
          \    'input' : [
          \     'A',
          \     'a',
          \     'À',
          \     'à',
          \     'E',
          \     'e',
          \     'É',
          \     'é',
          \     'È',
          \     'è',
          \     'O',
          \     'o',
          \     'Ô',
          \     'ô',
          \     'œ',
          \     'Z',
          \     'z'
          \    ],
          \    'expected' : [
          \     'A',
          \     'a',
          \     'À',
          \     'à',
          \     'E',
          \     'e',
          \     'É',
          \     'é',
          \     'È',
          \     'è',
          \     'O',
          \     'o',
          \     'Ô',
          \     'ô',
          \     'œ',
          \     'Z',
          \     'z'
          \    ]
          \ },
          \ ]
      elseif v:collate =~? '^\(en\|es\|de\|fr\|it\|nl\).*\.utf-\?8$'
      " With these locales, the accentuated letters are ordered
      " similarly to the non-accentuated letters.
        let tests += [
          \ {
          \    'name' : 'uniq with locale ' .. v:collate,
          \    'cmd' : '%uniq li',
          \    'input' : [
          \     'A',
          \     'À',
          \     'a',
          \     'à',
          \     'à',
          \     'E',
          \     'È',
          \     'É',
          \     'o',
          \     'O',
          \     'Ô',
          \     'e',
          \     'è',
          \     'é',
          \     'ô',
          \     'Œ',
          \     'œ',
          \     'z',
          \     'Z'
          \    ],
          \    'expected' : [
          \     'A',
          \     'À',
          \     'a',
          \     'à',
          \     'E',
          \     'È',
          \     'É',
          \     'o',
          \     'O',
          \     'Ô',
          \     'e',
          \     'è',
          \     'é',
          \     'ô',
          \     'Œ',
          \     'œ',
          \     'z',
          \     'Z'
          \    ]
          \ },
          \ ]
    endif
  endif

  for t in tests
    enew!
    call append(0, t.input)
    $delete _
    setlocal nomodified
    execute t.cmd

    call assert_equal(t.expected, getline(1, '$'), t.name)

    " Previously, the ":uniq" command would set 'modified' even if the buffer
    " contents did not change.  Here, we check that this problem is fixed.
    if t.input == t.expected
      call assert_false(&modified, t.name . ': &mod is not correct')
    else
      call assert_true(&modified, t.name . ': &mod is not correct')
    endif
  endfor

  " Needs at least two lines for this test
  call setline(1, ['line1', 'line2'])
  call assert_fails('uniq no', 'E475:')
  call assert_fails('uniq c', 'E475:')
  call assert_fails('uniq #pat%', 'E654:')
  call assert_fails('uniq /\%(/', 'E53:')
  call assert_fails('333uniq', 'E16:')
  call assert_fails('1,999uniq', 'E16:')

  enew!
endfunc

func Test_uniq_cmd_report()
    enew!
    call append(0, repeat([1], 3) + repeat([2], 3) + repeat([3], 3))
    $delete _
    setlocal nomodified
    let res = execute('%uniq')

    call assert_equal([1,2,3], map(getline(1, '$'), 'v:val+0'))
    call assert_match("6 fewer lines", res)
    enew!
    call append(0, repeat([1], 3) + repeat([2], 3) + repeat([3], 3))
    $delete _
    setlocal nomodified report=10
    let res = execute('%uniq')

    call assert_equal([1,2,3], map(getline(1, '$'), 'v:val+0'))
    call assert_equal("", res)
    enew!
    call append(0, repeat([1], 3) + repeat([2], 3) + repeat([3], 3))
    $delete _
    setl report&vim
    setlocal nomodified
    let res = execute('1g/^/%uniq')

    call assert_equal([1,2,3], map(getline(1, '$'), 'v:val+0'))
    " the output comes from the :g command, not from the :uniq
    call assert_match("6 fewer lines", res)
    enew!
endfunc

" Test for a :uniq command followed by another command
func Test_uniq_followed_by_cmd()
  new
  let var = ''
  call setline(1, ['cc', 'aa', 'bb'])
  %uniq | let var = "uniqcmdtest"
  call assert_equal(var, "uniqcmdtest")
  call assert_equal(['cc', 'aa', 'bb'], getline(1, '$'))
  " Test for :uniq followed by a comment
  call setline(1, ['3b', '3b', '3b', '1c', '2a'])
  %uniq " uniq alphabetically
  call assert_equal(['3b', '1c', '2a'], getline(1, '$'))
  bw!
endfunc

" Test for retaining marks across a :uniq
func Test_uniq_with_marks()
  new
  call setline(1, ['cc', 'cc', 'aa', 'bb', 'bb', 'bb', 'bb'])
  call setpos("'c", [0, 1, 0, 0])
  call setpos("'a", [0, 4, 0, 0])
  call setpos("'b", [0, 7, 0, 0])
  %uniq
  call assert_equal(['cc', 'aa', 'bb'], getline(1, '$'))
  call assert_equal(1, line("'c"))
  call assert_equal(0, line("'a"))
  call assert_equal(0, line("'b"))
  bw!
endfunc

" Test for undo after a :uniq
func Test_uniq_undo()
  new
  let li = ['cc', 'cc', 'aa', 'bb', 'bb', 'bb', 'bb', 'aa']
  call writefile(li, 'XfileUniq', 'D')
  edit XfileUniq
  uniq
  call assert_equal(['cc', 'aa', 'bb', 'aa'], getline(1, '$'))
  call assert_true(&modified)
  undo
  call assert_equal(li, getline(1, '$'))
  call assert_false(&modified)
  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
