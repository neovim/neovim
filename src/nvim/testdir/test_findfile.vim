" Test findfile() and finddir()

let s:files = [ 'Xdir1/foo',
      \         'Xdir1/bar',
      \         'Xdir1/Xdir2/foo',
      \         'Xdir1/Xdir2/foobar',
      \         'Xdir1/Xdir2/Xdir3/bar',
      \         'Xdir1/Xdir2/Xdir3/barfoo' ]

func CreateFiles()
  call mkdir('Xdir1/Xdir2/Xdir3/Xdir2', 'p')
  for f in s:files
    call writefile([], f)
  endfor
endfunc

func CleanFiles()
  " Safer to delete each file even if it's more verbose
  " than doing a recursive delete('Xdir1', 'rf').
  for f in s:files
    call delete(f)
  endfor

  call delete('Xdir1/Xdir2/Xdir3/Xdir2', 'd')
  call delete('Xdir1/Xdir2/Xdir3', 'd')
  call delete('Xdir1/Xdir2', 'd')
  call delete('Xdir1', 'd')
endfunc

" Test findfile({name} [, {path} [, {count}]])
func Test_findfile()
  let save_path = &path
  let save_shellslash = &shellslash
  let save_dir = getcwd()
  set shellslash
  call CreateFiles()
  cd Xdir1
  e Xdir2/foo

  " With ,, in path, findfile() searches in current directory.
  set path=,,
  call assert_equal('foo', findfile('foo'))
  call assert_equal('bar', findfile('bar'))
  call assert_equal('',    findfile('foobar'))

  " Directories should not be found (finddir() finds them).
  call assert_equal('', findfile('Xdir2'))

  " With . in 'path', findfile() searches relatively to current file.
  set path=.
  call assert_equal('Xdir2/foo',    findfile('foo'))
  call assert_equal('',             findfile('bar'))
  call assert_equal('Xdir2/foobar', findfile('foobar'))

  " Empty {path} 2nd argument is the same as no 2nd argument.
  call assert_equal('Xdir2/foo', findfile('foo', ''))
  call assert_equal('',          findfile('bar', ''))

  " Test with *
  call assert_equal('Xdir2/foo',       findfile('foo', '*'))
  call assert_equal('',                findfile('bar', '*'))
  call assert_equal('Xdir2/Xdir3/bar', findfile('bar', '*/*'))
  call assert_equal('Xdir2/Xdir3/bar', findfile('bar', 'Xdir2/*'))
  call assert_equal('Xdir2/Xdir3/bar', findfile('bar', 'Xdir*/Xdir3'))
  call assert_equal('Xdir2/Xdir3/bar', findfile('bar', '*2/*3'))

  " Test with **
  call assert_equal('bar',             findfile('bar', '**'))
  call assert_equal('Xdir2/Xdir3/bar', findfile('bar', '**/Xdir3'))
  call assert_equal('Xdir2/Xdir3/bar', findfile('bar', 'Xdir2/**'))

  call assert_equal('Xdir2/Xdir3/barfoo', findfile('barfoo', '**2'))
  call assert_equal('',                   findfile('barfoo', '**1'))
  call assert_equal('Xdir2/foobar',       findfile('foobar', '**1'))

  " Test with {count} 3rd argument.
  call assert_equal('bar',                      findfile('bar', '**', 0))
  call assert_equal('bar',                      findfile('bar', '**', 1))
  call assert_equal('Xdir2/Xdir3/bar',          findfile('bar', '**', 2))
  call assert_equal('',                         findfile('bar', '**', 3))
  call assert_equal(['bar', 'Xdir2/Xdir3/bar'], findfile('bar', '**', -1))

  " Test upwards search.
  cd Xdir2/Xdir3
  call assert_equal('bar',                findfile('bar', ';'))
  call assert_match('.*/Xdir1/Xdir2/foo', findfile('foo', ';'))
  call assert_match('.*/Xdir1/Xdir2/foo', findfile('foo', ';', 1))
  call assert_match('.*/Xdir1/foo',       findfile('foo', ';', 2))
  call assert_match('.*/Xdir1/foo',       findfile('foo', ';', 2))
  call assert_match('.*/Xdir1/Xdir2/foo', findfile('foo', 'Xdir2;', 1))
  call assert_equal('',                   findfile('foo', 'Xdir2;', 2))

  " List l should have at least 2 values (possibly more if foo file
  " happens to be found upwards above Xdir1).
  let l = findfile('foo', ';', -1)
  call assert_match('.*/Xdir1/Xdir2/foo', l[0])
  call assert_match('.*/Xdir1/foo',       l[1])

  " Test upwards search with stop-directory.
  cd Xdir2
  let l = findfile('bar', ';' . save_dir . '/Xdir1/Xdir2/', -1)
  call assert_equal(1, len(l))
  call assert_match('.*/Xdir1/Xdir2/Xdir3/bar', l[0])

  let l = findfile('bar', ';' . save_dir . '/Xdir1/', -1)
  call assert_equal(2, len(l))
  call assert_match('.*/Xdir1/Xdir2/Xdir3/bar', l[0])
  call assert_match('.*/Xdir1/bar',             l[1])

  " Test combined downwards and upwards search from Xdir2/.
  cd ../..
  call assert_equal('Xdir3/bar',    findfile('bar', '**;', 1))
  call assert_match('.*/Xdir1/bar', findfile('bar', '**;', 2))

  bwipe!
  exe 'cd  ' . save_dir
  call CleanFiles()
  let &path = save_path
  let &shellslash = save_shellslash
endfunc

" Test finddir({name} [, {path} [, {count}]])
func Test_finddir()
  let save_path = &path
  let save_shellslash = &shellslash
  let save_dir = getcwd()
  set path=,,
  call CreateFiles()
  cd Xdir1

  call assert_equal('Xdir2', finddir('Xdir2'))
  call assert_equal('',      finddir('Xdir3'))

  " Files should not be found (findfile() finds them).
  call assert_equal('', finddir('foo'))

  call assert_equal('Xdir2',       finddir('Xdir2', '**'))
  call assert_equal('Xdir2/Xdir3', finddir('Xdir3', '**'))

  call assert_equal('Xdir2',               finddir('Xdir2', '**', 1))
  call assert_equal('Xdir2/Xdir3/Xdir2',   finddir('Xdir2', '**', 2))
  call assert_equal(['Xdir2',
        \            'Xdir2/Xdir3/Xdir2'], finddir('Xdir2', '**', -1))

  call assert_equal('Xdir2',       finddir('Xdir2', '**1'))
  call assert_equal('Xdir2',       finddir('Xdir2', '**0'))
  call assert_equal('Xdir2/Xdir3', finddir('Xdir3', '**1'))
  call assert_equal('',            finddir('Xdir3', '**0'))

  " Test upwards dir search.
  cd Xdir2/Xdir3
  call assert_match('.*/Xdir1', finddir('Xdir1', ';'))

  " Test upwards search with stop-directory.
  call assert_match('.*/Xdir1', finddir('Xdir1', ';' . save_dir . '/'))
  call assert_equal('',         finddir('Xdir1', ';' . save_dir . '/Xdir1/'))

  " Test combined downwards and upwards dir search from Xdir2/.
  cd ..
  call assert_match('.*/Xdir1',       finddir('Xdir1', '**;', 1))
  call assert_equal('Xdir3/Xdir2',    finddir('Xdir2', '**;', 1))
  call assert_match('.*/Xdir1/Xdir2', finddir('Xdir2', '**;', 2))
  call assert_equal('Xdir3',          finddir('Xdir3', '**;', 1))

  exe 'cd  ' . save_dir
  call CleanFiles()
  let &path = save_path
  let &shellslash = save_shellslash
endfunc
