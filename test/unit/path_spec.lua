local lfs = require('lfs')
local helpers = require('test.unit.helpers')(after_each)
local itp = helpers.gen_itp(it)

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
local cimp = cimport('./src/nvim/os/os.h', './src/nvim/path.h')

local length = 0
local buffer = nil

describe('path.c', function()
  describe('path_full_dir_name', function()
    setup(function()
      lfs.mkdir('unit-test-directory')
    end)

    teardown(function()
      lfs.rmdir('unit-test-directory')
    end)

    local function path_full_dir_name(directory, buf, len)
      directory = to_cstr(directory)
      return cimp.path_full_dir_name(directory, buf, len)
    end

    before_each(function()
      -- Create empty string buffer which will contain the resulting path.
      length = string.len(lfs.currentdir()) + 22
      buffer = cstr(length, '')
    end)

    itp('returns the absolute directory name of a given relative one', function()
      local result = path_full_dir_name('..', buffer, length)
      eq(OK, result)
      local old_dir = lfs.currentdir()
      lfs.chdir('..')
      local expected = lfs.currentdir()
      lfs.chdir(old_dir)
      eq(expected, (ffi.string(buffer)))
    end)

    itp('returns the current directory name if the given string is empty', function()
      eq(OK, (path_full_dir_name('', buffer, length)))
      eq(lfs.currentdir(), (ffi.string(buffer)))
    end)

    itp('fails if the given directory does not exist', function()
      eq(FAIL, path_full_dir_name('does_not_exist', buffer, length))
    end)

    itp('works with a normal relative dir', function()
      local result = path_full_dir_name('unit-test-directory', buffer, length)
      eq(lfs.currentdir() .. '/unit-test-directory', (ffi.string(buffer)))
      eq(OK, result)
    end)
  end)

  describe('path_full_compare', function()
    local function path_full_compare(s1, s2, cn)
      s1 = to_cstr(s1)
      s2 = to_cstr(s2)
      return cimp.path_full_compare(s1, s2, cn or 0)
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

    itp('returns kEqualFiles when passed the same file', function()
      eq(cimp.kEqualFiles, (path_full_compare(f1, f1)))
    end)

    itp('returns kEqualFileNames when files that dont exist and have same name', function()
      eq(cimp.kEqualFileNames, (path_full_compare('null.txt', 'null.txt', true)))
    end)

    itp('returns kBothFilesMissing when files that dont exist', function()
      eq(cimp.kBothFilesMissing, (path_full_compare('null.txt', 'null.txt')))
    end)

    itp('returns kDifferentFiles when passed different files', function()
      eq(cimp.kDifferentFiles, (path_full_compare(f1, f2)))
      eq(cimp.kDifferentFiles, (path_full_compare(f2, f1)))
    end)

    itp('returns kOneFileMissing if only one does not exist', function()
      eq(cimp.kOneFileMissing, (path_full_compare(f1, 'null.txt')))
      eq(cimp.kOneFileMissing, (path_full_compare('null.txt', f1)))
    end)
  end)

  describe('path_tail', function()
    local function path_tail(file)
      local res = cimp.path_tail((to_cstr(file)))
      neq(NULL, res)
      return ffi.string(res)
    end

    itp('returns the tail of a given file path', function()
      eq('file.txt', path_tail('directory/file.txt'))
    end)

    itp('returns an empty string if file ends in a slash', function()
      eq('', path_tail('directory/'))
    end)
  end)

  describe('path_tail_with_sep', function()
    local function path_tail_with_sep(file)
      local res = cimp.path_tail_with_sep((to_cstr(file)))
      neq(NULL, res)
      return ffi.string(res)
    end

    itp('returns the tail of a file together with its separator', function()
      eq('///file.txt', path_tail_with_sep('directory///file.txt'))
    end)

    itp('returns an empty string when given an empty file name', function()
      eq('', path_tail_with_sep(''))
    end)

    itp('returns only the separator if there is a trailing separator', function()
      eq('/', path_tail_with_sep('some/directory/'))
    end)

    itp('cuts a leading separator', function()
      eq('file.txt', path_tail_with_sep('/file.txt'))
      eq('', path_tail_with_sep('/'))
    end)

    itp('returns the whole file name if there is no separator', function()
      eq('file.txt', path_tail_with_sep('file.txt'))
    end)
  end)

  describe('invocation_path_tail', function()
    -- Returns the path tail and length (out param) of the tail.
    -- Does not convert the tail from C-pointer to lua string for use with
    -- strcmp.
    local function invocation_path_tail(invk)
      local plen = ffi.new('size_t[?]', 1)
      local ptail = cimp.invocation_path_tail((to_cstr(invk)), plen)
      neq(NULL, ptail)

      -- it does not change the output if len==NULL
      local tail2 = cimp.invocation_path_tail((to_cstr(invk)), NULL)
      neq(NULL, tail2)
      eq((ffi.string(ptail)), (ffi.string(tail2)))
      return ptail, plen[0]
    end

    -- This test mimics the intended use in C.
    local function compare(base, pinvk, len)
      return eq(0, (ffi.C.strncmp((to_cstr(base)), pinvk, len)))
    end

    itp('returns the executable name of an invocation given a relative invocation', function()
      local invk, len = invocation_path_tail('directory/exe a b c')
      compare("exe a b c", invk, len)
      eq(3, len)
    end)

    itp('returns the executable name of an invocation given an absolute invocation', function()
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

    itp('does not count arguments to the executable as part of its path', function()
      local invk, len = invocation_path_tail('exe a/b\\c')
      compare("exe a/b\\c", invk, len)
      eq(3, len)
    end)

    itp('only accepts whitespace as a terminator for the executable name', function()
      local invk, _ = invocation_path_tail('exe-a+b_c[]()|#!@$%^&*')
      eq('exe-a+b_c[]()|#!@$%^&*', (ffi.string(invk)))
    end)

    itp('is equivalent to path_tail when args do not contain a path separator', function()
      local ptail = cimp.path_tail(to_cstr("a/b/c x y z"))
      neq(NULL, ptail)
      local tail = ffi.string(ptail)
      local invk, _ = invocation_path_tail("a/b/c x y z")
      eq(tail, ffi.string(invk))
    end)

    itp('is not equivalent to path_tail when args contain a path separator', function()
      local ptail = cimp.path_tail(to_cstr("a/b/c x y/z"))
      neq(NULL, ptail)
      local invk, _ = invocation_path_tail("a/b/c x y/z")
      neq((ffi.string(ptail)), (ffi.string(invk)))
    end)
  end)

  describe('path_next_component', function()
    local function path_next_component(file)
      local res = cimp.path_next_component((to_cstr(file)))
      neq(NULL, res)
      return ffi.string(res)
    end

    itp('returns', function()
      eq('directory/file.txt', path_next_component('some/directory/file.txt'))
    end)

    itp('returns empty string if given file contains no separator', function()
      eq('', path_next_component('file.txt'))
    end)
  end)

  describe('path_shorten_fname', function()
    itp('returns NULL if `full_path` is NULL', function()
      local dir = to_cstr('some/directory/file.txt')
      eq(NULL, (cimp.path_shorten_fname(NULL, dir)))
    end)

    itp('returns NULL if the path and dir does not match', function()
      local dir = to_cstr('not/the/same')
      local full = to_cstr('as/this.txt')
      eq(NULL, (cimp.path_shorten_fname(full, dir)))
    end)

    itp('returns NULL if the path is not separated properly', function()
      local dir = to_cstr('some/very/long/')
      local full = to_cstr('some/very/long/directory/file.txt')
      eq(NULL, (cimp.path_shorten_fname(full, dir)))
    end)

    itp('shortens the filename if `dir_name` is the start of `full_path`', function()
      local full = to_cstr('some/very/long/directory/file.txt')
      local dir = to_cstr('some/very/long')
      eq('directory/file.txt', (ffi.string(cimp.path_shorten_fname(full, dir))))
    end)
  end)
end)

describe('path_try_shorten_fname', function()
  local cwd = lfs.currentdir()

  before_each(function()
    lfs.mkdir('ut_directory')
  end)

  after_each(function()
    lfs.chdir(cwd)
    lfs.rmdir('ut_directory')
  end)

  describe('path_try_shorten_fname', function()
    itp('returns shortened path if possible', function()
      lfs.chdir('ut_directory')
      local full = to_cstr(lfs.currentdir() .. '/subdir/file.txt')
      eq('subdir/file.txt', (ffi.string(cimp.path_try_shorten_fname(full))))
    end)

    itp('returns `full_path` if a shorter version is not possible', function()
      local old = lfs.currentdir()
      lfs.chdir('ut_directory')
      local full = old .. '/subdir/file.txt'
      eq(full, (ffi.string(cimp.path_try_shorten_fname(to_cstr(full)))))
    end)

    itp('returns NULL if `full_path` is NULL', function()
      eq(NULL, (cimp.path_try_shorten_fname(NULL)))
    end)
  end)
end)

describe('path.c path_guess_exepath', function()
  local cwd = lfs.currentdir()

  for _,name in ipairs({'./nvim', '.nvim', 'foo/nvim'}) do
    itp('"'..name..'" returns name catenated with CWD', function()
      local bufsize = 255
      local buf = cstr(bufsize, '')
      cimp.path_guess_exepath(name, buf, bufsize)
      eq(cwd..'/'..name, ffi.string(buf))
    end)
  end

  itp('absolute path returns the name unmodified', function()
    local name = '/foo/bar/baz'
    local bufsize = 255
    local buf = cstr(bufsize, '')
    cimp.path_guess_exepath(name, buf, bufsize)
    eq(name, ffi.string(buf))
  end)

  itp('returns the name unmodified if not found in $PATH', function()
    local name = '23u0293_not_in_path'
    local bufsize = 255
    local buf = cstr(bufsize, '')
    cimp.path_guess_exepath(name, buf, bufsize)
    eq(name, ffi.string(buf))
  end)

  itp('does not crash if $PATH item exceeds MAXPATHL', function()
    local orig_path_env = os.getenv('PATH')
    local name = 'cat'  -- Some executable in $PATH.
    local bufsize = 255
    local buf = cstr(bufsize, '')
    local insane_path = orig_path_env..':'..(("x/"):rep(4097))

    cimp.os_setenv('PATH', insane_path, true)
    cimp.path_guess_exepath(name, buf, bufsize)
    eq('bin/' .. name, ffi.string(buf):sub(-#('bin/' .. name), -1))

    -- Restore $PATH.
    cimp.os_setenv('PATH', orig_path_env, true)
  end)

  itp('returns full path found in $PATH', function()
    local name = 'cat'  -- Some executable in $PATH.
    local bufsize = 255
    local buf = cstr(bufsize, '')
    cimp.path_guess_exepath(name, buf, bufsize)
    -- Usually "/bin/cat" on unix, "/path/to/nvim/cat" on Windows.
    eq('bin/' .. name, ffi.string(buf):sub(-#('bin/' .. name), -1))
  end)
end)

describe('path.c', function()
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
    local function vim_FullName(filename, buflen, do_expand)
      local buf = cstr(buflen, '')
      local result = cimp.vim_FullName(to_cstr(filename), buf, buflen, do_expand)
      return buf, result
    end

    local function get_buf_len(s, t)
      return math.max(string.len(s), string.len(t)) + 1
    end

    itp('fails if given filename is NULL', function()
      local do_expand = 1
      local buflen = 10
      local buf = cstr(buflen, '')
      local result = cimp.vim_FullName(NULL, buf, buflen, do_expand)
      eq(FAIL, result)
    end)

    itp('fails safely if given length is wrong #5737', function()
      local filename = 'foo/bar/bazzzzzzz/buz/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/a'
      local too_short_len = 8
      local buf = cstr(too_short_len, '')
      local do_expand = 1
      local result = cimp.vim_FullName(filename, buf, too_short_len, do_expand)
      local expected = string.sub(filename, 1, (too_short_len - 1))
      eq(expected, ffi.string(buf))
      eq(FAIL, result)
    end)

    itp('uses the filename if the filename is a URL', function()
      local filename = 'http://www.neovim.org'
      local buflen = string.len(filename) + 1
      local do_expand = 1
      local buf, result = vim_FullName(filename, buflen, do_expand)
      eq(filename, ffi.string(buf))
      eq(OK, result)
    end)

    itp('fails and uses filename if given filename contains non-existing directory', function()
      local filename = 'non_existing_dir/test.file'
      local buflen = string.len(filename) + 1
      local do_expand = 1
      local buf, result = vim_FullName(filename, buflen, do_expand)
      eq(filename, ffi.string(buf))
      eq(FAIL, result)
    end)

    itp('concatenates filename if it does not contain a slash', function()
      local expected = lfs.currentdir() .. '/test.file'
      local filename = 'test.file'
      local buflen = get_buf_len(expected, filename)
      local do_expand = 1
      local buf, result = vim_FullName(filename, buflen, do_expand)
      eq(expected, ffi.string(buf))
      eq(OK, result)
    end)

    itp('concatenates directory name if it does not contain a slash', function()
      local expected = lfs.currentdir() .. '/..'
      local filename = '..'
      local buflen = get_buf_len(expected, filename)
      local do_expand = 1
      local buf, result = vim_FullName(filename, buflen, do_expand)
      eq(expected, ffi.string(buf))
      eq(OK, result)
    end)

    itp('enters given directory (instead of just concatenating the strings) if possible and if path contains a slash', function()
      local old_dir = lfs.currentdir()
      lfs.chdir('..')
      local expected = lfs.currentdir() .. '/test.file'
      lfs.chdir(old_dir)
      local filename = '../test.file'
      local buflen = get_buf_len(expected, filename)
      local do_expand = 1
      local buf, result = vim_FullName(filename, buflen, do_expand)
      eq(expected, ffi.string(buf))
      eq(OK, result)
    end)

    itp('just copies the path if it is already absolute and force=0', function()
      local absolute_path = '/absolute/path'
      local buflen = string.len(absolute_path) + 1
      local do_expand = 0
      local buf, result = vim_FullName(absolute_path, buflen, do_expand)
      eq(absolute_path, ffi.string(buf))
      eq(OK, result)
    end)

    itp('fails and uses filename when the path is relative to HOME', function()
      eq(false, cimp.os_isdir('~')) -- sanity check: no literal "~" directory.
      local absolute_path = '~/home.file'
      local buflen = string.len(absolute_path) + 1
      local do_expand = 1
      local buf, result = vim_FullName(absolute_path, buflen, do_expand)
      eq(absolute_path, ffi.string(buf))
      eq(FAIL, result)
    end)

    itp('works with some "normal" relative path with directories', function()
      local expected = lfs.currentdir() .. '/unit-test-directory/test.file'
      local filename = 'unit-test-directory/test.file'
      local buflen = get_buf_len(expected, filename)
      local do_expand = 1
      local buf, result = vim_FullName(filename, buflen, do_expand)
      eq(expected, ffi.string(buf))
      eq(OK, result)
    end)

    itp('does not modify the given filename', function()
      local expected = lfs.currentdir() .. '/unit-test-directory/test.file'
      local filename = to_cstr('unit-test-directory/test.file')
      local buflen = string.len(expected) + 1
      local buf = cstr(buflen, '')
      local do_expand = 1
      -- Don't use the wrapper but pass a cstring directly to the c function.
      eq('unit-test-directory/test.file', ffi.string(filename))
      local result = cimp.vim_FullName(filename, buf, buflen, do_expand)
      eq(expected, ffi.string(buf))
      eq(OK, result)
    end)

    itp('works with directories that have one path component', function()
      local filename = '/tmp'
      local expected = filename
      local buflen = get_buf_len(expected, filename)
      local do_expand = 1
      local buf, result = vim_FullName(filename, buflen, do_expand)
      eq('/tmp', ffi.string(buf))
      eq(OK, result)
    end)

    itp('expands "./" to the current directory #7117', function()
      local expected = lfs.currentdir() .. '/unit-test-directory/test.file'
      local filename = './unit-test-directory/test.file'
      local buflen = get_buf_len(expected, filename)
      local do_expand = 1
      local buf, result = vim_FullName(filename, buflen, do_expand)
      eq(OK, result)
      eq(expected, ffi.string(buf))
    end)

    itp('collapses "foo/../foo" to "foo" #7117', function()
      local expected = lfs.currentdir() .. '/unit-test-directory/test.file'
      local filename = 'unit-test-directory/../unit-test-directory/test.file'
      local buflen = get_buf_len(expected, filename)
      local do_expand = 1
      local buf, result = vim_FullName(filename, buflen, do_expand)
      eq(OK, result)
      eq(expected, ffi.string(buf))
    end)
  end)

  describe('path_fix_case', function()
    local function fix_case(file)
      local c_file = to_cstr(file)
      cimp.path_fix_case(c_file)
      return ffi.string(c_file)
    end

    before_each(function() lfs.mkdir('CamelCase') end)
    after_each(function() lfs.rmdir('CamelCase') end)

    if ffi.os == 'Windows' or ffi.os == 'OSX' then
      itp('Corrects the case of file names in Mac and Windows', function()
        eq('CamelCase', fix_case('camelcase'))
        eq('CamelCase', fix_case('cAMELcASE'))
      end)
    else
      itp('does nothing on Linux', function()
        eq('camelcase', fix_case('camelcase'))
        eq('cAMELcASE', fix_case('cAMELcASE'))
      end)
    end
  end)

  describe('append_path', function()
    itp('joins given paths with a slash', function()
      local path1 = cstr(100, 'path1')
      local to_append = to_cstr('path2')
      eq(OK, (cimp.append_path(path1, to_append, 100)))
      eq("path1/path2", (ffi.string(path1)))
    end)

    itp('joins given paths without adding an unnecessary slash', function()
      local path1 = cstr(100, 'path1/')
      local to_append = to_cstr('path2')
      eq(OK, cimp.append_path(path1, to_append, 100))
      eq("path1/path2", (ffi.string(path1)))
    end)

    itp('fails and uses filename if there is not enough space left for to_append', function()
      local path1 = cstr(11, 'path1/')
      local to_append = to_cstr('path2')
      eq(FAIL, (cimp.append_path(path1, to_append, 11)))
    end)

    itp('does not append a slash if to_append is empty', function()
      local path1 = cstr(6, 'path1')
      local to_append = to_cstr('')
      eq(OK, (cimp.append_path(path1, to_append, 6)))
      eq('path1', (ffi.string(path1)))
    end)

    itp('does not append unnecessary dots', function()
      local path1 = cstr(6, 'path1')
      local to_append = to_cstr('.')
      eq(OK, (cimp.append_path(path1, to_append, 6)))
      eq('path1', (ffi.string(path1)))
    end)

    itp('copies to_append to path, if path is empty', function()
      local path1 = cstr(7, '')
      local to_append = to_cstr('/path2')
      eq(OK, (cimp.append_path(path1, to_append, 7)))
      eq('/path2', (ffi.string(path1)))
    end)
  end)

  describe('path_is_absolute', function()
    local function path_is_absolute(filename)
      filename = to_cstr(filename)
      return cimp.path_is_absolute(filename)
    end

    itp('returns true if filename starts with a slash', function()
      eq(OK, path_is_absolute('/some/directory/'))
    end)

    itp('returns true if filename starts with a tilde', function()
      eq(OK, path_is_absolute('~/in/my/home~/directory'))
    end)

    itp('returns false if filename starts not with slash nor tilde', function()
      eq(FAIL, path_is_absolute('not/in/my/home~/directory'))
    end)
  end)
end)
