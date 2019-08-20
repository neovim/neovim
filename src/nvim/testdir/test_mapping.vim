" Tests for mappings and abbreviations

source shared.vim

func Test_abbreviation()
  " abbreviation with 0x80 should work
  inoreab чкпр   vim
  call feedkeys("Goчкпр \<Esc>", "xt")
  call assert_equal('vim ', getline('$'))
  iunab чкпр
  set nomodified
endfunc

func Test_abclear()
   abbrev foo foobar
   iabbrev fooi foobari
   cabbrev fooc foobarc
   call assert_equal("\n\nc  fooc          foobarc\ni  fooi          foobari\n!  foo           foobar", execute('abbrev'))

   iabclear
   call assert_equal("\n\nc  fooc          foobarc\nc  foo           foobar", execute('abbrev'))
   abbrev foo foobar
   iabbrev fooi foobari

   cabclear
   call assert_equal("\n\ni  fooi          foobari\ni  foo           foobar", execute('abbrev'))
   abbrev foo foobar
   cabbrev fooc foobarc

   abclear
   call assert_equal("\n\nNo abbreviation found", execute('abbrev'))
endfunc

func Test_abclear_buffer()
  abbrev foo foobar
  new X1
  abbrev <buffer> foo1 foobar1
  new X2
  abbrev <buffer> foo2 foobar2

  call assert_equal("\n\n!  foo2         @foobar2\n!  foo           foobar", execute('abbrev'))

  abclear <buffer>
  call assert_equal("\n\n!  foo           foobar", execute('abbrev'))

  b X1
  call assert_equal("\n\n!  foo1         @foobar1\n!  foo           foobar", execute('abbrev'))
  abclear <buffer>
  call assert_equal("\n\n!  foo           foobar", execute('abbrev'))

  abclear
   call assert_equal("\n\nNo abbreviation found", execute('abbrev'))

  %bwipe
endfunc

func Test_map_ctrl_c_insert()
  " mapping of ctrl-c in Insert mode
  set cpo-=< cpo-=k
  inoremap <c-c> <ctrl-c>
  cnoremap <c-c> dummy
  cunmap <c-c>
  call feedkeys("GoTEST2: CTRL-C |\<C-C>A|\<Esc>", "xt")
  call assert_equal('TEST2: CTRL-C |<ctrl-c>A|', getline('$'))
  unmap! <c-c>
  set nomodified
endfunc

func Test_map_ctrl_c_visual()
  " mapping of ctrl-c in Visual mode
  vnoremap <c-c> :<C-u>$put ='vmap works'
  call feedkeys("GV\<C-C>\<CR>", "xt")
  call assert_equal('vmap works', getline('$'))
  vunmap <c-c>
  set nomodified
endfunc

func Test_map_langmap()
  if !has('langmap')
    return
  endif

  " check langmap applies in normal mode
  set langmap=+- nolangremap
  new
  call setline(1, ['a', 'b', 'c'])
  2
  call assert_equal('b', getline('.'))
  call feedkeys("+", "xt")
  call assert_equal('a', getline('.'))

  " check no remapping
  map x +
  2
  call feedkeys("x", "xt")
  call assert_equal('c', getline('.'))

  " check with remapping
  set langremap
  2
  call feedkeys("x", "xt")
  call assert_equal('a', getline('.'))

  unmap x
  bwipe!

  " 'langnoremap' follows 'langremap' and vise versa
  set langremap
  set langnoremap
  call assert_equal(0, &langremap)
  set langremap
  call assert_equal(0, &langnoremap)
  set nolangremap
  call assert_equal(1, &langnoremap)

  " check default values
  set langnoremap&
  call assert_equal(1, &langnoremap)
  call assert_equal(0, &langremap)
  set langremap&
  call assert_equal(1, &langnoremap)
  call assert_equal(0, &langremap)

  " langmap should not apply in insert mode, 'langremap' doesn't matter
  set langmap=+{ nolangremap
  call feedkeys("Go+\<Esc>", "xt")
  call assert_equal('+', getline('$'))
  set langmap=+{ langremap
  call feedkeys("Go+\<Esc>", "xt")
  call assert_equal('+', getline('$'))

  " langmap used for register name in insert mode.
  call setreg('a', 'aaaa')
  call setreg('b', 'bbbb')
  call setreg('c', 'cccc')
  set langmap=ab langremap
  call feedkeys("Go\<C-R>a\<Esc>", "xt")
  call assert_equal('bbbb', getline('$'))
  call feedkeys("Go\<C-R>\<C-R>a\<Esc>", "xt")
  call assert_equal('bbbb', getline('$'))
  " mapping does not apply
  imap c a
  call feedkeys("Go\<C-R>c\<Esc>", "xt")
  call assert_equal('cccc', getline('$'))
  imap a c
  call feedkeys("Go\<C-R>a\<Esc>", "xt")
  call assert_equal('bbbb', getline('$'))

  " langmap should not apply in Command-line mode
  set langmap=+{ nolangremap
  call feedkeys(":call append(line('$'), '+')\<CR>", "xt")
  call assert_equal('+', getline('$'))

  iunmap a
  iunmap c
  set nomodified
endfunc

func Test_map_feedkeys()
  " issue #212 (feedkeys insert mapping at current position)
  nnoremap . :call feedkeys(".", "in")<cr>
  call setline('$', ['a b c d', 'a b c d'])
  $-1
  call feedkeys("0qqdw.ifoo\<Esc>qj0@q\<Esc>", "xt")
  call assert_equal(['fooc d', 'fooc d'], getline(line('$') - 1, line('$')))
  nunmap .
  set nomodified
endfunc

func Test_map_cursor()
  " <c-g>U<cursor> works only within a single line
  imapclear
  imap ( ()<c-g>U<left>
  call feedkeys("G2o\<Esc>ki\<CR>Test1: text with a (here some more text\<Esc>k.", "xt")
  call assert_equal('Test1: text with a (here some more text)', getline(line('$') - 2))
  call assert_equal('Test1: text with a (here some more text)', getline(line('$') - 1))

  " test undo
  call feedkeys("G2o\<Esc>ki\<CR>Test2: text wit a (here some more text [und undo]\<C-G>u\<Esc>k.u", "xt")
  call assert_equal('', getline(line('$') - 2))
  call assert_equal('Test2: text wit a (here some more text [und undo])', getline(line('$') - 1))
  set nomodified
  imapclear
endfunc

func Test_map_cursor_ctrl_gU()
  " <c-g>U<cursor> works only within a single line
  nnoremap c<* *Ncgn<C-r>"<C-G>U<S-Left>
  call setline(1, ['foo', 'foobar', '', 'foo'])
  call cursor(1,2)
  call feedkeys("c<*PREFIX\<esc>.", 'xt')
  call assert_equal(['PREFIXfoo', 'foobar', '', 'PREFIXfoo'], getline(1,'$'))
  " break undo manually
  set ul=1000
  exe ":norm! uu"
  call assert_equal(['foo', 'foobar', '', 'foo'], getline(1,'$'))

  " Test that it does not work if the cursor moves to the previous line
  " 2 times <S-Left> move to the previous line
  nnoremap c<* *Ncgn<C-r>"<C-G>U<S-Left><C-G>U<S-Left>
  call setline(1, ['', ' foo', 'foobar', '', 'foo'])
  call cursor(2,3)
  call feedkeys("c<*PREFIX\<esc>.", 'xt')
  call assert_equal(['PREFIXPREFIX', ' foo', 'foobar', '', 'foo'], getline(1,'$'))
  nmapclear
endfunc


" This isn't actually testing a mapping, but similar use of CTRL-G U as above.
func Test_break_undo()
  set whichwrap=<,>,[,]
  call feedkeys("G4o2k", "xt")
  exe ":norm! iTest3: text with a (parenthesis here\<C-G>U\<Right>new line here\<esc>\<up>\<up>."
  call assert_equal('new line here', getline(line('$') - 3))
  call assert_equal('Test3: text with a (parenthesis here', getline(line('$') - 2))
  call assert_equal('new line here', getline(line('$') - 1))
  set nomodified
endfunc

func Test_map_meta_quotes()
  imap <M-"> foo
  call feedkeys("Go-\<M-\">-\<Esc>", "xt")
  call assert_equal("-foo-", getline('$'))
  set nomodified
  iunmap <M-">
endfunc

func Test_map_meta_multibyte()
  imap <M-á> foo
  call assert_match('i  <M-á>\s*foo', execute('imap'))
  iunmap <M-á>
endfunc

func Test_abbr_after_line_join()
  new
  abbr foo bar
  set backspace=indent,eol,start
  exe "normal o\<BS>foo "
  call assert_equal("bar ", getline(1))
  bwipe!
  unabbr foo
  set backspace&
endfunc

func Test_map_timeout()
  if !has('timers')
    return
  endif
  nnoremap aaaa :let got_aaaa = 1<CR>
  nnoremap bb :let got_bb = 1<CR>
  nmap b aaa
  new
  func ExitInsert(timer)
    let g:line = getline(1)
    call feedkeys("\<Esc>", "t")
  endfunc
  set timeout timeoutlen=200
  let timer = timer_start(300, 'ExitInsert')
  " After the 'b' Vim waits for another character to see if it matches 'bb'.
  " When it times out it is expanded to "aaa", but there is no wait for
  " "aaaa".  Can't check that reliably though.
  call feedkeys("b", "xt!")
  call assert_equal("aa", g:line)
  call assert_false(exists('got_aaa'))
  call assert_false(exists('got_bb'))

  bwipe!
  nunmap aaaa
  nunmap bb
  nunmap b
  set timeoutlen&
  delfunc ExitInsert
  call timer_stop(timer)
endfunc

func Test_map_timeout_with_timer_interrupt()
  if !has('job') || !has('timers')
    return
  endif

  " Confirm the timer invoked in exit_cb of the job doesn't disturb mapped key
  " sequence.
  new
  let g:val = 0
  nnoremap \12 :let g:val = 1<CR>
  nnoremap \123 :let g:val = 2<CR>
  set timeout timeoutlen=200

  func ExitCb(job, status)
    let g:timer = timer_start(1, {_ -> feedkeys("3\<Esc>", 't')})
  endfunc

  call job_start([&shell, &shellcmdflag, 'echo'], {'exit_cb': 'ExitCb'})
  call feedkeys('\12', 'xt!')
  call assert_equal(2, g:val)

  bwipe!
  nunmap \12
  nunmap \123
  set timeoutlen&
  call WaitFor({-> exists('g:timer')})
  call timer_stop(g:timer)
  unlet g:timer
  unlet g:val
  delfunc ExitCb
endfunc

func Test_cabbr_visual_mode()
  cabbr s su
  call feedkeys(":s \<c-B>\"\<CR>", 'itx')
  call assert_equal('"su ', getreg(':'))
  call feedkeys(":'<,'>s \<c-B>\"\<CR>", 'itx')
  let expected = '"'. "'<,'>su "
  call assert_equal(expected, getreg(':'))
  call feedkeys(":  '<,'>s \<c-B>\"\<CR>", 'itx')
  let expected = '"  '. "'<,'>su "
  call assert_equal(expected, getreg(':'))
  call feedkeys(":'a,'bs \<c-B>\"\<CR>", 'itx')
  let expected = '"'. "'a,'bsu "
  call assert_equal(expected, getreg(':'))
  cunabbr s
endfunc

func Test_abbreviation_CR()
  new
  func Eatchar(pat)
    let c = nr2char(getchar(0))
    return (c =~ a:pat) ? '' : c
  endfunc
  iabbrev <buffer><silent> ~~7 <c-r>=repeat('~', 7)<CR><c-r>=Eatchar('\s')<cr>
  call feedkeys("GA~~7 \<esc>", 'xt')
  call assert_equal('~~~~~~~', getline('$'))
  %d
  call feedkeys("GA~~7\<cr>\<esc>", 'xt')
  call assert_equal(['~~~~~~~', ''], getline(1,'$'))
  delfunc Eatchar
  bw!
endfunc

func Test_motionforce_omap()
  func GetCommand()
    let g:m=mode(1)
    let [g:lnum1, g:col1] = searchpos('-', 'Wb')
    if g:lnum1 == 0
        return "\<Esc>"
    endif
    let [g:lnum2, g:col2] = searchpos('-', 'W')
    if g:lnum2 == 0
        return "\<Esc>"
    endif
    return ":call Select()\<CR>"
  endfunc
  func Select()
    call cursor([g:lnum1, g:col1])
    exe "normal! 1 ". (strlen(g:m) == 2 ? 'v' : g:m[2])
    call cursor([g:lnum2, g:col2])
    execute "normal! \<BS>"
  endfunc
  new
  onoremap <buffer><expr> i- GetCommand()
  " 1) default omap mapping
  %d_
  call setline(1, ['aaa - bbb', 'x', 'ddd - eee'])
  call cursor(2, 1)
  norm di-
  call assert_equal('no', g:m)
  call assert_equal(['aaa -- eee'], getline(1, '$'))
  " 2) forced characterwise operation
  %d_
  call setline(1, ['aaa - bbb', 'x', 'ddd - eee'])
  call cursor(2, 1)
  norm dvi-
  call assert_equal('nov', g:m)
  call assert_equal(['aaa -- eee'], getline(1, '$'))
  " 3) forced linewise operation
  %d_
  call setline(1, ['aaa - bbb', 'x', 'ddd - eee'])
  call cursor(2, 1)
  norm dVi-
  call assert_equal('noV', g:m)
  call assert_equal([''], getline(1, '$'))
  " 4) forced blockwise operation
  %d_
  call setline(1, ['aaa - bbb', 'x', 'ddd - eee'])
  call cursor(2, 1)
  exe "norm d\<C-V>i-"
  call assert_equal("no\<C-V>", g:m)
  call assert_equal(['aaabbb', 'x', 'dddeee'], getline(1, '$'))
  bwipe!
  delfunc Select
  delfunc GetCommand
endfunc
