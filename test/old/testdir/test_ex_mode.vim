" Test editing line in Ex mode (see :help Q and :help gQ).

source check.vim
source shared.vim

" Helper function to test editing line in Q Ex mode
func Ex_Q(cmd)
  " Is there a simpler way to test editing Ex line?
  call feedkeys("Q"
        \    .. "let s:test_ex =<< END\<CR>"
        \    .. a:cmd .. "\<CR>"
        \    .. "END\<CR>"
        \    .. "visual\<CR>", 'tx')
  return s:test_ex[0]
endfunc

" Helper function to test editing line in gQ Ex mode
func Ex_gQ(cmd)
  call feedkeys("gQ" .. a:cmd .. "\<C-b>\"\<CR>", 'tx')
  let ret = @:[1:] " Remove leading quote.
  call feedkeys("visual\<CR>", 'tx')
  return ret
endfunc

" Helper function to test editing line with both Q and gQ Ex mode.
func Ex(cmd)
 return [Ex_Q(a:cmd), Ex_gQ(a:cmd)]
endfunc

" Test editing line in Ex mode (both Q and gQ)
func Test_ex_mode()
  throw 'Skipped: Nvim only supports Vim Ex mode'
  let encoding_save = &encoding
  set sw=2

  for e in ['utf8', 'latin1']
    exe 'set encoding=' . e

    call assert_equal(['bar', 'bar'],             Ex("foo bar\<C-u>bar"), e)
    call assert_equal(["1\<C-u>2", "1\<C-u>2"],   Ex("1\<C-v>\<C-u>2"), e)
    call assert_equal(["1\<C-b>2\<C-e>3", '213'], Ex("1\<C-b>2\<C-e>3"), e)
    call assert_equal(['0123', '2013'],           Ex("01\<Home>2\<End>3"), e)
    call assert_equal(['0123', '0213'],           Ex("01\<Left>2\<Right>3"), e)
    call assert_equal(['01234', '0342'],          Ex("012\<Left>\<Left>\<Insert>3\<Insert>4"), e)
    call assert_equal(["foo bar\<C-w>", 'foo '],  Ex("foo bar\<C-w>"), e)
    call assert_equal(['foo', 'foo'],             Ex("fooba\<Del>\<Del>"), e)
    call assert_equal(["foo\tbar", 'foobar'],     Ex("foo\<Tab>bar"), e)
    call assert_equal(["abbrev\t", 'abbreviate'], Ex("abbrev\<Tab>"), e)
    call assert_equal(['    1', "1\<C-t>\<C-t>"], Ex("1\<C-t>\<C-t>"), e)
    call assert_equal(['  1', "1\<C-t>\<C-t>"],   Ex("1\<C-t>\<C-t>\<C-d>"), e)
    call assert_equal(['  foo', '    foo'],       Ex("    foo\<C-d>"), e)
    call assert_equal(['foo', '    foo0'],        Ex("    foo0\<C-d>"), e)
    call assert_equal(['foo', '    foo^'],        Ex("    foo^\<C-d>"), e)
    call assert_equal(['foo', 'foo'],
          \ Ex("\<BS>\<C-H>\<Del>\<kDel>foo"), e)
    " default wildchar <Tab> interferes with this test
    set wildchar=<c-e>
    call assert_equal(["a\tb", "a\tb"],           Ex("a\t\t\<C-H>b"), e)
    call assert_equal(["\t  mn", "\tm\<C-T>n"],        Ex("\tm\<C-T>n"), e)
    set wildchar&
  endfor

  set sw&
  let &encoding = encoding_save
endfunc

" Test substitute confirmation prompt :%s/pat/str/c in Ex mode
func Test_Ex_substitute()
  CheckRunVimInTerminal
  let buf = RunVimInTerminal('', {'rows': 6})

  call term_sendkeys(buf, ":call setline(1, repeat(['foo foo'], 4))\<CR>")
  call term_sendkeys(buf, ":set number\<CR>")
  call term_sendkeys(buf, "gQ")
  call WaitForAssert({-> assert_match(':', term_getline(buf, 6))}, 1000)

  call term_sendkeys(buf, "%s/foo/bar/gc\<CR>")
  call WaitForAssert({-> assert_match('  1 foo foo', term_getline(buf, 5))},
        \ 1000)
  call WaitForAssert({-> assert_match('    ^^^', term_getline(buf, 6))}, 1000)
  call term_sendkeys(buf, "N\<CR>")
  call term_wait(buf)
  call WaitForAssert({-> assert_match('    ^^^', term_getline(buf, 6))}, 1000)
  call term_sendkeys(buf, "n\<CR>")
  call WaitForAssert({-> assert_match('        ^^^', term_getline(buf, 6))},
        \ 1000)
  call term_sendkeys(buf, "y\<CR>")

  call term_sendkeys(buf, "q\<CR>")
  call WaitForAssert({-> assert_match(':', term_getline(buf, 6))}, 1000)

  " Pressing enter in ex mode should print the current line
  call term_sendkeys(buf, "\<CR>")
  call WaitForAssert({-> assert_match('  3 foo foo', term_getline(buf, 5))}, 1000)
  call WaitForAssert({-> assert_match(':', term_getline(buf, 6))}, 1000)

  " The printed line should overwrite the colon
  call term_sendkeys(buf, "\<CR>")
  call WaitForAssert({-> assert_match('  3 foo foo', term_getline(buf, 4))}, 1000)
  call WaitForAssert({-> assert_match('  4 foo foo', term_getline(buf, 5))}, 1000)
  call WaitForAssert({-> assert_match(':', term_getline(buf, 6))}, 1000)

  call term_sendkeys(buf, ":vi\<CR>")
  call WaitForAssert({-> assert_match('foo bar', term_getline(buf, 1))}, 1000)

  call StopVimInTerminal(buf)
endfunc

" Test for displaying lines from an empty buffer in Ex mode
func Test_Ex_emptybuf()
  new
  call assert_fails('call feedkeys("Q\<CR>", "xt")', 'E749:')
  call setline(1, "abc")
  call assert_fails('call feedkeys("Q\<CR>", "xt")', 'E501:')
  call assert_fails('call feedkeys("Q%d\<CR>", "xt")', 'E749:')
  close!
endfunc

" Test for the :open command
func Test_open_command()
  throw 'Skipped: Nvim does not have :open'
  new
  call setline(1, ['foo foo', 'foo bar', 'foo baz'])
  call feedkeys("Qopen\<CR>j", 'xt')
  call assert_equal('foo bar', getline('.'))
  call feedkeys("Qopen /bar/\<CR>", 'xt')
  call assert_equal(5, col('.'))
  call assert_fails('call feedkeys("Qopen /baz/\<CR>", "xt")', 'E479:')
  close!
endfunc

func Test_open_command_flush_line()
  throw 'Skipped: Nvim does not have :open'
  " this was accessing freed memory: the regexp match uses a pointer to the
  " current line which becomes invalid when searching for the ') mark.
  new
  call setline(1, ['one', 'two. three'])
  s/one/ONE
  try
    open /\%')/
  catch /E479/
  endtry
  bwipe!
endfunc

" FIXME: this doesn't fail without the fix but hangs
func Skip_Test_open_command_state()
  " Tricky script that failed because State was not set properly
  let lines =<< trim END
      !ls 
      0scìi
      so! Xsourced
      set t_û0=0
      v/-/o
  END
  call writefile(lines, 'XopenScript', '')

  let sourced = ["!f\u0083\x02\<Esc>z=0"]
  call writefile(sourced, 'Xsourced', 'b')

  CheckRunVimInTerminal
  let buf = RunVimInTerminal('-u NONE -i NONE -n -m -X -Z -e -s -S XopenScript -c qa!', #{rows: 6, wait_for_ruler: 0, no_clean: 1})
  sleep 3

  call StopVimInTerminal(buf)
endfunc

" Test for :g/pat/visual to run vi commands in Ex mode
" This used to hang Vim before 8.2.0274.
func Test_Ex_global()
  new
  call setline(1, ['', 'foo', 'bar', 'foo', 'bar', 'foo'])
  call feedkeys("Q\<bs>g/bar/visual\<CR>$rxQ$ryQvisual\<CR>j", "xt")
  call assert_equal('bax', getline(3))
  call assert_equal('bay', getline(5))
  bwipe!
endfunc

" Test for pressing Ctrl-C in :append inside a loop in Ex mode
" This used to hang Vim
func Test_Ex_append_in_loop()
  CheckRunVimInTerminal
  let buf = RunVimInTerminal('', {'rows': 6})

  call term_sendkeys(buf, "gQ")
  call term_sendkeys(buf, "for i in range(1)\<CR>")
  call term_sendkeys(buf, "append\<CR>")
  call WaitForAssert({-> assert_match(':  append', term_getline(buf, 5))}, 1000)
  call term_sendkeys(buf, "\<C-C>")
  " Wait for input to be flushed
  call term_wait(buf)
  call term_sendkeys(buf, "foo\<CR>")
  call WaitForAssert({-> assert_match('foo', term_getline(buf, 5))}, 1000)
  call term_sendkeys(buf, ".\<CR>")
  call WaitForAssert({-> assert_match('.', term_getline(buf, 5))}, 1000)
  call term_sendkeys(buf, "endfor\<CR>")
  call term_sendkeys(buf, "vi\<CR>")
  call WaitForAssert({-> assert_match('foo', term_getline(buf, 1))}, 1000)

  call StopVimInTerminal(buf)
endfunc

" In Ex-mode, a backslash escapes a newline
func Test_Ex_escape_enter()
  call feedkeys("gQlet l = \"a\\\<kEnter>b\"\<cr>vi\<cr>", 'xt')
  call assert_equal("a\rb", l)
endfunc

" Test for :append! command in Ex mode
func Test_Ex_append()
  throw 'Skipped: Nvim only supports Vim Ex mode'
  new
  call setline(1, "\t   abc")
  call feedkeys("Qappend!\npqr\nxyz\n.\nvisual\n", 'xt')
  call assert_equal(["\t   abc", "\t   pqr", "\t   xyz"], getline(1, '$'))
  close!
endfunc

" In Ex-mode, backslashes at the end of a command should be halved.
func Test_Ex_echo_backslash()
  throw 'Skipped: Nvim only supports Vim Ex mode'
  " This test works only when the language is English
  CheckEnglish
  let bsl = '\\\\'
  let bsl2 = '\\\'
  call assert_fails('call feedkeys("Qecho " .. bsl .. "\nvisual\n", "xt")',
        \ 'E15: Invalid expression: "\\"')
  call assert_fails('call feedkeys("Qecho " .. bsl2 .. "\nm\nvisual\n", "xt")',
        \ "E15: Invalid expression: \"\\\nm\"")
endfunc

func Test_ex_mode_errors()
  " Not allowed to enter ex mode when text is locked
  au InsertCharPre <buffer> normal! gQ<CR>
  let caught_e565 = 0
  try
    call feedkeys("ix\<esc>", 'xt')
  catch /^Vim\%((\a\+)\)\=:E565/ " catch E565
    let caught_e565 = 1
  endtry
  call assert_equal(1, caught_e565)
  au! InsertCharPre

  new
  au CmdLineEnter * call ExEnterFunc()
  func ExEnterFunc()

  endfunc
  call feedkeys("gQvi\r", 'xt')

  au! CmdLineEnter
  delfunc ExEnterFunc

  au CmdlineEnter * :
  call feedkeys("gQecho 1\r", 'xt')

  au! CmdlineEnter

  quit
endfunc

func Test_ex_mode_count_overflow()
  " The multiplication causes an integer overflow
  CheckNotAsan

  " this used to cause a crash
  let lines =<< trim END
    call feedkeys("\<Esc>gQ\<CR>")
    v9|9silent! vi|333333233333y32333333%O
    call writefile(['done'], 'Xdidexmode')
    qall!
  END
  call writefile(lines, 'Xexmodescript')
  call assert_equal(1, RunVim([], [], '-e -s -S Xexmodescript -c qa'))
  call assert_equal(['done'], readfile('Xdidexmode'))

  call delete('Xdidexmode')
  call delete('Xexmodescript')
endfunc

func Test_ex_mode_large_indent()
  new
  set ts=500 ai
  call setline(1, "\t")
  exe "normal gQi\<CR>."
  set ts=8 noai
  bwipe!
endfunc


" Testing implicit print command
func Test_implicit_print()
  new
  call setline(1, ['one', 'two', 'three'])
  call feedkeys('Q:let a=execute(":1,2")', 'xt')
  call feedkeys('Q:let b=execute(":3")', 'xt')
  call assert_equal('one two', a->split('\n')->join(' '))
  call assert_equal('three', b->split('\n')->join(' '))
  bw!
endfunc

" Test inserting text after the trailing bar
func Test_insert_after_trailing_bar()
  new
  call feedkeys("Qi|\nfoo\n.\na|bar\nbar\n.\nc|baz\n.", "xt")
  call assert_equal(['', 'foo', 'bar', 'baz'], getline(1, '$'))
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
