local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local get_pathsep = helpers.get_pathsep
local command = helpers.command

describe("'%:p' expanding", function()
  local pathsep
  local targetdir
  local expected_path

  local function get_full_path()
    return eval('expand("%:p")')
  end

  local function join_path(...)
    return table.concat({...}, pathsep)
  end

  before_each(function()
    clear()
    pathsep = get_pathsep()
    targetdir = join_path('test', 'functional', 'fixtures')
    clear(join_path(targetdir, 'tty-test.c'))
    expected_path = get_full_path()
  end)

  it('given a relative path with current directory in the middle #7117', function()
    clear(join_path(targetdir, '.', 'tty-test.c'))
    eq(expected_path, get_full_path())
  end)

  it('given a relative path with current directory #7117', function()
    clear(join_path('.', targetdir, 'tty-test.c'))
    eq(expected_path, get_full_path())
  end)

  it('given a relative path with current directory to a file when changing directory #7117', function()
    clear(join_path('.', targetdir, 'tty-test.c'))
    command('cd test')
    eq(expected_path, get_full_path())
  end)

  it('given a relative path with directory up the tree to a file #7117', function()
    clear(join_path(targetdir, '..', 'fixtures', 'tty-test.c'))
    eq(expected_path, get_full_path())
  end)

  it('given a different starting directory and a relative path with directory up the tree #7117', function()
    command('cd test')
    command('e ' .. join_path('..', targetdir, 'tty-test.c'))
    eq(expected_path, get_full_path())
  end)

  it('given a different starting directory and a relative path with current directory and up the tree #7117', function()
    command('cd test')
    command('e ' .. join_path('.', '..', targetdir, 'tty-test.c'))
    eq(expected_path, get_full_path())
  end)
end)
