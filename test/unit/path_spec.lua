local lfs = require('lfs')
local helpers = require('test.unit.helpers')

local cimport = helpers.cimport
local eq = helpers.eq
local neq = helpers.neq
local ffi = helpers.ffi
local cstr = helpers.cstr
local to_cstr = helpers.to_cstr
local NULL = helpers.NULL
local OK = helpers.OK
local FAIL = helpers.FAIL

cimport('string.h')
local path = cimport('./src/nvim/path.h')

-- import constants parsed by ffi
local kEqualFiles = path.kEqualFiles
local kDifferentFiles = path.kDifferentFiles
local kBothFilesMissing = path.kBothFilesMissing
local kOneFileMissing = path.kOneFileMissing
local kEqualFileNames = path.kEqualFileNames

local length = 0
local buffer = nil

describe('path function', function()
  describe('path_full_dir_name', function()
    setup(function()
      lfs.mkdir('unit-test-directory')
    end)

    teardown(function()
      lfs.rmdir('unit-test-directory')
    end)

    local function path_full_dir_name(directory, buf, len)
      directory = to_cstr(directory)
      return path.path_full_dir_name(directory, buf, len)
    end

    before_each(function()
      -- Create empty string buffer which will contain the resulting path.
      length = string.len(lfs.currentdir()) + 22
      buffer = cstr(length, '')
    end)

    it('returns the absolute directory name of a given relative one', function()
      local result = path_full_dir_name('..', buffer, length)
      eq(OK, result)
      local old_dir = lfs.currentdir()
      lfs.chdir('..')
      local expected = lfs.currentdir()
      lfs.chdir(old_dir)
      eq(expected, (ffi.string(buffer)))
    end)

    it('returns the current directory name if the given string is empty', function()
      eq(OK, (path_full_dir_name('', buffer, length)))
      eq(lfs.currentdir(), (ffi.string(buffer)))
    end)

    it('fails if the given directory does not exist', function()
      eq(FAIL, path_full_dir_name('does_not_exist', buffer, length))
    end)

    it('works with a normal relative dir', function()
      local result = path_full_dir_name('unit-test-directory', buffer, length)
      eq(lfs.currentdir() .. '/unit-test-directory', (ffi.string(buffer)))
      eq(OK, result)
    end)
  end)

  describe('path_full_compare', function()
    local function path_full_compare(s1, s2, cn)
      s1 = to_cstr(s1)
      s2 = to_cstr(s2)
      return path.path_full_compare(s1, s2, cn or 0)
    end

    local f1 = 'f1.o'
    local f2 = 'f2.o'
    before_each(function()
      -- create the three files that will be used in this spec
      io.open(f1, 'w').close()
      io.open(f2, 'w').close()
    end)

    after_each(function()
      os.remove(f1)
      os.remove(f2)
    end)

    it('returns kEqualFiles when passed the same file', function()
      eq(kEqualFiles, (path_full_compare(f1, f1)))
    end)

    it('returns kEqualFileNames when files that dont exist and have same name', function()
      eq(kEqualFileNames, (path_full_compare('null.txt', 'null.txt', true)))
    end)

    it('returns kBothFilesMissing when files that dont exist', function()
      eq(kBothFilesMissing, (path_full_compare('null.txt', 'null.txt')))
    end)

    it('returns kDifferentFiles when passed different files', function()
      eq(kDifferentFiles, (path_full_compare(f1, f2)))
      eq(kDifferentFiles, (path_full_compare(f2, f1)))
    end)

    it('returns kOneFileMissing if only one does not exist', function()
      eq(kOneFileMissing, (path_full_compare(f1, 'null.txt')))
      eq(kOneFileMissing, (path_full_compare('null.txt', f1)))
    end)
  end)

  describe('path_tail', function()
    local function path_tail(file)
      local res = path.path_tail((to_cstr(file)))
      neq(NULL, res)
      return ffi.string(res)
    end

    it('returns the tail of a given file path', function()
      eq('file.txt', path_tail('directory/file.txt'))
    end)

    it('returns an empty string if file ends in a slash', function()
      eq('', path_tail('directory/'))
    end)
  end)

  describe('path_tail_with_sep', function()
    local function path_tail_with_sep(file)
      local res = path.path_tail_with_sep((to_cstr(file)))
      neq(NULL, res)
      return ffi.string(res)
    end

    it('returns the tail of a file together with its separator', function()
      eq('///file.txt', path_tail_with_sep('directory///file.txt'))
    end)

    it('returns an empty string when given an empty file name', function()
      eq('', path_tail_with_sep(''))
    end)

    it('returns only the separator if there is a trailing separator', function()
      eq('/', path_tail_with_sep('some/directory/'))
    end)

    it('cuts a leading separator', function()
      eq('file.txt', path_tail_with_sep('/file.txt'))
      eq('', path_tail_with_sep('/'))
    end)

    it('returns the whole file name if there is no separator', function()
      eq('file.txt', path_tail_with_sep('file.txt'))
    end)
  end)

  describe('invocation_path_tail', function()
    -- Returns the path tail and length (out param) of the tail.
    -- Does not convert the tail from C-pointer to lua string for use with
    -- strcmp.
    local function invocation_path_tail(invk)
      local plen = ffi.new('size_t[?]', 1)
      local ptail = path.invocation_path_tail((to_cstr(invk)), plen)
      neq(NULL, ptail)

      -- it does not change the output if len==NULL
      local tail2 = path.invocation_path_tail((to_cstr(invk)), NULL)
      neq(NULL, tail2)
      eq((ffi.string(ptail)), (ffi.string(tail2)))
      return ptail, plen[0]
    end

    -- This test mimics the intended use in C.
    local function compare(base, pinvk, len)
      return eq(0, (ffi.C.strncmp((to_cstr(base)), pinvk, len)))
    end

    it('returns the executable name of an invocation given a relative invocation', function()
      local invk, len = invocation_path_tail('directory/exe a b c')
      compare("exe a b c", invk, len)
      eq(3, len)
    end)

    it('returns the executable name of an invocation given an absolute invocation', function()
      if ffi.os == 'Windows' then
        local invk, len = invocation_path_tail('C:\\Users\\anyone\\Program Files\\z a b')
        compare('z a b', invk, len)
        eq(1, len)
      else
        local invk, len = invocation_path_tail('/usr/bin/z a b')
        compare('z a b', invk, len)
        eq(1, len)
      end
    end)

    it('does not count arguments to the executable as part of its path', function()
      local invk, len = invocation_path_tail('exe a/b\\c')
      compare("exe a/b\\c", invk, len)
      eq(3, len)
    end)

    it('only accepts whitespace as a terminator for the executable name', function()
      local invk, _ = invocation_path_tail('exe-a+b_c[]()|#!@$%^&*')
      eq('exe-a+b_c[]()|#!@$%^&*', (ffi.string(invk)))
    end)

    it('is equivalent to path_tail when args do not contain a path separator', function()
      local ptail = path.path_tail(to_cstr("a/b/c x y z"))
      neq(NULL, ptail)
      local tail = ffi.string(ptail)
      local invk, _ = invocation_path_tail("a/b/c x y z")
      eq(tail, ffi.string(invk))
    end)

    it('is not equivalent to path_tail when args contain a path separator', function()
      local ptail = path.path_tail(to_cstr("a/b/c x y/z"))
      neq(NULL, ptail)
      local invk, _ = invocation_path_tail("a/b/c x y/z")
      neq((ffi.string(ptail)), (ffi.string(invk)))
    end)
  end)

  describe('path_next_component', function()
    local function path_next_component(file)
      local res = path.path_next_component((to_cstr(file)))
      neq(NULL, res)
      return ffi.string(res)
    end

    it('returns', function()
      eq('directory/file.txt', path_next_component('some/directory/file.txt'))
    end)

    it('returns empty string if given file contains no separator', function()
      eq('', path_next_component('file.txt'))
    end)
  end)

  describe('path_shorten_fname', function()
    it('returns NULL if `full_path` is NULL', function()
      local dir = to_cstr('some/directory/file.txt')
      eq(NULL, (path.path_shorten_fname(NULL, dir)))
    end)

    it('returns NULL if the path and dir does not match', function()
      local dir = to_cstr('not/the/same')
      local full = to_cstr('as/this.txt')
      eq(NULL, (path.path_shorten_fname(full, dir)))
    end)

    it('returns NULL if the path is not separated properly', function()
      local dir = to_cstr('some/very/long/')
      local full = to_cstr('some/very/long/directory/file.txt')
      eq(NULL, (path.path_shorten_fname(full, dir)))
    end)

    it('shortens the filename if `dir_name` is the start of `full_path`', function()
      local full = to_cstr('some/very/long/directory/file.txt')
      local dir = to_cstr('some/very/long')
      eq('directory/file.txt', (ffi.string(path.path_shorten_fname(full, dir))))
    end)
  end)
end)

describe('path_shorten_fname_if_possible', function()
  local cwd = lfs.currentdir()

  before_each(function()
    lfs.mkdir('ut_directory')
  end)

  after_each(function()
    lfs.chdir(cwd)
    lfs.rmdir('ut_directory')
  end)

  describe('path_shorten_fname_if_possible', function()
    it('returns shortened path if possible', function()
      lfs.chdir('ut_directory')
      local full = to_cstr(lfs.currentdir() .. '/subdir/file.txt')
      eq('subdir/file.txt', (ffi.string(path.path_shorten_fname_if_possible(full))))
    end)

    it('returns `full_path` if a shorter version is not possible', function()
      local old = lfs.currentdir()
      lfs.chdir('ut_directory')
      local full = old .. '/subdir/file.txt'
      eq(full, (ffi.string(path.path_shorten_fname_if_possible(to_cstr(full)))))
    end)

    it('returns NULL if `full_path` is NULL', function()
      eq(NULL, (path.path_shorten_fname_if_possible(NULL)))
    end)
  end)
end)

describe('more path function', function()
  setup(function()
    lfs.mkdir('unit-test-directory');
    io.open('unit-test-directory/test.file', 'w').close()

    -- Since the tests are executed, they are called by an executable. We use
    -- that executable for several asserts.
    local absolute_executable = arg[0]

    -- Split absolute_executable into a directory and the actual file name for
    -- later usage.
    local directory, executable_name = string.match(absolute_executable, '^(.*)/(.*)$')  -- luacheck: ignore
  end)

  teardown(function()
    os.remove('unit-test-directory/test.file')
    lfs.rmdir('unit-test-directory')
  end)

  describe('vim_FullName', function()
    local function vim_FullName(filename, buf, len, force)
      filename = to_cstr(filename)
      return path.vim_FullName(filename, buf, len, force)
    end

    before_each(function()
      -- Create empty string buffer which will contain the resulting path.
      length = (string.len(lfs.currentdir())) + 33
      buffer = cstr(length, '')
    end)

    it('fails if given filename is NULL', function()
      local force_expansion = 1
      local result = path.vim_FullName(NULL, buffer, length, force_expansion)
      eq(FAIL, result)
    end)

    it('uses the filename if the filename is a URL', function()
      local force_expansion = 1
      local filename = 'http://www.neovim.org'
      local result = vim_FullName(filename, buffer, length, force_expansion)
      eq(filename, (ffi.string(buffer)))
      eq(OK, result)
    end)

    it('fails and uses filename if given filename contains non-existing directory', function()
      local force_expansion = 1
      local filename = 'non_existing_dir/test.file'
      local result = vim_FullName(filename, buffer, length, force_expansion)
      eq(filename, (ffi.string(buffer)))
      eq(FAIL, result)
    end)

    it('concatenates given filename if it does not contain a slash', function()
      local force_expansion = 1
      local result = vim_FullName('test.file', buffer, length, force_expansion)
      local expected = lfs.currentdir() .. '/test.file'
      eq(expected, (ffi.string(buffer)))
      eq(OK, result)
    end)

    it('concatenates given filename if it is a directory but does not contain a\n    slash', function()
      local force_expansion = 1
      local result = vim_FullName('..', buffer, length, force_expansion)
      local expected = lfs.currentdir() .. '/..'
      eq(expected, (ffi.string(buffer)))
      eq(OK, result)
    end)

    -- Is it possible for every developer to enter '..' directory while running
    -- the unit tests? Which other directory would be better?
    it('enters given directory (instead of just concatenating the strings) if possible and if path contains a slash', function()
      local force_expansion = 1
      local result = vim_FullName('../test.file', buffer, length, force_expansion)
      local old_dir = lfs.currentdir()
      lfs.chdir('..')
      local expected = lfs.currentdir() .. '/test.file'
      lfs.chdir(old_dir)
      eq(expected, (ffi.string(buffer)))
      eq(OK, result)
    end)

    it('just copies the path if it is already absolute and force=0', function()
      local force_expansion = 0
      local absolute_path = '/absolute/path'
      local result = vim_FullName(absolute_path, buffer, length, force_expansion)
      eq(absolute_path, (ffi.string(buffer)))
      eq(OK, result)
    end)

    it('fails and uses filename when the path is relative to HOME', function()
      local force_expansion = 1
      local absolute_path = '~/home.file'
      local result = vim_FullName(absolute_path, buffer, length, force_expansion)
      eq(absolute_path, (ffi.string(buffer)))
      eq(FAIL, result)
    end)

    it('works with some "normal" relative path with directories', function()
      local force_expansion = 1
      local result = vim_FullName('unit-test-directory/test.file', buffer, length, force_expansion)
      eq(OK, result)
      eq(lfs.currentdir() .. '/unit-test-directory/test.file', (ffi.string(buffer)))
    end)

    it('does not modify the given filename', function()
      local force_expansion = 1
      local filename = to_cstr('unit-test-directory/test.file')
      -- Don't use the wrapper here but pass a cstring directly to the c
      -- function.
      local result = path.vim_FullName(filename, buffer, length, force_expansion)
      eq(lfs.currentdir() .. '/unit-test-directory/test.file', (ffi.string(buffer)))
      eq('unit-test-directory/test.file', (ffi.string(filename)))
      eq(OK, result)
    end)

    it('works with directories that have one path component', function()
      local force_expansion = 1
      local filename = to_cstr('/tmp')
      local result = path.vim_FullName(filename, buffer, length, force_expansion)
      eq('/tmp', ffi.string(buffer))
      eq(OK, result)
    end)
  end)

  describe('path_fix_case', function()
    local function fix_case(file)
      local c_file = to_cstr(file)
      path.path_fix_case(c_file)
      return ffi.string(c_file)
    end

    before_each(function() lfs.mkdir('CamelCase') end)
    after_each(function() lfs.rmdir('CamelCase') end)

    if ffi.os == 'Windows' or ffi.os == 'OSX' then
      it('Corrects the case of file names in Mac and Windows', function()
        eq('CamelCase', fix_case('camelcase'))
        eq('CamelCase', fix_case('cAMELcASE'))
      end)
    else
      it('does nothing on Linux', function()
        eq('camelcase', fix_case('camelcase'))
        eq('cAMELcASE', fix_case('cAMELcASE'))
      end)
    end
  end)

  describe('append_path', function()
    it('joins given paths with a slash', function()
      local path1 = cstr(100, 'path1')
      local to_append = to_cstr('path2')
      eq(OK, (path.append_path(path1, to_append, 100)))
      eq("path1/path2", (ffi.string(path1)))
    end)

    it('joins given paths without adding an unnecessary slash', function()
      local path1 = cstr(100, 'path1/')
      local to_append = to_cstr('path2')
      eq(OK, path.append_path(path1, to_append, 100))
      eq("path1/path2", (ffi.string(path1)))
    end)

    it('fails and uses filename if there is not enough space left for to_append', function()
      local path1 = cstr(11, 'path1/')
      local to_append = to_cstr('path2')
      eq(FAIL, (path.append_path(path1, to_append, 11)))
    end)

    it('does not append a slash if to_append is empty', function()
      local path1 = cstr(6, 'path1')
      local to_append = to_cstr('')
      eq(OK, (path.append_path(path1, to_append, 6)))
      eq('path1', (ffi.string(path1)))
    end)

    it('does not append unnecessary dots', function()
      local path1 = cstr(6, 'path1')
      local to_append = to_cstr('.')
      eq(OK, (path.append_path(path1, to_append, 6)))
      eq('path1', (ffi.string(path1)))
    end)

    it('copies to_append to path, if path is empty', function()
      local path1 = cstr(7, '')
      local to_append = to_cstr('/path2')
      eq(OK, (path.append_path(path1, to_append, 7)))
      eq('/path2', (ffi.string(path1)))
    end)
  end)

  describe('path_is_absolute_path', function()
    local function path_is_absolute_path(filename)
      filename = to_cstr(filename)
      return path.path_is_absolute_path(filename)
    end

    it('returns true if filename starts with a slash', function()
      eq(OK, path_is_absolute_path('/some/directory/'))
    end)

    it('returns true if filename starts with a tilde', function()
      eq(OK, path_is_absolute_path('~/in/my/home~/directory'))
    end)

    it('returns false if filename starts not with slash nor tilde', function()
      eq(FAIL, path_is_absolute_path('not/in/my/home~/directory'))
    end)
  end)
end)
