{:cimport, :internalize, :eq, :ffi, :lib, :cstr, :to_cstr} = require 'test.unit.helpers'

path = lib

ffi.cdef [[
typedef enum file_comparison {
  FPC_SAME = 1, FPC_DIFF = 2, FPC_NOTX = 4, FPC_DIFFX = 6, FPC_SAMEX = 7
} FileComparison;
FileComparison path_full_compare(char_u *s1, char_u *s2, int checkname);
]]

-- import constants parsed by ffi
{:FPC_SAME, :FPC_DIFF, :FPC_NOTX, :FPC_DIFFX, :FPC_SAMEX} = path

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

    it 'returns FPC_SAME when passed the same file', ->
      eq FPC_SAME, (path_full_compare f1, f1)

    it 'returns FPC_SAMEX when files that dont exist and have same name', ->
      eq FPC_SAMEX, (path_full_compare 'null.txt', 'null.txt', true)

    it 'returns FPC_NOTX when files that dont exist', ->
      eq FPC_NOTX, (path_full_compare 'null.txt', 'null.txt')

    it 'returns FPC_DIFF when passed different files', ->
      eq FPC_DIFF, (path_full_compare f1, f2)
      eq FPC_DIFF, (path_full_compare f2, f1)

    it 'returns FPC_DIFFX if only one does not exist', ->
      eq FPC_DIFFX, (path_full_compare f1, 'null.txt')
      eq FPC_DIFFX, (path_full_compare 'null.txt', f1)

