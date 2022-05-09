" Tests for mappings and abbreviations

source shared.vim
source check.vim
source screendump.vim

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
  call feedkeys("GoTEST2: CTRL-C |\<*C-C>A|\<Esc>", "xt")
  call assert_equal('TEST2: CTRL-C |<ctrl-c>A|', getline('$'))
  unmap! <c-c>
  set nomodified
endfunc

func Test_map_ctrl_c_visual()
  " mapping of ctrl-c in Visual mode
  vnoremap <c-c> :<C-u>$put ='vmap works'
  call feedkeys("GV\<*C-C>\<CR>", "xt")
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
  call feedkeys("Go-\<*M-\">-\<Esc>", "xt")
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
    let g:timer = timer_start(1, {-> feedkeys("3\<Esc>", 't')})
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

func Test_error_in_map_expr()
  if !has('terminal') || (has('win32') && has('gui_running'))
    throw 'Skipped: cannot run Vim in a terminal window'
  endif

  let lines =<< trim [CODE]
  func Func()
    " fail to create list
    let x = [
  endfunc
  nmap <expr> ! Func()
  set updatetime=50
  [CODE]
  call writefile(lines, 'Xtest.vim')

  let buf = term_start(GetVimCommandCleanTerm() .. ' -S Xtest.vim', {'term_rows': 8})
  let job = term_getjob(buf)
  call WaitForAssert({-> assert_notequal('', term_getline(buf, 8))})

  " GC must not run during map-expr processing, which can make Vim crash.
  call term_sendkeys(buf, '!')
  call term_wait(buf, 100)
  call term_sendkeys(buf, "\<CR>")
  call term_wait(buf, 100)
  call assert_equal('run', job_status(job))

  call term_sendkeys(buf, ":qall!\<CR>")
  call WaitFor({-> job_status(job) ==# 'dead'})
  if has('unix')
    call assert_equal('', job_info(job).termsig)
  endif

  call delete('Xtest.vim')
  exe buf .. 'bwipe!'
endfunc

func Test_list_mappings()
  " Remove default mappings
  imapclear

  " reset 'isident' to check it isn't used
  set isident=
  inoremap <C-m> CtrlM
  inoremap <A-S> AltS
  inoremap <S-/> ShiftSlash
  set isident&
  call assert_equal([
	\ 'i  <S-/>       * ShiftSlash',
	\ 'i  <M-S>       * AltS',
	\ 'i  <C-M>       * CtrlM',
	\], execute('imap')->trim()->split("\n"))
  iunmap <C-M>
  iunmap <A-S>
  call assert_equal(['i  <S-/>       * ShiftSlash'], execute('imap')->trim()->split("\n"))
  iunmap <S-/>
  call assert_equal(['No mapping found'], execute('imap')->trim()->split("\n"))

  " List global, buffer local and script local mappings
  nmap ,f /^\k\+ (<CR>
  nmap <buffer> ,f /^\k\+ (<CR>
  nmap <script> ,fs /^\k\+ (<CR>
  call assert_equal(['n  ,f           @/^\k\+ (<CR>',
        \ 'n  ,fs         & /^\k\+ (<CR>',
        \ 'n  ,f            /^\k\+ (<CR>'],
        \ execute('nmap ,f')->trim()->split("\n"))

  " List <Nop> mapping
  nmap ,n <Nop>
  call assert_equal(['n  ,n            <Nop>'],
        \ execute('nmap ,n')->trim()->split("\n"))

  " verbose map
  call assert_match("\tLast set from .*/test_mapping.vim line \\d\\+$",
        \ execute('verbose map ,n')->trim()->split("\n")[1])

  " character with K_SPECIAL byte in rhs
  nmap foo …
  call assert_equal(['n  foo           …'],
        \ execute('nmap foo')->trim()->split("\n"))

  " modified character with K_SPECIAL byte in rhs
  nmap foo <M-…>
  call assert_equal(['n  foo           <M-…>'],
        \ execute('nmap foo')->trim()->split("\n"))

  " character with K_SPECIAL byte in lhs
  nmap … foo
  call assert_equal(['n  …             foo'],
        \ execute('nmap …')->trim()->split("\n"))

  " modified character with K_SPECIAL byte in lhs
  nmap <M-…> foo
  call assert_equal(['n  <M-…>         foo'],
        \ execute('nmap <M-…>')->trim()->split("\n"))

  " illegal bytes
  let str = ":\x7f:\x80:\x90:\xd0:"
  exe 'nmap foo ' .. str
  call assert_equal(['n  foo           ' .. strtrans(str)],
        \ execute('nmap foo')->trim()->split("\n"))
  unlet str

  " map to CTRL-V
  exe "nmap ,k \<C-V>"
  call assert_equal(['n  ,k            <Nop>'],
        \ execute('nmap ,k')->trim()->split("\n"))

  " map with space at the beginning
  exe "nmap \<C-V> w <Nop>"
  call assert_equal(['n  <Space>w      <Nop>'],
        \ execute("nmap \<C-V> w")->trim()->split("\n"))

  nmapclear
endfunc

func Test_expr_map_gets_cursor()
  new
  call setline(1, ['one', 'some w!rd'])
  func StoreColumn()
    let g:exprLine = line('.')
    let g:exprCol = col('.')
    return 'x'
  endfunc
  nnoremap <expr> x StoreColumn()
  2
  nmap ! f!<Ignore>x
  call feedkeys("!", 'xt')
  call assert_equal('some wrd', getline(2))
  call assert_equal(2, g:exprLine)
  call assert_equal(7, g:exprCol)

  bwipe!
  unlet g:exprLine
  unlet g:exprCol
  delfunc StoreColumn
  nunmap x
  nunmap !
endfunc

func Test_expr_map_restore_cursor()
  CheckScreendump

  let lines =<< trim END
      call setline(1, ['one', 'two', 'three'])
      2
      set ls=2
      hi! link StatusLine ErrorMsg
      noremap <expr> <C-B> Func()
      func Func()
	  let g:on = !get(g:, 'on', 0)
	  redraws
	  return ''
      endfunc
      func Status()
	  return get(g:, 'on', 0) ? '[on]' : ''
      endfunc
      set stl=%{Status()}
  END
  call writefile(lines, 'XtestExprMap')
  let buf = RunVimInTerminal('-S XtestExprMap', #{rows: 10})
  call term_sendkeys(buf, "\<C-B>")
  call VerifyScreenDump(buf, 'Test_map_expr_1', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('XtestExprMap')
endfunc

func Test_map_listing()
  CheckScreendump

  let lines =<< trim END
      nmap a b
  END
  call writefile(lines, 'XtestMapList')
  let buf = RunVimInTerminal('-S XtestMapList', #{rows: 6})
  call term_sendkeys(buf, ":                      nmap a\<CR>")
  call VerifyScreenDump(buf, 'Test_map_list_1', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('XtestMapList')
endfunc

func Test_expr_map_error()
  CheckScreendump

  let lines =<< trim END
      func Func()
        throw 'test'
        return ''
      endfunc

      nnoremap <expr> <F2> Func()
      cnoremap <expr> <F2> Func()

      call test_override('ui_delay', 10)
  END
  call writefile(lines, 'XtestExprMap')
  let buf = RunVimInTerminal('-S XtestExprMap', #{rows: 10})
  call term_sendkeys(buf, "\<F2>")
  call TermWait(buf)
  call term_sendkeys(buf, "\<CR>")
  call VerifyScreenDump(buf, 'Test_map_expr_2', {})

  call term_sendkeys(buf, ":abc\<F2>")
  call VerifyScreenDump(buf, 'Test_map_expr_3', {})
  call term_sendkeys(buf, "\<Esc>0")
  call VerifyScreenDump(buf, 'Test_map_expr_4', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('XtestExprMap')
endfunc

" Test for mapping errors
func Test_map_error()
  call assert_fails('unmap', 'E474:')
  call assert_fails("exe 'map ' .. repeat('a', 51) .. ' :ls'", 'E474:')
  call assert_fails('unmap abc', 'E31:')
  call assert_fails('unabbr abc', 'E24:')
  call assert_equal('', maparg(''))
  call assert_fails('echo maparg("abc", [])', 'E730:')

  " unique map
  map ,w /[#&!]<CR>
  call assert_fails("map <unique> ,w /[#&!]<CR>", 'E227:')
  " unique buffer-local map
  call assert_fails("map <buffer> <unique> ,w /[.,;]<CR>", 'E225:')
  unmap ,w

  " unique abbreviation
  abbr SP special
  call assert_fails("abbr <unique> SP special", 'E226:')
  " unique buffer-local map
  call assert_fails("abbr <buffer> <unique> SP special", 'E224:')
  unabbr SP

  call assert_fails('mapclear abc', 'E474:')
  call assert_fails('abclear abc', 'E474:')
  call assert_fails('abbr $xyz abc', 'E474:')

  " space character in an abbreviation
  call assert_fails('abbr ab<space> ABC', 'E474:')

  " invalid <expr> map
  map <expr> ,f abc
  call assert_fails('normal ,f', 'E121:')
  unmap <expr> ,f
endfunc

" Test for <special> key mapping
func Test_map_special()
  throw 'skipped: Nvim does not support cpoptions flag "<"'
  new
  let old_cpo = &cpo
  set cpo+=<
  imap <F12> Blue
  call feedkeys("i\<F12>", "x")
  call assert_equal("<F12>", getline(1))
  call feedkeys("ddi<F12>", "x")
  call assert_equal("Blue", getline(1))
  iunmap <F12>
  imap <special> <F12> Green
  call feedkeys("ddi\<F12>", "x")
  call assert_equal("Green", getline(1))
  call feedkeys("ddi<F12>", "x")
  call assert_equal("<F12>", getline(1))
  iunmap <special> <F12>
  let &cpo = old_cpo
  %bwipe!
endfunc

" Test for hasmapto()
func Test_hasmapto()
  call assert_equal(0, hasmapto('/^\k\+ ('))
  map ,f /^\k\+ (<CR>
  call assert_equal(1, hasmapto('/^\k\+ ('))
  unmap ,f

  " Insert mode mapping
  call assert_equal(0, hasmapto('/^\k\+ (', 'i'))
  imap ,f /^\k\+ (<CR>
  call assert_equal(1, hasmapto('/^\k\+ (', 'i'))
  iunmap ,f

  " Normal mode mapping
  call assert_equal(0, hasmapto('/^\k\+ (', 'n'))
  nmap ,f /^\k\+ (<CR>
  call assert_equal(1, hasmapto('/^\k\+ ('))
  call assert_equal(1, hasmapto('/^\k\+ (', 'n'))
  nunmap ,f

  " Visual and Select mode mapping
  call assert_equal(0, hasmapto('/^\k\+ (', 'v'))
  call assert_equal(0, hasmapto('/^\k\+ (', 'x'))
  call assert_equal(0, hasmapto('/^\k\+ (', 's'))
  vmap ,f /^\k\+ (<CR>
  call assert_equal(1, hasmapto('/^\k\+ (', 'v'))
  call assert_equal(1, hasmapto('/^\k\+ (', 'x'))
  call assert_equal(1, hasmapto('/^\k\+ (', 's'))
  vunmap ,f

  " Visual mode mapping
  call assert_equal(0, hasmapto('/^\k\+ (', 'x'))
  xmap ,f /^\k\+ (<CR>
  call assert_equal(1, hasmapto('/^\k\+ (', 'v'))
  call assert_equal(1, hasmapto('/^\k\+ (', 'x'))
  call assert_equal(0, hasmapto('/^\k\+ (', 's'))
  xunmap ,f

  " Select mode mapping
  call assert_equal(0, hasmapto('/^\k\+ (', 's'))
  smap ,f /^\k\+ (<CR>
  call assert_equal(1, hasmapto('/^\k\+ (', 'v'))
  call assert_equal(0, hasmapto('/^\k\+ (', 'x'))
  call assert_equal(1, hasmapto('/^\k\+ (', 's'))
  sunmap ,f

  " Operator-pending mode mapping
  call assert_equal(0, hasmapto('/^\k\+ (', 'o'))
  omap ,f /^\k\+ (<CR>
  call assert_equal(1, hasmapto('/^\k\+ (', 'o'))
  ounmap ,f

  " Language mapping
  call assert_equal(0, hasmapto('/^\k\+ (', 'l'))
  lmap ,f /^\k\+ (<CR>
  call assert_equal(1, hasmapto('/^\k\+ (', 'l'))
  lunmap ,f

  " Cmdline mode mapping
  call assert_equal(0, hasmapto('/^\k\+ (', 'c'))
  cmap ,f /^\k\+ (<CR>
  call assert_equal(1, hasmapto('/^\k\+ (', 'c'))
  cunmap ,f

  call assert_equal(0, hasmapto('/^\k\+ (', 'n', 1))
endfunc

" Test for command-line completion of maps
func Test_mapcomplete()
  call assert_equal(['<buffer>', '<expr>', '<nowait>', '<script>',
	      \ '<silent>', '<special>', '<unique>'],
	      \ getcompletion('', 'mapping'))
  call assert_equal([], getcompletion(',d', 'mapping'))

  call feedkeys(":unmap <buf\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"unmap <buffer>', @:)

  call feedkeys(":unabbr <buf\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"unabbr <buffer>', @:)

  call feedkeys(":abbr! \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"abbr! \x01", @:)

  " Multiple matches for a map
  nmap ,f /H<CR>
  omap ,f /H<CR>
  call feedkeys(":map ,\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"map ,f', @:)
  mapclear
endfunc

" Test for <expr> in abbreviation
func Test_expr_abbr()
  new
  iabbr <expr> teh "the"
  call feedkeys("iteh ", "tx")
  call assert_equal('the ', getline(1))
  iabclear
  call setline(1, '')

  " invalid <expr> abbreviation
  abbr <expr> hte GetAbbr()
  call assert_fails('normal ihte ', 'E117:')
  call assert_equal(' ', getline(1))
  unabbr <expr> hte

  close!
endfunc

" Test for storing mappings in different modes in a vimrc file
func Test_mkvimrc_mapmodes()
  map a1 /a1
  nmap a2 /a2
  vmap a3 /a3
  smap a4 /a4
  xmap a5 /a5
  omap a6 /a6
  map! a7 /a7
  imap a8 /a8
  lmap a9 /a9
  cmap a10 /a10
  tmap a11 /a11
  " Normal + Visual map
  map a12 /a12
  sunmap a12
  ounmap a12
  " Normal + Selectmode map
  map a13 /a13
  xunmap a13
  ounmap a13
  " Normal + OpPending map
  map a14 /a14
  vunmap a14
  " Visual + Selectmode map
  map a15 /a15
  nunmap a15
  ounmap a15
  " Visual + OpPending map
  map a16 /a16
  nunmap a16
  sunmap a16
  " Selectmode + OpPending map
  map a17 /a17
  nunmap a17
  xunmap a17
  " Normal + Visual + Selectmode map
  map a18 /a18
  ounmap a18
  " Normal + Visual + OpPending map
  map a19 /a19
  sunmap a19
  " Normal + Selectmode + OpPending map
  map a20 /a20
  xunmap a20
  " Visual + Selectmode + OpPending map
  map a21 /a21
  nunmap a21
  " Mapping to Nop
  map a22 <Nop>
  " Script local mapping
  map <script> a23 /a23

  " Newline in {lhs} and {rhs} of a map
  exe "map a24\<C-V>\<C-J> ia24\<C-V>\<C-J><Esc>"

  " Abbreviation
  abbr a25 A25
  cabbr a26 A26
  iabbr a27 A27

  mkvimrc! Xvimrc
  let l = readfile('Xvimrc')
  call assert_equal(['map a1 /a1'], filter(copy(l), 'v:val =~ " a1 "'))
  call assert_equal(['nmap a2 /a2'], filter(copy(l), 'v:val =~ " a2 "'))
  call assert_equal(['vmap a3 /a3'], filter(copy(l), 'v:val =~ " a3 "'))
  call assert_equal(['smap a4 /a4'], filter(copy(l), 'v:val =~ " a4 "'))
  call assert_equal(['xmap a5 /a5'], filter(copy(l), 'v:val =~ " a5 "'))
  call assert_equal(['omap a6 /a6'], filter(copy(l), 'v:val =~ " a6 "'))
  call assert_equal(['map! a7 /a7'], filter(copy(l), 'v:val =~ " a7 "'))
  call assert_equal(['imap a8 /a8'], filter(copy(l), 'v:val =~ " a8 "'))
  call assert_equal(['lmap a9 /a9'], filter(copy(l), 'v:val =~ " a9 "'))
  call assert_equal(['cmap a10 /a10'], filter(copy(l), 'v:val =~ " a10 "'))
  call assert_equal(['tmap a11 /a11'], filter(copy(l), 'v:val =~ " a11 "'))
  call assert_equal(['nmap a12 /a12', 'xmap a12 /a12'],
        \ filter(copy(l), 'v:val =~ " a12 "'))
  call assert_equal(['nmap a13 /a13', 'smap a13 /a13'],
        \ filter(copy(l), 'v:val =~ " a13 "'))
  call assert_equal(['nmap a14 /a14', 'omap a14 /a14'],
        \ filter(copy(l), 'v:val =~ " a14 "'))
  call assert_equal(['vmap a15 /a15'], filter(copy(l), 'v:val =~ " a15 "'))
  call assert_equal(['xmap a16 /a16', 'omap a16 /a16'],
        \ filter(copy(l), 'v:val =~ " a16 "'))
  call assert_equal(['smap a17 /a17', 'omap a17 /a17'],
        \ filter(copy(l), 'v:val =~ " a17 "'))
  call assert_equal(['nmap a18 /a18', 'vmap a18 /a18'],
        \ filter(copy(l), 'v:val =~ " a18 "'))
  call assert_equal(['nmap a19 /a19', 'xmap a19 /a19', 'omap a19 /a19'],
        \ filter(copy(l), 'v:val =~ " a19 "'))
  call assert_equal(['nmap a20 /a20', 'smap a20 /a20', 'omap a20 /a20'],
        \ filter(copy(l), 'v:val =~ " a20 "'))
  call assert_equal(['vmap a21 /a21', 'omap a21 /a21'],
        \ filter(copy(l), 'v:val =~ " a21 "'))
  call assert_equal(['map a22 <Nop>'], filter(copy(l), 'v:val =~ " a22 "'))
  call assert_equal([], filter(copy(l), 'v:val =~ " a23 "'))
  call assert_equal(["map a24<NL> ia24<NL>\x16\e"],
        \ filter(copy(l), 'v:val =~ " a24"'))

  call assert_equal(['abbr a25 A25'], filter(copy(l), 'v:val =~ " a25 "'))
  call assert_equal(['cabbr a26 A26'], filter(copy(l), 'v:val =~ " a26 "'))
  call assert_equal(['iabbr a27 A27'], filter(copy(l), 'v:val =~ " a27 "'))
  call delete('Xvimrc')

  mapclear
  nmapclear
  vmapclear
  xmapclear
  smapclear
  omapclear
  imapclear
  lmapclear
  cmapclear
  tmapclear
endfunc

" Test for recursive mapping ('maxmapdepth')
func Test_map_recursive()
  map x y
  map y x
  call assert_fails('normal x', 'E223:')
  unmap x
  unmap y
endfunc

" Test for removing an abbreviation using {rhs} and with space after {lhs}
func Test_abbr_remove()
  abbr foo bar
  let d = maparg('foo', 'i', 1, 1)
  call assert_equal(['foo', 'bar', '!'], [d.lhs, d.rhs, d.mode])
  unabbr bar
  call assert_equal({}, maparg('foo', 'i', 1, 1))

  abbr foo bar
  unabbr foo<space><tab>
  call assert_equal({}, maparg('foo', 'i', 1, 1))
endfunc

func Test_map_cmdkey_redo()
  func SelectDash()
    call search('^---\n\zs', 'bcW')
    norm! V
    call search('\n\ze---$', 'W')
  endfunc

  let text =<< trim END
      ---
      aaa
      ---
      bbb
      bbb
      ---
      ccc
      ccc
      ccc
      ---
  END
  new Xcmdtext
  call setline(1, text)

  onoremap <silent> i- <Cmd>call SelectDash()<CR>
  call feedkeys('2Gdi-', 'xt')
  call assert_equal(['---', '---'], getline(1, 2))
  call feedkeys('j.', 'xt')
  call assert_equal(['---', '---', '---'], getline(1, 3))
  call feedkeys('j.', 'xt')
  call assert_equal(['---', '---', '---', '---'], getline(1, 4))

  bwipe!
  call delete('Xcmdtext')
  delfunc SelectDash
  ounmap i-
endfunc

func Test_abbreviate_multi_byte()
  new
  iabbrev foo bar
  call feedkeys("ifoo…\<Esc>", 'xt')
  call assert_equal("bar…", getline(1))
  iunabbrev foo
  bwipe!
endfunc

" Test for <Plug> always being mapped, even when used with "noremap".
func Test_plug_remap()
  let g:foo = 0
  nnoremap <Plug>(Increase_x) <Cmd>let g:foo += 1<CR>
  nmap <F2> <Plug>(Increase_x)
  nnoremap <F3> <Plug>(Increase_x)
  call feedkeys("\<F2>", 'xt')
  call assert_equal(1, g:foo)
  call feedkeys("\<F3>", 'xt')
  call assert_equal(2, g:foo)
  nnoremap x <Nop>
  nmap <F4> x<Plug>(Increase_x)x
  nnoremap <F5> x<Plug>(Increase_x)x
  call setline(1, 'Some text')
  normal! gg$
  call feedkeys("\<F4>", 'xt')
  call assert_equal(3, g:foo)
  call assert_equal('Some text', getline(1))
  call feedkeys("\<F5>", 'xt')
  call assert_equal(4, g:foo)
  call assert_equal('Some te', getline(1))
  nunmap <Plug>(Increase_x)
  nunmap <F2>
  nunmap <F3>
  nunmap <F4>
  nunmap <F5>
  unlet g:foo
  %bw!
endfunc

func Test_mouse_drag_mapped_start_select()
  CheckFunction test_setmouse
  set mouse=a
  set selectmode=key,mouse
  func ClickExpr()
    call test_setmouse(1, 1)
    return "\<LeftMouse>"
  endfunc
  func DragExpr()
    call test_setmouse(1, 2)
    return "\<LeftDrag>"
  endfunc
  nnoremap <expr> <F2> ClickExpr()
  nmap <expr> <F3> DragExpr()

  nnoremap <LeftDrag> <LeftDrag><Cmd><CR>
  exe "normal \<F2>\<F3>"
  call assert_equal('s', mode())
  exe "normal! \<C-\>\<C-N>"

  nunmap <LeftDrag>
  nunmap <F2>
  nunmap <F3>
  delfunc ClickExpr
  delfunc DragExpr
  set selectmode&
  set mouse&
endfunc

" Test for mapping <LeftDrag> in Insert mode
func Test_mouse_drag_insert_map()
  CheckFunction test_setmouse
  set mouse=a
  func ClickExpr()
    call test_setmouse(1, 1)
    return "\<LeftMouse>"
  endfunc
  func DragExpr()
    call test_setmouse(1, 2)
    return "\<LeftDrag>"
  endfunc
  inoremap <expr> <F2> ClickExpr()
  imap <expr> <F3> DragExpr()

  inoremap <LeftDrag> <LeftDrag><Cmd>let g:dragged = 1<CR>
  exe "normal i\<F2>\<F3>"
  call assert_equal(1, g:dragged)
  call assert_equal('v', mode())
  exe "normal! \<C-\>\<C-N>"
  unlet g:dragged

  inoremap <LeftDrag> <LeftDrag><C-\><C-N>
  exe "normal i\<F2>\<F3>"
  call assert_equal('n', mode())

  iunmap <LeftDrag>
  iunmap <F2>
  iunmap <F3>
  delfunc ClickExpr
  delfunc DragExpr
  set mouse&
endfunc

func Test_unmap_simplifiable()
  map <C-I> foo
  map <Tab> bar
  call assert_equal('foo', maparg('<C-I>'))
  call assert_equal('bar', maparg('<Tab>'))
  unmap <C-I>
  call assert_equal('', maparg('<C-I>'))
  call assert_equal('bar', maparg('<Tab>'))
  unmap <Tab>

  map <C-I> foo
  unmap <Tab>
  " This should not error
  unmap <C-I>
endfunc

func Test_expr_map_escape_special()
  nnoremap … <Cmd>let g:got_ellipsis += 1<CR>
  func Func()
    return '…'
  endfunc
  nmap <expr> <F2> Func()
  let g:got_ellipsis = 0
  call feedkeys("\<F2>", 'xt')
  call assert_equal(1, g:got_ellipsis)
  delfunc Func
  nunmap <F2>
  unlet g:got_ellipsis
  nunmap …
endfunc

" vim: shiftwidth=2 sts=2 expandtab
