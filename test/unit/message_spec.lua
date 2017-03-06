local helpers = require("test.unit.helpers")

local ffi = helpers.ffi
local eq = helpers.eq
local to_cstr = helpers.to_cstr

local cimp = helpers.cimport('./src/nvim/message.h')

describe('trunc_string', function()
  local buffer = ffi.typeof('char_u[40]')

  local function test_inplace(s, expected)
    local buf = buffer()
    ffi.C.strcpy(buf, s)
    cimp.trunc_string(buf, buf, 20, 40)
    eq(expected, ffi.string(buf))
  end

  local function test_copy(s, expected)
    local buf = buffer()
    cimp.trunc_string(to_cstr(s), buf, 20, 40)
    eq(expected, ffi.string(buf))
  end

  local permutations = {
    { ['desc'] = 'in-place', ['func'] = test_inplace },
    { ['desc'] = 'by copy', ['func'] = test_copy },
  }

  for _,t in ipairs(permutations) do
    describe('populates buf '..t.desc, function()
      it('with a small string', function()
        t.func('text', 'text')
      end)

      it('with a medium string', function()
        t.func('a short text', 'a short text')
      end)

      it('with a string exactly the truncate size', function()
        t.func('a text tha just fits', 'a text tha just fits')
      end)

      it('with a string that must be truncated', function()
        t.func('a text that nott fits', 'a text t...nott fits')
      end)
    end)
  end
end)
