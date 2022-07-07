" Tests for the history functions

source check.vim
CheckFeature cmdline_hist

set history=7

function History_Tests(hist)
  " First clear the history
  call histadd(a:hist, 'dummy')
  call assert_true(histdel(a:hist))
  call assert_equal(-1, histnr(a:hist))
  call assert_equal('', histget(a:hist))

  call assert_true('ls'->histadd(a:hist))
  call assert_true(histadd(a:hist, 'buffers'))
  call assert_equal('buffers', histget(a:hist))
  call assert_equal('ls', histget(a:hist, -2))
  call assert_equal('ls', histget(a:hist, 1))
  call assert_equal('', histget(a:hist, 5))
  call assert_equal('', histget(a:hist, -5))
  call assert_equal(2, histnr(a:hist))
  call assert_true(histdel(a:hist, 2))
  call assert_false(a:hist->histdel(7))
  call assert_equal(1, histnr(a:hist))
  call assert_equal('ls', histget(a:hist, -1))

  call assert_true(histadd(a:hist, 'buffers'))
  call assert_true(histadd(a:hist, 'ls'))
  call assert_equal('ls', a:hist->histget(-1))
  call assert_equal(4, a:hist->histnr())

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
  call assert_fails('history xyz', 'E488:')
  call assert_fails('history ,abc', 'E488:')
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

" Test for increasing the 'history' option value
func Test_history_size()
  let save_histsz = &history
  call histdel(':')
  set history=5
  for i in range(1, 5)
    call histadd(':', 'cmd' .. i)
  endfor
  call assert_equal(5, histnr(':'))
  call assert_equal('cmd5', histget(':', -1))

  set history=10
  for i in range(6, 10)
    call histadd(':', 'cmd' .. i)
  endfor
  call assert_equal(10, histnr(':'))
  call assert_equal('cmd1', histget(':', 1))
  call assert_equal('cmd10', histget(':', -1))

  set history=5
  call histadd(':', 'abc')
  call assert_equal('', histget(':', 6))
  call assert_equal('', histget(':', 12))
  call assert_equal('cmd7', histget(':', 7))
  call assert_equal('abc', histget(':', -1))

  let &history=save_histsz
endfunc

" Test for recalling old search patterns in /
func Test_history_search()
  call histdel('/')
  let g:pat = []
  func SavePat()
    call add(g:pat, getcmdline())
    return ''
  endfunc
  cnoremap <F2> <C-\>eSavePat()<CR>
  call histadd('/', 'pat1')
  call histadd('/', 'pat2')
  let @/ = ''
  call feedkeys("/\<Up>\<F2>\<Up>\<F2>\<Down>\<Down>\<F2>\<Esc>", 'xt')
  call assert_equal(['pat2', 'pat1', ''], g:pat)
  cunmap <F2>
  delfunc SavePat
endfunc

" vim: shiftwidth=2 sts=2 expandtab
