" Test for the search command

source shared.vim
source screendump.vim

func Test_search_cmdline()
  " See test/functional/legacy/search_spec.lua
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
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

func Test_search_cmdline2()
  " See test/functional/legacy/search_spec.lua
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
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
  " Therefore, disableing this test
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
  call setline(1, ['other code here', '', '[', '" cursor here', ']'])
  4
  let a = searchpair('\[','',']','bW')
  call assert_equal(3, a)
  set nomagic
  4
  let a = searchpair('\[','',']','bW')
  call assert_equal(3, a)
  set magic
  q!
endfunc

func Test_searchpair_errors()
  call assert_fails("call searchpair([0], 'middle', 'end', 'bW', 'skip', 99, 100)", 'E730: using List as a String')
  call assert_fails("call searchpair('start', {-> 0}, 'end', 'bW', 'skip', 99, 100)", 'E729: using Funcref as a String')
  call assert_fails("call searchpair('start', 'middle', {'one': 1}, 'bW', 'skip', 99, 100)", 'E731: using Dictionary as a String')
  call assert_fails("call searchpair('start', 'middle', 'end', 'flags', 'skip', 99, 100)", 'E475: Invalid argument: flags')
  call assert_fails("call searchpair('start', 'middle', 'end', 'bW', 0, 99, 100)", 'E475: Invalid argument: 0')
  call assert_fails("call searchpair('start', 'middle', 'end', 'bW', 'func', -99, 100)", 'E475: Invalid argument: -99')
  call assert_fails("call searchpair('start', 'middle', 'end', 'bW', 'func', 99, -100)", 'E475: Invalid argument: -100')
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
  throw 'skipped: Nvim does not support test_override()'
  " need to disable char_avail,
  " so that expansion of commandline works
  call test_override("char_avail", 1)
  new
  call setline(1, ['  1', '  2 the~e', '  3 the theother'])
  set incsearch
endfunc

func Incsearch_cleanup()
  throw 'skipped: Nvim does not support test_override()'
  set noincsearch
  call test_override("char_avail", 0)
  bw!
endfunc

func Test_search_cmdline3()
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
  call Cmdline3_prep()
  1
  " first match
  call feedkeys("/the\<c-l>\<cr>", 'tx')
  call assert_equal('  2 the~e', getline('.'))

  call Incsearch_cleanup()
endfunc

func Test_search_cmdline3s()
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
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
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
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
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
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

func Test_search_cmdline4()
  " See test/functional/legacy/search_spec.lua
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
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
  if !exists('+incsearch')
    return
  endif
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

func Test_search_cmdline7()
  throw 'skipped: Nvim does not support test_override()'
  " Test that an pressing <c-g> in an empty command line
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

" Tests for regexp with various magic settings
func Test_search_regexp()
  enew!

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

  set undolevels=100
  put ='9 foobar'
  put =''
  exe "normal! a\<C-G>u\<Esc>"
  normal G
  exe 'normal! dv?bar?' . "\<CR>"
  call assert_equal('9 foo', getline('.'))
  call assert_equal([0, 10, 5, 0], getpos('.'))
  call assert_equal(10, line('$'))
  normal u
  call assert_equal('9 foobar', getline('.'))
  call assert_equal([0, 10, 6, 0], getpos('.'))
  call assert_equal(11, line('$'))

  set undolevels&
  enew!
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

" Similar to Test_incsearch_substitute() but with a screendump halfway.
func Test_incsearch_substitute_dump()
  if !exists('+incsearch')
    return
  endif
  if !CanRunVimInTerminal()
    throw 'Skipped: cannot make screendumps'
  endif
  call writefile([
	\ 'set incsearch hlsearch scrolloff=0',
	\ 'for n in range(1, 10)',
	\ '  call setline(n, "foo " . n)',
	\ 'endfor',
	\ 'call setline(11, "bar 11")',
	\ '3',
	\ ], 'Xis_subst_script')
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
  call delete('Xis_subst_script')
endfunc

" Similar to Test_incsearch_substitute_dump() for :sort
func Test_incsearch_sort_dump()
  if !exists('+incsearch')
    return
  endif
  if !CanRunVimInTerminal()
    throw 'Skipped: cannot make screendumps'
  endif
  call writefile([
	\ 'set incsearch hlsearch scrolloff=0',
	\ 'call setline(1, ["another one 2", "that one 3", "the one 1"])',
	\ ], 'Xis_sort_script')
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
  call delete('Xis_sort_script')
endfunc

" Similar to Test_incsearch_substitute_dump() for :vimgrep famiry
func Test_incsearch_vimgrep_dump()
  if !exists('+incsearch')
    return
  endif
  if !CanRunVimInTerminal()
    throw 'Skipped: cannot make screendumps'
  endif
  call writefile([
	\ 'set incsearch hlsearch scrolloff=0',
	\ 'call setline(1, ["another one 2", "that one 3", "the one 1"])',
	\ ], 'Xis_vimgrep_script')
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
  call delete('Xis_vimgrep_script')
endfunc

func Test_keep_last_search_pattern()
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
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
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
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
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
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

func Test_incsearch_with_change()
  if !has('timers') || !exists('+incsearch') || !CanRunVimInTerminal()
    throw 'Skipped: cannot make screendumps and/or timers feature and/or incsearch option missing'
  endif

  call writefile([
	\ 'set incsearch hlsearch scrolloff=0',
	\ 'call setline(1, ["one", "two ------ X", "three"])',
	\ 'call timer_start(200, { _ -> setline(2, "x")})',
	\ ], 'Xis_change_script')
  let buf = RunVimInTerminal('-S Xis_change_script', {'rows': 9, 'cols': 70})
  " Give Vim a chance to redraw to get rid of the spaces in line 2 caused by
  " the 'ambiwidth' check.
  sleep 300m

  " Highlight X, it will be deleted by the timer callback.
  call term_sendkeys(buf, ':%s/X')
  call VerifyScreenDump(buf, 'Test_incsearch_change_01', {})
  call term_sendkeys(buf, "\<Esc>")

  call StopVimInTerminal(buf)
  call delete('Xis_change_script')
endfunc

func Test_incsearch_cmdline_modifier()
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
  call test_override("char_avail", 1)
  new
  call setline(1, ['foo'])
  set incsearch
  " Test that error E14 does not occur in parsing command modifier.
  call feedkeys("V:tab", 'tx')

  call Incsearch_cleanup()
endfunc

func Test_incsearch_scrolling()
  if !CanRunVimInTerminal()
    return
  endif
  call assert_equal(0, &scrolloff)
  call writefile([
	\ 'let dots = repeat(".", 120)',
	\ 'set incsearch cmdheight=2 scrolloff=0',
	\ 'call setline(1, [dots, dots, dots, "", "target", dots, dots])',
	\ 'normal gg',
	\ 'redraw',
	\ ], 'Xscript')
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
  call delete('Xscript')
endfunc

func Test_incsearch_search_dump()
  if !exists('+incsearch')
    return
  endif
  if !CanRunVimInTerminal()
    return
  endif
  call writefile([
	\ 'set incsearch hlsearch scrolloff=0',
	\ 'for n in range(1, 8)',
	\ '  call setline(n, "foo " . n)',
	\ 'endfor',
	\ '3',
	\ ], 'Xis_search_script')
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
  call delete('Xis_search_script')
endfunc

func Test_incsearch_substitute()
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
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
  throw 'skipped: Nvim does not support test_override()'
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

func Test_search_undefined_behaviour()
  if !has("terminal")
    return
  endif
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

" This was causing E874.  Also causes an invalid read?
func Test_look_behind()
  new
  call setline(1, '0\|\&\n\@<=') 
  call search(getline("."))
  bwipe!
endfunc

func Test_search_sentence()
  new
  " this used to cause a crash
  call assert_fails("/\\%')", 'E486')
  call assert_fails("/", 'E486')
  /\%'(
  /
endfunc

" Test that there is no crash when there is a last search pattern but no last
" substitute pattern.
func Test_no_last_substitute_pat()
  " Use viminfo to set the last search pattern to a string and make the last
  " substitute pattern the most recent used and make it empty (NULL).
  call writefile(['~MSle0/bar', '~MSle0~&'], 'Xviminfo')
  rviminfo! Xviminfo
  call assert_fails('normal n', 'E35:')

  call delete('Xviminfo')
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
  if !exists('+incsearch')
    return
  endif
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
  " This  was also giving an internal error
  call assert_fails('call search(" \\((\\v[[=P=]]){185}+             ")', 'E871:')
endfunc

func Test_incsearch_add_char_under_cursor()
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
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

  call search('foobar', 'c')
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

func Test_search_display_pattern()
  new
  call setline(1, ['foo', 'bar', 'foobar'])

  call cursor(1, 1)
  let @/ = 'foo'
  let pat = escape(@/, '()*?'. '\s\+')
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

func Test_search_special()
  " this was causing illegal memory access and an endless loop
  set t_PE=
  exe "norm /\x80PS"
endfunc
