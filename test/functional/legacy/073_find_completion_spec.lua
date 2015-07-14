-- Tests for find completion.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local write_file = helpers.write_file

local function expect_empty_buffer()
  -- The space will be removed by helpers.dedent but is needed as dedent will
  -- throw an error if it can not find the common indent of the given lines.
  return expect(' ')
end

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
    execute('let cwd=getcwd()')
    execute('cd Xfind')
    execute('set path=')
    execute('find \t')
    expect_empty_buffer()
    execute('set path=.')
    execute('find \t')
    expect_empty_buffer()
    execute('set path=.,,')
    execute('find \t')
    expect_empty_buffer()
    execute('set path=./**')
    execute('find \t')
    expect_empty_buffer()
    lfs.mkdir('Xfind/in')
    lfs.mkdir('Xfind/in/path')
    write_file('Xfind/file.txt', 'Holy Grail\n')
    write_file('Xfind/in/file.txt', 'Jimmy Hoffa\n')
    write_file('Xfind/in/stuff.txt', 'Another Holy Grail\n')
    write_file('Xfind/in/path/file.txt', 'E.T.\n')
    execute('exec "cd " . cwd')
    execute('set path=Xfind/**')
    execute('find file\t')
    expect('Holy Grail')
    execute('find file\t\t')
    expect('Jimmy Hoffa')
    execute('find file\t\t\t')
    expect('E.T.')
    -- Rerun the previous three find completions, using fullpath in 'path'.
    execute('exec "set path=" . cwd . "/Xfind/**"')
    execute('find file\t')
    expect('Holy Grail')
    execute('find file\t\t')
    expect('Jimmy Hoffa')
    execute('find file\t\t\t')
    expect('E.T.')
    -- Same steps again, using relative and fullpath items that point to the
    -- same recursive location.  This is to test that there are no duplicates
    -- in the completion list.
    execute('set path+=Xfind/**')
    execute('find file\t')
    expect('Holy Grail')
    execute('find file\t\t')
    expect('Jimmy Hoffa')
    execute('find file\t\t\t')
    expect('E.T.')
    execute('find file\t\t')
    -- Test find completion for directory of current buffer, which at this
    -- point is Xfind/in/file.txt.
    execute('set path=.')
    execute('find st\t')
    expect('Another Holy Grail')
    -- Test find completion for empty path item ",," which is the current
    -- directory.
    execute('cd Xfind')
    execute('set path=,,')
    execute('find f\t\t')
    expect('Holy Grail')
    -- Test shortening of
    --
    --   foo/x/bar/voyager.txt
    --   foo/y/bar/voyager.txt
    --
    -- When current directory is above foo/ they should be shortened to (in
    -- order of appearance):
    --
    --   x/bar/voyager.txt
    --   y/bar/voyager.txt
    lfs.mkdir('Xfind/foo')
    lfs.mkdir('Xfind/foo/x')
    lfs.mkdir('Xfind/foo/x/bar')
    lfs.mkdir('Xfind/foo/y')
    lfs.mkdir('Xfind/foo/y/bar')
    write_file('Xfind/foo/x/bar/voyager.txt', 'Voyager 1\n')
    write_file('Xfind/foo/y/bar/voyager.txt', 'Voyager 2\n')
    execute('exec "set path=" . cwd . "/Xfind/**"')
    execute('find voyager\t')
    expect('Voyager 1')
    execute('find voyager\t\t')
    expect('Voyager 2')

    -- When current directory is .../foo/y/bar they should be shortened to (in
    -- order of appearance):
    --
    --   ./voyager.txt
    --   x/bar/voyager.txt
    execute('cd foo')
    execute('cd y')
    execute('cd bar')
    execute('find voyager\t')
    expect('Voyager 2')
    execute('find voyager\t\t')
    expect('Voyager 1')
    -- Check the opposite too:
    execute('cd ..')
    execute('cd ..')
    execute('cd x')
    execute('cd bar')
    execute('find voyager\t')
    expect('Voyager 1')
    execute('find voyager\t\t')
    expect('Voyager 2')
    -- Check for correct handling of shorten_fname()'s behavior on windows.
    execute('exec "cd " . cwd . "/Xfind/in"')
    execute('find file\t')
    expect('Jimmy Hoffa')
    -- Test for relative to current buffer 'path' item.
    execute('exec "cd " . cwd . "/Xfind/"')
    execute('set path=./path')
    -- Open the file where Jimmy Hoffa is found.
    execute('e in/file.txt')
    -- Find the file containing 'E.T.' in the Xfind/in/path directory.
    execute('find file\t')
    expect('E.T.')

    -- Test that completion works when path=.,,.
    execute('set path=.,,')
    -- Open Jimmy Hoffa file.
    execute('e in/file.txt')
    expect('Jimmy Hoffa')
    -- Search for the file containing Holy Grail in same directory as in/path.txt.
    execute('find stu\t')
    expect('Another Holy Grail')
  end)
end)

