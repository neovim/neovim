" Test for the search command

set belloff=all
func Test_search_cmdline()
  " See test/functional/legacy/search_spec.lua
  throw 'skipped: Nvim does not support test_disable_char_avail()'
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
  call feedkeys("/thes\<C-P>\<C-P>\<cr>",'tx')
  call assert_equal('foobar', @/)

  " Test 2
  " Ctrl-G goes from one match to the next
  " until the end of the buffer
  set incsearch nowrapscan
  :1
  " first match
  call feedkeys("/the\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  :1
  " second match
  call feedkeys("/the\<C-G>\<cr>", 'tx')
  call assert_equal('  3 the', getline('.'))
  call assert_equal([0, 0, 0, 0], getpos('"'))
  :1
  " third match
  call feedkeys("/the".repeat("\<C-G>", 2)."\<cr>", 'tx')
  call assert_equal('  4 their', getline('.'))
  :1
  " fourth match
  call feedkeys("/the".repeat("\<C-G>", 3)."\<cr>", 'tx')
  call assert_equal('  5 there', getline('.'))
  :1
  " fifth match
  call feedkeys("/the".repeat("\<C-G>", 4)."\<cr>", 'tx')
  call assert_equal('  6 their', getline('.'))
  :1
  " sixth match
  call feedkeys("/the".repeat("\<C-G>", 5)."\<cr>", 'tx')
  call assert_equal('  7 the', getline('.'))
  :1
  " seventh match
  call feedkeys("/the".repeat("\<C-G>", 6)."\<cr>", 'tx')
  call assert_equal('  8 them', getline('.'))
  :1
  " eigth match
  call feedkeys("/the".repeat("\<C-G>", 7)."\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  :1
  " no further match
  call feedkeys("/the".repeat("\<C-G>", 8)."\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  call assert_equal([0, 0, 0, 0], getpos('"'))

  " Test 3
  " Ctrl-G goes from one match to the next
  " and continues back at the top
  set incsearch wrapscan
  :1
  " first match
  call feedkeys("/the\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  :1
  " second match
  call feedkeys("/the\<C-G>\<cr>", 'tx')
  call assert_equal('  3 the', getline('.'))
  :1
  " third match
  call feedkeys("/the".repeat("\<C-G>", 2)."\<cr>", 'tx')
  call assert_equal('  4 their', getline('.'))
  :1
  " fourth match
  call feedkeys("/the".repeat("\<C-G>", 3)."\<cr>", 'tx')
  call assert_equal('  5 there', getline('.'))
  :1
  " fifth match
  call feedkeys("/the".repeat("\<C-G>", 4)."\<cr>", 'tx')
  call assert_equal('  6 their', getline('.'))
  :1
  " sixth match
  call feedkeys("/the".repeat("\<C-G>", 5)."\<cr>", 'tx')
  call assert_equal('  7 the', getline('.'))
  :1
  " seventh match
  call feedkeys("/the".repeat("\<C-G>", 6)."\<cr>", 'tx')
  call assert_equal('  8 them', getline('.'))
  :1
  " eigth match
  call feedkeys("/the".repeat("\<C-G>", 7)."\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  :1
  " back at first match
  call feedkeys("/the".repeat("\<C-G>", 8)."\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))

  " Test 4
  " CTRL-T goes to the previous match
  set incsearch nowrapscan
  $
  " first match
  call feedkeys("?the\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  $
  " first match
  call feedkeys("?the\<C-G>\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  $
  " second match
  call feedkeys("?the".repeat("\<C-T>", 1)."\<cr>", 'tx')
  call assert_equal('  8 them', getline('.'))
  $
  " last match
  call feedkeys("?the".repeat("\<C-T>", 7)."\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  $
  " last match
  call feedkeys("?the".repeat("\<C-T>", 8)."\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))

  " Test 5
  " CTRL-T goes to the previous match
  set incsearch wrapscan
  $
  " first match
  call feedkeys("?the\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  $
  " first match at the top
  call feedkeys("?the\<C-G>\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  $
  " second match
  call feedkeys("?the".repeat("\<C-T>", 1)."\<cr>", 'tx')
  call assert_equal('  8 them', getline('.'))
  $
  " last match
  call feedkeys("?the".repeat("\<C-T>", 7)."\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  $
  " back at the bottom of the buffer
  call feedkeys("?the".repeat("\<C-T>", 8)."\<cr>", 'tx')
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
  call feedkeys("/the\<c-l>\<C-G>\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  1
  " wrap around
  call feedkeys("/the\<c-l>\<C-G>\<C-G>\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  1
  " wrap around
  set nowrapscan
  call feedkeys("/the\<c-l>\<C-G>\<C-G>\<cr>", 'tx')
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
  call assert_equal('  2 these', getline('.'))
  1
  " delete one char, add another,  go to previous match, add one char
  call feedkeys("/thei\<bs>s\<bs>\<C-T>\<c-l>\<cr>", 'tx')
  call assert_equal('  9 these', getline('.'))
  1
  " delete all chars, start from the beginning again
  call feedkeys("/them". repeat("\<bs>",4).'the\>'."\<cr>", 'tx')
  call assert_equal('  3 the', getline('.'))

  " clean up
  call test_disable_char_avail(0)
  bw!
endfunc

func Test_search_cmdline2()
  " See test/functional/legacy/search_spec.lua
  throw 'skipped: Nvim does not support test_disable_char_avail()'
  if !exists('+incsearch')
    return
  endif
  " need to disable char_avail,
  " so that expansion of commandline works
  call test_disable_char_avail(1)
  new
  call setline(1, ['  1', '  2 these', '  3 the theother'])
  " Test 1
  " Ctrl-T goes correctly back and forth
  set incsearch
  1
  " first match
  call feedkeys("/the\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))
  1
  " go to next match (on next line)
  call feedkeys("/the\<C-G>\<cr>", 'tx')
  call assert_equal('  3 the theother', getline('.'))
  1
  " go to next match (still on line 3)
  call feedkeys("/the\<C-G>\<C-G>\<cr>", 'tx')
  call assert_equal('  3 the theother', getline('.'))
  1
  " go to next match (still on line 3)
  call feedkeys("/the\<C-G>\<C-G>\<C-G>\<cr>", 'tx')
  call assert_equal('  3 the theother', getline('.'))
  1
  " go to previous match (on line 3)
  call feedkeys("/the\<C-G>\<C-G>\<C-G>\<C-T>\<cr>", 'tx')
  call assert_equal('  3 the theother', getline('.'))
  1
  " go to previous match (on line 3)
  call feedkeys("/the\<C-G>\<C-G>\<C-G>\<C-T>\<C-T>\<cr>", 'tx')
  call assert_equal('  3 the theother', getline('.'))
  1
  " go to previous match (on line 2)
  call feedkeys("/the\<C-G>\<C-G>\<C-G>\<C-T>\<C-T>\<C-T>\<cr>", 'tx')
  call assert_equal('  2 these', getline('.'))

  " Test 2: keep the view,
  " after deleting a character from the search cmd
  call setline(1, ['  1', '  2 these', '  3 the', '  4 their', '  5 there', '  6 their', '  7 the', '  8 them', '  9 these', ' 10 foobar'])
  resize 5
  1
  call feedkeys("/foo\<bs>\<cr>", 'tx')
  redraw
  call assert_equal({'lnum': 10, 'leftcol': 0, 'col': 4, 'topfill': 0, 'topline': 6, 'coladd': 0, 'skipcol': 0, 'curswant': 4}, winsaveview())

  " remove all history entries
  for i in range(10)
      call histdel('/')
  endfor

  " Test 3: reset the view,
  " after deleting all characters from the search cmd
  norm! 1gg0
  " unfortunately, neither "/foo\<c-w>\<cr>", nor "/foo\<bs>\<bs>\<bs>\<cr>",
  " nor "/foo\<c-u>\<cr>" works to delete the commandline.
  " In that case Vim should return "E35 no previous regular expression",
  " but it looks like Vim still sees /foo and therefore the test fails.
  " Therefore, disableing this test
  "call assert_fails(feedkeys("/foo\<c-w>\<cr>", 'tx'), 'E35')
  "call assert_equal({'lnum': 1, 'leftcol': 0, 'col': 0, 'topfill': 0, 'topline': 1, 'coladd': 0, 'skipcol': 0, 'curswant': 0}, winsaveview())

  " clean up
  set noincsearch
  call test_disable_char_avail(0)
  bw!
endfunc

func Test_use_sub_pat()
  split
  let @/ = ''
  func X()
    s/^/a/
    /
  endfunc
  call X()
  bwipe!
endfunc

func Test_searchpair()
  new
  call setline(1, ['other code here', '', '[', '" cursor here', ']'])
  4
  let a=searchpair('\[','',']','bW')
  call assert_equal(3, a)
  set nomagic
  4
  let a=searchpair('\[','',']','bW')
  call assert_equal(3, a)
  set magic
  q!
endfunc

func Test_searchc()
  " These commands used to cause memory overflow in searchc().
  new
  norm ixx
  exe "norm 0t\u93cf"
  bw!
endfunc
