" Test filename modifiers.

func Test_fnamemodify()
  let save_home = $HOME
  let save_shell = &shell
  let save_shellslash = &shellslash
  let $HOME = fnamemodify('.', ':p:h:h')
  set shell=sh
  set shellslash

  call assert_equal('/', fnamemodify('.', ':p')[-1:])
  call assert_equal('r', fnamemodify('.', ':p:h')[-1:])
  call assert_equal('t', fnamemodify('test.out', ':p')[-1:])
  call assert_equal($HOME .. "/foo" , fnamemodify('~/foo', ':p'))
  call assert_equal(fnamemodify('.', ':p:h:h:h') .. '/', fnamemodify($HOME .. '/../', ':p'))
  call assert_equal(fnamemodify('.', ':p:h:h:h') .. '/', fnamemodify($HOME .. '/..', ':p'))
  call assert_equal(fnamemodify('.', ':p:h:h') .. '/', fnamemodify('../', ':p'))
  call assert_equal(fnamemodify('.', ':p:h:h') .. '/', fnamemodify('..', ':p'))
  call assert_equal('test.out', fnamemodify('test.out', ':.'))
  call assert_equal('a', fnamemodify('../testdir/a', ':.'))
  call assert_equal('~/testdir/test.out', fnamemodify('test.out', ':~'))
  call assert_equal('~/testdir/a', fnamemodify('../testdir/a', ':~'))
  call assert_equal('a', '../testdir/a'->fnamemodify(':t'))
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
  call assert_equal(getcwd(), fnamemodify('', ':p:h'))

  let cwd = getcwd()
  call chdir($HOME)
  call assert_equal('foobar', fnamemodify('~/foobar', ':~:.'))
  call chdir(cwd)
  call mkdir($HOME . '/XXXXXXXX/a', 'p')
  call mkdir($HOME . '/XXXXXXXX/b', 'p')
  call chdir($HOME . '/XXXXXXXX/a/')
  call assert_equal('foo', fnamemodify($HOME . '/XXXXXXXX/a/foo', ':p:~:.'))
  call assert_equal('~/XXXXXXXX/b/foo', fnamemodify($HOME . '/XXXXXXXX/b/foo', ':p:~:.'))
  call mkdir($HOME . '/XXXXXXXX/a.ext', 'p')
  call assert_equal('~/XXXXXXXX/a.ext/foo', fnamemodify($HOME . '/XXXXXXXX/a.ext/foo', ':p:~:.'))
  call chdir(cwd)
  call delete($HOME . '/XXXXXXXX', 'rf')

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
  let &shellslash = save_shellslash
endfunc

func Test_fnamemodify_er()
  call assert_equal("with", fnamemodify("path/to/file.with.extensions", ':e:e:r:r'))

  call assert_equal('c', fnamemodify('a.c', ':e'))
  call assert_equal('c', fnamemodify('a.c', ':e:e'))
  call assert_equal('c', fnamemodify('a.c', ':e:e:r'))
  call assert_equal('c', fnamemodify('a.c', ':e:e:r:r'))

  call assert_equal('rb', fnamemodify('a.spec.rb', ':e:r'))
  call assert_equal('rb', fnamemodify('a.spec.rb', ':e:r'))
  call assert_equal('spec.rb', fnamemodify('a.spec.rb', ':e:e'))
  call assert_equal('spec', fnamemodify('a.spec.rb', ':e:e:r'))
  call assert_equal('spec', fnamemodify('a.spec.rb', ':e:e:r:r'))
  call assert_equal('spec', fnamemodify('a.b.spec.rb', ':e:e:r'))
  call assert_equal('b.spec', fnamemodify('a.b.spec.rb', ':e:e:e:r'))
  call assert_equal('b', fnamemodify('a.b.spec.rb', ':e:e:e:r:r'))

  call assert_equal('spec', fnamemodify('a.b.spec.rb', ':r:e'))
  call assert_equal('b', fnamemodify('a.b.spec.rb', ':r:r:e'))

  call assert_equal('c', fnamemodify('a.b.c.d.e', ':r:r:e'))
  call assert_equal('b.c', fnamemodify('a.b.c.d.e', ':r:r:e:e'))

  " :e never includes the whole filename, so "a.b":e:e:e --> "b"
  call assert_equal('b.c', fnamemodify('a.b.c.d.e', ':r:r:e:e:e'))
  call assert_equal('b.c', fnamemodify('a.b.c.d.e', ':r:r:e:e:e:e'))

  call assert_equal('', fnamemodify('', ':p:t'))
  call assert_equal('', fnamemodify(v:_null_string, v:_null_string))
endfunc

func Test_fnamemodify_fail()
  call assert_fails('call fnamemodify({}, ":p")', 'E731:')
  call assert_fails('call fnamemodify("x", {})', 'E731:')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
