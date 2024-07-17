" Tests for expand()

source shared.vim

let s:sfile = expand('<sfile>')
let s:slnum = str2nr(expand('<slnum>'))
let s:sflnum = str2nr(expand('<sflnum>'))

func s:expand_sfile()
  return expand('<sfile>')
endfunc

func s:expand_slnum()
  return str2nr(expand('<slnum>'))
endfunc

func s:expand_sflnum()
  return str2nr(expand('<sflnum>'))
endfunc

" This test depends on the location in the test file, put it first.
func Test_expand_sflnum()
  call assert_equal(7, s:sflnum)
  call assert_equal(24, str2nr(expand('<sflnum>')))

  " Line-continuation
  call assert_equal(
        \ 27,
        \ str2nr(expand('<sflnum>')))

  " Call in script-local function
  call assert_equal(18, s:expand_sflnum())

  " Call in command
  command Flnum echo expand('<sflnum>')
  call assert_equal(36, str2nr(trim(execute('Flnum'))))
  delcommand Flnum
endfunc

func Test_expand_sfile_and_stack()
  call assert_match('test_expand_func\.vim$', s:sfile)
  let expected = 'script .*testdir/runtest.vim\[\d\+\]\.\.function RunTheTest\[\d\+\]\.\.Test_expand_sfile_and_stack'
  call assert_match(expected .. '$', expand('<sfile>'))
  call assert_match(expected .. '\[4\]$' , expand('<stack>'))

  " Call in script-local function
  call assert_match('script .*testdir/runtest.vim\[\d\+\]\.\.function RunTheTest\[\d\+\]\.\.Test_expand_sfile_and_stack\[7\]\.\.<SNR>\d\+_expand_sfile$', s:expand_sfile())

  " Call in command
  command Sfile echo expand('<sfile>')
  call assert_match('script .*testdir/runtest.vim\[\d\+\]\.\.function RunTheTest\[\d\+\]\.\.Test_expand_sfile_and_stack$', trim(execute('Sfile')))
  delcommand Sfile

  " Use <stack> from sourced script.
  let lines =<< trim END
    " comment here
    let g:stack_value = expand('<stack>')
  END
  call writefile(lines, 'Xstack')
  source Xstack
  call assert_match('\<Xstack\[2\]$', g:stack_value)
  unlet g:stack_value
  call delete('Xstack')

  if exists('+shellslash')
    call mkdir('Xshellslash')
    let lines =<< trim END
      let g:stack1 = expand('<stack>')
      set noshellslash
      let g:stack2 = expand('<stack>')
      set shellslash
      let g:stack3 = expand('<stack>')
    END
    call writefile(lines, 'Xshellslash/Xstack')
    " Test that changing 'shellslash' always affects the result of expand()
    " when sourcing a script multiple times.
    for i in range(2)
      source Xshellslash/Xstack
      call assert_match('\<Xshellslash/Xstack\[1\]$', g:stack1)
      call assert_match('\<Xshellslash\\Xstack\[3\]$', g:stack2)
      call assert_match('\<Xshellslash/Xstack\[5\]$', g:stack3)
      unlet g:stack1
      unlet g:stack2
      unlet g:stack3
    endfor
    call delete('Xshellslash', 'rf')
  endif
endfunc

func Test_expand_slnum()
  call assert_equal(6, s:slnum)
  call assert_equal(2, str2nr(expand('<slnum>')))

  " Line-continuation
  call assert_equal(
        \ 5,
        \ str2nr(expand('<slnum>')))

  " Call in script-local function
  call assert_equal(1, s:expand_slnum())

  " Call in command
  command Slnum echo expand('<slnum>')
  call assert_equal(14, str2nr(trim(execute('Slnum'))))
  delcommand Slnum
endfunc

func Test_expand()
  new
  call assert_equal("", expand('%:S'))
  call assert_equal('3', '<slnum>'->expand())
  call assert_equal(['4'], expand('<slnum>', v:false, v:true))
  " Don't add any line above this, otherwise <slnum> will change.
  call assert_equal("", expand('%'))
  set verbose=1
  call assert_equal("", expand('%'))
  set verbose=0
  call assert_equal("", expand('%:p'))
  quit
endfunc

func s:sid_test()
  return 'works'
endfunc

func Test_expand_SID()
  let sid = expand('<SID>')
  execute 'let g:sid_result = ' .. sid .. 'sid_test()'
  call assert_equal('works', g:sid_result)
endfunc


" Test for 'wildignore' with expand()
func Test_expand_wildignore()
  set wildignore=*.vim
  call assert_equal('', expand('test_expand_func.vim'))
  call assert_equal('', expand('test_expand_func.vim', 0))
  call assert_equal([], expand('test_expand_func.vim', 0, 1))
  call assert_equal('test_expand_func.vim', expand('test_expand_func.vim', 1))
  call assert_equal(['test_expand_func.vim'],
        \ expand('test_expand_func.vim', 1, 1))
  call assert_fails("call expand('*', [])", 'E745:')
  set wildignore&
endfunc

" vim: shiftwidth=2 sts=2 expandtab
