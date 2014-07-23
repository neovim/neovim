{:cimport, :internalize, :eq, :neq, :ffi, :lib, :cstr, :to_cstr, :NULL, :OK, :FAIL} = require 'test.unit.helpers'
require 'lfs'

path = cimport './src/nvim/path.h'

-- import constants parsed by ffi
{:kEqualFiles, :kDifferentFiles, :kBothFilesMissing, :kOneFileMissing, :kEqualFileNames} = path

describe 'path function', ->
  describe 'path_full_dir_name', ->
    setup ->
      lfs.mkdir 'unit-test-directory'

    teardown ->
      lfs.rmdir 'unit-test-directory'

    path_full_dir_name = (directory, buffer, len) ->
      directory = to_cstr directory
      path.path_full_dir_name directory, buffer, len

    before_each ->
      -- Create empty string buffer which will contain the resulting path.
      export len = (string.len lfs.currentdir!) + 22
      export buffer = cstr len, ''

    it 'returns the absolute directory name of a given relative one', ->
      result = path_full_dir_name '..', buffer, len
      eq OK, result
      old_dir = lfs.currentdir!
      lfs.chdir '..'
      expected = lfs.currentdir!
      lfs.chdir old_dir
      eq expected, (ffi.string buffer)

    it 'returns the current directory name if the given string is empty', ->
      eq OK, (path_full_dir_name '', buffer, len)
      eq lfs.currentdir!, (ffi.string buffer)

    it 'fails if the given directory does not exist', ->
      eq FAIL, path_full_dir_name('does_not_exist', buffer, len)

    it 'works with a normal relative dir', ->
      result = path_full_dir_name('unit-test-directory', buffer, len)
      eq lfs.currentdir! .. '/unit-test-directory', (ffi.string buffer)
      eq OK, result

  describe 'path_full_compare', ->

    path_full_compare = (s1, s2, cn) ->
      s1 = to_cstr s1
      s2 = to_cstr s2
      path.path_full_compare s1, s2, cn or 0

    f1 = 'f1.o'
    f2 = 'f2.o'

    before_each ->
      -- create the three files that will be used in this spec
      (io.open f1, 'w').close!
      (io.open f2, 'w').close!

    after_each ->
      os.remove f1
      os.remove f2

    it 'returns kEqualFiles when passed the same file', ->
      eq kEqualFiles, (path_full_compare f1, f1)

    it 'returns kEqualFileNames when files that dont exist and have same name', ->
      eq kEqualFileNames, (path_full_compare 'null.txt', 'null.txt', true)

    it 'returns kBothFilesMissing when files that dont exist', ->
      eq kBothFilesMissing, (path_full_compare 'null.txt', 'null.txt')

    it 'returns kDifferentFiles when passed different files', ->
      eq kDifferentFiles, (path_full_compare f1, f2)
      eq kDifferentFiles, (path_full_compare f2, f1)

    it 'returns kOneFileMissing if only one does not exist', ->
      eq kOneFileMissing, (path_full_compare f1, 'null.txt')
      eq kOneFileMissing, (path_full_compare 'null.txt', f1)

  describe 'path_tail', ->
    path_tail = (file) ->
      res = path.path_tail (to_cstr file)
      neq NULL, res
      ffi.string res

    it 'returns the tail of a given file path', ->
      eq 'file.txt', path_tail 'directory/file.txt'

    it 'returns an empty string if file ends in a slash', ->
      eq '', path_tail 'directory/'

  describe 'path_tail_with_sep', ->
    path_tail_with_sep = (file) ->
      res = path.path_tail_with_sep (to_cstr file)
      neq NULL, res
      ffi.string res

    it 'returns the tail of a file together with its separator', ->
      eq '///file.txt', path_tail_with_sep 'directory///file.txt'

    it 'returns an empty string when given an empty file name', ->
      eq '', path_tail_with_sep ''

    it 'returns only the separator if there is a trailing separator', ->
      eq '/', path_tail_with_sep 'some/directory/'

    it 'cuts a leading separator', ->
      eq 'file.txt', path_tail_with_sep '/file.txt'
      eq '', path_tail_with_sep '/'

    it 'returns the whole file name if there is no separator', ->
      eq 'file.txt', path_tail_with_sep 'file.txt'

  describe 'invocation_path_tail', ->
    -- Returns the path tail and length (out param) of the tail.
    -- Does not convert the tail from C-pointer to lua string for use with
    -- strcmp.
    invocation_path_tail = (invk) ->
      plen = ffi.new 'size_t[?]', 1
      ptail = path.invocation_path_tail (to_cstr invk), plen
      neq NULL, ptail

      -- it does not change the output if len==NULL
      tail2 = path.invocation_path_tail (to_cstr invk), NULL
      neq NULL, tail2
      eq (ffi.string ptail), (ffi.string tail2)

      ptail, plen[0]

    -- This test mimics the intended use in C.
    compare = (base, pinvk, len) ->
      eq 0, (ffi.C.strncmp (to_cstr base), pinvk, len)

    it 'returns the executable name of an invocation given a relative invocation', ->
      invk, len = invocation_path_tail 'directory/exe a b c'
      compare "exe a b c", invk, len
      eq 3, len

    it 'returns the executable name of an invocation given an absolute invocation', ->
      if ffi.os == 'Windows'
        invk, len = invocation_path_tail 'C:\\Users\\anyone\\Program Files\\z a b'
        compare 'z a b', invk, len
        eq 1, len
      else
        invk, len = invocation_path_tail '/usr/bin/z a b'
        compare 'z a b', invk, len
        eq 1, len

    it 'does not count arguments to the executable as part of its path', ->
      invk, len = invocation_path_tail 'exe a/b\\c'
      compare "exe a/b\\c", invk, len
      eq 3, len

    it 'only accepts whitespace as a terminator for the executable name', ->
      invk, len = invocation_path_tail 'exe-a+b_c[]()|#!@$%^&*'
      eq 'exe-a+b_c[]()|#!@$%^&*', (ffi.string invk)

    it 'is equivalent to path_tail when args do not contain a path separator', ->
      ptail = path.path_tail to_cstr "a/b/c x y z"
      neq NULL, ptail
      tail = ffi.string ptail

      invk, len = invocation_path_tail "a/b/c x y z"
      eq tail, ffi.string invk

    it 'is not equivalent to path_tail when args contain a path separator', ->
      ptail = path.path_tail to_cstr "a/b/c x y/z"
      neq NULL, ptail

      invk, len = invocation_path_tail "a/b/c x y/z"
      neq (ffi.string ptail), (ffi.string invk)

  describe 'path_next_component', ->
    path_next_component = (file) ->
      res = path.path_next_component (to_cstr file)
      neq NULL, res
      ffi.string res

    it 'returns', ->
      eq 'directory/file.txt', path_next_component 'some/directory/file.txt'

    it 'returns empty string if given file contains no separator', ->
      eq '', path_next_component 'file.txt'

  describe 'path_shorten_fname', ->
    it 'returns NULL if `full_path` is NULL', ->
      dir = to_cstr 'some/directory/file.txt'
      eq NULL, (path.path_shorten_fname NULL, dir)

    it 'returns NULL if the path and dir does not match', ->
      dir = to_cstr 'not/the/same'
      full = to_cstr 'as/this.txt'
      eq NULL, (path.path_shorten_fname full, dir)

    it 'returns NULL if the path is not separated properly', ->
      dir = to_cstr 'some/very/long/'
      full = to_cstr 'some/very/long/directory/file.txt'
      eq NULL, (path.path_shorten_fname full, dir)

    it 'shortens the filename if `dir_name` is the start of `full_path`', ->
      full = to_cstr 'some/very/long/directory/file.txt'
      dir = to_cstr 'some/very/long'
      eq 'directory/file.txt', (ffi.string path.path_shorten_fname full, dir)

describe 'path_shorten_fname_if_possible', ->
  cwd = lfs.currentdir!
  before_each ->
      lfs.mkdir 'ut_directory'
  after_each ->
      lfs.chdir cwd
      lfs.rmdir 'ut_directory'

  describe 'path_shorten_fname_if_possible', ->
    it 'returns shortened path if possible', ->
      lfs.chdir 'ut_directory'
      full = to_cstr lfs.currentdir! .. '/subdir/file.txt'
      eq 'subdir/file.txt', (ffi.string path.path_shorten_fname_if_possible full)

    it 'returns `full_path` if a shorter version is not possible', ->
      old = lfs.currentdir!
      lfs.chdir 'ut_directory'
      full = old .. '/subdir/file.txt'
      eq full, (ffi.string path.path_shorten_fname_if_possible to_cstr full)

    it 'returns NULL if `full_path` is NULL', ->
      eq NULL, (path.path_shorten_fname_if_possible NULL)

describe 'more path function', ->
  setup ->
    lfs.mkdir 'unit-test-directory'
    (io.open 'unit-test-directory/test.file', 'w').close!

    -- Since the tests are executed, they are called by an executable. We use
    -- that executable for several asserts.
    export absolute_executable = arg[0]

    -- Split absolute_executable into a directory and the actual file name for
    -- later usage.
    export directory, executable_name = string.match(absolute_executable, '^(.*)/(.*)$')

  teardown ->
    os.remove 'unit-test-directory/test.file'
    lfs.rmdir 'unit-test-directory'

  describe 'vim_FullName', ->
    vim_FullName = (filename, buffer, length, force) ->
      filename = to_cstr filename
      path.vim_FullName filename, buffer, length, force

    before_each ->
      -- Create empty string buffer which will contain the resulting path.
      export len = (string.len lfs.currentdir!) + 33
      export buffer = cstr len, ''

    it 'fails if given filename is NULL', ->
      force_expansion = 1
      result = path.vim_FullName NULL, buffer, len, force_expansion
      eq FAIL, result

    it 'uses the filename if the filename is a URL', ->
      force_expansion = 1
      filename = 'http://www.neovim.org'
      result = vim_FullName filename, buffer, len, force_expansion
      eq filename, (ffi.string buffer)
      eq OK, result

    it 'fails and uses filename if given filename contains non-existing directory', ->
      force_expansion = 1
      filename = 'non_existing_dir/test.file'
      result = vim_FullName filename, buffer, len, force_expansion
      eq filename, (ffi.string buffer)
      eq FAIL, result

    it 'concatenates given filename if it does not contain a slash', ->
      force_expansion = 1
      result = vim_FullName 'test.file', buffer, len, force_expansion
      expected = lfs.currentdir! .. '/test.file'
      eq expected, (ffi.string buffer)
      eq OK, result

    it 'concatenates given filename if it is a directory but does not contain a
    slash', ->
      force_expansion = 1
      result = vim_FullName '..', buffer, len, force_expansion
      expected = lfs.currentdir! .. '/..'
      eq expected, (ffi.string buffer)
      eq OK, result

    -- Is it possible for every developer to enter '..' directory while running
    -- the unit tests? Which other directory would be better?
    it 'enters given directory (instead of just concatenating the strings) if
    possible and if path contains a slash', ->
      force_expansion = 1
      result = vim_FullName '../test.file', buffer, len, force_expansion
      old_dir = lfs.currentdir!
      lfs.chdir '..'
      expected = lfs.currentdir! .. '/test.file'
      lfs.chdir old_dir
      eq expected, (ffi.string buffer)
      eq OK, result

    it 'just copies the path if it is already absolute and force=0', ->
      force_expansion = 0
      absolute_path = '/absolute/path'
      result = vim_FullName absolute_path, buffer, len, force_expansion
      eq absolute_path, (ffi.string buffer)
      eq OK, result

    it 'fails and uses filename when the path is relative to HOME', ->
      force_expansion = 1
      absolute_path = '~/home.file'
      result = vim_FullName absolute_path, buffer, len, force_expansion
      eq absolute_path, (ffi.string buffer)
      eq FAIL, result

    it 'works with some "normal" relative path with directories', ->
      force_expansion = 1
      result = vim_FullName 'unit-test-directory/test.file', buffer, len, force_expansion
      eq OK, result
      eq lfs.currentdir! .. '/unit-test-directory/test.file', (ffi.string buffer)

    it 'does not modify the given filename', ->
      force_expansion = 1
      filename = to_cstr 'unit-test-directory/test.file'
      -- Don't use the wrapper here but pass a cstring directly to the c
      -- function.
      result = path.vim_FullName filename, buffer, len, force_expansion
      eq lfs.currentdir! .. '/unit-test-directory/test.file', (ffi.string buffer)
      eq 'unit-test-directory/test.file', (ffi.string filename)
      eq OK, result

  describe 'append_path', ->
    it 'joins given paths with a slash', ->
     path1 = cstr 100, 'path1'
     to_append = to_cstr 'path2'
     eq OK, (path.append_path path1, to_append, 100)
     eq "path1/path2", (ffi.string path1)

    it 'joins given paths without adding an unnecessary slash', ->
     path1 = cstr 100, 'path1/'
     to_append = to_cstr 'path2'
     eq OK, path.append_path path1, to_append, 100
     eq "path1/path2", (ffi.string path1)

    it 'fails and uses filename if there is not enough space left for to_append', ->
      path1 = cstr 11, 'path1/'
      to_append = to_cstr 'path2'
      eq FAIL, (path.append_path path1, to_append, 11)

    it 'does not append a slash if to_append is empty', ->
      path1 = cstr 6, 'path1'
      to_append = to_cstr ''
      eq OK, (path.append_path path1, to_append, 6)
      eq 'path1', (ffi.string path1)

    it 'does not append unnecessary dots', ->
      path1 = cstr 6, 'path1'
      to_append = to_cstr '.'
      eq OK, (path.append_path path1, to_append, 6)
      eq 'path1', (ffi.string path1)

    it 'copies to_append to path, if path is empty', ->
      path1 = cstr 7, ''
      to_append = to_cstr '/path2'
      eq OK, (path.append_path path1, to_append, 7)
      eq '/path2', (ffi.string path1)

  describe 'path_is_absolute_path', ->
    path_is_absolute_path = (filename) ->
      filename = to_cstr filename
      path.path_is_absolute_path filename

    it 'returns true if filename starts with a slash', ->
      eq OK, path_is_absolute_path '/some/directory/'

    it 'returns true if filename starts with a tilde', ->
      eq OK, path_is_absolute_path '~/in/my/home~/directory'

    it 'returns false if filename starts not with slash nor tilde', ->
      eq FAIL, path_is_absolute_path 'not/in/my/home~/directory'
