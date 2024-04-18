local t = require('test.functional.testutil')()
local clear = t.clear
local command = t.command
local eq = t.eq
local eval = t.eval
local feed = t.feed
local fn = t.fn
local insert = t.insert
local is_os = t.is_os
local mkdir = t.mkdir
local rmdir = t.rmdir
local write_file = t.write_file

local function join_path(...)
  local pathsep = (is_os('win') and '\\' or '/')
  return table.concat({ ... }, pathsep)
end

describe('path collapse', function()
  local targetdir
  local expected_path

  before_each(function()
    targetdir = join_path('test', 'functional', 'fixtures')
    clear()
    command('edit ' .. join_path(targetdir, 'tty-test.c'))
    expected_path = eval('expand("%:p")')
  end)

  it('with /./ segment #7117', function()
    command('edit ' .. join_path(targetdir, '.', 'tty-test.c'))
    eq(expected_path, eval('expand("%:p")'))
  end)

  it('with ./ prefix #7117', function()
    command('edit ' .. join_path('.', targetdir, 'tty-test.c'))
    eq(expected_path, eval('expand("%:p")'))
  end)

  it('with ./ prefix, after directory change #7117', function()
    command('edit ' .. join_path('.', targetdir, 'tty-test.c'))
    command('cd test')
    eq(expected_path, eval('expand("%:p")'))
  end)

  it('with /../ segment #7117', function()
    command('edit ' .. join_path(targetdir, '..', 'fixtures', 'tty-test.c'))
    eq(expected_path, eval('expand("%:p")'))
  end)

  it('with ../ and different starting directory #7117', function()
    command('cd test')
    command('edit ' .. join_path('..', targetdir, 'tty-test.c'))
    eq(expected_path, eval('expand("%:p")'))
  end)

  it('with ./../ and different starting directory #7117', function()
    command('cd test')
    command('edit ' .. join_path('.', '..', targetdir, 'tty-test.c'))
    eq(expected_path, eval('expand("%:p")'))
  end)
end)

describe('expand wildcard', function()
  before_each(clear)

  it('with special characters #24421', function()
    local folders = is_os('win') and {
      '{folder}',
      'folder$name',
    } or {
      'folder-name',
      'folder#name',
    }
    for _, folder in ipairs(folders) do
      mkdir(folder)
      local file = join_path(folder, 'file.txt')
      write_file(file, '')
      eq(file, eval('expand("' .. folder .. '/*")'))
      rmdir(folder)
    end
  end)
end)

describe('file search', function()
  local testdir = 'Xtest_path_spec'

  before_each(clear)

  setup(function()
    mkdir(testdir)
  end)

  teardown(function()
    rmdir(testdir)
  end)

  it('gf finds multibyte filename in line #20517', function()
    command('cd test/functional/fixtures')
    insert('filename_with_unicode_ααα')
    eq('', eval('expand("%")'))
    feed('gf')
    eq('filename_with_unicode_ααα', eval('expand("%:t")'))
  end)

  it('gf/<cfile> matches Windows drive-letter filepaths (without ":" in &isfname)', function()
    local iswin = is_os('win')
    local function test_cfile(input, expected, expected_win)
      expected = (iswin and expected_win or expected) or input
      command('%delete')
      insert(input)
      command('norm! 0')
      eq(expected, eval('expand("<cfile>")'))
    end

    test_cfile([[c:/d:/foo/bar.txt]]) -- TODO(justinmk): should return "d:/foo/bar.txt" ?
    test_cfile([[//share/c:/foo/bar/]])
    test_cfile([[file://c:/foo/bar]])
    test_cfile([[file://c:/foo/bar:42]])
    test_cfile([[file://c:/foo/bar:42:666]])
    test_cfile([[https://c:/foo/bar]])
    test_cfile([[\foo\bar]], [[foo]], [[\foo\bar]])
    test_cfile([[/foo/bar]], [[/foo/bar]])
    test_cfile([[c:\foo\bar]], [[c:]], [[c:\foo\bar]])
    test_cfile([[c:\foo\bar:42:666]], [[c:]], [[c:\foo\bar]])
    test_cfile([[c:/foo/bar]])
    test_cfile([[c:/foo/bar:42]], [[c:/foo/bar]])
    test_cfile([[c:/foo/bar:42:666]], [[c:/foo/bar]])
    test_cfile([[c:foo\bar]], [[c]])
    test_cfile([[c:foo/bar]], [[c]])
    test_cfile([[c:foo]], [[c]])
    -- Examples from: https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats#example-ways-to-refer-to-the-same-file
    test_cfile([[c:\temp\test-file.txt]], [[c:]], [[c:\temp\test-file.txt]])
    test_cfile(
      [[\\127.0.0.1\c$\temp\test-file.txt]],
      [[127.0.0.1]],
      [[\\127.0.0.1\c$\temp\test-file.txt]]
    )
    test_cfile(
      [[\\LOCALHOST\c$\temp\test-file.txt]],
      [[LOCALHOST]],
      [[\\LOCALHOST\c$\temp\test-file.txt]]
    )
    -- not supported yet
    test_cfile([[\\.\c:\temp\test-file.txt]], [[.]], [[\\.\c]])
    -- not supported yet
    test_cfile([[\\?\c:\temp\test-file.txt]], [[c:]], [[\\]])
    test_cfile(
      [[\\.\UNC\LOCALHOST\c$\temp\test-file.txt]],
      [[.]],
      [[\\.\UNC\LOCALHOST\c$\temp\test-file.txt]]
    )
    test_cfile(
      [[\\127.0.0.1\c$\temp\test-file.txt]],
      [[127.0.0.1]],
      [[\\127.0.0.1\c$\temp\test-file.txt]]
    )
  end)

  ---@param funcname 'finddir' | 'findfile'
  local function test_find_func(funcname, folder, item)
    local d = join_path(testdir, folder)
    mkdir(d)
    local expected = join_path(d, item)
    if funcname == 'finddir' then
      mkdir(expected)
    else
      write_file(expected, '')
    end
    eq(expected, fn[funcname](item, d:gsub(' ', [[\ ]])))
  end

  it('finddir()', function()
    test_find_func('finddir', 'directory', 'folder')
    test_find_func('finddir', 'directory', 'folder name')
    test_find_func('finddir', 'fold#er name', 'directory')
  end)

  it('findfile()', function()
    test_find_func('findfile', 'directory', 'file.txt')
    test_find_func('findfile', 'directory', 'file name.txt')
    test_find_func('findfile', 'fold#er name', 'file.txt')
  end)
end)
