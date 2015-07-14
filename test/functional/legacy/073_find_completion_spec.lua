-- Tests for find completion.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local write_file = helpers.write_file

describe(':find completion', function()
  setup(function()
    clear()
    lfs.mkdir('Xfind')
  end)
  teardown(function()
    os.execute('rm -rf Xfind')
  end)

  it('is working', function()
    -- This test relies on the default setting of 'wildmode' as it was in
    -- plain Vim.
    execute('set wildmode=full')
    -- This will cause a few errors, do it silently.
    execute('set visualbell')
    -- Do all test in a separate window to avoid E211 when we recursively
    -- delete the Xfind directory during cleanup.
    execute('new')
    execute('let cwd=getcwd()')
    execute('let test_out = cwd . "/test.out"')
    execute('cd Xfind')
    execute('set path=')
    execute('find 	')
    source([[
      exec "w! " . test_out
      close
      new
      set path=.
    ]])
    execute('find 	')
    execute('exec "w >>" . test_out')
    execute('close')
    execute('new')
    execute('set path=.,,')
    execute('find 	')
    execute('exec "w >>" . test_out')
    execute('close')
    execute('new')
    execute('set path=./**')
    execute('find 	')
    execute('exec "w >>" . test_out')
    execute('close')
    execute('new')
    -- We shouldn't find any file at this point, test.out must be empty.
    lfs.mkdir('Xfind/in')
    lfs.mkdir('Xfind/in/path')
    write_file('Xfind/file.txt', 'Holy Grail\n')
    write_file('Xfind/in/file.txt', 'Jimmy Hoffa\n')
    write_file('Xfind/in/stuff.txt', 'Another Holy Grail\n')
    write_file('Xfind/in/path/file.txt', 'E.T.\n')
    execute('exec "cd " . cwd')
    execute('set path=Xfind/**')
    execute('find file	')
    execute('exec "w >>" . test_out')
    execute('find file		')
    execute('exec "w >>" . test_out')
    execute('find file			')
    execute('exec "w >>" . test_out')
    -- Rerun the previous three find completions, using fullpath in 'path'.
    execute('exec "set path=" . cwd . "/Xfind/**"')
    execute('find file	')
    execute('exec "w >>" .  test_out')
    execute('find file		')
    execute('exec "w >>" . test_out')
    execute('find file			')
    execute('exec "w >>" . test_out')
    -- Same steps again, using relative and fullpath items that point to the
    -- same.  Recursive location.
    -- This is to test that there are no duplicates in the completion list.
    execute('exec "set path+=Xfind/**"')
    execute('find file	')
    execute('exec "w >>" .  test_out')
    execute('find file		')
    execute('exec "w >>" . test_out')
    execute('find file			')
    execute('exec "w >>" . test_out')
    execute('find file		')
    -- Test find completion for directory of current buffer, which at this
    -- point is Xfind/in/file.txt.
    execute('set path=.')
    execute('find st	')
    execute('exec "w >>" .  test_out')
    -- Test find completion for empty path item ",," which is the current
    -- directory.
    execute('cd Xfind')
    execute('set path=,,')
    execute('find f		')
    execute('exec "w >>" . test_out')
    -- Test shortening of
    --
    --   foo/x/bar/voyager.txt
    --   foo/y/bar/voyager.txt
    --
    -- When current directory is above foo/ they should be shortened to (in
    -- order of appearance):
    --
    --   x/bar/voyager.txt.
    --   y/bar/voyager.txt.
    lfs.mkdir('Xfind/foo')
    lfs.mkdir('Xfind/foo/x')
    lfs.mkdir('Xfind/foo/x/bar')
    lfs.mkdir('Xfind/foo/y')
    lfs.mkdir('Xfind/foo/y/bar')
    -- We should now be in the Xfind directory.
    helpers.eq('Xfind', helpers.eval('fnamemodify(getcwd(), ":t")'))
    write_file('Xfind/foo/x/bar/voyager.txt', 'Voyager 1\n')
    write_file('Xfind/foo/y/bar/voyager.txt', 'Voyager 2\n')
    execute('exec "set path=" . cwd . "/Xfind/**"')
    execute('find voyager	')
    execute('exec "w >>" . test_out')
    execute('find voyager		')
    execute('exec "w >>" . test_out')

    -- When current directory is .../foo/y/bar they should be shortened to (in
    -- order of appearance):
    --
    --   ./voyager.txt
    --   x/bar/voyager.txt
    execute('cd foo')
    execute('cd y')
    execute('cd bar')
    execute('find voyager	')
    execute('exec "w >> " . test_out')
    execute('find voyager		')
    execute('exec "w >> " . test_out')
    -- Check the opposite too:.
    execute('cd ..')
    execute('cd ..')
    execute('cd x')
    execute('cd bar')
    execute('find voyager	')
    execute('exec "w >> " . test_out')
    execute('find voyager		')
    execute('exec "w >> " . test_out')
    -- Check for correct handling of shorten_fname()'s behavior on windows.
    execute('exec "cd " . cwd . "/Xfind/in"')
    execute('find file	')
    execute('exec "w >>" . test_out')
    -- Test for relative to current buffer 'path' item.
    execute('exec "cd " . cwd . "/Xfind/"')
    execute('set path=./path')
    -- Open the file where Jimmy Hoffa is found.
    execute('e in/file.txt')
    -- Find the file containing 'E.T.' in the Xfind/in/path directory.
    execute('find file	')
    execute('exec "w >>" . test_out')

    -- Test that completion works when path=.,,.

    execute('set path=.,,')
    -- Open Jimmy Hoffa file.
    execute('e in/file.txt')
    execute('exec "w >>" . test_out')
    -- Search for the file containing Holy Grail in same directory as in/path.txt.
    execute('find stu	')
    execute('exec "w >>" . test_out')
    execute('q')
    execute('exec "cd " . cwd')
    execute('e test.out')

    -- Assert buffer contents.
    expect([[
      Holy Grail
      Jimmy Hoffa
      E.T.
      Holy Grail
      Jimmy Hoffa
      E.T.
      Holy Grail
      Jimmy Hoffa
      E.T.
      Another Holy Grail
      Holy Grail
      Voyager 1
      Voyager 2
      Voyager 2
      Voyager 1
      Voyager 1
      Voyager 2
      Jimmy Hoffa
      E.T.
      Jimmy Hoffa
      Another Holy Grail]])
  end)
end)
