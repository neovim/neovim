local helpers = require("test.unit.helpers")
local cimport = helpers.cimport
local env = cimport('./src/nvim/os/os.h')
local eq = helpers.eq
local neq = helpers.neq

describe('Dont use $VIM/$VIMRUNTIME', function()

  env.os_unsetenv('NVIM')
  env.os_unsetenv('NVIMRUNTIME')
  env.os_setenv('VIM', 'VIM_VALUE', 1)
  env.os_setenv('VIMRUNTIME', 'VIMRUNTIME_VALUE', 1)

  helpers.vim_init()

  describe('$VIM is cleared if $NVIM is unset', function()
      neq(os.getenv('VIM'), 'VIM_VALUE')
  end)
  describe('$VIMRUNTIME is cleared if $NVIMRUNTIME is unset', function()
      neq(os.getenv('VIMRUNTIME'), 'VIMRUNTIME_VALUE')
  end)
end)

