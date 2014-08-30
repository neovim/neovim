local helpers = require('test.unit.helpers')
local ffi, eq = helpers.ffi, helpers.eq
local intern = helpers.internalize
local to_cstr = helpers.to_cstr
local NULL = helpers.NULL

local ex_cmds2 = helpers.cimport(
  './src/nvim/os/shell.h',
  './src/nvim/ex_cmds_defs.h',
  './src/nvim/ex_getln.h',
  './src/nvim/ex_cmds2.h'
)


describe('ex_cmds2 functions', function()
  describe('find_locales', function()
    function find_locale(idx)
      return intern(ex_cmds2.find_locale_helper(idx))
    end

    before_each(function()
      ex_cmds2.set_os_system_mock(function(cmd, input, len)
        eq(intern(cmd), 'locale -a') -- command used to obtain locales
        return to_cstr('locale1\nlocale2\nlocale3')
      end)
    end)

    after_each(function()
      ex_cmds2.set_os_system_mock(NULL)
    end)

    it('splits the locales', function()
      eq('locale1', find_locale(0))
      eq('locale2', find_locale(1))
      eq('locale3', find_locale(2))
    end)
  end)
end)
