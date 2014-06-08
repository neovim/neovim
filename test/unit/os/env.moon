{:cimport, :internalize, :eq, :ffi, :lib, :cstr, :to_cstr} = require 'test.unit.helpers'
require 'lfs'

env = cimport './src/nvim/os/os.h'

NULL = ffi.cast 'void*', 0

describe 'env function', ->

  os_setenv = (name, value, override) ->
    env.os_setenv (to_cstr name), (to_cstr value), override

  os_getenv = (name) ->
    rval = env.os_getenv (to_cstr name)
    if rval != NULL
      ffi.string rval
    else
      NULL

  describe 'os_setenv', ->

    OK = 0

    it 'sets an env variable and returns OK', ->
      name = 'NEOVIM_UNIT_TEST_SETENV_1N'
      value = 'NEOVIM_UNIT_TEST_SETENV_1V'
      eq nil, os.getenv name
      eq OK, (os_setenv name, value, 1)
      eq value, os.getenv name

    it "dosn't overwrite an env variable if overwrite is 0", ->
      name = 'NEOVIM_UNIT_TEST_SETENV_2N'
      value = 'NEOVIM_UNIT_TEST_SETENV_2V'
      value_updated = 'NEOVIM_UNIT_TEST_SETENV_2V_UPDATED'
      eq OK, (os_setenv name, value, 0)
      eq value, os.getenv name
      eq OK, (os_setenv name, value_updated, 0)
      eq value, os.getenv name

  describe 'os_getenv', ->

    it 'reads an env variable', ->
      name = 'NEOVIM_UNIT_TEST_GETENV_1N'
      value =  'NEOVIM_UNIT_TEST_GETENV_1V'
      eq NULL, os_getenv name
      -- need to use os_setenv, because lua dosn't have a setenv function
      os_setenv name, value, 1
      eq value, os_getenv name

    it 'returns NULL if the env variable is not found', ->
      name = 'NEOVIM_UNIT_TEST_GETENV_NOTFOUND'
      eq NULL, os_getenv name

  describe 'os_getenvname_at_index', ->

    it 'returns names of environment variables', ->
      test_name = 'NEOVIM_UNIT_TEST_GETENVNAME_AT_INDEX_1N'
      test_value =  'NEOVIM_UNIT_TEST_GETENVNAME_AT_INDEX_1V'
      os_setenv test_name, test_value, 1
      i = 0
      names = {}
      found_name = false
      name = env.os_getenvname_at_index i
      while name != NULL
        table.insert names, ffi.string name
        if (ffi.string name) == test_name
          found_name = true
        i += 1
        name = env.os_getenvname_at_index i

      eq true, (table.getn names) > 0
      eq true, found_name

    it 'returns NULL if the index is out of bounds', ->
      huge = ffi.new 'size_t', 10000
      maxuint32 = ffi.new 'size_t', 4294967295
      eq NULL, env.os_getenvname_at_index huge
      eq NULL, env.os_getenvname_at_index maxuint32
      if ffi.abi '64bit'
        -- couldn't use a bigger number because it gets converted to
        -- double somewere, should be big enough anyway
        -- maxuint64 = ffi.new 'size_t', 18446744073709551615
        maxuint64 = ffi.new 'size_t', 18446744073709000000
        eq NULL, env.os_getenvname_at_index maxuint64

  describe 'os_get_pid', ->

    it 'returns the process ID', ->
      stat_file = io.open '/proc/self/stat'
      if stat_file
        stat_str = stat_file\read '*l'
        stat_file\close!
        pid = tonumber (stat_str\match '%d+')
        eq pid, tonumber env.os_get_pid!
      else
        -- /proc is not available on all systems, test if pid is nonzero.
        eq true, (env.os_get_pid! > 0)

  describe 'os_get_hostname', ->

    it 'returns the hostname', ->
      handle = io.popen 'hostname'
      hostname = handle\read '*l'
      handle\close!
      hostname_buf = cstr 255, ''
      env.os_get_hostname hostname_buf, 255
      eq hostname,  (ffi.string hostname_buf)

