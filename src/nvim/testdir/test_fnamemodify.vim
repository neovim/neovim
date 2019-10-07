" Test filename modifiers.

func Test_fnamemodify()
  let save_home = $HOME
  let save_shell = &shell
  let $HOME = fnamemodify('.', ':p:h:h')
  set shell=sh

  call assert_equal('/', fnamemodify('.', ':p')[-1:])
  call assert_equal('r', fnamemodify('.', ':p:h')[-1:])
  call assert_equal('t', fnamemodify('test.out', ':p')[-1:])
  call assert_equal('test.out', fnamemodify('test.out', ':.'))
  call assert_equal('a', fnamemodify('../testdir/a', ':.'))
  call assert_equal('~/testdir/test.out', fnamemodify('test.out', ':~'))
  call assert_equal('~/testdir/a', fnamemodify('../testdir/a', ':~'))
  call assert_equal('a', fnamemodify('../testdir/a', ':t'))
  call assert_equal('', fnamemodify('.', ':p:t'))
  call assert_equal('test.out', fnamemodify('test.out', ':p:t'))
  call assert_equal('out', fnamemodify('test.out', ':p:e'))
  call assert_equal('out', fnamemodify('test.out', ':p:t:e'))
  call assert_equal('abc.fb2.tar', fnamemodify('abc.fb2.tar.gz', ':r'))
  call assert_equal('abc.fb2', fnamemodify('abc.fb2.tar.gz', ':r:r'))
  call assert_equal('abc', fnamemodify('abc.fb2.tar.gz', ':r:r:r'))
  call assert_equal('testdir/abc.fb2', substitute(fnamemodify('abc.fb2.tar.gz', ':p:r:r'), '.*\(testdir/.*\)', '\1', ''))
  call assert_equal('gz', fnamemodify('abc.fb2.tar.gz', ':e'))
  call assert_equal('tar.gz', fnamemodify('abc.fb2.tar.gz', ':e:e'))
  call assert_equal('fb2.tar.gz', fnamemodify('abc.fb2.tar.gz', ':e:e:e'))
  call assert_equal('fb2.tar.gz', fnamemodify('abc.fb2.tar.gz', ':e:e:e:e'))
  call assert_equal('tar', fnamemodify('abc.fb2.tar.gz', ':e:e:r'))

  call assert_equal('''abc def''', fnamemodify('abc def', ':S'))
  call assert_equal('''abc" "def''', fnamemodify('abc" "def', ':S'))
  call assert_equal('''abc"%"def''', fnamemodify('abc"%"def', ':S'))
  call assert_equal('''abc''\'''' ''\''''def''', fnamemodify('abc'' ''def', ':S'))
  call assert_equal('''abc''\''''%''\''''def''', fnamemodify('abc''%''def', ':S'))
  sp test_alot.vim
  call assert_equal(expand('%:r:S'), shellescape(expand('%:r')))
  call assert_equal('test_alot,''test_alot'',test_alot.vim', join([expand('%:r'), expand('%:r:S'), expand('%')], ','))
  quit

  call assert_equal("'abc\ndef'", fnamemodify("abc\ndef", ':S'))
  set shell=tcsh
  call assert_equal("'abc\\\ndef'",  fnamemodify("abc\ndef", ':S'))

  let $HOME = save_home
  let &shell = save_shell
endfunc
