{:cimport, :internalize, :eq, :ffi} = require 'test.unit.helpers'

misc1 = cimport './src/misc1.h'
cstr = ffi.typeof 'char[?]'

-- TODO extract constants from vim.h

describe 'misc1 function', ->
  describe 'fullpathcmp', ->
    ffi.cdef 'int fullpathcmp(char *s1, char *s2, int checkname);'
    fullpathcmp = (s1, s2, cn) ->
      s1 = cstr (string.len s1) + 1, s1
      s2 = cstr (string.len s2) + 1, s2
      misc1.fullpathcmp s1, s2, cn or 0

    f1 = 'f1.o'
    f2 = 'f2.o'
    f3 = 'test/f1.o'
    FPC_SAME = 1
    FPC_DIFF = 2
    FPC_NOTX = 4
    FPC_DIFFX = 6
    FPC_SAMEX = 7

    before_each ->
      -- create the three files that will be used in this spec
      (io.open f1, 'w').close!
      (io.open f2, 'w').close!
      (io.open f3, 'w').close!

    after_each ->
      os.remove f1
      os.remove f2
      os.remove f3
    
    it 'returns FPC_SAME when passed the same file', ->
      eq FPC_SAME, (fullpathcmp f1, f1)

