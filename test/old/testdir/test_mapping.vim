" Tests for mappings and abbreviations

source shared.vim
source check.vim
source screendump.vim
source term_util.vim

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
   call assert_fails('%abclear', 'E481:')
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

  " 'langnoremap' follows 'langremap' and vice versa
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

func Test_map_super_quotes()
  if "\<D-j>"[-1:] == '>'
    throw 'Skipped: <D- modifier not supported'
  endif

  imap <D-"> foo
  call feedkeys("Go-\<*D-\">-\<Esc>", "xt")
  call assert_equal("-foo-", getline('$'))
  set nomodified
  iunmap <D-">
endfunc

func Test_map_super_multibyte()
  if "\<D-j>"[-1:] == '>'
    throw 'Skipped: <D- modifier not supported'
  endif

  imap <D-á> foo
  call assert_match('i  <D-á>\s*foo', execute('imap'))
  iunmap <D-á>
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
  CheckFeature job
  CheckFeature timers
  let g:test_is_flaky = 1

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
  " Unlike CheckRunVimInTerminal this does work in a win32 console
  CheckFeature terminal
  if has('win32') && has('gui_running')
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
  call TermWait(buf, 50)
  call term_sendkeys(buf, "\<CR>")
  call TermWait(buf, 50)
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

  " Recursive use of :normal in a map
  set maxmapdepth=100
  map gq :normal gq<CR>
  call assert_fails('normal gq', 'E192:')
  unmap gq
  set maxmapdepth&
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

  " When multiple matches have the same {lhs}, it should only appear once.
  " The simplified form should also not be included.
  nmap ,<C-F> /H<CR>
  omap ,<C-F> /H<CR>
  call feedkeys(":map ,\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"map ,<C-F>', @:)
  mapclear
endfunc

func GetAbbrText()
  unabbr hola
  return 'hello'
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
  call assert_equal('', getline(1))
  unabbr <expr> hte

  " evaluating the expression deletes the abbreviation
  abbr <expr> hola GetAbbrText()
  call assert_equal('GetAbbrText()', maparg('hola', 'i', '1'))
  call feedkeys("ahola \<Esc>", 'xt')
  call assert_equal('hello ', getline('.'))
  call assert_equal('', maparg('hola', 'i', '1'))

  bwipe!
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

" Trigger an abbreviation using a special key
func Test_abbr_trigger_special()
  new
  iabbr teh the
  call feedkeys("iteh\<F2>\<Esc>", 'xt')
  call assert_equal('the<F2>', getline(1))
  iunab teh
  close!
endfunc

" Test for '<' in 'cpoptions'
func Test_map_cpo_special_keycode()
  set cpo-=<
  imap x<Bslash>k Test
  let d = maparg('x<Bslash>k', 'i', 0, 1)
  call assert_equal(['x\k', 'Test', 'i'], [d.lhs, d.rhs, d.mode])
  call feedkeys(":imap x\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"imap x\k', @:)
  iunmap x<Bslash>k
  " Nvim: no "<" flag in 'cpoptions'.
  " set cpo+=<
  " imap x<Bslash>k Test
  " let d = maparg('x<Bslash>k', 'i', 0, 1)
  " call assert_equal(['x<Bslash>k', 'Test', 'i'], [d.lhs, d.rhs, d.mode])
  " call feedkeys(":imap x\<C-A>\<C-B>\"\<CR>", 'tx')
  " call assert_equal('"imap x<Bslash>k', @:)
  " iunmap x<Bslash>k
  set cpo-=<
  " Modifying 'cpo' above adds some default mappings, remove them
  mapclear
  mapclear!
endfunc

" Test for <Cmd> key in maps to execute commands
func Test_map_cmdkey()
  new

  " Error cases
  let x = 0
  noremap <F3> <Cmd><Cmd>let x = 1<CR>
  call assert_fails('call feedkeys("\<F3>", "xt")', 'E1136:')
  call assert_equal(0, x)

  noremap <F3> <Cmd>let x = 3
  call assert_fails('call feedkeys("\<F3>", "xt!")', 'E1255:')
  call assert_equal(0, x)

  " works in various modes and sees the correct mode()
  noremap <F3> <Cmd>let m = mode(1)<CR>
  noremap! <F3> <Cmd>let m = mode(1)<CR>

  " normal mode
  call feedkeys("\<F3>", 'xt')
  call assert_equal('n', m)

  " visual mode
  call feedkeys("v\<F3>", 'xt!')
  call assert_equal('v', m)
  " shouldn't leave the visual mode
  call assert_equal('v', mode(1))
  call feedkeys("\<Esc>", 'xt')
  call assert_equal('n', mode(1))

  " visual mapping in select mode
  call feedkeys("gh\<F3>", 'xt!')
  call assert_equal('v', m)
  " shouldn't leave select mode
  call assert_equal('s', mode(1))
  call feedkeys("\<Esc>", 'xt')
  call assert_equal('n', mode(1))

  " select mode mapping
  snoremap <F3> <Cmd>let m = mode(1)<cr>
  call feedkeys("gh\<F3>", 'xt!')
  call assert_equal('s', m)
  " shouldn't leave select mode
  call assert_equal('s', mode(1))
  call feedkeys("\<Esc>", 'xt')
  call assert_equal('n', mode(1))

  " operator-pending mode
  call feedkeys("d\<F3>", 'xt!')
  call assert_equal('no', m)
  " leaves the operator-pending mode
  call assert_equal('n', mode(1))

  " insert mode
  call feedkeys("i\<F3>abc", 'xt')
  call assert_equal('i', m)
  call assert_equal('abc', getline('.'))

  " replace mode
  call feedkeys("0R\<F3>two", 'xt')
  call assert_equal('R', m)
  call assert_equal('two', getline('.'))

  " virtual replace mode
  call setline('.', "one\ttwo")
  call feedkeys("4|gR\<F3>xxx", 'xt')
  call assert_equal('Rv', m)
  call assert_equal("onexxx\ttwo", getline('.'))

  " cmdline mode
  call feedkeys(":\<F3>\"xxx\<CR>", 'xt!')
  call assert_equal('c', m)
  call assert_equal('"xxx', @:)

  " terminal mode
  if CanRunVimInTerminal()
    tnoremap <F3> <Cmd>let m = mode(1)<CR>
    let buf = Run_shell_in_terminal({})
    call feedkeys("\<F3>", 'xt')
    call assert_equal('t', m)
    call assert_equal('t', mode(1))
    call StopShellInTerminal(buf)
    close!
    tunmap <F3>
  endif

  " invoke cmdline mode recursively
  noremap! <F2> <Cmd>norm! :foo<CR>
  %d
  call setline(1, ['some short lines', 'of test text'])
  call feedkeys(":bar\<F2>x\<C-B>\"\r", 'xt')
  call assert_equal('"barx', @:)
  unmap! <F2>

  " test for calling a <SID> function
  let lines =<< trim END
    map <F2> <Cmd>call <SID>do_it()<CR>
    func s:do_it()
      let g:x = 32
    endfunc
  END
  call writefile(lines, 'Xscript')
  source Xscript
  call feedkeys("\<F2>", 'xt')
  call assert_equal(32, g:x)
  call delete('Xscript')

  unmap <F3>
  unmap! <F3>
  %bw!
endfunc

" text object enters visual mode
func TextObj()
  if mode() !=# "v"
    normal! v
  end
  call cursor(1, 3)
  normal! o
  call cursor(2, 4)
endfunc

func s:cmdmap(lhs, rhs)
  exe 'noremap ' .. a:lhs .. ' <Cmd>' .. a:rhs .. '<CR>'
  exe 'noremap! ' .. a:lhs .. ' <Cmd>' .. a:rhs .. '<CR>'
endfunc

func s:cmdunmap(lhs)
  exe 'unmap ' .. a:lhs
  exe 'unmap! ' .. a:lhs
endfunc

" Map various <Fx> keys used by the <Cmd> key tests
func s:setupMaps()
  call s:cmdmap('<F3>', 'let m = mode(1)')
  call s:cmdmap('<F4>', 'normal! ww')
  call s:cmdmap('<F5>', 'normal! "ay')
  call s:cmdmap('<F6>', 'throw "very error"')
  call s:cmdmap('<F7>', 'call TextObj()')
  call s:cmdmap('<F8>', 'startinsert')
  call s:cmdmap('<F9>', 'stopinsert')
endfunc

" Remove the mappings setup by setupMaps()
func s:cleanupMaps()
  call s:cmdunmap('<F3>')
  call s:cmdunmap('<F4>')
  call s:cmdunmap('<F5>')
  call s:cmdunmap('<F6>')
  call s:cmdunmap('<F7>')
  call s:cmdunmap('<F8>')
  call s:cmdunmap('<F9>')
endfunc

" Test for <Cmd> mapping in normal mode
func Test_map_cmdkey_normal_mode()
  new
  call s:setupMaps()

  " check v:count and v:register works
  call s:cmdmap('<F2>', 'let s = [mode(1), v:count, v:register]')
  call feedkeys("\<F2>", 'xt')
  call assert_equal(['n', 0, '"'], s)
  call feedkeys("7\<F2>", 'xt')
  call assert_equal(['n', 7, '"'], s)
  call feedkeys("\"e\<F2>", 'xt')
  call assert_equal(['n', 0, 'e'], s)
  call feedkeys("5\"k\<F2>", 'xt')
  call assert_equal(['n', 5, 'k'], s)
  call s:cmdunmap('<F2>')

  call setline(1, ['some short lines', 'of test text'])
  call feedkeys("\<F7>y", 'xt')
  call assert_equal("me short lines\nof t", @")
  call assert_equal('v', getregtype('"'))
  call assert_equal([0, 1, 3, 0], getpos("'<"))
  call assert_equal([0, 2, 4, 0], getpos("'>"))

  " startinsert
  %d
  call feedkeys("\<F8>abc", 'xt')
  call assert_equal('abc', getline(1))

  " feedkeys are not executed immediately
  noremap ,a <Cmd>call feedkeys("aalpha") \| let g:a = getline(2)<CR>
  %d
  call setline(1, ['some short lines', 'of test text'])
  call cursor(2, 3)
  call feedkeys(",a\<F3>", 'xt')
  call assert_equal('of test text', g:a)
  call assert_equal('n', m)
  call assert_equal(['some short lines', 'of alphatest text'], getline(1, '$'))
  nunmap ,a

  " feedkeys(..., 'x') is executed immediately, but insert mode is aborted
  noremap ,b <Cmd>call feedkeys("abeta", 'x') \| let g:b = getline(2)<CR>
  call feedkeys(",b\<F3>", 'xt')
  call assert_equal('n', m)
  call assert_equal('of alphabetatest text', g:b)
  nunmap ,b

  call s:cleanupMaps()
  %bw!
endfunc

" Test for <Cmd> mapping with the :normal command
func Test_map_cmdkey_normal_cmd()
  new
  noremap ,x <Cmd>call append(1, "xx") \| call append(1, "aa")<CR>
  noremap ,f <Cmd>nosuchcommand<CR>
  noremap ,e <Cmd>throw "very error" \| call append(1, "yy")<CR>
  noremap ,m <Cmd>echoerr "The message." \| call append(1, "zz")<CR>
  noremap ,w <Cmd>for i in range(5) \| if i==1 \| echoerr "Err" \| endif \| call append(1, i) \| endfor<CR>

  call setline(1, ['some short lines', 'of test text'])
  exe "norm ,x\r"
  call assert_equal(['some short lines', 'aa', 'xx', 'of test text'], getline(1, '$'))

  call assert_fails('norm ,f', 'E492:')
  call assert_fails('norm ,e', 'very error')
  call assert_fails('norm ,m', 'The message.')
  call assert_equal(['some short lines', 'aa', 'xx', 'of test text'], getline(1, '$'))

  %d
  let caught_err = 0
  try
    exe "normal ,w"
  catch /Vim(echoerr):Err/
    let caught_err = 1
  endtry
  call assert_equal(1, caught_err)
  call assert_equal(['', '0'], getline(1, '$'))

  %d
  call assert_fails('normal ,w', 'Err')
  call assert_equal(['', '4', '3', '2' ,'1', '0'], getline(1, '$'))
  call assert_equal(1, line('.'))

  nunmap ,x
  nunmap ,f
  nunmap ,e
  nunmap ,m
  nunmap ,w
  %bw!
endfunc

" Test for <Cmd> mapping in visual mode
func Test_map_cmdkey_visual_mode()
  new
  set showmode
  call s:setupMaps()

  call setline(1, ['some short lines', 'of test text'])
  call feedkeys("v\<F4>", 'xt!')
  call assert_equal(['v', 1, 12], [mode(1), col('v'), col('.')])

  " can invoke an operator, ending the visual mode
  let @a = ''
  call feedkeys("\<F5>", 'xt!')
  call assert_equal('n', mode(1))
  call assert_equal('some short l', @a)

  " error doesn't interrupt visual mode
  call assert_fails('call feedkeys("ggvw\<F6>", "xt!")', 'E605:')
  call assert_equal(['v', 1, 6], [mode(1), col('v'), col('.')])
  call feedkeys("\<F7>", 'xt!')
  call assert_equal(['v', 1, 3, 2, 4], [mode(1), line('v'), col('v'), line('.'), col('.')])

  " startinsert gives "-- (insert) VISUAL --" mode
  call feedkeys("\<F8>", 'xt!')
  call assert_equal(['v', 1, 3, 2, 4], [mode(1), line('v'), col('v'), line('.'), col('.')])
  redraw!
  call assert_match('^-- (insert) VISUAL --', Screenline(&lines))
  call feedkeys("\<Esc>new ", 'x')
  call assert_equal(['some short lines', 'of new test text'], getline(1, '$'))

  call s:cleanupMaps()
  set showmode&
  %bw!
endfunc

" Test for <Cmd> mapping in select mode
func Test_map_cmdkey_select_mode()
  new
  set showmode
  call s:setupMaps()

  snoremap <F1> <cmd>throw "very error"<CR>
  snoremap <F2> <cmd>normal! <c-g>"by<CR>
  call setline(1, ['some short lines', 'of test text'])

  call feedkeys("gh\<F4>", "xt!")
  call assert_equal(['s', 1, 12], [mode(1), col('v'), col('.')])
  redraw!
  call assert_match('^-- SELECT --', Screenline(&lines))

  " visual mapping in select mode restarts select mode after operator
  let @a = ''
  call feedkeys("\<F5>", 'xt!')
  call assert_equal('s', mode(1))
  call assert_equal('some short l', @a)

  " select mode mapping works, and does not restart select mode
  let @b = ''
  call feedkeys("\<F2>", 'xt!')
  call assert_equal('n', mode(1))
  call assert_equal('some short l', @b)

  " error doesn't interrupt temporary visual mode
  call assert_fails('call feedkeys("\<Esc>ggvw\<C-G>\<F6>", "xt!")', 'E605:')
  redraw!
  call assert_match('^-- VISUAL --', Screenline(&lines))
  " quirk: restoration of select mode is not performed
  call assert_equal(['v', 1, 6], [mode(1), col('v'), col('.')])

  " error doesn't interrupt select mode
  call assert_fails('call feedkeys("\<Esc>ggvw\<C-G>\<F1>", "xt!")', 'E605:')
  redraw!
  call assert_match('^-- SELECT --', Screenline(&lines))
  call assert_equal(['s', 1, 6], [mode(1), col('v'), col('.')])

  call feedkeys("\<F7>", 'xt!')
  redraw!
  call assert_match('^-- SELECT --', Screenline(&lines))
  call assert_equal(['s', 1, 3, 2, 4], [mode(1), line('v'), col('v'), line('.'), col('.')])

  " startinsert gives "-- SELECT (insert) --" mode
  call feedkeys("\<F8>", 'xt!')
  redraw!
  call assert_match('^-- (insert) SELECT --', Screenline(&lines))
  call assert_equal(['s', 1, 3, 2, 4], [mode(1), line('v'), col('v'), line('.'), col('.')])
  call feedkeys("\<Esc>new ", 'x')
  call assert_equal(['some short lines', 'of new test text'], getline(1, '$'))

  sunmap <F1>
  sunmap <F2>
  call s:cleanupMaps()
  set showmode&
  %bw!
endfunc

" Test for <Cmd> mapping in operator-pending mode
func Test_map_cmdkey_op_pending_mode()
  new
  call s:setupMaps()

  call setline(1, ['some short lines', 'of test text'])
  call feedkeys("d\<F4>", 'xt')
  call assert_equal(['lines', 'of test text'], getline(1, '$'))
  call assert_equal(['some short '], getreg('"', 1, 1))
  " create a new undo point
  let &g:undolevels = &g:undolevels

  call feedkeys(".", 'xt')
  call assert_equal(['test text'], getline(1, '$'))
  call assert_equal(['lines', 'of '], getreg('"', 1, 1))
  " create a new undo point
  let &g:undolevels = &g:undolevels

  call feedkeys("uu", 'xt')
  call assert_equal(['some short lines', 'of test text'], getline(1, '$'))

  " error aborts operator-pending, operator not performed
  call assert_fails('call feedkeys("d\<F6>", "xt")', 'E605:')
  call assert_equal(['some short lines', 'of test text'], getline(1, '$'))

  call feedkeys("\"bd\<F7>", 'xt')
  call assert_equal(['soest text'], getline(1, '$'))
  call assert_equal(['me short lines', 'of t'], getreg('b', 1, 1))

  " startinsert aborts operator
  call feedkeys("d\<F8>cc", 'xt')
  call assert_equal(['soccest text'], getline(1, '$'))

  call s:cleanupMaps()
  %bw!
endfunc

" Test for <Cmd> mapping in insert mode
func Test_map_cmdkey_insert_mode()
  new
  call s:setupMaps()

  call setline(1, ['some short lines', 'of test text'])
  " works the same as <C-O>w<C-O>w
  call feedkeys("iindeed \<F4>little ", 'xt')
  call assert_equal(['indeed some short little lines', 'of test text'], getline(1, '$'))
  call assert_fails('call feedkeys("i\<F6> 2", "xt")', 'E605:')
  call assert_equal(['indeed some short little 2 lines', 'of test text'], getline(1, '$'))

  " Note when entering visual mode from InsertEnter autocmd, an async event,
  " or a <Cmd> mapping, vim ends up in undocumented "INSERT VISUAL" mode.
  call feedkeys("i\<F7>stuff ", 'xt')
  call assert_equal(['indeed some short little 2 lines', 'of stuff test text'], getline(1, '$'))
  call assert_equal(['v', 1, 3, 2, 9], [mode(1), line('v'), col('v'), line('.'), col('.')])

  call feedkeys("\<F5>", 'xt')
  call assert_equal(['deed some short little 2 lines', 'of stuff '], getreg('a', 1, 1))

  " also works as part of abbreviation
  abbr foo <Cmd>let g:y = 17<CR>bar
  exe "normal i\<space>foo "
  call assert_equal(17, g:y)
  call assert_equal('in bar deed some short little 2 lines', getline(1))
  unabbr foo

  " :startinsert does nothing
  call setline(1, 'foo bar')
  call feedkeys("ggi\<F8>vim", 'xt')
  call assert_equal('vimfoo bar', getline(1))

  " :stopinsert works
  call feedkeys("ggi\<F9>Abc", 'xt')
  call assert_equal('vimfoo barbc', getline(1))

  call s:cleanupMaps()
  %bw!
endfunc

" Test for <Cmd> mapping in insert-completion mode
func Test_map_cmdkey_insert_complete_mode()
  new
  call s:setupMaps()

  call setline(1, 'some short lines')
  call feedkeys("os\<C-X>\<C-N>\<F3>\<C-N> ", 'xt')
  call assert_equal('ic', m)
  call assert_equal(['some short lines', 'short '], getline(1, '$'))

  call s:cleanupMaps()
  %bw!
endfunc

" Test for <Cmd> mapping in cmdline mode
func Test_map_cmdkey_cmdline_mode()
  new
  call s:setupMaps()

  call setline(1, ['some short lines', 'of test text'])
  let x = 0
  call feedkeys(":let x\<F3>= 10\r", 'xt')
  call assert_equal('c', m)
  call assert_equal(10, x)

  " exception doesn't leave cmdline mode
  call assert_fails('call feedkeys(":let x\<F6>= 20\r", "xt")', 'E605:')
  call assert_equal(20, x)

  " move cursor in the buffer from cmdline mode
  call feedkeys(":let x\<F4>= 30\r", 'xt')
  call assert_equal(30, x)
  call assert_equal(12, col('.'))

  " :startinsert takes effect after leaving cmdline mode
  call feedkeys(":let x\<F8>= 40\rnew ", 'xt')
  call assert_equal(40, x)
  call assert_equal('some short new lines', getline(1))

  call s:cleanupMaps()
  %bw!
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

  new
  call setline(1, 'aaa bbb ccc ddd')

  " command can contain special keys
  onoremap ix <Cmd>let g:foo ..= '…'<Bar>normal! <C-Right><CR>
  let g:foo = ''
  call feedkeys('0dix.', 'xt')
  call assert_equal('……', g:foo)
  call assert_equal('ccc ddd', getline(1))
  unlet g:foo

  " command line ending in "0" is handled without errors
  onoremap ix <Cmd>eval 0<CR>
  call feedkeys('dix.', 'xt')

  ounmap ix
  bwipe!
endfunc

" Test for using <script> with a map to remap characters in rhs
func Test_script_local_remap()
  new
  inoremap <buffer> <SID>xyz mno
  inoremap <buffer> <script> abc st<SID>xyzre
  normal iabc
  call assert_equal('stmnore', getline(1))
  bwipe!
endfunc

func Test_abbreviate_multi_byte()
  new
  iabbrev foo bar
  call feedkeys("ifoo…\<Esc>", 'xt')
  call assert_equal("bar…", getline(1))
  iunabbrev foo
  bwipe!
endfunc

" Test for abbreviations with 'latin1' encoding
func Test_abbreviate_latin1_encoding()
  " set encoding=latin1
  call assert_fails('abbr ab#$c ABC', 'E474:')
  new
  iabbr <buffer> #i #include
  iabbr <buffer> ## #enddef
  exe "normal i#i\<C-]>"
  call assert_equal('#include', getline(1))
  exe "normal 0Di##\<C-]>"
  call assert_equal('#enddef', getline(1))
  %bw!
  set encoding=utf-8
endfunc
+
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
  set mouse=a
  set selectmode=key,mouse
  func ClickExpr()
    call Ntest_setmouse(1, 1)
    return "\<LeftMouse>"
  endfunc
  func DragExpr()
    call Ntest_setmouse(1, 2)
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

func Test_mouse_drag_statusline()
  set laststatus=2
  set mouse=a
  func ClickExpr()
    call Ntest_setmouse(&lines - 1, 1)
    return "\<LeftMouse>"
  endfunc
  func DragExpr()
    call Ntest_setmouse(&lines - 2, 1)
    return "\<LeftDrag>"
  endfunc
  nnoremap <expr> <F2> ClickExpr()
  nnoremap <expr> <F3> DragExpr()

  " this was causing a crash in win_drag_status_line()
  call feedkeys("\<F2>:tabnew\<CR>\<F3>", 'tx')

  nunmap <F2>
  nunmap <F3>
  delfunc ClickExpr
  delfunc DragExpr
  set laststatus& mouse&
endfunc

" Test for mapping <LeftDrag> in Insert mode
func Test_mouse_drag_insert_map()
  set mouse=a
  func ClickExpr()
    call Ntest_setmouse(1, 1)
    return "\<LeftMouse>"
  endfunc
  func DragExpr()
    call Ntest_setmouse(1, 2)
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

" Testing for mapping after an <Nop> mapping is triggered on timeout.
" Test for what patch 8.1.0052 fixes.
func Test_map_after_timed_out_nop()
  CheckRunVimInTerminal

  let lines =<< trim END
    set timeout timeoutlen=400
    inoremap ab TEST
    inoremap a <Nop>
  END
  call writefile(lines, 'Xtest_map_after_timed_out_nop', 'D')
  let buf = RunVimInTerminal('-S Xtest_map_after_timed_out_nop', #{rows: 6})

  " Enter Insert mode
  call term_sendkeys(buf, 'i')
  " Wait for the "a" mapping to timeout
  call term_sendkeys(buf, 'a')
  call term_wait(buf, 500)
  " Send "a" and wait for a period shorter than 'timeoutlen'
  call term_sendkeys(buf, 'a')
  call term_wait(buf, 100)
  " Send "b", should trigger the "ab" mapping
  call term_sendkeys(buf, 'b')
  call WaitForAssert({-> assert_equal("TEST", term_getline(buf, 1))})

  " clean up
  call StopVimInTerminal(buf)
endfunc

" Test 'showcmd' behavior with a partial mapping
func Test_showcmd_part_map()
  CheckRunVimInTerminal

  let lines =<< trim END
    set notimeout showcmd
    nnoremap ,a <Ignore>
    nnoremap ;a <Ignore>
    nnoremap Àa <Ignore>
    nnoremap Ëa <Ignore>
    nnoremap βa <Ignore>
    nnoremap ωa <Ignore>
    nnoremap …a <Ignore>
    nnoremap <C-W>a <Ignore>
  END
  call writefile(lines, 'Xtest_showcmd_part_map', 'D')
  let buf = RunVimInTerminal('-S Xtest_showcmd_part_map', #{rows: 6})

  call term_sendkeys(buf, ":set noruler | echo\<CR>")
  call WaitForAssert({-> assert_equal('', term_getline(buf, 6))})

  for c in [',', ';', 'À', 'Ë', 'β', 'ω', '…']
    call term_sendkeys(buf, c)
    call WaitForAssert({-> assert_equal(c, trim(term_getline(buf, 6)))})
    call term_sendkeys(buf, 'a')
    call WaitForAssert({-> assert_equal('', trim(term_getline(buf, 6)))})
  endfor

  call term_sendkeys(buf, "\<C-W>")
  call WaitForAssert({-> assert_equal('^W', trim(term_getline(buf, 6)))})
  call term_sendkeys(buf, 'a')
  call WaitForAssert({-> assert_equal('', trim(term_getline(buf, 6)))})

  " Use feedkeys() as terminal buffer cannot forward unsimplified Ctrl-W.
  " This is like typing Ctrl-W with modifyOtherKeys enabled.
  call term_sendkeys(buf, ':call feedkeys("\<*C-W>", "m")' .. " | echo\<CR>")
  call WaitForAssert({-> assert_equal('^W', trim(term_getline(buf, 6)))})
  call term_sendkeys(buf, 'a')
  call WaitForAssert({-> assert_equal('', trim(term_getline(buf, 6)))})

  call StopVimInTerminal(buf)
endfunc

func Test_using_past_typeahead()
  nnoremap :00 0
  exe "norm :set \x80\xfb0=0\<CR>"
  exe "sil norm :0\x0f\<C-U>\<CR>"

  exe "norm :set \x80\xfb0=\<CR>"
  nunmap :00
endfunc


" vim: shiftwidth=2 sts=2 expandtab
