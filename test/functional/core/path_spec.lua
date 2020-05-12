local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local command = helpers.command
local iswin = helpers.iswin

describe('path collapse', function()
  local targetdir
  local expected_path

  local function join_path(...)
    local pathsep = (iswin() and '\\' or '/')
    return table.concat({...}, pathsep)
  end

  before_each(function()
    targetdir = join_path('test', 'functional', 'fixtures')
    clear()
    command('edit '..join_path(targetdir, 'tty-test.c'))
    expected_path = eval('expand("%:p")')
  end)

  it('with /./ segment #7117', function()
    command('edit '..join_path(targetdir, '.', 'tty-test.c'))
    eq(expected_path, eval('expand("%:p")'))
  end)

  it('with ./ prefix #7117', function()
    command('edit '..join_path('.', targetdir, 'tty-test.c'))
    eq(expected_path, eval('expand("%:p")'))
  end)

  it('with ./ prefix, after directory change #7117', function()
    command('edit '..join_path('.', targetdir, 'tty-test.c'))
    command('cd test')
    eq(expected_path, eval('expand("%:p")'))
  end)

  it('with /../ segment #7117', function()
    command('edit '..join_path(targetdir, '..', 'fixtures', 'tty-test.c'))
    eq(expected_path, eval('expand("%:p")'))
  end)

  it('with ../ and different starting directory #7117', function()
    command('cd test')
    command('edit '..join_path('..', targetdir, 'tty-test.c'))
    eq(expected_path, eval('expand("%:p")'))
  end)

  it('with ./../ and different starting directory #7117', function()
    command('cd test')
    command('edit '..join_path('.', '..', targetdir, 'tty-test.c'))
    eq(expected_path, eval('expand("%:p")'))
  end)
end)
