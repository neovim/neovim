
" Tests for :help

func Test_help_restore_snapshot()
  help
  set buftype=
  help
  edit x
  help
  helpclose
endfunc

func Test_help_errors()
  call assert_fails('help doesnotexist', 'E149:')
  call assert_fails('help!', 'E478:')

  new
  set keywordprg=:help
  call setline(1, "   ")
  call assert_fails('normal VK', 'E349:')
  bwipe!
endfunc

func Test_help_expr()
  help expr-!~?
  call assert_equal('eval.txt', expand('%:t'))
  close
endfunc

func Test_help_keyword()
  new
  set keywordprg=:help
  call setline(1, "  Visual ")
  normal VK
  call assert_match('^Visual mode', getline('.'))
  call assert_equal('help', &ft)
  close
  bwipe!
endfunc

func Test_help_local_additions()
  call mkdir('Xruntime/doc', 'p')
  call writefile(['*mydoc.txt* my awesome doc'], 'Xruntime/doc/mydoc.txt')
  call writefile(['*mydoc-ext.txt* my extended awesome doc'], 'Xruntime/doc/mydoc-ext.txt')
  let rtp_save = &rtp
  set rtp+=./Xruntime
  help
  1
  call search('mydoc.txt')
  call assert_equal('|mydoc.txt| my awesome doc', getline('.'))
  1
  call search('mydoc-ext.txt')
  call assert_equal('|mydoc-ext.txt| my extended awesome doc', getline('.'))
  close

  call delete('Xruntime', 'rf')
  let &rtp = rtp_save
endfunc

" Test for the :helptags command
func Test_helptag_cmd()
  call mkdir('Xdir/a/doc', 'p')

  " No help file to process in the directory
  call assert_fails('helptags Xdir', 'E151:')

  call writefile([], 'Xdir/a/doc/sample.txt')

  " Test for ++t argument
  helptags ++t Xdir
  call assert_equal(["help-tags\ttags\t1"], readfile('Xdir/tags'))
  call delete('Xdir/tags')

  " The following tests fail on FreeBSD for some reason
  if has('unix') && !has('bsd')
    " Read-only tags file
    call mkdir('Xdir/doc', 'p')
    call writefile([''], 'Xdir/doc/tags')
    call writefile([], 'Xdir/doc/sample.txt')
    call setfperm('Xdir/doc/tags', 'r-xr--r--')
    call assert_fails('helptags Xdir/doc', 'E152:', getfperm('Xdir/doc/tags'))

    let rtp = &rtp
    let &rtp = 'Xdir'
    helptags ALL
    let &rtp = rtp

    call delete('Xdir/doc/tags')

    " No permission to read the help file
    call setfperm('Xdir/a/doc/sample.txt', '-w-------')
    call assert_fails('helptags Xdir', 'E153:', getfperm('Xdir/a/doc/sample.txt'))
    call delete('Xdir/a/doc/sample.txt')
    call delete('Xdir/tags')
  endif

  " Duplicate tags in the help file
  call writefile(['*tag1*', '*tag1*', '*tag2*'], 'Xdir/a/doc/sample.txt')
  call assert_fails('helptags Xdir', 'E154:')

  call delete('Xdir', 'rf')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
