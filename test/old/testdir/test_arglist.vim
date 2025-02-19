" Test argument list commands

source check.vim
source shared.vim
source term_util.vim

func Reset_arglist()
  args a | %argd
endfunc

func Test_argidx()
  args a b c
  last
  call assert_equal(2, argidx())
  %argdelete
  call assert_equal(0, argidx())
  " doing it again doesn't result in an error
  %argdelete
  call assert_equal(0, argidx())
  call assert_fails('2argdelete', 'E16:')

  args a b c
  call assert_equal(0, argidx())
  next
  call assert_equal(1, argidx())
  next
  call assert_equal(2, argidx())
  1argdelete
  call assert_equal(1, argidx())
  1argdelete
  call assert_equal(0, argidx())
  1argdelete
  call assert_equal(0, argidx())
endfunc

func Test_argadd()
  call Reset_arglist()

  %argdelete
  argadd a b c
  call assert_equal(0, argidx())

  %argdelete
  argadd a
  call assert_equal(0, argidx())
  argadd b c d
  call assert_equal(0, argidx())

  call Init_abc()
  argadd x
  call Assert_argc(['a', 'b', 'x', 'c'])
  call assert_equal(1, argidx())

  call Init_abc()
  0argadd x
  call Assert_argc(['x', 'a', 'b', 'c'])
  call assert_equal(2, argidx())

  call Init_abc()
  1argadd x
  call Assert_argc(['a', 'x', 'b', 'c'])
  call assert_equal(2, argidx())

  call Init_abc()
  $argadd x
  call Assert_argc(['a', 'b', 'c', 'x'])
  call assert_equal(1, argidx())

  call Init_abc()
  $argadd x
  +2argadd y
  call Assert_argc(['a', 'b', 'c', 'x', 'y'])
  call assert_equal(1, argidx())

  %argd
  edit d
  arga
  call assert_equal(1, len(argv()))
  call assert_equal('d', get(argv(), 0, ''))

  %argd
  edit some\ file
  arga
  call assert_equal(1, len(argv()))
  call assert_equal('some file', get(argv(), 0, ''))

  %argd
  new
  arga
  call assert_equal(0, len(argv()))

  if has('unix')
    call assert_fails('argadd `Xdoes_not_exist`', 'E479:')
  endif
endfunc

func Test_argadd_empty_curbuf()
  new
  let curbuf = bufnr('%')
  call writefile(['test', 'Xargadd'], 'Xargadd', 'D')
  " must not re-use the current buffer.
  argadd Xargadd
  call assert_equal(curbuf, bufnr('%'))
  call assert_equal('', bufname('%'))
  call assert_equal(1, '$'->line())
  rew
  call assert_notequal(curbuf, '%'->bufnr())
  call assert_equal('Xargadd', '%'->bufname())
  call assert_equal(2, line('$'))

  %argd
  bwipe!
endfunc

func Init_abc()
  args a b c
  next
endfunc

func Assert_argc(l)
  call assert_equal(len(a:l), argc())
  let i = 0
  while i < len(a:l) && i < argc()
    call assert_equal(a:l[i], argv(i))
    let i += 1
  endwhile
endfunc

" Test for [count]argument and [count]argdelete commands
" Ported from the test_argument_count.in test script
func Test_argument()
  call Reset_arglist()

  let save_hidden = &hidden
  set hidden

  let g:buffers = []
  augroup TEST
    au BufEnter * call add(buffers, expand('%:t'))
  augroup END

  argadd a b c d
  $argu
  $-argu
  -argu
  1argu
  +2argu

  augroup TEST
    au!
  augroup END

  call assert_equal(['d', 'c', 'b', 'a', 'c'], g:buffers)

  call assert_equal("\na   b   [c] d   ", execute(':args'))

  .argd
  call assert_equal(['a', 'b', 'd'], argv())

  -argd
  call assert_equal(['a', 'd'], argv())

  $argd
  call assert_equal(['a'], argv())

  1arga c
  1arga b
  $argu
  $arga x
  call assert_equal(['a', 'b', 'c', 'x'], argv())

  0arga y
  call assert_equal(['y', 'a', 'b', 'c', 'x'], argv())

  %argd
  call assert_equal([], argv())

  arga a b c d e f
  2,$-argd
  call assert_equal(['a', 'f'], argv())

  let &hidden = save_hidden

  let save_columns = &columns
  let &columns = 79
  try
    exe 'args ' .. join(range(1, 81))
    call assert_equal(join([
          \ '',
          \ '[1] 6   11  16  21  26  31  36  41  46  51  56  61  66  71  76  81  ',
          \ '2   7   12  17  22  27  32  37  42  47  52  57  62  67  72  77  ',
          \ '3   8   13  18  23  28  33  38  43  48  53  58  63  68  73  78  ',
          \ '4   9   14  19  24  29  34  39  44  49  54  59  64  69  74  79  ',
          \ '5   10  15  20  25  30  35  40  45  50  55  60  65  70  75  80  ',
          \ ], "\n"),
          \ execute('args'))

    " No trailing newline with one item per row.
    let long_arg = repeat('X', 81)
    exe 'args ' .. long_arg
    call assert_equal("\n[".long_arg.']', execute('args'))
  finally
    let &columns = save_columns
  endtry

  " Setting argument list should fail when the current buffer has unsaved
  " changes
  %argd
  enew!
  set modified
  call assert_fails('args x y z', 'E37:')
  args! x y z
  call assert_equal(['x', 'y', 'z'], argv())
  call assert_equal('x', expand('%:t'))

  last | enew | argu
  call assert_equal('z', expand('%:t'))

  %argdelete
  call assert_fails('argument', 'E163:')
endfunc

func Test_list_arguments()
  " Clean the argument list
  arga a | %argd

  " four args half the screen width makes two lines with two columns
  let aarg = repeat('a', &columns / 2 - 4)
  let barg = repeat('b', &columns / 2 - 4)
  let carg = repeat('c', &columns / 2 - 4)
  let darg = repeat('d', &columns / 2 - 4)
  exe 'argadd ' aarg barg carg darg

  redir => result
  args
  redir END
  call assert_match('\[' . aarg . '] \+' . carg . '\n' . barg . ' \+' . darg, trim(result))

  " if one arg is longer than half the screen make one column
  exe 'argdel' aarg
  let aarg = repeat('a', &columns / 2 + 2)
  exe '0argadd' aarg
  redir => result
  args
  redir END
  call assert_match(aarg . '\n\[' . barg . ']\n' . carg . '\n' . darg, trim(result))

  %argdelete
endfunc

func Test_args_with_quote()
  " Only on Unix can a file name include a double quote.
  if has('unix')
    args \"foobar
    call assert_equal('"foobar', argv(0))
    %argdelete
  endif
endfunc

" Test for 0argadd and 0argedit
" Ported from the test_argument_0count.in test script
func Test_zero_argadd()
  call Reset_arglist()

  arga a b c d
  2argu
  0arga added
  call assert_equal(['added', 'a', 'b', 'c', 'd'], argv())

  2argu
  arga third
  call assert_equal(['added', 'a', 'third', 'b', 'c', 'd'], argv())

  %argd
  arga a b c d
  2argu
  0arge edited
  call assert_equal(['edited', 'a', 'b', 'c', 'd'], argv())

  2argu
  arga third
  call assert_equal(['edited', 'a', 'third', 'b', 'c', 'd'], argv())

  2argu
  argedit file\ with\ spaces another file
  call assert_equal(['edited', 'a', 'file with spaces', 'another', 'file', 'third', 'b', 'c', 'd'], argv())
  call assert_equal('file with spaces', expand('%'))
endfunc

" Test for argc()
func Test_argc()
  call Reset_arglist()
  call assert_equal(0, argc())
  argadd a b
  call assert_equal(2, argc())
endfunc

" Test for arglistid()
func Test_arglistid()
  call Reset_arglist()
  arga a b
  call assert_equal(0, arglistid())
  split
  arglocal
  call assert_equal(1, arglistid())
  tabnew | tabfirst
  call assert_equal(0, arglistid(2))
  call assert_equal(1, arglistid(1, 1))
  call assert_equal(0, arglistid(2, 1))
  call assert_equal(1, arglistid(1, 2))
  tabonly | only | enew!
  argglobal
  call assert_equal(0, arglistid())
endfunc

" Tests for argv() and argc()
func Test_argv()
  call Reset_arglist()
  call assert_equal([], argv())
  call assert_equal("", argv(2))
  call assert_equal(0, argc())
  argadd a b c d
  call assert_equal(4, argc())
  call assert_equal('c', argv(2))

  let w1_id = win_getid()
  split
  let w2_id = win_getid()
  arglocal
  args e f g
  tabnew
  let w3_id = win_getid()
  split
  let w4_id = win_getid()
  argglobal
  tabfirst
  call assert_equal(4, argc(w1_id))
  call assert_equal('b', argv(1, w1_id))
  call assert_equal(['a', 'b', 'c', 'd'], argv(-1, w1_id))

  call assert_equal(3, argc(w2_id))
  call assert_equal('f', argv(1, w2_id))
  call assert_equal(['e', 'f', 'g'], argv(-1, w2_id))

  call assert_equal(3, argc(w3_id))
  call assert_equal('e', argv(0, w3_id))
  call assert_equal(['e', 'f', 'g'], argv(-1, w3_id))

  call assert_equal(4, argc(w4_id))
  call assert_equal('c', argv(2, w4_id))
  call assert_equal(['a', 'b', 'c', 'd'], argv(-1, w4_id))

  call assert_equal(4, argc(-1))
  call assert_equal(3, argc())
  call assert_equal('d', argv(3, -1))
  call assert_equal(['a', 'b', 'c', 'd'], argv(-1, -1))
  tabonly | only | enew!
  " Negative test cases
  call assert_equal(-1, argc(100))
  call assert_equal('', argv(1, 100))
  call assert_equal([], argv(-1, 100))
  call assert_equal('', argv(10, -1))
  %argdelete
endfunc

" Test for the :argedit command
func Test_argedit()
  call Reset_arglist()
  argedit a
  call assert_equal(['a'], argv())
  call assert_equal('a', expand('%:t'))
  argedit b
  call assert_equal(['a', 'b'], argv())
  call assert_equal('b', expand('%:t'))
  argedit a
  call assert_equal(['a', 'b', 'a'], argv())
  call assert_equal('a', expand('%:t'))
  " When file name case is ignored, an existing buffer with only case
  " difference is re-used.
  argedit C D
  call assert_equal('C', expand('%:t'))
  call assert_equal(['a', 'b', 'a', 'C', 'D'], argv())
  argedit c
  if has('fname_case')
    call assert_equal(['a', 'b', 'a', 'C', 'c', 'D'], argv())
  else
    call assert_equal(['a', 'b', 'a', 'C', 'C', 'D'], argv())
  endif
  0argedit x
  if has('fname_case')
    call assert_equal(['x', 'a', 'b', 'a', 'C', 'c', 'D'], argv())
  else
    call assert_equal(['x', 'a', 'b', 'a', 'C', 'C', 'D'], argv())
  endif
  enew! | set modified
  call assert_fails('argedit y', 'E37:')
  argedit! y
  if has('fname_case')
    call assert_equal(['x', 'y', 'y', 'a', 'b', 'a', 'C', 'c', 'D'], argv())
  else
    call assert_equal(['x', 'y', 'y', 'a', 'b', 'a', 'C', 'C', 'D'], argv())
  endif
  %argd
  bwipe! C
  bwipe! D

  " :argedit reuses the current buffer if it is empty
  %argd
  " make sure to use a new buffer number for x when it is loaded
  bw! x
  new
  let a = bufnr()
  argedit x
  call assert_equal(a, bufnr())
  call assert_equal('x', bufname())
  %argd
  bw! x
endfunc

" Test for the :argdedupe command
func Test_argdedupe()
  call Reset_arglist()
  argdedupe
  call assert_equal([], argv())

  args a a a aa b b a b aa
  argdedupe
  call assert_equal(['a', 'aa', 'b'], argv())

  args a b c
  argdedupe
  call assert_equal(['a', 'b', 'c'], argv())

  args a
  argdedupe
  call assert_equal(['a'], argv())

  args a A b B
  argdedupe
  if has('fname_case')
    call assert_equal(['a', 'A', 'b', 'B'], argv())
  else
    call assert_equal(['a', 'b'], argv())
  endif

  args a b a c a b
  last
  argdedupe
  next
  call assert_equal('c', expand('%:t'))

  args a ./a
  argdedupe
  call assert_equal(['a'], argv())

  %argd
endfunc

" Test for the :argdelete command
func Test_argdelete()
  call Reset_arglist()
  args aa a aaa b bb
  argdelete a*
  call assert_equal(['b', 'bb'], argv())
  call assert_equal('aa', expand('%:t'))
  last
  argdelete %
  call assert_equal(['b'], argv())
  call assert_fails('argdelete', 'E610:')
  call assert_fails('1,100argdelete', 'E16:')
  call assert_fails('argdel /\)/', 'E55:')
  call assert_fails('1argdel 1', 'E474:')

  call Reset_arglist()
  args a b c d
  next
  argdel
  call Assert_argc(['a', 'c', 'd'])
  %argdel

  call assert_fails('argdel does_not_exist', 'E480:')
endfunc

func Test_argdelete_completion()
  args foo bar

  call feedkeys(":argdelete \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"argdelete bar foo', @:)

  call feedkeys(":argdelete x \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"argdelete x bar foo', @:)

  %argd
endfunc

" Tests for the :next, :prev, :first, :last, :rewind commands
func Test_argpos()
  call Reset_arglist()
  args a b c d
  last
  call assert_equal(3, argidx())
  call assert_fails('next', 'E165:')
  prev
  call assert_equal(2, argidx())
  Next
  call assert_equal(1, argidx())
  first
  call assert_equal(0, argidx())
  call assert_fails('prev', 'E164:')
  3next
  call assert_equal(3, argidx())
  rewind
  call assert_equal(0, argidx())
  %argd
endfunc

" Test for autocommand that redefines the argument list, when doing ":all".
func Test_arglist_autocmd()
  autocmd BufReadPost Xxx2 next Xxx2 Xxx1
  call writefile(['test file Xxx1'], 'Xxx1', 'D')
  call writefile(['test file Xxx2'], 'Xxx2', 'D')
  call writefile(['test file Xxx3'], 'Xxx3', 'D')

  new
  " redefine arglist; go to Xxx1
  next! Xxx1 Xxx2 Xxx3
  " open window for all args; Reading Xxx2 will try to change the arglist and
  " that will fail
  call assert_fails("all", "E1156:")
  call assert_equal('test file Xxx1', getline(1))
  wincmd w
  call assert_equal('test file Xxx2', getline(1))
  wincmd w
  call assert_equal('test file Xxx3', getline(1))

  autocmd! BufReadPost Xxx2
  enew! | only
  argdelete Xxx*
  bwipe! Xxx1 Xxx2 Xxx3
endfunc

func Test_arg_all_expand()
  call writefile(['test file Xxx1'], 'Xx x', 'D')
  next notexist Xx\ x runtest.vim
  call assert_equal('notexist Xx\ x runtest.vim', expand('##'))
endfunc

func Test_large_arg()
  " Argument longer or equal to the number of columns used to cause
  " access to invalid memory.
  exe 'argadd ' .repeat('x', &columns)
  args
endfunc

func Test_argdo()
  next! Xa.c Xb.c Xc.c
  new
  let l = []
  argdo call add(l, expand('%'))
  call assert_equal(['Xa.c', 'Xb.c', 'Xc.c'], l)
  bwipe Xa.c Xb.c Xc.c
endfunc

" Test for quitting Vim with unedited files in the argument list
func Test_quit_with_arglist()
  CheckRunVimInTerminal
  let buf = RunVimInTerminal('', {'rows': 6})
  call term_sendkeys(buf, ":set nomore\n")
  call term_sendkeys(buf, ":args a b c\n")
  call term_sendkeys(buf, ":quit\n")
  call TermWait(buf)
  call WaitForAssert({-> assert_match('^E173:', term_getline(buf, 6))})
  call StopVimInTerminal(buf)

  " Try :confirm quit with unedited files in arglist
  let buf = RunVimInTerminal('', {'rows': 6})
  call term_sendkeys(buf, ":set nomore\n")
  call term_sendkeys(buf, ":args a b c\n")
  call term_sendkeys(buf, ":confirm quit\n")
  call TermWait(buf)
  call WaitForAssert({-> assert_match('^\[Y\]es, (N)o: *$',
        \ term_getline(buf, 6))})
  call term_sendkeys(buf, "N")
  call TermWait(buf)
  call term_sendkeys(buf, ":confirm quit\n")
  call WaitForAssert({-> assert_match('^\[Y\]es, (N)o: *$',
        \ term_getline(buf, 6))})
  call term_sendkeys(buf, "Y")
  call TermWait(buf)
  call WaitForAssert({-> assert_equal("finished", term_getstatus(buf))})
  only!
  " When this test fails, swap files are left behind which breaks subsequent
  " tests
  call delete('.a.swp')
  call delete('.b.swp')
  call delete('.c.swp')
endfunc

" Test for ":all" not working when in the cmdline window
func Test_all_not_allowed_from_cmdwin()
  au BufEnter * all
  next x
  " Use try/catch here, somehow assert_fails() doesn't work on MS-Windows
  " console.
  let caught = 'no'
  try
    exe ":norm! 7q?apat\<CR>"
  catch /E11:/
    let caught = 'yes'
  endtry
  call assert_equal('yes', caught)
  au! BufEnter
endfunc

func Test_clear_arglist_in_all()
  n 0 00 000 0000 00000 000000
  au WinNew 0 n 0
  call assert_fails("all", "E1156")
  au! *
endfunc

" Test for the :all command
func Test_all_command()
  %argdelete

  " :all command should not close windows with files in the argument list,
  " but can rearrange the windows.
  args Xargnew1 Xargnew2
  %bw!
  edit Xargold1
  split Xargnew1
  let Xargnew1_winid = win_getid()
  split Xargold2
  split Xargnew2
  let Xargnew2_winid = win_getid()
  split Xargold3
  all
  call assert_equal(2, winnr('$'))
  call assert_equal([Xargnew1_winid, Xargnew2_winid],
        \ [win_getid(1), win_getid(2)])
  call assert_equal([bufnr('Xargnew1'), bufnr('Xargnew2')],
        \ [winbufnr(1), winbufnr(2)])

  " :all command should close windows for files which are not in the
  " argument list in the current tab page.
  %bw!
  edit Xargold1
  split Xargold2
  tabedit Xargold3
  split Xargold4
  tabedit Xargold5
  tabfirst
  all
  call assert_equal(3, tabpagenr('$'))
  call assert_equal([bufnr('Xargnew1'), bufnr('Xargnew2')], tabpagebuflist(1))
  call assert_equal([bufnr('Xargold4'), bufnr('Xargold3')], tabpagebuflist(2))
  call assert_equal([bufnr('Xargold5')], tabpagebuflist(3))

  " :tab all command should close windows for files which are not in the
  " argument list across all the tab pages.
  %bw!
  edit Xargold1
  split Xargold2
  tabedit Xargold3
  split Xargold4
  tabedit Xargold5
  tabfirst
  args Xargnew1 Xargnew2
  tab all
  call assert_equal(2, tabpagenr('$'))
  call assert_equal([bufnr('Xargnew1')], tabpagebuflist(1))
  call assert_equal([bufnr('Xargnew2')], tabpagebuflist(2))

  " If a count is specified, then :all should open only that many windows.
  %bw!
  args Xargnew1 Xargnew2 Xargnew3 Xargnew4 Xargnew5
  all 3
  call assert_equal(3, winnr('$'))
  call assert_equal([bufnr('Xargnew1'), bufnr('Xargnew2'), bufnr('Xargnew3')],
        \ [winbufnr(1), winbufnr(2), winbufnr(3)])

  " The :all command should not open more than 'tabpagemax' tab pages.
  " If there are more files, then they should be opened in the last tab page.
  %bw!
  set tabpagemax=3
  tab all
  call assert_equal(3, tabpagenr('$'))
  call assert_equal([bufnr('Xargnew1')], tabpagebuflist(1))
  call assert_equal([bufnr('Xargnew2')], tabpagebuflist(2))
  call assert_equal([bufnr('Xargnew3'), bufnr('Xargnew4'), bufnr('Xargnew5')],
        \ tabpagebuflist(3))
  set tabpagemax&

  " Without the 'hidden' option, modified buffers should not be closed.
  args Xargnew1 Xargnew2
  %bw!
  edit Xargtemp1
  call setline(1, 'temp buffer 1')
  split Xargtemp2
  call setline(1, 'temp buffer 2')
  all
  call assert_equal(4, winnr('$'))
  call assert_equal([bufnr('Xargtemp2'), bufnr('Xargtemp1'), bufnr('Xargnew1'),
        \ bufnr('Xargnew2')],
        \ [winbufnr(1), winbufnr(2), winbufnr(3), winbufnr(4)])

  " With the 'hidden' option set, both modified and unmodified buffers in
  " closed windows should be hidden.
  set hidden
  all
  call assert_equal(2, winnr('$'))
  call assert_equal([bufnr('Xargnew1'), bufnr('Xargnew2')],
        \ [winbufnr(1), winbufnr(2)])
  call assert_equal([1, 1, 0, 0], [getbufinfo('Xargtemp1')[0].hidden,
        \ getbufinfo('Xargtemp2')[0].hidden,
        \ getbufinfo('Xargnew1')[0].hidden,
        \ getbufinfo('Xargnew2')[0].hidden])
  set nohidden

  " When 'winheight' is set to a large value, :all should open only one
  " window.
  args Xargnew1 Xargnew2 Xargnew3 Xargnew4 Xargnew5
  %bw!
  set winheight=9999
  call assert_fails('all', 'E36:')
  call assert_equal([1, bufnr('Xargnew1')], [winnr('$'), winbufnr(1)])
  set winheight&

  " When 'winwidth' is set to a large value, :vert all should open only one
  " window.
  %bw!
  set winwidth=9999
  call assert_fails('vert all', 'E36:')
  call assert_equal([1, bufnr('Xargnew1')], [winnr('$'), winbufnr(1)])
  set winwidth&

  " empty argument list tests
  %bw!
  %argdelete
  call assert_equal('', execute('args'))
  all
  call assert_equal(1, winnr('$'))

  %argdelete
  %bw!
endfunc

" Test for deleting buffer when creating an arglist. This was accessing freed
" memory
func Test_crash_arglist_uaf()
  "%argdelete
  new one
  au BufAdd XUAFlocal :bw
  "call assert_fails(':arglocal XUAFlocal', 'E163:')
  arglocal XUAFlocal
  au! BufAdd
  bw! XUAFlocal

  au BufAdd XUAFlocal2 :bw
  new two
  new three
  arglocal
  argadd XUAFlocal2 Xfoobar
  bw! XUAFlocal2
  bw! two

  au! BufAdd
endfunc

" vim: shiftwidth=2 sts=2 expandtab
