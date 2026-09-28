local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, setup, teardown =
  t.describe, t.it, t.before_each, t.setup, t.teardown
local clear = n.clear
local command = n.command
local eq = t.eq
local eval = n.eval
local feed = n.feed
local fn = n.fn
local insert = n.insert
local is_os = t.is_os
local mkdir = t.mkdir
local rmdir = n.rmdir
local write_file = t.write_file
local api = n.api

local function join_path(...)
  return table.concat({ ... }, '/')
end

describe('path', function()
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

  it('with implicit drive letter #40013', function()
    t.skip(not is_os('win'), 'N/A: only works on Windows')
    command('edit ' .. expected_path:sub(3))
    eq(1, #fn.getbufinfo())
    eq(expected_path, eval('expand("%:p")'))
  end)
end)

describe('startup', function()
  local home, foo, bar = vim.fs.normalize('~'), 'Xtest-foo.lua', 'Xtest-bar.lua'

  setup(function()
    write_file(('%s/%s'):format(home, foo), 'local foo = 1;')
    write_file(('%s/%s'):format(home, bar), '')
  end)

  teardown(function()
    os.remove(('%s/%s'):format(home, foo))
    os.remove(('%s/%s'):format(home, bar))
  end)

  it('expands tilde-prefixed paths #29380', function()
    t.skip(not is_os('win'), 'N/A: shell expands ~ on Unix')
    clear {
      args = { ('~/%s'):format(foo), ('~\\%s'):format(bar) },
    }
    local expected = { ('%s/%s'):format(home, foo), ('%s/%s'):format(home, bar) }
    eq(expected, vim.tbl_map(fn.bufname, api.nvim_list_bufs()))
    eq(expected, fn.argv())
  end)

  it('normalizes v:progpath #39382', function()
    clear()
    eq(
      n.nvim_prog,
      fn.system({
        is_os('win') and n.nvim_prog:gsub('/', '\\') or n.nvim_prog,
        '--clean',
        '--headless',
        '+echo v:progpath',
        '+q',
      })
    )
  end)

  it('normalizes -u arguments and triggers autocmd events #39382', function()
    local file = ('%s/%s'):format(home, foo)
    if is_os('win') then
      file = file:gsub('/', '\\')
    end
    clear {
      args_rm = { '--cmd', '-u' },
      args = {
        '--cmd',
        ('autocmd SourcePre */%s let g:matched = 1'):format(foo),
        '-u',
        file,
      },
    }
    local scripts = fn.getscriptinfo({ name = foo })
    eq(1, #scripts)
    eq(('%s/%s'):format(home, foo), scripts[1].name)
    t.ok(fn.eval('g:matched'))
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
      local file = ('%s%sfile.txt'):format(folder, n.get_pathsep())
      write_file(file, '')
      eq(file, fn.expand(('%s/*'):format(folder)))
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
    local function test_cfile(input, char, expected, expected_win)
      expected = (iswin and expected_win or expected) or input
      command('%delete')
      insert(input)
      command(char and ('norm! F%s'):format(char) or 'norm! 0')
      eq(expected, eval('expand("<cfile>")'))
    end

    -- Common path formats
    test_cfile([[/foo/bar.z]], nil, [[/foo/bar.z]])
    test_cfile([[\foo\bar.z]], nil, [[foo]], [[\foo\bar.z]])
    test_cfile([[/foo/bar.z]], 'f', [[/foo/bar.z]])
    test_cfile([[\foo\bar.z]], 'f', [[foo]], [[\foo\bar.z]])
    test_cfile([[/foo/bar.z]], '/', [[/foo/bar.z]]) -- 2nd '/'
    test_cfile([[\foo\bar.z]], '\\', [[bar.z]], [[\foo\bar.z]]) -- 2nd '\'
    test_cfile([[/foo/bar.z]], 'b', [[/foo/bar.z]])
    test_cfile([[\foo\bar.z]], 'b', [[bar.z]], [[\foo\bar.z]])
    -- Unix treats 'c:/' as a url, but doesn't treat '\' as a sep
    test_cfile([[c:/bar.z]], 'c', [[c:/bar.z]], [[c:/bar.z]])
    test_cfile([[c:\bar.z]], 'c', [[c]], [[c:\bar.z]])
    -- Relative path on Windows
    test_cfile([[c:foo/bar]], 'c', [[c]], [[c:foo/bar]])
    test_cfile([[c:foo\bar]], 'c', [[c]], [[c:foo\bar]])
    test_cfile([[c:/bar.z:42]], 'c', [[c:/bar.z:42]], [[c:/bar.z]])
    test_cfile([[c:/bar.z:42:666]], 'c', [[c:/bar.z:42:666]], [[c:/bar.z]])
    test_cfile([[c:\bar.z:42:666]], 'c', [[c]], [[c:\bar.z]])

    test_cfile([[*/foo/bar.z]], nil, [[/foo/bar.z]])
    test_cfile([[*\foo\bar.z]], nil, [[foo]], [[\foo\bar.z]])
    test_cfile([[*c:/bar.z]], nil, [[c:/bar.z]], [[c:/bar.z]])
    test_cfile([[*c:\bar.z]], nil, [[c]], [[c:\bar.z]])

    -- edge case, multiple drive letters
    test_cfile([[c:/d:/bar.z]], 'c', [[c:/d:/bar.z]], [[c:/d]])
    test_cfile([[c:\d:\bar.z]], 'c', [[c]], [[c:\d]])
    test_cfile([[c:/d:/bar.z]], 'd', [[c:/d:/bar.z]], [[c:/d]])
    test_cfile([[c:\d:\bar.z]], 'd', [[d]], [[c:\d]])
    test_cfile([[c:/d:/bar.z]], 'b', [[c:/d:/bar.z]], [[d:/bar.z]])
    test_cfile([[c:\d:\bar.z]], 'b', [[bar.z]], [[d:\bar.z]])
    test_cfile([[c:/d:/bar.z]], '/', [[c:/d:/bar.z]], [[d:/bar.z]])
    test_cfile([[c:\d:\bar.z]], '\\', [[bar.z]], [[d:\bar.z]])

    -- common url
    test_cfile([[file://c:/bar.z]], 'f')
    test_cfile([[file://c:/bar.z]], 'c')
    test_cfile([[file://c:/bar.z]], 'b')
    test_cfile([[file://c:/bar.z:42]], 'f')
    test_cfile([[file://c:/bar.z:42]], 'c')
    test_cfile([[file://c:/bar.z:42]], 'b')
    test_cfile([[file://c:/bar.z:42:666]], 'f')
    test_cfile([[file://c:/bar.z:42:666]], 'c')
    test_cfile([[file://c:/bar.z:42:666]], 'b')
    -- 'file:/' prefix is removed on Windows temporarily, see neovim#38915
    test_cfile([[file:/c:/bar.z]], 'f', [[/c:/bar.z]], [[c:/bar.z]])

    -- filepath, since path sep is not a valid scheme letter
    test_cfile([[/bin:/usr]], 'b', [[/bin]])
    test_cfile([[\bin:\usr]], 'b', [[bin]], [[\bin]])
    test_cfile([[/bin:/usr]], 'u', [[/usr]], [[n:/usr]])
    test_cfile([[\bin:\usr]], 'u', [[usr]], [[n:\usr]])

    -- Examples from: https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats#example-ways-to-refer-to-the-same-file
    test_cfile([[//127.0.0.1/c$/bar.z]], nil)
    test_cfile([[\\127.0.0.1\c$\bar.z]], nil, [[127.0.0.1]], [[\\127.0.0.1\c$\bar.z]])
    test_cfile([[//127.0.0.1/c$/bar.z]], '$')
    test_cfile([[\\127.0.0.1\c$\bar.z]], '$', [[c$]], [[\\127.0.0.1\c$\bar.z]])
    test_cfile([[//localhost/c$/bar.z]], nil)
    test_cfile([[\\localhost\c$\bar.z]], nil, [[localhost]], [[\\localhost\c$\bar.z]])
    -- not fully supported yet
    test_cfile([[//./c:/bar.z]], nil, [[//./c]])
    test_cfile([[\\.\c:\bar.z]], nil, [[.]], [[\\.\c]])
    test_cfile([[//?/c:/bar.z]], nil, [[//]])
    test_cfile([[\\?\c:\bar.z]], nil, [[c]], [[\\]])
    test_cfile([[//./c:/bar.z]], 'c', [[//./c]])
    test_cfile([[\\.\c:\bar.z]], 'c', [[c]], [[\\.\c]])
    test_cfile([[//?/c:/bar.z]], 'c', [[/c]])
    test_cfile([[\\?\c:\bar.z]], 'c', [[c]], [[\c]])
    test_cfile([[//./c:/bar.z]], 'b', [[/bar.z]], [[c:/bar.z]])
    test_cfile([[\\.\c:\bar.z]], 'b', [[bar.z]], [[c:\bar.z]])
    test_cfile([[//?/c:/bar.z]], 'b', [[/bar.z]], [[c:/bar.z]])
    test_cfile([[\\?\c:\bar.z]], 'b', [[bar.z]], [[c:\bar.z]])
    test_cfile([[//./unc/localhost/c$/bar.z]], nil, [[//./unc/localhost/c$/bar.z]])
    test_cfile([[\\.\unc\localhost\c$\bar.z]], nil, [[.]], [[\\.\unc\localhost\c$\bar.z]])
  end)

  it('gf/<cfile> handles local file: paths', function()
    local path = fn.fnamemodify(join_path(testdir, 'gf-target.txt'), ':p'):gsub('\\', '/')
    local uri = 'file:' .. (is_os('win') and '/' or '') .. path
    write_file(path, '')
    insert(uri)
    command('norm! 0')
    eq(path, eval('expand("<cfile>")'))
    feed('gf')
    eq(path, fn.fnamemodify(eval('expand("%:p")'), ':p'):gsub('\\', '/'))
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
