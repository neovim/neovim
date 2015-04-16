local helpers = require("test.unit.helpers")
local cimport = helpers.cimport
local env = cimport('./src/nvim/os/os.h')
local eq = helpers.eq

describe('Use $NVIM/$NVIMRUNTIME as $VIM/$VIMRUNTIME', function()

  env.os_setenv('NVIM', 'NVIM_VALUE', 1)
  env.os_setenv('NVIMRUNTIME', 'NVIMRUNTIME_VALUE', 1)

  helpers.vim_init()

  describe('$VIM is $NVIM', function()
      eq(os.getenv('VIM'), os.getenv('NVIM'))
  end)
  describe('$VIMRUNTIME is $NVIMRUNTIME', function()
      eq(os.getenv('VIMRUNTIME'), os.getenv('NVIMRUNTIME'))
  end)
end)

