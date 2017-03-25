" Test for the search command

func Test_search_cmdline()
  if !exists('+incsearch')
    return
  endif
  " need to disable char_avail,
  " so that expansion of commandline works
  call test_disable_char_avail(1)
  new
  call setline(1, ['  1', '  2 these', '  3 the', '  4 their', '  5 there', '  6 their', '  7 the', '  8 them', '  9 these', ' 10 foobar'])
  " Test 1
  " CTRL-N / CTRL-P skips through the previous search history
  set noincsearch
  :1
  call feedkeys("/foobar\<cr>", 'tx')
  call feedkeys("/the\<cr>",'tx')
  call assert_equal('the', @/)
  call feedkeys("/thes\<c-p>\<c-p>\<cr>",'tx')
  call assert_equal('foobar', @/)

  " Test 2
  " Ctrl-N goes from one match to the next
  " until the end of the buffer
  set incsearch nowrapscan
  :1
  " first match
  call feedkeys("/the\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  :1
  " second match
  call feedkeys("/the\<c-n>\<cr>", 'tx')
  call assert_equal('  3 the', getline('.'))
  :1
  " third match
  call feedkeys("/the".repeat("\<c-n>", 2)."\<cr>", 'tx')
  call assert_equal('  4 their', getline('.'))
  :1
  " fourth match
  call feedkeys("/the".repeat("\<c-n>", 3)."\<cr>", 'tx')
  call assert_equal('  5 there', getline('.'))
  :1
  " fifth match
  call feedkeys("/the".repeat("\<c-n>", 4)."\<cr>", 'tx')
  call assert_equal('  6 their', getline('.'))
  :1
  " sixth match
  call feedkeys("/the".repeat("\<c-n>", 5)."\<cr>", 'tx')
  call assert_equal('  7 the', getline('.'))
  :1
  " seventh match
  call feedkeys("/the".repeat("\<c-n>", 6)."\<cr>", 'tx')
  call assert_equal('  8 them', getline('.'))
  :1
  " eigth match
  call feedkeys("/the".repeat("\<c-n>", 7)."\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  :1
  " no further match
  call feedkeys("/the".repeat("\<c-n>", 8)."\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))

  " Test 3
  " Ctrl-N goes from one match to the next
  " and continues back at the top
  set incsearch wrapscan
  :1
  " first match
  call feedkeys("/the\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  :1
  " second match
  call feedkeys("/the\<c-n>\<cr>", 'tx')
  call assert_equal('  3 the', getline('.'))
  :1
  " third match
  call feedkeys("/the".repeat("\<c-n>", 2)."\<cr>", 'tx')
  call assert_equal('  4 their', getline('.'))
  :1
  " fourth match
  call feedkeys("/the".repeat("\<c-n>", 3)."\<cr>", 'tx')
  call assert_equal('  5 there', getline('.'))
  :1
  " fifth match
  call feedkeys("/the".repeat("\<c-n>", 4)."\<cr>", 'tx')
  call assert_equal('  6 their', getline('.'))
  :1
  " sixth match
  call feedkeys("/the".repeat("\<c-n>", 5)."\<cr>", 'tx')
  call assert_equal('  7 the', getline('.'))
  :1
  " seventh match
  call feedkeys("/the".repeat("\<c-n>", 6)."\<cr>", 'tx')
  call assert_equal('  8 them', getline('.'))
  :1
  " eigth match
  call feedkeys("/the".repeat("\<c-n>", 7)."\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  :1
  " back at first match
  call feedkeys("/the".repeat("\<c-n>", 8)."\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))

  " Test 4
  " CTRL-P goes to the previous match
  set incsearch nowrapscan
  $
  " first match
  call feedkeys("?the\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  $
  " first match
  call feedkeys("?the\<c-n>\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  $
  " second match
  call feedkeys("?the".repeat("\<c-p>", 1)."\<cr>", 'tx')
  call assert_equal('  8 them', getline('.'))
  $
  " last match
  call feedkeys("?the".repeat("\<c-p>", 7)."\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  $
  " last match
  call feedkeys("?the".repeat("\<c-p>", 8)."\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))

  " Test 5
  " CTRL-P goes to the previous match
  set incsearch wrapscan
  $
  " first match
  call feedkeys("?the\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  $
  " first match at the top
  call feedkeys("?the\<c-n>\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  $
  " second match
  call feedkeys("?the".repeat("\<c-p>", 1)."\<cr>", 'tx')
  call assert_equal('  8 them', getline('.'))
  $
  " last match
  call feedkeys("?the".repeat("\<c-p>", 7)."\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  $
  " back at the bottom of the buffer
  call feedkeys("?the".repeat("\<c-p>", 8)."\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))

  " Test 6
  " CTRL-L adds to the search pattern
  set incsearch wrapscan
  1
  " first match
  call feedkeys("/the\<c-l>\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  1
  " go to next match of 'thes'
  call feedkeys("/the\<c-l>\<c-n>\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  1
  " wrap around
  call feedkeys("/the\<c-l>\<c-n>\<c-n>\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  1
  " wrap around
  set nowrapscan
  call feedkeys("/the\<c-l>\<c-n>\<c-n>\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))

  " Test 7
  " <bs> remove from match, but stay at current match
  set incsearch wrapscan
  1
  " first match
  call feedkeys("/thei\<cr>", 'tx')
  call assert_equal('  4 their', getline('.'))
  1
  " delete one char, add another
  call feedkeys("/thei\<bs>s\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  1
  " delete one char, add another,  go to previous match, add one char
  call feedkeys("/thei\<bs>s\<bs>\<c-p>\<c-l>\<cr>", 'tx')
  call assert_equal('  8 them', getline('.'))
  1
  " delete all chars, start from the beginning again
  call feedkeys("/them". repeat("\<bs>",4).'the\>'."\<cr>", 'tx')
  call assert_equal('  3 the', getline('.'))

  " clean up
  call test_disable_char_avail(0)
  bw!
endfunc

func Test_search_cmdline2()
  if !exists('+incsearch')
    return
  endif
  " need to disable char_avail,
  " so that expansion of commandline works
  call test_disable_char_avail(1)
  new
  call setline(1, ['  1', '  2 these', '  3 the theother'])
  " Test 1
  " Ctrl-P goes correctly back and forth
  set incsearch
  1
  " first match
  call feedkeys("/the\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  1
  " go to next match (on next line)
  call feedkeys("/the\<c-n>\<cr>", 'tx')
  call assert_equal('  3 the theother', getline('.'))
  1
  " go to next match (still on line 3)
  call feedkeys("/the\<c-n>\<c-n>\<cr>", 'tx')
  call assert_equal('  3 the theother', getline('.'))
  1
  " go to next match (still on line 3)
  call feedkeys("/the\<c-n>\<c-n>\<c-n>\<cr>", 'tx')
  call assert_equal('  3 the theother', getline('.'))
  1
  " go to previous match (on line 3)
  call feedkeys("/the\<c-n>\<c-n>\<c-n>\<c-p>\<cr>", 'tx')
  call assert_equal('  3 the theother', getline('.'))
  1
  " go to previous match (on line 3)
  call feedkeys("/the\<c-n>\<c-n>\<c-n>\<c-p>\<c-p>\<cr>", 'tx')
  call assert_equal('  3 the theother', getline('.'))
  1
  " go to previous match (on line 2)
  call feedkeys("/the\<c-n>\<c-n>\<c-n>\<c-p>\<c-p>\<c-p>\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))

  " clean up
  call test_disable_char_avail(0)
  bw!
endfunc
