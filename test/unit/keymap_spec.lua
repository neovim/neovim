local helpers = require("test.unit.helpers")(after_each)
local itp = helpers.gen_itp(it)

local ffi     = helpers.ffi
local eq      = helpers.eq
local neq     = helpers.neq

local keymap = helpers.cimport("./src/nvim/keymap.h")

describe('keymap.c', function()

  describe('find_special_key()', function()
    local srcp = ffi.new('const unsigned char *[1]')
    local modp = ffi.new('int[1]')

    itp('no keycode', function()
      srcp[0] = 'abc'
      eq(0, keymap.find_special_key(srcp, 3, modp, false, false, false))
    end)

    itp('keycode with multiple modifiers', function()
      srcp[0] = '<C-M-S-A>'
      neq(0, keymap.find_special_key(srcp, 9, modp, false, false, false))
      neq(0, modp[0])
    end)

    itp('case-insensitive', function()
      -- Compare other capitalizations to this.
      srcp[0] = '<C-A>'
      local all_caps_key =
          keymap.find_special_key(srcp, 5, modp, false, false, false)
      local all_caps_mod = modp[0]

      srcp[0] = '<C-a>'
      eq(all_caps_key,
         keymap.find_special_key(srcp, 5, modp, false, false, false))
      eq(all_caps_mod, modp[0])

      srcp[0] = '<c-A>'
      eq(all_caps_key,
         keymap.find_special_key(srcp, 5, modp, false, false, false))
      eq(all_caps_mod, modp[0])

      srcp[0] = '<c-a>'
      eq(all_caps_key,
         keymap.find_special_key(srcp, 5, modp, false, false, false))
      eq(all_caps_mod, modp[0])
    end)

    itp('double-quote in keycode #7411', function()
      -- Unescaped with in_string=false
      srcp[0] = '<C-">'
      eq(string.byte('"'),
         keymap.find_special_key(srcp, 5, modp, false, false, false))

      -- Unescaped with in_string=true
      eq(0, keymap.find_special_key(srcp, 5, modp, false, false, true))

      -- Escaped with in_string=false
      srcp[0] = '<C-\\">'
      -- Should fail because the key is invalid
      -- (more than 1 non-modifier character).
      eq(0, keymap.find_special_key(srcp, 6, modp, false, false, false))

      -- Escaped with in_string=true
      eq(string.byte('"'),
         keymap.find_special_key(srcp, 6, modp, false, false, true))
    end)
  end)

end)
