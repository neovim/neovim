" Tests for the 'find' command completion.

" Do all the tests in a separate window to avoid E211 when we recursively
" delete the Xfind directory during cleanup
func Test_find_complete()
  let shellslash = &shellslash
  set shellslash
  set belloff=all

  " On windows a stale "Xfind" directory may exist, remove it so that
  " we start from a clean state.
  call delete("Xfind", "rf")
  let cwd = getcwd()
  let test_out = cwd . '/test.out'
  call mkdir('Xfind')
  cd Xfind

  new
  set path=
  call assert_fails('call feedkeys(":find\t\n", "xt")', 'E345:')
  close

  new
  set path=.
  call assert_fails('call feedkeys(":find\t\n", "xt")', 'E32:')
  close

  new
  set path=.,,
  call assert_fails('call feedkeys(":find\t\n", "xt")', 'E32:')
  close

  new
  set path=./**
  call assert_fails('call feedkeys(":find\t\n", "xt")', 'E32:')
  close

  " We shouldn't find any file till this point

  call mkdir('in/path', 'p')
  exe 'cd ' . cwd
  call writefile(['Holy Grail'], 'Xfind/file.txt')
  call writefile(['Jimmy Hoffa'], 'Xfind/in/file.txt')
  call writefile(['Another Holy Grail'], 'Xfind/in/stuff.txt')
  call writefile(['E.T.'], 'Xfind/in/path/file.txt')

  new
  set path=Xfind/**
  call feedkeys(":find file\t\n", "xt")
  call assert_equal('Holy Grail', getline(1))
  call feedkeys(":find file\t\t\n", "xt")
  call assert_equal('Jimmy Hoffa', getline(1))
  call feedkeys(":find file\t\t\t\n", "xt")
  call assert_equal('E.T.', getline(1))

  " Rerun the previous three find completions, using fullpath in 'path'
  exec "set path=" . cwd . "/Xfind/**"

  call feedkeys(":find file\t\n", "xt")
  call assert_equal('Holy Grail', getline(1))
  call feedkeys(":find file\t\t\n", "xt")
  call assert_equal('Jimmy Hoffa', getline(1))
  call feedkeys(":find file\t\t\t\n", "xt")
  call assert_equal('E.T.', getline(1))

  " Same steps again, using relative and fullpath items that point to the same
  " recursive location.
  " This is to test that there are no duplicates in the completion list.
  set path+=Xfind/**
  call feedkeys(":find file\t\n", "xt")
  call assert_equal('Holy Grail', getline(1))
  call feedkeys(":find file\t\t\n", "xt")
  call assert_equal('Jimmy Hoffa', getline(1))
  call feedkeys(":find file\t\t\t\n", "xt")
  call assert_equal('E.T.', getline(1))
  call feedkeys(":find file\t\t\n", "xt")

  " Test find completion for directory of current buffer, which at this point
  " is Xfind/in/file.txt.
  set path=.
  call feedkeys(":find st\t\n", "xt")
  call assert_equal('Another Holy Grail', getline(1))

  " Test find completion for empty path item ",," which is the current
  " directory
  cd Xfind
  set path=,,
  call feedkeys(":find f\t\n", "xt")
  call assert_equal('Holy Grail', getline(1))

  " Test shortening of
  "
  "    foo/x/bar/voyager.txt
  "    foo/y/bar/voyager.txt
  "
  " When current directory is above foo/ they should be shortened to (in order
  " of appearance):
  "
  "    x/bar/voyager.txt
  "    y/bar/voyager.txt
  call mkdir('foo/x/bar', 'p')
  call mkdir('foo/y/bar', 'p')
  call writefile(['Voyager 1'], 'foo/x/bar/voyager.txt')
  call writefile(['Voyager 2'], 'foo/y/bar/voyager.txt')

  exec "set path=" . cwd . "/Xfind/**"
  call feedkeys(":find voyager\t\n", "xt")
  call assert_equal('Voyager 1', getline(1))
  call feedkeys(":find voyager\t\t\n", "xt")
  call assert_equal('Voyager 2', getline(1))

  "
  " When current directory is .../foo/y/bar they should be shortened to (in
  " order of appearance):
  "
  "    ./voyager.txt
  "    x/bar/voyager.txt
  cd foo/y/bar
  call feedkeys(":find voyager\t\n", "xt")
  call assert_equal('Voyager 2', getline(1))
  call feedkeys(":find voyager\t\t\n", "xt")
  call assert_equal('Voyager 1', getline(1))

  " Check the opposite too:
  cd ../../x/bar
  call feedkeys(":find voyager\t\n", "xt")
  call assert_equal('Voyager 1', getline(1))
  call feedkeys(":find voyager\t\t\n", "xt")
  call assert_equal('Voyager 2', getline(1))

  " Check for correct handling of shorten_fname()'s behavior on windows
  exec "cd " . cwd . "/Xfind/in"
  call feedkeys(":find file\t\n", "xt")
  call assert_equal('Jimmy Hoffa', getline(1))

  " Test for relative to current buffer 'path' item
  exec "cd " . cwd . "/Xfind/"
  set path=./path
  " Open the file where Jimmy Hoffa is found
  e in/file.txt
  " Find the file containing 'E.T.' in the Xfind/in/path directory
  call feedkeys(":find file\t\n", "xt")
  call assert_equal('E.T.', getline(1))

  " Test that completion works when path=.,,
  set path=.,,
  " Open Jimmy Hoffa file
  e in/file.txt
  call assert_equal('Jimmy Hoffa', getline(1))

  " Search for the file containing Holy Grail in same directory as in/path.txt
  call feedkeys(":find stu\t\n", "xt")
  call assert_equal('Another Holy Grail', getline(1))

  enew | only
  exe 'cd ' . cwd
  call delete('Xfind', 'rf')
  set path&
  let &shellslash = shellslash
endfunc
