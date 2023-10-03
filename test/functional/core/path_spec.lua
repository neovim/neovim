local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local command = helpers.command
local insert = helpers.insert
local feed = helpers.feed
local is_os = helpers.is_os
local mkdir = helpers.mkdir
local rmdir = helpers.rmdir
local write_file = helpers.write_file

local function join_path(...)
  local pathsep = (is_os('win') and '\\' or '/')
  return table.concat({...}, pathsep)
end

describe('path collapse', function()
  local targetdir
  local expected_path

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

describe('expand wildcard', function()
  before_each(clear)

  it('with special characters #24421', function()
    local folders = is_os('win') and {
      '{folder}',
      'folder$name'
    } or {
      'folder-name',
      'folder#name'
    }
    for _, folder in ipairs(folders) do
      mkdir(folder)
      local file = join_path(folder, 'file.txt')
      write_file(file, '')
      eq(file, eval('expand("'..folder..'/*")'))
      rmdir(folder)
    end
  end)
end)

describe('file search', function()
  before_each(clear)

  it('find multibyte file name in line #20517', function()
    command('cd test/functional/fixtures')
    insert('filename_with_unicode_ααα')
    eq('', eval('expand("%")'))
    feed('gf')
    eq('filename_with_unicode_ααα', eval('expand("%:t")'))
  end)
end)
