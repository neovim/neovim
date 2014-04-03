{:cimport, :internalize, :eq, :neq, :ffi, :lib, :cstr, :to_cstr} = require 'test.unit.helpers'

path = lib

ffi.cdef [[
typedef enum file_comparison {
  kEqualFiles = 1, kDifferentFiles = 2, kBothFilesMissing = 4, kOneFileMissing = 6, kEqualFileNames = 7
} FileComparison;
FileComparison path_full_compare(char_u *s1, char_u *s2, int checkname);
char_u *path_tail(char_u *fname);
char_u *path_tail_with_sep(char_u *fname);
char_u *path_next_component(char_u *fname);
]]

-- import constants parsed by ffi
{:kEqualFiles, :kDifferentFiles, :kBothFilesMissing, :kOneFileMissing, :kEqualFileNames} = path
NULL = ffi.cast 'void*', 0

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
