{:cimport, :internalize, :eq, :ffi, :lib, :cstr, :to_cstr} = require 'test.unit.helpers'
require 'lfs'

-- fs = cimport './src/os/os.h'
-- remove these statements once 'cimport' is working properly for misc1.h
env = lib
ffi.cdef [[
const char *mch_getenv(const char *name);
int mch_setenv(const char *name, const char *value, int override);
char *mch_getenvname_at_index(size_t index);
]]

NULL = ffi.cast 'void*', 0

describe 'env function', ->

  mch_setenv = (name, value, override) ->
    env.mch_setenv (to_cstr name), (to_cstr value), override

  mch_getenv = (name) ->
    rval = env.mch_getenv (to_cstr name)
    if rval != NULL
      ffi.string rval
    else
      NULL

  describe 'mch_setenv', ->

    OK = 0

    it 'sets an env variable and returns OK', ->
      name = 'NEOVIM_UNIT_TEST_SETENV_1N'
      value = 'NEOVIM_UNIT_TEST_SETENV_1V'
      eq nil, os.getenv name
      eq OK, (mch_setenv name, value, 1)
      eq value, os.getenv name

    it "dosn't overwrite an env variable if overwrite is 0", ->
      name = 'NEOVIM_UNIT_TEST_SETENV_2N'
      value = 'NEOVIM_UNIT_TEST_SETENV_2V'
      value_updated = 'NEOVIM_UNIT_TEST_SETENV_2V_UPDATED'
      eq OK, (mch_setenv name, value, 0)
      eq value, os.getenv name
      eq OK, (mch_setenv name, value_updated, 0)
      eq value, os.getenv name

  describe 'mch_getenv', ->

    it 'reads an env variable', ->
      name = 'NEOVIM_UNIT_TEST_GETENV_1N'
      value =  'NEOVIM_UNIT_TEST_GETENV_1V'
      eq NULL, mch_getenv name
      -- need to use mch_setenv, because lua dosn't have a setenv function
      mch_setenv name, value, 1
      eq value, mch_getenv name

    it 'returns NULL if the env variable is not found', ->
      name = 'NEOVIM_UNIT_TEST_GETENV_NOTFOUND'
      eq NULL, mch_getenv name

  describe 'mch_getenvname_at_index', ->

    it 'returns names of environment variables', ->
      test_name = 'NEOVIM_UNIT_TEST_GETENVNAME_AT_INDEX_1N'
      test_value =  'NEOVIM_UNIT_TEST_GETENVNAME_AT_INDEX_1V'
      mch_setenv test_name, test_value, 1
      i = 0
      names = {}
      found_name = false
      name = env.mch_getenvname_at_index i
      while name != NULL
        table.insert names, ffi.string name
        if (ffi.string name) == test_name
          found_name = true
        i += 1
        name = env.mch_getenvname_at_index i

      eq true, (table.getn names) > 0
      eq true, found_name

    it 'returns NULL if the index is out of bounds', ->
      huge = ffi.new 'size_t', 10000
      maxuint32 = ffi.new 'size_t', 4294967295
      eq NULL, env.mch_getenvname_at_index huge
      eq NULL, env.mch_getenvname_at_index maxuint32
      if ffi.abi '64bit'
        -- couldn't use a bigger number because it gets converted to 
        -- double somewere, should be big enough anyway
        -- maxuint64 = ffi.new 'size_t', 18446744073709551615
        maxuint64 = ffi.new 'size_t', 18446744073709000000
        eq NULL, env.mch_getenvname_at_index maxuint64

