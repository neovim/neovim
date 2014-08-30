local helpers = require('test.unit.helpers')

local cimport = helpers.cimport
local internalize = helpers.internalize
local eq = helpers.eq
local ffi = helpers.ffi
local lib = helpers.lib
local cstr = helpers.cstr
local to_cstr = helpers.to_cstr
local NULL = helpers.NULL

require('lfs')

local env = cimport('./src/nvim/os/os.h')

describe('env function', function()
  function os_setenv(name, value, override)
    return env.os_setenv((to_cstr(name)), (to_cstr(value)), override)
  end

  function os_getenv(name)
    local rval = env.os_getenv((to_cstr(name)))
    if rval ~= NULL then
      return ffi.string(rval)
    else
      return NULL
    end
  end

  describe('os_setenv', function()
    local OK = 0

    it('sets an env variable and returns OK', function()
      local name = 'NEOVIM_UNIT_TEST_SETENV_1N'
      local value = 'NEOVIM_UNIT_TEST_SETENV_1V'
      eq(nil, os.getenv(name))
      eq(OK, (os_setenv(name, value, 1)))
      eq(value, os.getenv(name))
    end)

    it("dosn't overwrite an env variable if overwrite is 0", function()
      local name = 'NEOVIM_UNIT_TEST_SETENV_2N'
      local value = 'NEOVIM_UNIT_TEST_SETENV_2V'
      local value_updated = 'NEOVIM_UNIT_TEST_SETENV_2V_UPDATED'
      eq(OK, (os_setenv(name, value, 0)))
      eq(value, os.getenv(name))
      eq(OK, (os_setenv(name, value_updated, 0)))
      eq(value, os.getenv(name))
    end)
  end)

  describe('os_getenv', function()
    it('reads an env variable', function()
      local name = 'NEOVIM_UNIT_TEST_GETENV_1N'
      local value = 'NEOVIM_UNIT_TEST_GETENV_1V'
      eq(NULL, os_getenv(name))
      -- need to use os_setenv, because lua dosn't have a setenv function
      os_setenv(name, value, 1)
      eq(value, os_getenv(name))
    end)

    it('returns NULL if the env variable is not found', function()
      local name = 'NEOVIM_UNIT_TEST_GETENV_NOTFOUND'
      return eq(NULL, os_getenv(name))
    end)
  end)

  describe('os_getenvname_at_index', function()
    it('returns names of environment variables', function()
      local test_name = 'NEOVIM_UNIT_TEST_GETENVNAME_AT_INDEX_1N'
      local test_value = 'NEOVIM_UNIT_TEST_GETENVNAME_AT_INDEX_1V'
      os_setenv(test_name, test_value, 1)
      local i = 0
      local names = { }
      local found_name = false
      local name = env.os_getenvname_at_index(i)
      while name ~= NULL do
        table.insert(names, ffi.string(name))
        if (ffi.string(name)) == test_name then
          found_name = true
        end
        i = i + 1
        name = env.os_getenvname_at_index(i)
      end
      eq(true, (table.getn(names)) > 0)
      eq(true, found_name)
    end)

    it('returns NULL if the index is out of bounds', function()
      local huge = ffi.new('size_t', 10000)
      local maxuint32 = ffi.new('size_t', 4294967295)
      eq(NULL, env.os_getenvname_at_index(huge))
      eq(NULL, env.os_getenvname_at_index(maxuint32))

      if ffi.abi('64bit') then
        -- couldn't use a bigger number because it gets converted to
        -- double somewere, should be big enough anyway
        -- maxuint64 = ffi.new 'size_t', 18446744073709551615
        local maxuint64 = ffi.new('size_t', 18446744073709000000)
        eq(NULL, env.os_getenvname_at_index(maxuint64))
      end
    end)
  end)

  describe('os_get_pid', function()
    it('returns the process ID', function()
      local stat_file = io.open('/proc/self/stat')
      if stat_file then
        local stat_str = stat_file:read('*l')
        stat_file:close()
        local pid = tonumber((stat_str:match('%d+')))
        eq(pid, tonumber(env.os_get_pid()))
      else
        -- /proc is not available on all systems, test if pid is nonzero.
        eq(true, (env.os_get_pid() > 0))
      end
    end)
  end)

  describe('os_get_hostname', function()
    it('returns the hostname', function()
      local handle = io.popen('hostname')
      local hostname = handle:read('*l')
      handle:close()
      local hostname_buf = cstr(255, '')
      env.os_get_hostname(hostname_buf, 255)
      eq(hostname, (ffi.string(hostname_buf)))
    end)
  end)
end)
