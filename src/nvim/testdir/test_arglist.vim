" Test argument list commands

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

  call delete('Xargadd')
  %argd
  new
  arga
  call assert_equal(0, len(argv()))
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
  " Clean the argument list
  arga a | %argd

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

  redir => result
  ar
  redir END
  call assert_true(result =~# 'a b \[c] d')

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
  " Clean the argument list
  arga a | %argd

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

func Reset_arglist()
  args a | %argd
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
  let a = bufnr('')
  argedit x
  call assert_equal(a, bufnr(''))
  call assert_equal('x', bufname(''))
  %argd
  bw! x
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
  call assert_fails('argdelete', 'E471:')
  call assert_fails('1,100argdelete', 'E16:')
  %argd
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
  call writefile(['test file Xxx1'], 'Xxx1')
  call writefile(['test file Xxx2'], 'Xxx2')
  call writefile(['test file Xxx3'], 'Xxx3')

  new
  " redefine arglist; go to Xxx1
  next! Xxx1 Xxx2 Xxx3
  " open window for all args
  all
  call assert_equal('test file Xxx1', getline(1))
  wincmd w
  wincmd w
  call assert_equal('test file Xxx1', getline(1))
  " should now be in Xxx2
  rewind
  call assert_equal('test file Xxx2', getline(1))

  autocmd! BufReadPost Xxx2
  enew! | only
  call delete('Xxx1')
  call delete('Xxx2')
  call delete('Xxx3')
  argdelete Xxx*
  bwipe! Xxx1 Xxx2 Xxx3
endfunc

func Test_arg_all_expand()
  call writefile(['test file Xxx1'], 'Xx x')
  next notexist Xx\ x runtest.vim
  call assert_equal('notexist Xx\ x runtest.vim', expand('##'))
  call delete('Xx x')
endfunc
