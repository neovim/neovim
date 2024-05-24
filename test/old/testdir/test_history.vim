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

  " Test for freeing an entry at the beginning of the history list
  for i in range(1, 4)
      call histadd(a:hist, 'text_' . i)
  endfor
  call histdel(a:hist, 1)
  call assert_equal('', histget(a:hist, 1))
  call assert_equal('text_4', histget(a:hist, 4))
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
  call assert_fails('call histdel(":", "\\%(")', 'E53:')

  " Test for filtering the history list
  let hist_filter = execute(':filter /_\d/ :history all')->split('\n')
  call assert_equal(20, len(hist_filter))
  let expected = ['      #  cmd history',
               \ '      2  text_2',
               \ '      3  text_3',
               \ '>     4  text_4',
               \ '      #  search history',
               \ '      2  text_2',
               \ '      3  text_3',
               \ '>     4  text_4',
               \ '      #  expr history',
               \ '      2  text_2',
               \ '      3  text_3',
               \ '>     4  text_4',
               \ '      #  input history',
               \ '      2  text_2',
               \ '      3  text_3',
               \ '>     4  text_4',
               \ '      #  debug history',
               \ '      2  text_2',
               \ '      3  text_3',
               \ '>     4  text_4']
  call assert_equal(expected, hist_filter)

  let cmds = {'c': 'cmd', 's': 'search', 'e': 'expr', 'i': 'input', 'd': 'debug'}
  for h in sort(keys(cmds))
    " find some items
    let hist_filter = execute(':filter /_\d/ :history ' .. h)->split('\n')
    call assert_equal(4, len(hist_filter))

    let expected = ['      #  ' .. cmds[h] .. ' history',
               \ '      2  text_2',
               \ '      3  text_3',
               \ '>     4  text_4']
    call assert_equal(expected, hist_filter)

    " Search for an item that is not there
    let hist_filter = execute(':filter /XXXX/ :history ' .. h)->split('\n')
    call assert_equal(1, len(hist_filter))

    let expected = ['      #  ' .. cmds[h] .. ' history']
    call assert_equal(expected, hist_filter)

    " Invert the filter condition, find non-matches
    let hist_filter = execute(':filter! /_3$/ :history ' .. h)->split('\n')
    call assert_equal(3, len(hist_filter))

    let expected = ['      #  ' .. cmds[h] .. ' history',
               \ '      2  text_2',
               \ '>     4  text_4']
    call assert_equal(expected, hist_filter)
  endfor
endfunction

function Test_history_truncates_long_entry()
  " History entry short enough to fit on the screen should not be truncated.
  call histadd(':', 'echo x' .. repeat('y', &columns - 17) .. 'z')
  let a = execute('history : -1')

  call assert_match("^\n      #  cmd history\n"
        \        .. "> *\\d\\+  echo x" .. repeat('y', &columns - 17) ..  'z$', a)

  " Long history entry should be truncated to fit on the screen, with, '...'
  " inserted in the string to indicate the that there is truncation.
  call histadd(':', 'echo x' .. repeat('y', &columns - 16) .. 'z')
  let a = execute('history : -1')
  call assert_match("^\n      #  cmd history\n"
        \        .. ">  *\\d\\+  echo xy\\+\.\.\.y\\+z$", a)
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

" Test for :history command option completion
function Test_history_completion()
  call feedkeys(":history \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"history / : = > ? @ all cmd debug expr input search', @:)
endfunc

" Test for increasing the 'history' option value
func Test_history_size()
  let save_histsz = &history
  set history=10
  call histadd(':', 'ls')
  call histdel(':')
  for i in range(1, 5)
    call histadd(':', 'cmd' .. i)
  endfor
  call assert_equal(5, histnr(':'))
  call assert_equal('cmd5', histget(':', -1))

  set history=15
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

  " This test works only when the language is English
  if v:lang == "C" || v:lang =~ '^[Ee]n'
    set history=0
    redir => v
    call feedkeys(":history\<CR>", 'xt')
    redir END
    call assert_equal(["'history' option is zero"], split(v, "\n"))
  endif

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

  " Search for a pattern that is not present in the history
  call assert_beeps('call feedkeys("/a1b2\<Up>\<CR>", "xt")')

  " Recall patterns with 'history' set to 0
  set history=0
  let @/ = 'abc'
  let cmd = 'call feedkeys("/\<Up>\<Down>\<S-Up>\<S-Down>\<CR>", "xt")'
  call assert_fails(cmd, 'E486:')
  set history&

  " Recall patterns till the end of history
  set history=4
  call histadd('/', 'pat')
  call histdel('/')
  call histadd('/', 'pat1')
  call histadd('/', 'pat2')
  call assert_beeps('call feedkeys("/\<Up>\<Up>\<Up>\<C-U>\<cr>", "xt")')
  call assert_beeps('call feedkeys("/\<Down><cr>", "xt")')

  " Test for wrapping around the history list
  for i in range(3, 7)
    call histadd('/', 'pat' .. i)
  endfor
  let upcmd = "\<up>\<up>\<up>\<up>\<up>"
  let downcmd = "\<down>\<down>\<down>\<down>\<down>"
  try
    call feedkeys("/" .. upcmd .. "\<cr>", 'xt')
  catch /E486:/
  endtry
  call assert_equal('pat4', @/)
  try
    call feedkeys("/" .. upcmd .. downcmd .. "\<cr>", 'xt')
  catch /E486:/
  endtry
  call assert_equal('pat4', @/)

  " Test for changing the search command separator in the history
  call assert_fails('call feedkeys("/def/\<cr>", "xt")', 'E486:')
  call assert_fails('call feedkeys("?\<up>\<cr>", "xt")', 'E486:')
  call assert_equal('def?', histget('/', -1))

  call assert_fails('call feedkeys("/ghi?\<cr>", "xt")', 'E486:')
  call assert_fails('call feedkeys("?\<up>\<cr>", "xt")', 'E486:')
  call assert_equal('ghi\?', histget('/', -1))

  set history&
endfunc

" Test for making sure the key value is not stored in history
func Test_history_crypt_key()
  CheckFeature cryptv

  call feedkeys(":set bs=2 key=abc ts=8\<CR>", 'xt')
  call assert_equal('set bs=2 key= ts=8', histget(':'))

  call assert_fails("call feedkeys(':set bs=2 key-=abc ts=8\<CR>', 'xt')")
  call assert_equal('set bs=2 key-= ts=8', histget(':'))

  set key& bs& ts&
endfunc

" The following used to overflow and causing a use-after-free
func Test_history_max_val()

  set history=10
  call assert_fails(':history 2147483648', 'E1510:')
  set history&
endfunc

" vim: shiftwidth=2 sts=2 expandtab
