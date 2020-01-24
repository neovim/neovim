local helpers = require('test.unit.helpers')(after_each)
local itp = helpers.gen_itp(it)

local cimport = helpers.cimport
local eq = helpers.eq
local to_cstr = helpers.to_cstr
local NULL = helpers.NULL
local ffi = helpers.ffi

local cimp = cimport('./src/nvim/os/os.h')

local var_name = 'XDG_CONFIG_HOME'
local var_id = 0

describe('stdpaths.c', function()
  local function get_xdghome()
    local val = cimp.stdpaths_get_xdg_var(var_id)
    if val ~= NULL then
      return ffi.string(val)
    else
      return NULL
    end
  end

  local function set_xdghome(value)
    return cimp.os_setenv(to_cstr(var_name), to_cstr(value), 1)
  end

  describe('stdpaths_get_xdg_var', function()
    itp('filters duplicate paths from environment variables', function()
      local original = '/usr/share:/usr/share:/usr/local/share'
      local expected = '/usr/share:/usr/local/share'

      set_xdghome(original)
      eq(expected, get_xdghome())
    end)

    itp('works with empty environment variables', function()
      set_xdghome('')
      eq('', get_xdghome())
    end)

    itp('does not change valid environment variables', function()
      local original = '/usr/local/share:/usr/share'
      set_xdghome(original)
      eq(original, get_xdghome())
    end)
  end)
end)

