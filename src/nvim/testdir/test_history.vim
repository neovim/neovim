" Tests for the history functions

if !has('cmdline_hist')
  finish
endif

set history=7

function History_Tests(hist)
  " First clear the history
  call histadd(a:hist, 'dummy')
  call assert_true(histdel(a:hist))
  call assert_equal(-1, histnr(a:hist))
  call assert_equal('', histget(a:hist))

  call assert_true(histadd(a:hist, 'ls'))
  call assert_true(histadd(a:hist, 'buffers'))
  call assert_equal('buffers', histget(a:hist))
  call assert_equal('ls', histget(a:hist, -2))
  call assert_equal('ls', histget(a:hist, 1))
  call assert_equal('', histget(a:hist, 5))
  call assert_equal('', histget(a:hist, -5))
  call assert_equal(2, histnr(a:hist))
  call assert_true(histdel(a:hist, 2))
  call assert_false(histdel(a:hist, 7))
  call assert_equal(1, histnr(a:hist))
  call assert_equal('ls', histget(a:hist, -1))

  call assert_true(histadd(a:hist, 'buffers'))
  call assert_true(histadd(a:hist, 'ls'))
  call assert_equal('ls', histget(a:hist, -1))
  call assert_equal(4, histnr(a:hist))

  let a=execute('history ' . a:hist)
  call assert_match("^\n      #  \\S* history\n      3  buffers\n>     4  ls$", a)
  let a=execute('history all')
  call assert_match("^\n      #  .* history\n      3  buffers\n>     4  ls", a)

  if len(a:hist) > 0
    let a=execute('history ' . a:hist . ' 2')
    call assert_match("^\n      #  \\S* history$", a)
    let a=execute('history ' . a:hist . ' 3')
    call assert_match("^\n      #  \\S* history\n      3  buffers$", a)
    let a=execute('history ' . a:hist . ' 4')
    call assert_match("^\n      #  \\S* history\n>     4  ls$", a)
    let a=execute('history ' . a:hist . ' 3,4')
    call assert_match("^\n      #  \\S* history\n      3  buffers\n>     4  ls$", a)
    let a=execute('history ' . a:hist . ' -1')
    call assert_match("^\n      #  \\S* history\n>     4  ls$", a)
    let a=execute('history ' . a:hist . ' -2')
    call assert_match("^\n      #  \\S* history\n      3  buffers$", a)
    let a=execute('history ' . a:hist . ' -2,')
    call assert_match("^\n      #  \\S* history\n      3  buffers\n>     4  ls$", a)
    let a=execute('history ' . a:hist . ' -3')
    call assert_match("^\n      #  \\S* history$", a)
  endif

  " Test for removing entries matching a pattern
  for i in range(1, 3)
      call histadd(a:hist, 'text_' . i)
  endfor
  call assert_true(histdel(a:hist, 'text_\d\+'))
  call assert_equal('ls', histget(a:hist, -1))

  " Test for freeing the entire history list
  for i in range(1, 7)
      call histadd(a:hist, 'text_' . i)
  endfor
  call histdel(a:hist)
  for i in range(1, 7)
    call assert_equal('', histget(a:hist, i))
    call assert_equal('', histget(a:hist, i - 7 - 1))
  endfor
endfunction

function Test_History()
  for h in ['cmd', ':', '', 'search', '/', '?', 'expr', '=', 'input', '@', 'debug', '>']
    call History_Tests(h)
  endfor

  " Negative tests
  call assert_false(histdel('abc'))
  call assert_equal('', histget('abc'))
  call assert_fails('call histdel([])', 'E730:')
  call assert_equal('', histget(10))
  call assert_fails('call histget([])', 'E730:')
  call assert_equal(-1, histnr('abc'))
  call assert_fails('call histnr([])', 'E730:')
endfunction

function Test_Search_history_window()
  new
  call setline(1, ['a', 'b', 'a', 'b'])
  1
  call feedkeys("/a\<CR>", 'xt')
  call assert_equal('a', getline('.'))
  1
  call feedkeys("/b\<CR>", 'xt')
  call assert_equal('b', getline('.'))
  1
  " select the previous /a command
  call feedkeys("q/kk\<CR>", 'x!')
  call assert_equal('a', getline('.'))
  call assert_equal('a', @/)
  bwipe!
endfunc

function Test_history_completion()
  call feedkeys(":history \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"history / : = > ? @ all cmd debug expr input search', @:)
endfunc
