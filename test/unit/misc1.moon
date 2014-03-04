{:cimport, :internalize, :eq, :ffi, :lib, :cstr} = require 'test.unit.helpers'

--misc1 = cimport './src/misc1.h'

-- remove these statements once 'cimport' is working properly for misc1.h
misc1 = lib
ffi.cdef [[
enum FPC {
  FPC_SAME = 1, FPC_DIFF = 2, FPC_NOTX = 4, FPC_DIFFX = 6, FPC_SAMEX = 7
};
int fullpathcmp(char_u *s1, char_u *s2, int checkname);
]]

-- import constants parsed by ffi
{:FPC_SAME, :FPC_DIFF, :FPC_NOTX, :FPC_DIFFX, :FPC_SAMEX} = lib

describe 'misc1 function', ->
  describe 'fullpathcmp', ->

    fullpathcmp = (s1, s2, cn) ->
      s1 = cstr (string.len s1) + 1, s1
      s2 = cstr (string.len s2) + 1, s2
      misc1.fullpathcmp s1, s2, cn or 0

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
      eq FPC_SAME, (fullpathcmp f1, f1)

    it 'returns FPC_SAMEX when files that dont exist and have same name', ->
      eq FPC_SAMEX, (fullpathcmp 'null.txt', 'null.txt', true)

    it 'returns FPC_NOTX when files that dont exist', ->
      eq FPC_NOTX, (fullpathcmp 'null.txt', 'null.txt')

    it 'returns FPC_DIFF when passed different files', ->
      eq FPC_DIFF, (fullpathcmp f1, f2)
      eq FPC_DIFF, (fullpathcmp f2, f1)

    it 'returns FPC_DIFFX if only one does not exist', ->
      eq FPC_DIFFX, (fullpathcmp f1, 'null.txt')
      eq FPC_DIFFX, (fullpathcmp 'null.txt', f1)

