" Test for the search command

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

func Test_search_cmdline3()
  throw 'skipped: Nvim does not support test_override()'
  if !exists('+incsearch')
    return
  endif
  " need to disable char_avail,
  " so that expansion of commandline works
  call test_override("char_avail", 1)
  new
  call setline(1, ['  1', '  2 the~e', '  3 the theother'])
  set incsearch
  1
  " first match
  call feedkeys("/the\<c-l>\<cr>", 'tx')
  call assert_equal('  2 the~e', getline('.'))
  " clean up
  set noincsearch
  call test_override("char_avail", 0)
  bw!
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
  call setline(1, ['  1 the first', '  2 the second', '  3 the third'])
  set incsearch
  1
  call feedkeys("/the\<c-g>\<c-g>\<cr>", 'tx')
  call assert_equal('  3 the third', getline('.'))
  $
  call feedkeys("?the\<c-t>\<c-t>\<c-t>\<cr>", 'tx')
  call assert_equal('  2 the second', getline('.'))
  " clean up
  set noincsearch
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
  if !has('multi_byte')
    return
  endif
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
    return
  endif
  call writefile([
	\ 'set incsearch hlsearch scrolloff=0',
	\ 'for n in range(1, 10)',
	\ '  call setline(n, "foo " . n)',
	\ 'endfor',
	\ '3',
	\ ], 'Xis_subst_script')
  let buf = RunVimInTerminal('-S Xis_subst_script', {'rows': 9, 'cols': 70})
  " Give Vim a chance to redraw to get rid of the spaces in line 2 caused by
  " the 'ambiwidth' check.
  sleep 100m

  " Need to send one key at a time to force a redraw.
  call term_sendkeys(buf, ':.,.+2s/')
  sleep 100m
  call term_sendkeys(buf, 'f')
  sleep 100m
  call term_sendkeys(buf, 'o')
  sleep 100m
  call term_sendkeys(buf, 'o')
  call VerifyScreenDump(buf, 'Test_incsearch_substitute_01', {})

  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
  call delete('Xis_subst_script')
endfunc

func Test_incsearch_with_change()
  if !has('timers') || !exists('+incsearch') || !CanRunVimInTerminal()
    return
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
