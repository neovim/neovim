" Test for the search command

source shared.vim
source screendump.vim
source check.vim

" See test/functional/legacy/search_spec.lua
func Test_search_cmdline()
  CheckFunction test_override
  CheckOption incsearch

  " need to disable char_avail,
  " so that expansion of commandline works
  call test_override("char_avail", 1)
  new
  call setline(1, ['  1', '  2 these', '  3 the', '  4 their', '  5 there', '  6 their', '  7 the', '  8 them', '  9 these', ' 10 foobar'])
  " Test 1
  " CTRL-N / CTRL-P skips through the previous search history
  set noincsearch
  :1
  call feedkeys("/foobar\<cr>", 'tx')
  call feedkeys("/the\<cr>", 'tx')
  call assert_equal('the', @/)
  call feedkeys("/thes\<C-P>\<C-P>\<cr>", 'tx')
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
  " eighth match
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
  " eighth match
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
  call test_override("char_avail", 0)
  bw!
endfunc

" See test/functional/legacy/search_spec.lua
func Test_search_cmdline2()
  CheckFunction test_override
  CheckOption incsearch

  " need to disable char_avail,
  " so that expansion of commandline works
  call test_override("char_avail", 1)
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
  1
  " go to previous match (on line 2)
  call feedkeys("/the\<C-G>\<C-R>\<C-W>\<cr>", 'tx')
  call assert_equal('theother', @/)

  " Test 2: keep the view,
  " after deleting a character from the search cmd
  call setline(1, ['  1', '  2 these', '  3 the', '  4 their', '  5 there', '  6 their', '  7 the', '  8 them', '  9 these', ' 10 foobar'])
  resize 5
  1
  call feedkeys("/foo\<bs>\<cr>", 'tx')
  redraw
  call assert_equal({'lnum': 10, 'leftcol': 0, 'col': 4, 'topfill': 0, 'topline': 6, 'coladd': 0, 'skipcol': 0, 'curswant': 4}, winsaveview())

  " remove all history entries
  for i in range(11)
      call histdel('/')
  endfor

  " Test 3: reset the view,
  " after deleting all characters from the search cmd
  norm! 1gg0
  " unfortunately, neither "/foo\<c-w>\<cr>", nor "/foo\<bs>\<bs>\<bs>\<cr>",
  " nor "/foo\<c-u>\<cr>" works to delete the commandline.
  " In that case Vim should return "E35 no previous regular expression",
  " but it looks like Vim still sees /foo and therefore the test fails.
  " Therefore, disabling this test
  "call assert_fails(feedkeys("/foo\<c-w>\<cr>", 'tx'), 'E35')
  "call assert_equal({'lnum': 1, 'leftcol': 0, 'col': 0, 'topfill': 0, 'topline': 1, 'coladd': 0, 'skipcol': 0, 'curswant': 0}, winsaveview())

  " clean up
  set noincsearch
  call test_override("char_avail", 0)
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
  call setline(1, ['other code', 'here [', ' [', ' " cursor here', ' ]]'])

  " should not give an error for using "42"
  call assert_equal(0, searchpair('a', 'b', 'c', '', 42))

  4
  call assert_equal(3, searchpair('\[', '', ']', 'bW'))
  call assert_equal([0, 3, 2, 0], getpos('.'))
  4
  call assert_equal(2, searchpair('\[', '', ']', 'bWr'))
  call assert_equal([0, 2, 6, 0], getpos('.'))
  4
  call assert_equal(1, searchpair('\[', '', ']', 'bWm'))
  call assert_equal([0, 3, 2, 0], getpos('.'))
  4|norm ^
  call assert_equal(5, searchpair('\[', '', ']', 'Wn'))
  call assert_equal([0, 4, 2, 0], getpos('.'))
  4
  call assert_equal(2, searchpair('\[', '', ']', 'bW',
        \                         'getline(".") =~ "^\\s*\["'))
  call assert_equal([0, 2, 6, 0], getpos('.'))
  set nomagic
  4
  call assert_equal(3, searchpair('\[', '', ']', 'bW'))
  call assert_equal([0, 3, 2, 0], getpos('.'))
  set magic
  4|norm ^
  call assert_equal(0, searchpair('{', '', '}', 'bW'))
  call assert_equal([0, 4, 2, 0], getpos('.'))

  %d
  call setline(1, ['if 1', '  if 2', '  else', '  endif 2', 'endif 1'])

  /\<if 1
  call assert_equal(5, searchpair('\<if\>', '\<else\>', '\<endif\>', 'W'))
  call assert_equal([0, 5, 1, 0], getpos('.'))
  /\<if 2
  call assert_equal(3, searchpair('\<if\>', '\<else\>', '\<endif\>', 'W'))
  call assert_equal([0, 3, 3, 0], getpos('.'))

  q!
endfunc

func Test_searchpairpos()
  new
  call setline(1, ['other code', 'here [', ' [', ' " cursor here', ' ]]'])

  4
  call assert_equal([3, 2], searchpairpos('\[', '', ']', 'bW'))
  call assert_equal([0, 3, 2, 0], getpos('.'))
  4
  call assert_equal([2, 6], searchpairpos('\[', '', ']', 'bWr'))
  call assert_equal([0, 2, 6, 0], getpos('.'))
  4|norm ^
  call assert_equal([5, 2], searchpairpos('\[', '', ']', 'Wn'))
  call assert_equal([0, 4, 2, 0], getpos('.'))
  4
  call assert_equal([2, 6], searchpairpos('\[', '', ']', 'bW',
        \                                 'getline(".") =~ "^\\s*\["'))
  call assert_equal([0, 2, 6, 0], getpos('.'))
  4
  call assert_equal([2, 6], searchpairpos('\[', '', ']', 'bWr'))
  call assert_equal([0, 2, 6, 0], getpos('.'))
  set nomagic
  4
  call assert_equal([3, 2], searchpairpos('\[', '', ']', 'bW'))
  call assert_equal([0, 3, 2, 0], getpos('.'))
  set magic
  4|norm ^
  call assert_equal([0, 0], searchpairpos('{', '', '}', 'bW'))
  call assert_equal([0, 4, 2, 0], getpos('.'))

  %d
  call setline(1, ['if 1', '  if 2', '  else', '  endif 2', 'endif 1'])
  /\<if 1
  call assert_equal([5, 1], searchpairpos('\<if\>', '\<else\>', '\<endif\>', 'W'))
  call assert_equal([0, 5, 1, 0], getpos('.'))
  /\<if 2
  call assert_equal([3, 3], searchpairpos('\<if\>', '\<else\>', '\<endif\>', 'W'))
  call assert_equal([0, 3, 3, 0], getpos('.'))

  q!
endfunc

func Test_searchpair_errors()
  call assert_fails("call searchpair([0], 'middle', 'end', 'bW', 'skip', 99, 100)", 'E730: Using a List as a String')
  call assert_fails("call searchpair('start', {-> 0}, 'end', 'bW', 'skip', 99, 100)", 'E729: Using a Funcref as a String')
  call assert_fails("call searchpair('start', 'middle', {'one': 1}, 'bW', 'skip', 99, 100)", 'E731: Using a Dictionary as a String')
  call assert_fails("call searchpair('start', 'middle', 'end', 'flags', 'skip', 99, 100)", 'E475: Invalid argument: flags')
  call assert_fails("call searchpair('start', 'middle', 'end', 'bW', 'func', -99, 100)", 'E475: Invalid argument: -99')
  call assert_fails("call searchpair('start', 'middle', 'end', 'bW', 'func', 99, -100)", 'E475: Invalid argument: -100')
  call assert_fails("call searchpair('start', 'middle', 'end', 'e')", 'E475: Invalid argument: e')
  call assert_fails("call searchpair('start', 'middle', 'end', 'sn')", 'E475: Invalid argument: sn')
endfunc

func Test_searchpairpos_errors()
  call assert_fails("call searchpairpos([0], 'middle', 'end', 'bW', 'skip', 99, 100)", 'E730: Using a List as a String')
  call assert_fails("call searchpairpos('start', {-> 0}, 'end', 'bW', 'skip', 99, 100)", 'E729: Using a Funcref as a String')
  call assert_fails("call searchpairpos('start', 'middle', {'one': 1}, 'bW', 'skip', 99, 100)", 'E731: Using a Dictionary as a String')
  call assert_fails("call searchpairpos('start', 'middle', 'end', 'flags', 'skip', 99, 100)", 'E475: Invalid argument: flags')
  call assert_fails("call searchpairpos('start', 'middle', 'end', 'bW', 'func', -99, 100)", 'E475: Invalid argument: -99')
  call assert_fails("call searchpairpos('start', 'middle', 'end', 'bW', 'func', 99, -100)", 'E475: Invalid argument: -100')
  call assert_fails("call searchpairpos('start', 'middle', 'end', 'e')", 'E475: Invalid argument: e')
  call assert_fails("call searchpairpos('start', 'middle', 'end', 'sn')", 'E475: Invalid argument: sn')
endfunc

func Test_searchpair_skip()
    func Zero()
      return 0
    endfunc
    func Partial(x)
      return a:x
    endfunc
    new
    call setline(1, ['{', 'foo', 'foo', 'foo', '}'])
    3 | call assert_equal(1, searchpair('{', '', '}', 'bWn', ''))
    3 | call assert_equal(1, searchpair('{', '', '}', 'bWn', '0'))
    3 | call assert_equal(1, searchpair('{', '', '}', 'bWn', {-> 0}))
    3 | call assert_equal(1, searchpair('{', '', '}', 'bWn', function('Zero')))
    3 | call assert_equal(1, searchpair('{', '', '}', 'bWn', function('Partial', [0])))
    bw!
endfunc

func Test_searchpair_leak()
  new
  call setline(1, 'if one else another endif')

  " The error in the skip expression caused memory to leak.
  call assert_fails("call searchpair('\\<if\\>', '\\<else\\>', '\\<endif\\>', '', '\"foo\" 2')", 'E15:')

  bwipe!
endfunc

func Test_searchc()
  " These commands used to cause memory overflow in searchc().
  new
  norm ixx
  exe "norm 0t\u93cf"
  bw!
endfunc

func Cmdline3_prep()
  CheckFunction test_override
  " need to disable char_avail,
  " so that expansion of commandline works
  call test_override("char_avail", 1)
  new
  call setline(1, ['  1', '  2 the~e', '  3 the theother'])
  set incsearch
endfunc

func Incsearch_cleanup()
  CheckFunction test_override
  set noincsearch
  call test_override("char_avail", 0)
  bw!
endfunc

func Test_search_cmdline3()
  CheckOption incsearch

  call Cmdline3_prep()
  1
  " first match
  call feedkeys("/the\<c-l>\<cr>", 'tx')
  call assert_equal('  2 the~e', getline('.'))

  call Incsearch_cleanup()
endfunc

func Test_search_cmdline3s()
  CheckOption incsearch

  call Cmdline3_prep()
  1
  call feedkeys(":%s/the\<c-l>/xxx\<cr>", 'tx')
  call assert_equal('  2 xxxe', getline('.'))
  undo
  call feedkeys(":%subs/the\<c-l>/xxx\<cr>", 'tx')
  call assert_equal('  2 xxxe', getline('.'))
  undo
  call feedkeys(":%substitute/the\<c-l>/xxx\<cr>", 'tx')
  call assert_equal('  2 xxxe', getline('.'))
  undo
  call feedkeys(":%smagic/the.e/xxx\<cr>", 'tx')
  call assert_equal('  2 xxx', getline('.'))
  undo
  call assert_fails(":%snomagic/the.e/xxx\<cr>", 'E486')
  "
  call feedkeys(":%snomagic/the\\.e/xxx\<cr>", 'tx')
  call assert_equal('  2 xxx', getline('.'))

  call Incsearch_cleanup()
endfunc

func Test_search_cmdline3g()
  CheckOption incsearch

  call Cmdline3_prep()
  1
  call feedkeys(":g/the\<c-l>/d\<cr>", 'tx')
  call assert_equal('  3 the theother', getline(2))
  undo
  call feedkeys(":global/the\<c-l>/d\<cr>", 'tx')
  call assert_equal('  3 the theother', getline(2))
  undo
  call feedkeys(":g!/the\<c-l>/d\<cr>", 'tx')
  call assert_equal(1, line('$'))
  call assert_equal('  2 the~e', getline(1))
  undo
  call feedkeys(":global!/the\<c-l>/d\<cr>", 'tx')
  call assert_equal(1, line('$'))
  call assert_equal('  2 the~e', getline(1))

  call Incsearch_cleanup()
endfunc

func Test_search_cmdline3v()
  CheckOption incsearch

  call Cmdline3_prep()
  1
  call feedkeys(":v/the\<c-l>/d\<cr>", 'tx')
  call assert_equal(1, line('$'))
  call assert_equal('  2 the~e', getline(1))
  undo
  call feedkeys(":vglobal/the\<c-l>/d\<cr>", 'tx')
  call assert_equal(1, line('$'))
  call assert_equal('  2 the~e', getline(1))

  call Incsearch_cleanup()
endfunc

" See test/functional/legacy/search_spec.lua
func Test_search_cmdline4()
  CheckFunction test_override
  CheckOption incsearch

  " need to disable char_avail,
  " so that expansion of commandline works
  call test_override("char_avail", 1)
  new
  call setline(1, ['  1 the first', '  2 the second', '  3 the third'])
  set incsearch
  $
  call feedkeys("?the\<c-g>\<cr>", 'tx')
  call assert_equal('  3 the third', getline('.'))
  $
  call feedkeys("?the\<c-g>\<c-g>\<cr>", 'tx')
  call assert_equal('  1 the first', getline('.'))
  $
  call feedkeys("?the\<c-g>\<c-g>\<c-g>\<cr>", 'tx')
  call assert_equal('  2 the second', getline('.'))
  $
  call feedkeys("?the\<c-t>\<cr>", 'tx')
  call assert_equal('  1 the first', getline('.'))
  $
  call feedkeys("?the\<c-t>\<c-t>\<cr>", 'tx')
  call assert_equal('  3 the third', getline('.'))
  $
  call feedkeys("?the\<c-t>\<c-t>\<c-t>\<cr>", 'tx')
  call assert_equal('  2 the second', getline('.'))
  " clean up
  set noincsearch
  call test_override("char_avail", 0)
  bw!
endfunc

func Test_search_cmdline5()
  CheckOption incsearch

  " Do not call test_override("char_avail", 1) so that <C-g> and <C-t> work
  " regardless char_avail.
  new
  call setline(1, ['  1 the first', '  2 the second', '  3 the third', ''])
  set incsearch
  1
  call feedkeys("/the\<c-g>\<c-g>\<cr>", 'tx')
  call assert_equal('  3 the third', getline('.'))
  $
  call feedkeys("?the\<c-t>\<c-t>\<c-t>\<cr>", 'tx')
  call assert_equal('  1 the first', getline('.'))
  " clean up
  set noincsearch
  bw!
endfunc

func Test_search_cmdline6()
  " Test that consecutive matches
  " are caught by <c-g>/<c-t>
  CheckFunction test_override
  CheckOption incsearch

  " need to disable char_avail,
  " so that expansion of commandline works
  call test_override("char_avail", 1)
  new
  call setline(1, [' bbvimb', ''])
  set incsearch
  " first match
  norm! gg0
  call feedkeys("/b\<cr>", 'tx')
  call assert_equal([0,1,2,0], getpos('.'))
  " second match
  norm! gg0
  call feedkeys("/b\<c-g>\<cr>", 'tx')
  call assert_equal([0,1,3,0], getpos('.'))
  " third match
  norm! gg0
  call feedkeys("/b\<c-g>\<c-g>\<cr>", 'tx')
  call assert_equal([0,1,7,0], getpos('.'))
  " first match again
  norm! gg0
  call feedkeys("/b\<c-g>\<c-g>\<c-g>\<cr>", 'tx')
  call assert_equal([0,1,2,0], getpos('.'))
  set nowrapscan
  " last match
  norm! gg0
  call feedkeys("/b\<c-g>\<c-g>\<c-g>\<cr>", 'tx')
  call assert_equal([0,1,7,0], getpos('.'))
  " clean up
  set wrapscan&vim
  set noincsearch
  call test_override("char_avail", 0)
  bw!
endfunc

func Test_search_cmdline7()
  CheckFunction test_override
  " Test that pressing <c-g> in an empty command line
  " does not move the cursor
  if !exists('+incsearch')
    return
  endif
  " need to disable char_avail,
  " so that expansion of commandline works
  call test_override("char_avail", 1)
  new
  let @/ = 'b'
  call setline(1, [' bbvimb', ''])
  set incsearch
  " first match
  norm! gg0
  " moves to next match of previous search pattern, just like /<cr>
  call feedkeys("/\<c-g>\<cr>", 'tx')
  call assert_equal([0,1,2,0], getpos('.'))
  " moves to next match of previous search pattern, just like /<cr>
  call feedkeys("/\<cr>", 'tx')
  call assert_equal([0,1,3,0], getpos('.'))
  " moves to next match of previous search pattern, just like /<cr>
  call feedkeys("/\<c-t>\<cr>", 'tx')
  call assert_equal([0,1,7,0], getpos('.'))

  " using an offset uses the last search pattern
  call cursor(1, 1)
  call setline(1, ['1 bbvimb', ' 2 bbvimb'])
  let @/ = 'b'
  call feedkeys("//e\<c-g>\<cr>", 'tx')
  call assert_equal('1 bbvimb', getline('.'))
  call assert_equal(4, col('.'))

  set noincsearch
  call test_override("char_avail", 0)
  bw!
endfunc

func Test_search_cmdline8()
  " Highlighting is cleared in all windows
  " since hls applies to all windows
  CheckOption incsearch
  CheckFeature terminal
  CheckNotGui
  if has("win32")
    throw "Skipped: Bug with sending <ESC> to terminal window not fixed yet"
  endif

  let h = winheight(0)
  if h < 3
    return
  endif
  " Prepare buffer text
  let lines = ['abb vim vim vi', 'vimvivim']
  call writefile(lines, 'Xsearch.txt', 'D')
  let buf = term_start([GetVimProg(), '--clean', '-c', 'set noswapfile', 'Xsearch.txt'], {'term_rows': 3})

  call WaitForAssert({-> assert_equal(lines, [term_getline(buf, 1), term_getline(buf, 2)])})

  call term_sendkeys(buf, ":set incsearch hlsearch\<cr>")
  call term_sendkeys(buf, ":14vsp\<cr>")
  call term_sendkeys(buf, "/vim\<cr>")
  call term_sendkeys(buf, "/b\<esc>")
  call term_sendkeys(buf, "gg0")
  call TermWait(buf, 250)
  let screen_line = term_scrape(buf, 1)
  let [a0,a1,a2,a3] = [screen_line[3].attr, screen_line[4].attr,
        \ screen_line[18].attr, screen_line[19].attr]
  call assert_notequal(a0, a1)
  call assert_notequal(a0, a3)
  call assert_notequal(a1, a2)
  call assert_equal(a0, a2)
  call assert_equal(a1, a3)

  " clean up
  bwipe!
endfunc

" Tests for regexp with various magic settings
func Run_search_regexp_magic_opt()
  put ='1 a aa abb abbccc'
  exe 'normal! /a*b\{2}c\+/e' . "\<CR>"
  call assert_equal([0, 2, 17, 0], getpos('.'))

  put ='2 d dd dee deefff'
  exe 'normal! /\Md\*e\{2}f\+/e' . "\<CR>"
  call assert_equal([0, 3, 17, 0], getpos('.'))

  set nomagic
  put ='3 g gg ghh ghhiii'
  exe 'normal! /g\*h\{2}i\+/e' . "\<CR>"
  call assert_equal([0, 4, 17, 0], getpos('.'))

  put ='4 j jj jkk jkklll'
  exe 'normal! /\mj*k\{2}l\+/e' . "\<CR>"
  call assert_equal([0, 5, 17, 0], getpos('.'))

  put ='5 m mm mnn mnnooo'
  exe 'normal! /\vm*n{2}o+/e' . "\<CR>"
  call assert_equal([0, 6, 17, 0], getpos('.'))

  put ='6 x ^aa$ x'
  exe 'normal! /\V^aa$' . "\<CR>"
  call assert_equal([0, 7, 5, 0], getpos('.'))

  set magic
  put ='7 (a)(b) abbaa'
  exe 'normal! /\v(a)(b)\2\1\1/e' . "\<CR>"
  call assert_equal([0, 8, 14, 0], getpos('.'))

  put ='8 axx [ab]xx'
  exe 'normal! /\V[ab]\(\[xy]\)\1' . "\<CR>"
  call assert_equal([0, 9, 7, 0], getpos('.'))

  %d
endfunc

func Test_search_regexp()
  enew!

  set regexpengine=1
  call Run_search_regexp_magic_opt()
  set regexpengine=2
  call Run_search_regexp_magic_opt()
  set regexpengine&

  set undolevels=100
  put ='9 foobar'
  put =''
  exe "normal! a\<C-G>u\<Esc>"
  normal G
  exe 'normal! dv?bar?' . "\<CR>"
  call assert_equal('9 foo', getline('.'))
  call assert_equal([0, 2, 5, 0], getpos('.'))
  call assert_equal(2, line('$'))
  normal u
  call assert_equal('9 foobar', getline('.'))
  call assert_equal([0, 2, 6, 0], getpos('.'))
  call assert_equal(3, line('$'))

  set undolevels&
  enew!
endfunc

func Test_search_cmdline_incsearch_highlight()
  CheckFunction test_override
  CheckOption incsearch

  set incsearch hlsearch
  " need to disable char_avail,
  " so that expansion of commandline works
  call test_override("char_avail", 1)
  new
  call setline(1, ['aaa  1 the first', '  2 the second', '  3 the third'])

  1
  call feedkeys("/second\<cr>", 'tx')
  call assert_equal('second', @/)
  call assert_equal('  2 the second', getline('.'))

  " Canceling search won't change @/
  1
  let @/ = 'last pattern'
  call feedkeys("/third\<C-c>", 'tx')
  call assert_equal('last pattern', @/)
  call feedkeys("/third\<Esc>", 'tx')
  call assert_equal('last pattern', @/)
  call feedkeys("/3\<bs>\<bs>", 'tx')
  call assert_equal('last pattern', @/)
  call feedkeys("/third\<c-g>\<c-t>\<Esc>", 'tx')
  call assert_equal('last pattern', @/)

  " clean up
  set noincsearch nohlsearch
  bw!
endfunc

func Test_search_cmdline_incsearch_highlight_attr()
  CheckOption incsearch
  CheckFeature terminal
  CheckNotGui

  let h = winheight(0)
  if h < 3
    return
  endif

  " Prepare buffer text
  let lines = ['abb vim vim vi', 'vimvivim']
  call writefile(lines, 'Xsearch.txt', 'D')
  let buf = term_start([GetVimProg(), '--clean', '-c', 'set noswapfile', 'Xsearch.txt'], {'term_rows': 3})

  call WaitForAssert({-> assert_equal(lines, [term_getline(buf, 1), term_getline(buf, 2)])})
  " wait for vim to complete initialization
  call TermWait(buf)

  " Get attr of normal(a0), incsearch(a1), hlsearch(a2) highlight
  call term_sendkeys(buf, ":set incsearch hlsearch\<cr>")
  call term_sendkeys(buf, '/b')
  call TermWait(buf, 100)
  let screen_line1 = term_scrape(buf, 1)
  call assert_true(len(screen_line1) > 2)
  " a0: attr_normal
  let a0 = screen_line1[0].attr
  " a1: attr_incsearch
  let a1 = screen_line1[1].attr
  " a2: attr_hlsearch
  let a2 = screen_line1[2].attr
  call assert_notequal(a0, a1)
  call assert_notequal(a0, a2)
  call assert_notequal(a1, a2)
  call term_sendkeys(buf, "\<cr>gg0")

  " Test incremental highlight search
  call term_sendkeys(buf, "/vim")
  call TermWait(buf, 100)
  " Buffer:
  " abb vim vim vi
  " vimvivim
  " Search: /vim
  let attr_line1 = [a0,a0,a0,a0,a1,a1,a1,a0,a2,a2,a2,a0,a0,a0]
  let attr_line2 = [a2,a2,a2,a0,a0,a2,a2,a2]
  call assert_equal(attr_line1, map(term_scrape(buf, 1)[:len(attr_line1)-1], 'v:val.attr'))
  call assert_equal(attr_line2, map(term_scrape(buf, 2)[:len(attr_line2)-1], 'v:val.attr'))

  " Test <C-g>
  call term_sendkeys(buf, "\<C-g>\<C-g>")
  call TermWait(buf, 100)
  let attr_line1 = [a0,a0,a0,a0,a2,a2,a2,a0,a2,a2,a2,a0,a0,a0]
  let attr_line2 = [a1,a1,a1,a0,a0,a2,a2,a2]
  call assert_equal(attr_line1, map(term_scrape(buf, 1)[:len(attr_line1)-1], 'v:val.attr'))
  call assert_equal(attr_line2, map(term_scrape(buf, 2)[:len(attr_line2)-1], 'v:val.attr'))

  " Test <C-t>
  call term_sendkeys(buf, "\<C-t>")
  call TermWait(buf, 100)
  let attr_line1 = [a0,a0,a0,a0,a2,a2,a2,a0,a1,a1,a1,a0,a0,a0]
  let attr_line2 = [a2,a2,a2,a0,a0,a2,a2,a2]
  call assert_equal(attr_line1, map(term_scrape(buf, 1)[:len(attr_line1)-1], 'v:val.attr'))
  call assert_equal(attr_line2, map(term_scrape(buf, 2)[:len(attr_line2)-1], 'v:val.attr'))

  " Type Enter and a1(incsearch highlight) should become a2(hlsearch highlight)
  call term_sendkeys(buf, "\<cr>")
  call TermWait(buf, 100)
  let attr_line1 = [a0,a0,a0,a0,a2,a2,a2,a0,a2,a2,a2,a0,a0,a0]
  let attr_line2 = [a2,a2,a2,a0,a0,a2,a2,a2]
  call assert_equal(attr_line1, map(term_scrape(buf, 1)[:len(attr_line1)-1], 'v:val.attr'))
  call assert_equal(attr_line2, map(term_scrape(buf, 2)[:len(attr_line2)-1], 'v:val.attr'))

  " Test nohlsearch. a2(hlsearch highlight) should become a0(normal highlight)
  call term_sendkeys(buf, ":1\<cr>")
  call term_sendkeys(buf, ":set nohlsearch\<cr>")
  call term_sendkeys(buf, "/vim")
  call TermWait(buf, 100)
  let attr_line1 = [a0,a0,a0,a0,a1,a1,a1,a0,a0,a0,a0,a0,a0,a0]
  let attr_line2 = [a0,a0,a0,a0,a0,a0,a0,a0]
  call assert_equal(attr_line1, map(term_scrape(buf, 1)[:len(attr_line1)-1], 'v:val.attr'))
  call assert_equal(attr_line2, map(term_scrape(buf, 2)[:len(attr_line2)-1], 'v:val.attr'))

  bwipe!
endfunc

func Test_incsearch_cmdline_modifier()
  CheckFunction test_override
  CheckOption incsearch

  call test_override("char_avail", 1)
  new
  call setline(1, ['foo'])
  set incsearch
  " Test that error E14 does not occur in parsing command modifier.
  call feedkeys("V:tab", 'tx')

  call Incsearch_cleanup()
endfunc

func Test_incsearch_scrolling()
  CheckRunVimInTerminal
  call assert_equal(0, &scrolloff)
  call writefile([
	\ 'let dots = repeat(".", 120)',
	\ 'set incsearch cmdheight=2 scrolloff=0',
	\ 'call setline(1, [dots, dots, dots, "", "target", dots, dots])',
	\ 'normal gg',
	\ 'redraw',
	\ ], 'Xscript', 'D')
  let buf = RunVimInTerminal('-S Xscript', {'rows': 9, 'cols': 70})
  " Need to send one key at a time to force a redraw
  call term_sendkeys(buf, '/')
  sleep 100m
  call term_sendkeys(buf, 't')
  sleep 100m
  call term_sendkeys(buf, 'a')
  sleep 100m
  call term_sendkeys(buf, 'r')
  sleep 100m
  call term_sendkeys(buf, 'g')
  call VerifyScreenDump(buf, 'Test_incsearch_scrolling_01', {})

  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
endfunc

func Test_incsearch_search_dump()
  CheckOption incsearch
  CheckScreendump

  call writefile([
	\ 'set incsearch hlsearch scrolloff=0',
	\ 'for n in range(1, 8)',
	\ '  call setline(n, "foo " . n)',
	\ 'endfor',
	\ '3',
	\ ], 'Xis_search_script', 'D')
  let buf = RunVimInTerminal('-S Xis_search_script', {'rows': 9, 'cols': 70})
  " Give Vim a chance to redraw to get rid of the spaces in line 2 caused by
  " the 'ambiwidth' check.
  sleep 100m

  " Need to send one key at a time to force a redraw.
  call term_sendkeys(buf, '/fo')
  call VerifyScreenDump(buf, 'Test_incsearch_search_01', {})
  call term_sendkeys(buf, "\<Esc>")
  sleep 100m

  call term_sendkeys(buf, '/\v')
  call VerifyScreenDump(buf, 'Test_incsearch_search_02', {})
  call term_sendkeys(buf, "\<Esc>")

  call StopVimInTerminal(buf)
endfunc

func Test_hlsearch_dump()
  CheckOption hlsearch
  CheckScreendump

  call writefile([
	\ 'set hlsearch cursorline',
        \ 'call setline(1, ["xxx", "xxx", "xxx"])',
	\ '/.*',
	\ '2',
	\ ], 'Xhlsearch_script', 'D')
  let buf = RunVimInTerminal('-S Xhlsearch_script', {'rows': 6, 'cols': 50})
  call VerifyScreenDump(buf, 'Test_hlsearch_1', {})

  call term_sendkeys(buf, "/\\_.*\<CR>")
  call VerifyScreenDump(buf, 'Test_hlsearch_2', {})

  call StopVimInTerminal(buf)
endfunc

func Test_hlsearch_and_visual()
  CheckOption hlsearch
  CheckScreendump

  call writefile([
	\ 'set hlsearch',
        \ 'call setline(1, repeat(["xxx yyy zzz"], 3))',
        \ 'hi Search cterm=bold',
	\ '/yyy',
	\ 'call cursor(1, 6)',
	\ ], 'Xhlvisual_script', 'D')
  let buf = RunVimInTerminal('-S Xhlvisual_script', {'rows': 6, 'cols': 40})
  call term_sendkeys(buf, "vjj")
  call VerifyScreenDump(buf, 'Test_hlsearch_visual_1', {})
  call term_sendkeys(buf, "\<Esc>")

  call StopVimInTerminal(buf)
endfunc

func Test_hlsearch_block_visual_match()
  CheckScreendump

  let lines =<< trim END
    set hlsearch
    call setline(1, ['aa', 'bbbb', 'cccccc'])
  END
  call writefile(lines, 'Xhlsearch_block', 'D')
  let buf = RunVimInTerminal('-S Xhlsearch_block', {'rows': 9, 'cols': 60})

  call term_sendkeys(buf, "G\<C-V>$kk\<Esc>")
  sleep 100m
  call term_sendkeys(buf, "/\\%V\<CR>")
  sleep 100m
  call VerifyScreenDump(buf, 'Test_hlsearch_block_visual_match', {})

  call StopVimInTerminal(buf)
endfunc

func Test_incsearch_substitute()
  CheckFunction test_override
  CheckOption incsearch

  call test_override("char_avail", 1)
  new
  set incsearch
  for n in range(1, 10)
    call setline(n, 'foo ' . n)
  endfor
  4
  call feedkeys(":.,.+2s/foo\<BS>o\<BS>o/xxx\<cr>", 'tx')
  call assert_equal('foo 3', getline(3))
  call assert_equal('xxx 4', getline(4))
  call assert_equal('xxx 5', getline(5))
  call assert_equal('xxx 6', getline(6))
  call assert_equal('foo 7', getline(7))

  call Incsearch_cleanup()
endfunc

func Test_incsearch_substitute_long_line()
  CheckFunction test_override
  new
  call test_override("char_avail", 1)
  set incsearch

  call repeat('x', 100000)->setline(1)
  call feedkeys(':s/\%c', 'xt')
  redraw
  call feedkeys("\<Esc>", 'xt')

  call Incsearch_cleanup()
  bwipe!
endfunc

func Test_hlsearch_cursearch()
  CheckScreendump

  let lines =<< trim END
    set hlsearch scrolloff=0
    call setline(1, ['one', 'foo', 'bar', 'baz', 'foo the foo and foo', 'bar'])
    hi Search ctermbg=yellow
    hi CurSearch ctermbg=blue
  END
  call writefile(lines, 'Xhlsearch_cursearch', 'D')
  let buf = RunVimInTerminal('-S Xhlsearch_cursearch', {'rows': 9, 'cols': 60})

  call term_sendkeys(buf, "gg/foo\<CR>")
  call VerifyScreenDump(buf, 'Test_hlsearch_cursearch_single_line_1', {})

  call term_sendkeys(buf, "n")
  call VerifyScreenDump(buf, 'Test_hlsearch_cursearch_single_line_2', {})

  call term_sendkeys(buf, "n")
  call VerifyScreenDump(buf, 'Test_hlsearch_cursearch_single_line_2a', {})

  call term_sendkeys(buf, "n")
  call VerifyScreenDump(buf, 'Test_hlsearch_cursearch_single_line_2b', {})

  call term_sendkeys(buf, ":call setline(5, 'foo')\<CR>")
  call term_sendkeys(buf, "0?\<CR>")
  call VerifyScreenDump(buf, 'Test_hlsearch_cursearch_single_line_3', {})

  call term_sendkeys(buf, "gg/foo\\nbar\<CR>")
  call VerifyScreenDump(buf, 'Test_hlsearch_cursearch_multiple_line_1', {})

  call term_sendkeys(buf, ":call setline(1, ['---', 'abcdefg', 'hijkl', '---', 'abcdefg', 'hijkl'])\<CR>")
  call term_sendkeys(buf, "gg/efg\\nhij\<CR>")
  call VerifyScreenDump(buf, 'Test_hlsearch_cursearch_multiple_line_2', {})
  call term_sendkeys(buf, "h\<C-L>")
  call VerifyScreenDump(buf, 'Test_hlsearch_cursearch_multiple_line_3', {})
  call term_sendkeys(buf, "j\<C-L>")
  call VerifyScreenDump(buf, 'Test_hlsearch_cursearch_multiple_line_4', {})
  call term_sendkeys(buf, "h\<C-L>")
  call VerifyScreenDump(buf, 'Test_hlsearch_cursearch_multiple_line_5', {})

  " check clearing CurSearch when using it for another match
  call term_sendkeys(buf, "G?^abcd\<CR>Y")
  call term_sendkeys(buf, "kkP")
  call VerifyScreenDump(buf, 'Test_hlsearch_cursearch_changed_1', {})

  call StopVimInTerminal(buf)
endfunc

" Similar to Test_incsearch_substitute() but with a screendump halfway.
func Test_incsearch_substitute_dump()
  CheckOption incsearch
  CheckScreendump

  call writefile([
	\ 'set incsearch hlsearch scrolloff=0',
	\ 'for n in range(1, 10)',
	\ '  call setline(n, "foo " . n)',
	\ 'endfor',
	\ 'call setline(11, "bar 11")',
	\ '3',
	\ ], 'Xis_subst_script', 'D')
  let buf = RunVimInTerminal('-S Xis_subst_script', {'rows': 9, 'cols': 70})
  " Give Vim a chance to redraw to get rid of the spaces in line 2 caused by
  " the 'ambiwidth' check.
  sleep 100m

  " Need to send one key at a time to force a redraw.
  " Select three lines at the cursor with typed pattern.
  call term_sendkeys(buf, ':.,.+2s/')
  sleep 100m
  call term_sendkeys(buf, 'f')
  sleep 100m
  call term_sendkeys(buf, 'o')
  sleep 100m
  call term_sendkeys(buf, 'o')
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_01', {})
  call term_sendkeys(buf, "\<Esc>")

  " Select three lines at the cursor using previous pattern.
  call term_sendkeys(buf, "/foo\<CR>")
  sleep 100m
  call term_sendkeys(buf, ':.,.+2s//')
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_02', {})

  " Deleting last slash should remove the match.
  call term_sendkeys(buf, "\<BS>")
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_03', {})
  call term_sendkeys(buf, "\<Esc>")

  " Reverse range is accepted
  call term_sendkeys(buf, ':5,2s/foo')
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_04', {})
  call term_sendkeys(buf, "\<Esc>")

  " White space after the command is skipped
  call term_sendkeys(buf, ':2,3sub  /fo')
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_05', {})
  call term_sendkeys(buf, "\<Esc>")

  " Command modifiers are skipped
  call term_sendkeys(buf, ':above below browse botr confirm keepmar keepalt keeppat keepjum filter xxx hide lockm leftabove noau noswap rightbel sandbox silent silent! $tab top unsil vert verbose 4,5s/fo.')
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_06', {})
  call term_sendkeys(buf, "\<Esc>")

  " Cursorline highlighting at match
  call term_sendkeys(buf, ":set cursorline\<CR>")
  call term_sendkeys(buf, 'G9G')
  call term_sendkeys(buf, ':9,11s/bar')
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_07', {})
  call term_sendkeys(buf, "\<Esc>")

  " Cursorline highlighting at cursor when no match
  call term_sendkeys(buf, ':9,10s/bar')
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_08', {})
  call term_sendkeys(buf, "\<Esc>")

  " Only \v handled as empty pattern, does not move cursor
  call term_sendkeys(buf, '3G4G')
  call term_sendkeys(buf, ":nohlsearch\<CR>")
  call term_sendkeys(buf, ':6,7s/\v')
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_09', {})
  call term_sendkeys(buf, "\<Esc>")

  call term_sendkeys(buf, ":set nocursorline\<CR>")

  " All matches are highlighted for 'hlsearch' after the incsearch canceled
  call term_sendkeys(buf, "1G*")
  call term_sendkeys(buf, ":2,5s/foo")
  sleep 100m
  call term_sendkeys(buf, "\<Esc>")
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_10', {})

  call term_sendkeys(buf, ":split\<CR>")
  call term_sendkeys(buf, ":let @/ = 'xyz'\<CR>")
  call term_sendkeys(buf, ":%s/.")
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_11', {})
  call term_sendkeys(buf, "\<BS>")
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_12', {})
  call term_sendkeys(buf, "\<Esc>")
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_13', {})
  call term_sendkeys(buf, ":%bwipe!\<CR>")
  call term_sendkeys(buf, ":only!\<CR>")

  "  get :'<,'>s command in history
  call term_sendkeys(buf, ":set cmdheight=2\<CR>")
  call term_sendkeys(buf, "aasdfasdf\<Esc>")
  call term_sendkeys(buf, "V:s/a/b/g\<CR>")
  " Using '<,'> does not give E20
  call term_sendkeys(buf, ":new\<CR>")
  call term_sendkeys(buf, "aasdfasdf\<Esc>")
  call term_sendkeys(buf, ":\<Up>\<Up>")
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_14', {})
  call term_sendkeys(buf, "<Esc>")

  call StopVimInTerminal(buf)
endfunc

func Test_incsearch_highlighting()
  CheckOption incsearch
  CheckScreendump

  call writefile([
	\ 'set incsearch hlsearch',
	\ 'call setline(1, "hello/there")',
	\ ], 'Xis_subst_hl_script', 'D')
  let buf = RunVimInTerminal('-S Xis_subst_hl_script', {'rows': 4, 'cols': 20})
  " Give Vim a chance to redraw to get rid of the spaces in line 2 caused by
  " the 'ambiwidth' check.
  sleep 300m

  " Using a different search delimiter should still highlight matches
  " that contain a '/'.
  call term_sendkeys(buf, ":%s;ello/the")
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_15', {})
  call term_sendkeys(buf, "<Esc>")

  call StopVimInTerminal(buf)
endfunc

func Test_incsearch_with_change()
  CheckFeature timers
  CheckOption incsearch
  CheckScreendump
 
  call writefile([
	\ 'set incsearch hlsearch scrolloff=0',
	\ 'call setline(1, ["one", "two ------ X", "three"])',
	\ 'call timer_start(200, { _ -> setline(2, "x")})',
	\ ], 'Xis_change_script', 'D')
  let buf = RunVimInTerminal('-S Xis_change_script', {'rows': 9, 'cols': 70})
  " Give Vim a chance to redraw to get rid of the spaces in line 2 caused by
  " the 'ambiwidth' check.
  sleep 300m

  " Highlight X, it will be deleted by the timer callback.
  call term_sendkeys(buf, ':%s/X')
  call VerifyScreenDump(buf, 'Test_incsearch_change_01', {})
  call term_sendkeys(buf, "\<Esc>")

  call StopVimInTerminal(buf)
endfunc

" Similar to Test_incsearch_substitute_dump() for :sort
func Test_incsearch_sort_dump()
  CheckOption incsearch
  CheckScreendump

  call writefile([
	\ 'set incsearch hlsearch scrolloff=0',
	\ 'call setline(1, ["another one 2", "that one 3", "the one 1"])',
	\ ], 'Xis_sort_script', 'D')
  let buf = RunVimInTerminal('-S Xis_sort_script', {'rows': 9, 'cols': 70})
  " Give Vim a chance to redraw to get rid of the spaces in line 2 caused by
  " the 'ambiwidth' check.
  sleep 100m

  call term_sendkeys(buf, ':sort ni u /on')
  call VerifyScreenDump(buf, 'Test_incsearch_sort_01', {})
  call term_sendkeys(buf, "\<Esc>")

  call term_sendkeys(buf, ':sort! /on')
  call VerifyScreenDump(buf, 'Test_incsearch_sort_02', {})
  call term_sendkeys(buf, "\<Esc>")

  call StopVimInTerminal(buf)
endfunc

" Similar to Test_incsearch_substitute_dump() for :vimgrep famiry
func Test_incsearch_vimgrep_dump()
  CheckOption incsearch
  CheckScreendump

  call writefile([
	\ 'set incsearch hlsearch scrolloff=0',
	\ 'call setline(1, ["another one 2", "that one 3", "the one 1"])',
	\ ], 'Xis_vimgrep_script', 'D')
  let buf = RunVimInTerminal('-S Xis_vimgrep_script', {'rows': 9, 'cols': 70})
  " Give Vim a chance to redraw to get rid of the spaces in line 2 caused by
  " the 'ambiwidth' check.
  sleep 100m

  " Need to send one key at a time to force a redraw.
  call term_sendkeys(buf, ':vimgrep on')
  call VerifyScreenDump(buf, 'Test_incsearch_vimgrep_01', {})
  call term_sendkeys(buf, "\<Esc>")

  call term_sendkeys(buf, ':vimg /on/ *.txt')
  call VerifyScreenDump(buf, 'Test_incsearch_vimgrep_02', {})
  call term_sendkeys(buf, "\<Esc>")

  call term_sendkeys(buf, ':vimgrepadd "\<on')
  call VerifyScreenDump(buf, 'Test_incsearch_vimgrep_03', {})
  call term_sendkeys(buf, "\<Esc>")

  call term_sendkeys(buf, ':lv "tha')
  call VerifyScreenDump(buf, 'Test_incsearch_vimgrep_04', {})
  call term_sendkeys(buf, "\<Esc>")

  call term_sendkeys(buf, ':lvimgrepa "the" **/*.txt')
  call VerifyScreenDump(buf, 'Test_incsearch_vimgrep_05', {})
  call term_sendkeys(buf, "\<Esc>")

  call StopVimInTerminal(buf)
endfunc

func Test_keep_last_search_pattern()
  CheckFunction test_override
  CheckOption incsearch

  new
  call setline(1, ['foo', 'foo', 'foo'])
  set incsearch
  call test_override("char_avail", 1)
  let @/ = 'bar'
  call feedkeys(":/foo/s//\<Esc>", 'ntx')
  call assert_equal('bar', @/)

  " no error message if pattern not found
  call feedkeys(":/xyz/s//\<Esc>", 'ntx')
  call assert_equal('bar', @/)

  bwipe!
  call test_override("ALL", 0)
  set noincsearch
endfunc

func Test_word_under_cursor_after_match()
  CheckFunction test_override
  CheckOption incsearch

  new
  call setline(1, 'foo bar')
  set incsearch
  call test_override("char_avail", 1)
  try
    call feedkeys("/foo\<C-R>\<C-W>\<CR>", 'ntx')
  catch /E486:/
  endtry
  call assert_equal('foobar', @/)

  bwipe!
  call test_override("ALL", 0)
  set noincsearch
endfunc

func Test_subst_word_under_cursor()
  CheckFunction test_override
  CheckOption incsearch

  new
  call setline(1, ['int SomeLongName;', 'for (xxx = 1; xxx < len; ++xxx)'])
  set incsearch
  call test_override("char_avail", 1)
  call feedkeys("/LongName\<CR>", 'ntx')
  call feedkeys(":%s/xxx/\<C-R>\<C-W>/g\<CR>", 'ntx')
  call assert_equal('for (SomeLongName = 1; SomeLongName < len; ++SomeLongName)', getline(2))

  bwipe!
  call test_override("ALL", 0)
  set noincsearch
endfunc

func Test_search_skip_all_matches()
  enew
  call setline(1, ['no match here',
        \ 'match this line',
        \ 'nope',
        \ 'match in this line',
        \ 'last line',
        \ ])
  call cursor(1, 1)
  let lnum = search('this', '', 0, 0, 'getline(".") =~ "this line"')
  " Only check that no match is found.  Previously it searched forever.
  call assert_equal(0, lnum)

  bwipe!
endfunc

func Test_search_undefined_behaviour()
  CheckFeature terminal

  let h = winheight(0)
  if h < 3
    return
  endif
  " did cause an undefined left shift
  let g:buf = term_start([GetVimProg(), '--clean', '-e', '-s', '-c', 'call search(getline("."))', 'samples/test000'], {'term_rows': 3})
  call assert_equal([''], getline(1, '$'))
  call term_sendkeys(g:buf, ":qa!\<cr>")
  bwipe!
endfunc

func Test_search_undefined_behaviour2()
  call search("\%UC0000000")
endfunc

" Test for search('multi-byte char', 'bce')
func Test_search_multibyte()
  let save_enc = &encoding
  set encoding=utf8
  enew!
  call append('$', 'Ａ')
  call cursor(2, 1)
  call assert_equal(2, search('Ａ', 'bce', line('.')))
  enew!
  let &encoding = save_enc
endfunc

" This was causing E874.  Also causes an invalid read?
func Test_look_behind()
  new
  call setline(1, '0\|\&\n\@<=')
  call search(getline("."))
  bwipe!
endfunc

func Test_search_visual_area_linewise()
  new
  call setline(1, ['aa', 'bb', 'cc'])
  exe "normal 2GV\<Esc>"
  for engine in [1, 2]
    exe 'set regexpengine=' .. engine
    exe "normal gg/\\%'<\<CR>>"
    call assert_equal([0, 2, 1, 0, 1], getcurpos(), 'engine ' .. engine)
    exe "normal gg/\\%'>\<CR>"
    call assert_equal([0, 2, 2, 0, 2], getcurpos(), 'engine ' .. engine)
  endfor

  bwipe!
  set regexpengine&
endfunc

func Test_search_sentence()
  new
  " this used to cause a crash
  /\%'(
  /
  bwipe
endfunc

" Test that there is no crash when there is a last search pattern but no last
" substitute pattern.
func Test_no_last_substitute_pat()
  " Use viminfo to set the last search pattern to a string and make the last
  " substitute pattern the most recent used and make it empty (NULL).
  call writefile(['~MSle0/bar', '~MSle0~&'], 'Xviminfo', 'D')
  rviminfo! Xviminfo
  call assert_fails('normal n', 'E35:')
endfunc

func Test_search_Ctrl_L_combining()
  " Make sure, that Ctrl-L works correctly with combining characters.
  " It uses an artificial example of an 'a' with 4 combining chars:
    " 'a' U+0061 Dec:97 LATIN SMALL LETTER A &#x61; /\%u61\Z "\u0061"
    " ' ̀' U+0300 Dec:768 COMBINING GRAVE ACCENT &#x300; /\%u300\Z "\u0300"
    " ' ́' U+0301 Dec:769 COMBINING ACUTE ACCENT &#x301; /\%u301\Z "\u0301"
    " ' ̇' U+0307 Dec:775 COMBINING DOT ABOVE &#x307; /\%u307\Z "\u0307"
    " ' ̣' U+0323 Dec:803 COMBINING DOT BELOW &#x323; /\%u323 "\u0323"
  " Those should also appear on the commandline
  CheckOption incsearch

  call Cmdline3_prep()
  1
  let bufcontent = ['', 'Miạ̀́̇m']
  call append('$', bufcontent)
  call feedkeys("/Mi\<c-l>\<c-l>\<cr>", 'tx')
  call assert_equal(5, line('.'))
  call assert_equal(bufcontent[1], @/)
  call Incsearch_cleanup()
endfunc

func Test_large_hex_chars1()
  " This used to cause a crash, the character becomes an NFA state.
  try
    /\%Ufffffc23
  catch
    call assert_match('E678:', v:exception)
  endtry
  try
    set re=1
    /\%Ufffffc23
  catch
    call assert_match('E678:', v:exception)
  endtry
  set re&
endfunc

func Test_large_hex_chars2()
  " This used to cause a crash, the character becomes an NFA state.
  try
    /[\Ufffffc1f]
  catch
    call assert_match('E486:', v:exception)
  endtry
  try
    set re=1
    /[\Ufffffc1f]
  catch
    call assert_match('E486:', v:exception)
  endtry
  set re&
endfunc

func Test_one_error_msg()
  " This was also giving an internal error
  call assert_fails('call search(" \\((\\v[[=P=]]){185}+             ")', 'E871:')
endfunc

func Test_incsearch_add_char_under_cursor()
  CheckFunction test_override
  CheckOption incsearch

  set incsearch
  new
  call setline(1, ['find match', 'anything'])
  1
  call test_override('char_avail', 1)
  call feedkeys("fc/m\<C-L>\<C-L>\<C-L>\<C-L>\<C-L>\<CR>", 'tx')
  call assert_equal('match', @/)
  call test_override('char_avail', 0)

  set incsearch&
  bwipe!
endfunc

" Test for the search() function with match at the cursor position
func Test_search_match_at_curpos()
  new
  call append(0, ['foobar', '', 'one two', ''])

  normal gg

  eval 'foobar'->search('c')
  call assert_equal([1, 1], [line('.'), col('.')])

  normal j
  call search('^$', 'c')
  call assert_equal([2, 1], [line('.'), col('.')])

  call search('^$', 'bc')
  call assert_equal([2, 1], [line('.'), col('.')])

  exe "normal /two\<CR>"
  call search('.', 'c')
  call assert_equal([3, 5], [line('.'), col('.')])

  close!
endfunc

" Test for error cases with the search() function
func Test_search_errors()
  call assert_fails("call search('pat', [])", 'E730:')
  call assert_fails("call search('pat', 'b', {})", 'E728:')
  call assert_fails("call search('pat', 'b', 1, [])", 'E745:')
  call assert_fails("call search('pat', 'ns')", 'E475:')
  call assert_fails("call search('pat', 'mr')", 'E475:')

  new
  call setline(1, ['foo', 'bar'])
  call assert_fails('call feedkeys("/foo/;/bar/;\<CR>", "tx")', 'E386:')
  bwipe!
endfunc

func Test_search_display_pattern()
  new
  call setline(1, ['foo', 'bar', 'foobar'])

  call cursor(1, 1)
  let @/ = 'foo'
  let pat = @/->escape('()*?'. '\s\+')
  let g:a = execute(':unsilent :norm! n')
  call assert_match(pat, g:a)

  " right-left
  if exists("+rightleft")
    set rl
    call cursor(1, 1)
    let @/ = 'foo'
    let pat = 'oof/\s\+'
    let g:a = execute(':unsilent :norm! n')
    call assert_match(pat, g:a)
    set norl
  endif
endfunc

func Test_searchdecl()
  let lines =<< trim END
     int global;

     func()
     {
       int global;
       if (cond) {
	 int local;
       }
       int local;
       // comment
     }
  END
  new
  call setline(1, lines)
  10
  call assert_equal(0, searchdecl('local', 0, 0))
  call assert_equal(7, getcurpos()[1])

  10
  call assert_equal(0, 'local'->searchdecl(0, 1))
  call assert_equal(9, getcurpos()[1])

  10
  call assert_equal(0, searchdecl('global'))
  call assert_equal(5, getcurpos()[1])

  10
  call assert_equal(0, searchdecl('global', 1))
  call assert_equal(1, getcurpos()[1])

  bwipe!
endfunc

func Test_search_special()
  " this was causing illegal memory access and an endless loop
  set t_PE=
  exe "norm /\x80PS"
endfunc

" Test for command failures when the last search pattern is not set.
" Need to run this in a new vim instance where last search pattern is not set.
func Test_search_with_no_last_pat()
  let lines =<< trim [SCRIPT]
    call assert_fails("normal i\<C-R>/\e", 'E35:')
    call assert_fails("exe '/'", 'E35:')
    call assert_fails("exe '?'", 'E35:')
    call assert_fails("/", 'E35:')
    call assert_fails("?", 'E35:')
    call assert_fails("normal n", 'E35:')
    call assert_fails("normal N", 'E35:')
    call assert_fails("normal gn", 'E35:')
    call assert_fails("normal gN", 'E35:')
    call assert_fails("normal cgn", 'E35:')
    call assert_fails("normal cgN", 'E35:')
    let p = []
    let p = @/
    call assert_equal('', p)
    call assert_fails("normal :\<C-R>/", 'E35:')
    call assert_fails("//p", 'E35:')
    call assert_fails(";//p", 'E35:')
    call assert_fails("??p", 'E35:')
    call assert_fails(";??p", 'E35:')
    call assert_fails('g//p', ['E35:', 'E476:'])
    call assert_fails('v//p', ['E35:', 'E476:'])
    call writefile(v:errors, 'Xresult')
    qall!
  [SCRIPT]
  call writefile(lines, 'Xscript', 'D')

  if RunVim([], [], '--clean -S Xscript')
    call assert_equal([], readfile('Xresult'))
  endif
  call delete('Xresult')
endfunc

" Test for using tilde (~) atom in search. This should use the last used
" substitute pattern
func Test_search_tilde_pat()
  let lines =<< trim [SCRIPT]
    set regexpengine=1
    call assert_fails('exe "normal /~\<CR>"', 'E33:')
    call assert_fails('exe "normal ?~\<CR>"', 'E33:')
    set regexpengine=2
    call assert_fails('exe "normal /~\<CR>"', ['E33:', 'E383:'])
    call assert_fails('exe "normal ?~\<CR>"', ['E33:', 'E383:'])
    set regexpengine&
    call writefile(v:errors, 'Xresult')
    qall!
  [SCRIPT]
  call writefile(lines, 'Xscript', 'D')
  if RunVim([], [], '--clean -S Xscript')
    call assert_equal([], readfile('Xresult'))
  endif
  call delete('Xresult')
endfunc

" Test for searching a pattern that is not present with 'nowrapscan'
func Test_search_pat_not_found()
  new
  set nowrapscan
  let @/ = '1abcxyz2'
  call assert_fails('normal n', 'E385:')
  call assert_fails('normal N', 'E384:')
  set wrapscan&
  close
endfunc

" Test for v:searchforward variable
func Test_searchforward_var()
  new
  call setline(1, ['foo', '', 'foo'])
  call cursor(2, 1)
  let @/ = 'foo'
  let v:searchforward = 0
  normal N
  call assert_equal(3, line('.'))
  call cursor(2, 1)
  let v:searchforward = 1
  normal N
  call assert_equal(1, line('.'))
  close!
endfunc

" Test for invalid regular expressions
func Test_invalid_regexp()
  set regexpengine=1
  call assert_fails("call search(repeat('\\(.\\)', 10))", 'E51:')
  call assert_fails("call search('\\%(')", 'E53:')
  call assert_fails("call search('\\(')", 'E54:')
  call assert_fails("call search('\\)')", 'E55:')
  call assert_fails("call search('x\\@#')", 'E59:')
  call assert_fails('call search(''\v%(%(%(%(%(%(%(%(%(%(%(a){1}){1}){1}){1}){1}){1}){1}){1}){1}){1}){1}'')', 'E60:')
  call assert_fails("call search('a\\+*')", 'E61:')
  call assert_fails("call search('\\_m')", 'E63:')
  call assert_fails("call search('\\+')", 'E64:')
  call assert_fails("call search('\\1')", 'E65:')
  call assert_fails("call search('\\z\\(\\)')", 'E66:')
  call assert_fails("call search('\\z2')", 'E67:')
  call assert_fails("call search('\\zx')", 'E68:')
  call assert_fails("call search('\\%[ab')", 'E69:')
  call assert_fails("call search('\\%[]')", 'E70:')
  call assert_fails("call search('\\%a')", 'E71:')
  call assert_fails("call search('ab\\%[\\(cd\\)]')", 'E369:')
  call assert_fails("call search('ab\\%[\\%(cd\\)]')", 'E369:')
  set regexpengine=2
  call assert_fails("call search('\\_')", 'E865:')
  call assert_fails("call search('\\+')", 'E866:')
  call assert_fails("call search('\\zx')", 'E867:')
  call assert_fails("call search('\\%a')", 'E867:')
  call assert_fails("call search('x\\@#')", 'E869:')
  call assert_fails("call search(repeat('\\(.\\)', 10))", 'E872:')
  call assert_fails("call search('\\_m')", 'E877:')
  call assert_fails("call search('\\%(')", 'E53:')
  call assert_fails("call search('\\(')", 'E54:')
  call assert_fails("call search('\\)')", 'E55:')
  call assert_fails("call search('\\z\\(\\)')", 'E66:')
  call assert_fails("call search('\\z2')", 'E67:')
  call assert_fails("call search('\\zx')", 'E867:')
  call assert_fails("call search('\\%[ab')", 'E69:')
  call assert_fails("call search('\\%[]')", 'E70:')
  call assert_fails("call search('\\%9999999999999999999999999999v')", 'E951:')
  set regexpengine&
  call assert_fails("call search('\\%#=3ab')", 'E864:')
endfunc

" Test for searching a very complex pattern in a string. Should switch the
" regexp engine from NFA to the old engine.
func Test_regexp_switch_engine()
  let l = readfile('samples/re.freeze.txt')
  let v = substitute(l[4], '..\@<!', '', '')
  call assert_equal(l[4], v)
endfunc

" Test for the \%V atom to search within visually selected text
func Test_search_in_visual_area()
  new
  call setline(1, ['foo bar1', 'foo bar2', 'foo bar3', 'foo bar4'])
  exe "normal 2GVjo/\\%Vbar\<CR>\<Esc>"
  call assert_equal([2, 5], [line('.'), col('.')])
  exe "normal 2GVj$?\\%Vbar\<CR>\<Esc>"
  call assert_equal([3, 5], [line('.'), col('.')])
  close!
endfunc

" Test for searching with 'smartcase' and 'ignorecase'
func Test_search_smartcase()
  new
  call setline(1, ['', 'Hello'])
  set noignorecase nosmartcase
  call assert_fails('exe "normal /\\a\\_.\\(.*\\)O\<CR>"', 'E486:')

  set ignorecase nosmartcase
  exe "normal /\\a\\_.\\(.*\\)O\<CR>"
  call assert_equal([2, 1], [line('.'), col('.')])

  call cursor(1, 1)
  set ignorecase smartcase
  call assert_fails('exe "normal /\\a\\_.\\(.*\\)O\<CR>"', 'E486:')

  exe "normal /\\a\\_.\\(.*\\)o\<CR>"
  call assert_equal([2, 1], [line('.'), col('.')])

  " Test for using special atoms with 'smartcase'
  call setline(1, ['', '    Hello\ '])
  call cursor(1, 1)
  call feedkeys('/\_.\%(\uello\)\' .. "\<CR>", 'xt')
  call assert_equal([2, 4], [line('.'), col('.')])

  set ignorecase& smartcase&
  close!
endfun

" Test 'smartcase' with utf-8.
func Test_search_smartcase_utf8()
  new
  let save_enc = &encoding
  set encoding=utf8 ignorecase smartcase

  call setline(1, 'Café cafÉ')
  1s/café/x/g
  call assert_equal('x x', getline(1))

  call setline(1, 'Café cafÉ')
  1s/cafÉ/x/g
  call assert_equal('Café x', getline(1))

  set ignorecase& smartcase&
  let &encoding = save_enc
  bwipe!
endfunc

" Test searching past the end of a file
func Test_search_past_eof()
  new
  call setline(1, ['Line'])
  exe "normal /\\n\\zs\<CR>"
  call assert_equal([1, 4], [line('.'), col('.')])
  bwipe!
endfunc

" Test setting the start of the match and still finding a next match in the
" same line.
func Test_search_set_start_same_line()
  new
  set cpo-=c

  call setline(1, ['1', '2', '3 .', '4', '5'])
  exe "normal /\\_s\\zs\\S\<CR>"
  call assert_equal([2, 1], [line('.'), col('.')])
  exe 'normal n'
  call assert_equal([3, 1], [line('.'), col('.')])
  exe 'normal n'
  call assert_equal([3, 3], [line('.'), col('.')])
  exe 'normal n'
  call assert_equal([4, 1], [line('.'), col('.')])
  exe 'normal n'
  call assert_equal([5, 1], [line('.'), col('.')])

  set cpo+=c
  bwipe!
endfunc

" Test for various search offsets
func Test_search_offset()
  " With /e, for a match in the first column of a line, the cursor should be
  " placed at the end of the previous line.
  new
  call setline(1, ['one two', 'three four'])
  call search('two\_.', 'e')
  call assert_equal([1, 7], [line('.'), col('.')])

  " with cursor at the beginning of the file, use /s+1
  call cursor(1, 1)
  exe "normal /two/s+1\<CR>"
  call assert_equal([1, 6], [line('.'), col('.')])

  " with cursor at the end of the file, use /e-1
  call cursor(2, 10)
  exe "normal ?three?e-1\<CR>"
  call assert_equal([2, 4], [line('.'), col('.')])

  " line offset - after the last line
  call cursor(1, 1)
  exe "normal /three/+1\<CR>"
  call assert_equal([2, 1], [line('.'), col('.')])

  " line offset - before the first line
  call cursor(2, 1)
  exe "normal ?one?-1\<CR>"
  call assert_equal([1, 1], [line('.'), col('.')])

  " character offset - before the first character in the file
  call cursor(2, 1)
  exe "normal ?one?s-1\<CR>"
  call assert_equal([1, 1], [line('.'), col('.')])
  call cursor(2, 1)
  exe "normal ?one?e-3\<CR>"
  call assert_equal([1, 1], [line('.'), col('.')])

  " character offset - after the last character in the file
  call cursor(1, 1)
  exe "normal /four/s+4\<CR>"
  call assert_equal([2, 10], [line('.'), col('.')])
  call cursor(1, 1)
  exe "normal /four/e+1\<CR>"
  call assert_equal([2, 10], [line('.'), col('.')])

  close!
endfunc

" Test for searching for matching parenthesis using %
func Test_search_match_paren()
  new
  call setline(1, "abc(def')'ghi'('jk'\\t'lm)no")
  " searching for a matching parenthesis should skip single quoted characters
  call cursor(1, 4)
  normal %
  call assert_equal([1, 25], [line('.'), col('.')])
  normal %
  call assert_equal([1, 4], [line('.'), col('.')])
  call cursor(1, 5)
  normal ])
  call assert_equal([1, 25], [line('.'), col('.')])
  call cursor(1, 24)
  normal [(
  call assert_equal([1, 4], [line('.'), col('.')])

  " matching parenthesis in 'virtualedit' mode with cursor after the eol
  call setline(1, 'abc(defgh)')
  set virtualedit=all
  normal 20|%
  call assert_equal(4, col('.'))
  set virtualedit&
  close!
endfunc

" Test for searching a pattern and stopping before a specified line
func Test_search_stopline()
  new
  call setline(1, ['', '', '', 'vim'])
  call assert_equal(0, search('vim', 'n', 3))
  call assert_equal(4, search('vim', 'n', 4))
  call setline(1, ['vim', '', '', ''])
  call cursor(4, 1)
  call assert_equal(0, search('vim', 'bn', 2))
  call assert_equal(1, search('vim', 'bn', 1))
  close!
endfunc

func Test_incsearch_highlighting_newline()
  CheckRunVimInTerminal
  CheckOption incsearch
  CheckScreendump
  new
  call test_override("char_avail", 1)

  let commands =<< trim [CODE]
    set incsearch nohls
    call setline(1, ['test', 'xxx'])
  [CODE]
  call writefile(commands, 'Xincsearch_nl', 'D')
  let buf = RunVimInTerminal('-S Xincsearch_nl', {'rows': 5, 'cols': 10})
  call term_sendkeys(buf, '/test')
  call VerifyScreenDump(buf, 'Test_incsearch_newline1', {})
  " Need to send one key at a time to force a redraw
  call term_sendkeys(buf, '\n')
  call VerifyScreenDump(buf, 'Test_incsearch_newline2', {})
  call term_sendkeys(buf, 'x')
  call VerifyScreenDump(buf, 'Test_incsearch_newline3', {})
  call term_sendkeys(buf, 'x')
  call VerifyScreenDump(buf, 'Test_incsearch_newline4', {})
  call term_sendkeys(buf, "\<CR>")
  call VerifyScreenDump(buf, 'Test_incsearch_newline5', {})
  call StopVimInTerminal(buf)

  " clean up
  call test_override("char_avail", 0)
  bw
endfunc

func Test_incsearch_substitute_dump2()
  CheckOption incsearch
  CheckScreendump

  call writefile([
	\ 'set incsearch hlsearch scrolloff=0',
	\ 'for n in range(1, 4)',
	\ '  call setline(n, "foo " . n)',
	\ 'endfor',
	\ 'call setline(5, "abc|def")',
	\ '3',
	\ ], 'Xis_subst_script2', 'D')
  let buf = RunVimInTerminal('-S Xis_subst_script2', {'rows': 9, 'cols': 70})

  call term_sendkeys(buf, ':%s/\vabc|')
  sleep 100m
  call VerifyScreenDump(buf, 'Test_incsearch_sub_01', {})
  call term_sendkeys(buf, "\<Esc>")

  " The following should not be highlighted
  call term_sendkeys(buf, ':1,5s/\v|')
  sleep 100m
  call VerifyScreenDump(buf, 'Test_incsearch_sub_02', {})


  call StopVimInTerminal(buf)
endfunc

func Test_incsearch_restore_view()
  CheckOption incsearch
  CheckScreendump

  let lines =<< trim [CODE]
    set incsearch nohlsearch
    setlocal scrolloff=0 smoothscroll
    call setline(1, [join(range(25), ' '), '', '', '', '', 'xxx'])
    call feedkeys("2\<C-E>", 't')
  [CODE]
  call writefile(lines, 'Xincsearch_restore_view', 'D')
  let buf = RunVimInTerminal('-S Xincsearch_restore_view', {'rows': 6, 'cols': 20})

  call VerifyScreenDump(buf, 'Test_incsearch_restore_view_01', {})
  call term_sendkeys(buf, '/xx')
  call VerifyScreenDump(buf, 'Test_incsearch_restore_view_02', {})
  call term_sendkeys(buf, 'x')
  call VerifyScreenDump(buf, 'Test_incsearch_restore_view_03', {})
  call term_sendkeys(buf, "\<Esc>")
  call VerifyScreenDump(buf, 'Test_incsearch_restore_view_01', {})

  call StopVimInTerminal(buf)
endfunc

func Test_pattern_is_uppercase_smartcase()
  new
  let input=['abc', 'ABC', 'Abc', 'abC']
  call setline(1, input)
  call cursor(1,1)
  " default, matches firstline
  %s/abc//g
  call assert_equal(['', 'ABC', 'Abc', 'abC'],
        \ getline(1, '$'))

  set smartcase ignorecase
  sil %d
  call setline(1, input)
  call cursor(1,1)
  " with smartcase and incsearch set, matches everything
  %s/abc//g
  call assert_equal(['', '', '', ''], getline(1, '$'))

  sil %d
  call setline(1, input)
  call cursor(1,1)
  " with smartcase and incsearch set and found an uppercase letter,
  " match only that.
  %s/abC//g
  call assert_equal(['abc', 'ABC', 'Abc', ''],
        \ getline(1, '$'))

  sil %d
  call setline(1, input)
  call cursor(1,1)
  exe "norm! vG$\<esc>"
  " \%V should not be detected as uppercase letter
  %s/\%Vabc//g
  call assert_equal(['', '', '', ''], getline(1, '$'))

  call setline(1, input)
  call cursor(1,1)
  exe "norm! vG$\<esc>"
  " \v%V should not be detected as uppercase letter
  %s/\v%Vabc//g
  call assert_equal(['', '', '', ''], getline(1, '$'))

  call setline(1, input)
  call cursor(1,1)
  exe "norm! vG$\<esc>"
  " \v%VabC should be detected as uppercase letter
  %s/\v%VabC//g
  call assert_equal(['abc', 'ABC', 'Abc', ''],
        \ getline(1, '$'))

  call setline(1, input)
  call cursor(1,1)
  " \Vabc should match everything
  %s/\Vabc//g
  call assert_equal(['', '', '', ''], getline(1, '$'))

  call setline(1, input + ['_abc'])
  " _ matches normally
  %s/\v_.*//g
  call assert_equal(['abc', 'ABC', 'Abc', 'abC', ''], getline(1, '$'))

  set smartcase& ignorecase&
  bw!
endfunc

func Test_no_last_search_pattern()
  CheckOption incsearch

  let @/ = ""
  set incsearch
  " these were causing a crash
  call feedkeys("//\<C-G>", 'xt')
  call feedkeys("//\<C-T>", 'xt')
  call feedkeys("??\<C-G>", 'xt')
  call feedkeys("??\<C-T>", 'xt')
endfunc

func Test_search_with_invalid_range()
  new
  let lines =<< trim END
    /\%.v
    5/
    c
  END
  call writefile(lines, 'Xrangesearch', 'D')
  source Xrangesearch

  bwipe!
endfunc


" vim: shiftwidth=2 sts=2 expandtab
