{:cimport, :internalize, :eq, :neq, :ffi, :lib, :cstr, :to_cstr} = require 'test.unit.helpers'
require 'lfs'

path = lib

ffi.cdef [[
typedef enum file_comparison {
  kEqualFiles = 1, kDifferentFiles = 2, kBothFilesMissing = 4, kOneFileMissing = 6, kEqualFileNames = 7
} FileComparison;
FileComparison path_full_compare(char_u *s1, char_u *s2, int checkname);
char_u *path_tail(char_u *fname);
char_u *path_tail_with_sep(char_u *fname);
char_u *path_next_component(char_u *fname);
int is_executable(char_u *name);
int os_can_exe(char_u *name);
]]


-- import constants parsed by ffi
{:kEqualFiles, :kDifferentFiles, :kBothFilesMissing, :kOneFileMissing, :kEqualFileNames} = path
NULL = ffi.cast 'void*', 0
{:OK, :FAIL} = path
{:TRUE, :FALSE} = path

describe 'path function', ->
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

    it 'returns the tail of a file together with its seperator', ->
      eq '///file.txt', path_tail_with_sep 'directory///file.txt'

    it 'returns an empty string when given an empty file name', ->
      eq '', path_tail_with_sep ''

    it 'returns only the seperator if there is a traling seperator', ->
      eq '/', path_tail_with_sep 'some/directory/'

    it 'cuts a leading seperator', ->
      eq 'file.txt', path_tail_with_sep '/file.txt'
      eq '', path_tail_with_sep '/'

    it 'returns the whole file name if there is no seperator', ->
      eq 'file.txt', path_tail_with_sep 'file.txt'

  describe 'path_next_component', ->
    path_next_component = (file) ->
      res = path.path_next_component (to_cstr file)
      neq NULL, res
      ffi.string res

    it 'returns', ->
      eq 'directory/file.txt', path_next_component 'some/directory/file.txt'

    it 'returns empty string if given file contains no seperator', ->
      eq '', path_next_component 'file.txt'

describe 'former os function', ->
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

  describe 'os_get_absolute_path', ->
    ffi.cdef 'int os_get_absolute_path(char *fname, char *buf, int len, int force);'

    os_get_absolute_path = (filename, buffer, length, force) ->
      filename = to_cstr filename
      path.os_get_absolute_path filename, buffer, length, force

    before_each ->
      -- Create empty string buffer which will contain the resulting path.
      export len = (string.len lfs.currentdir!) + 33
      export buffer = cstr len, ''

    it 'fails if given filename contains non-existing directory', ->
      force_expansion = 1
      result = os_get_absolute_path 'non_existing_dir/test.file', buffer, len, force_expansion
      eq FAIL, result

    it 'concatenates given filename if it does not contain a slash', ->
      force_expansion = 1
      result = os_get_absolute_path 'test.file', buffer, len, force_expansion
      expected = lfs.currentdir! .. '/test.file'
      eq expected, (ffi.string buffer)
      eq OK, result

    it 'concatenates given filename if it is a directory but does not contain a
    slash', ->
      force_expansion = 1
      result = os_get_absolute_path '..', buffer, len, force_expansion
      expected = lfs.currentdir! .. '/..'
      eq expected, (ffi.string buffer)
      eq OK, result

    -- Is it possible for every developer to enter '..' directory while running
    -- the unit tests? Which other directory would be better?
    it 'enters given directory (instead of just concatenating the strings) if
    possible and if path contains a slash', ->
      force_expansion = 1
      result = os_get_absolute_path '../test.file', buffer, len, force_expansion
      old_dir = lfs.currentdir!
      lfs.chdir '..'
      expected = lfs.currentdir! .. '/test.file'
      lfs.chdir old_dir
      eq expected, (ffi.string buffer)
      eq OK, result

    it 'just copies the path if it is already absolute and force=0', ->
      force_expansion = 0
      absolute_path = '/absolute/path'
      result = os_get_absolute_path absolute_path, buffer, len, force_expansion
      eq absolute_path, (ffi.string buffer)
      eq OK, result

    it 'fails when the path is relative to HOME', ->
      force_expansion = 1
      absolute_path = '~/home.file'
      result = os_get_absolute_path absolute_path, buffer, len, force_expansion
      eq FAIL, result

    it 'works with some "normal" relative path with directories', ->
      force_expansion = 1
      result = os_get_absolute_path 'unit-test-directory/test.file', buffer, len, force_expansion
      eq OK, result
      eq lfs.currentdir! .. '/unit-test-directory/test.file', (ffi.string buffer)

    it 'does not modify the given filename', ->
      force_expansion = 1
      filename = to_cstr 'unit-test-directory/test.file'
      -- Don't use the wrapper here but pass a cstring directly to the c
      -- function.
      result = path.os_get_absolute_path filename, buffer, len, force_expansion
      eq lfs.currentdir! .. '/unit-test-directory/test.file', (ffi.string buffer)
      eq 'unit-test-directory/test.file', (ffi.string filename)
      eq OK, result

  describe 'append_path', ->
    ffi.cdef 'int append_path(char *path, char *to_append, int max_len);'

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

    it 'fails if there is not enough space left for to_append', ->
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

  describe 'os_is_absolute_path', ->
    ffi.cdef 'int os_is_absolute_path(char *fname);'

    os_is_absolute_path = (filename) ->
      filename = to_cstr filename
      path.os_is_absolute_path filename

    it 'returns true if filename starts with a slash', ->
      eq OK, os_is_absolute_path '/some/directory/'

    it 'returns true if filename starts with a tilde', ->
      eq OK, os_is_absolute_path '~/in/my/home~/directory'

    it 'returns false if filename starts not with slash nor tilde', ->
      eq FAIL, os_is_absolute_path 'not/in/my/home~/directory'

  describe 'os_can_exe', ->
    os_can_exe = (name) ->
      path.os_can_exe (to_cstr name)

    it 'returns false when given a directory', ->
      eq FALSE, (os_can_exe './unit-test-directory')

    it 'returns false when given a regular file without executable bit set', ->
      eq FALSE, (os_can_exe 'unit-test-directory/test.file')

    it 'returns false when the given file does not exists', ->
      eq FALSE, (os_can_exe 'does-not-exist.file')

    it 'returns true when given an executable inside $PATH', ->
      eq TRUE, (os_can_exe executable_name)

    it 'returns true when given an executable relative to the current dir', ->
      old_dir = lfs.currentdir!
      lfs.chdir directory
      relative_executable = './' .. executable_name
      eq TRUE, (os_can_exe relative_executable)
      lfs.chdir old_dir
