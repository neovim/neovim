local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local ffi = t.ffi
local eq = t.eq
local neq = t.neq

local keycodes = t.cimport('./src/nvim/keycodes.h')
local NULL = t.NULL

describe('keycodes.c', function()
  describe('find_special_key()', function()
    local srcp = ffi.new('const unsigned char *[1]')
    local modp = ffi.new('int[1]')

    itp('no keycode', function()
      srcp[0] = 'abc'
      eq(0, keycodes.find_special_key(srcp, 3, modp, 0, NULL))
    end)

    itp('keycode with multiple modifiers', function()
      srcp[0] = '<C-M-S-A>'
      neq(0, keycodes.find_special_key(srcp, 9, modp, 0, NULL))
      neq(0, modp[0])
    end)

    itp('case-insensitive', function()
      -- Compare other capitalizations to this.
      srcp[0] = '<C-A>'
      local all_caps_key = keycodes.find_special_key(srcp, 5, modp, 0, NULL)
      local all_caps_mod = modp[0]

      srcp[0] = '<C-a>'
      eq(all_caps_key, keycodes.find_special_key(srcp, 5, modp, 0, NULL))
      eq(all_caps_mod, modp[0])

      srcp[0] = '<c-A>'
      eq(all_caps_key, keycodes.find_special_key(srcp, 5, modp, 0, NULL))
      eq(all_caps_mod, modp[0])

      srcp[0] = '<c-a>'
      eq(all_caps_key, keycodes.find_special_key(srcp, 5, modp, 0, NULL))
      eq(all_caps_mod, modp[0])
    end)

    itp('double-quote in keycode #7411', function()
      -- Unescaped with in_string=false
      srcp[0] = '<C-">'
      eq(string.byte('"'), keycodes.find_special_key(srcp, 5, modp, 0, NULL))

      -- Unescaped with in_string=true
      eq(0, keycodes.find_special_key(srcp, 5, modp, keycodes.FSK_IN_STRING, NULL))

      -- Escaped with in_string=false
      srcp[0] = '<C-\\">'
      -- Should fail because the key is invalid
      -- (more than 1 non-modifier character).
      eq(0, keycodes.find_special_key(srcp, 6, modp, 0, NULL))

      -- Escaped with in_string=true
      eq(string.byte('"'), keycodes.find_special_key(srcp, 6, modp, keycodes.FSK_IN_STRING, NULL))
    end)
  end)
end)
