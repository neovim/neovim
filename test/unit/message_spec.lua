local helpers = require("test.unit.helpers")(after_each)
local itp = helpers.gen_itp(it)

local ffi = helpers.ffi
local eq = helpers.eq
local to_cstr = helpers.to_cstr

local cimp = helpers.cimport('./src/nvim/message.h', './src/nvim/memory.h',
                             './src/nvim/strings.h')

describe('trunc_string', function()
  local buflen = 40
  local function test_inplace(s, expected, room)
    room = room and room or 20
    local buf = cimp.xmalloc(ffi.sizeof('char_u') * buflen)
    ffi.C.strcpy(buf, s)
    cimp.trunc_string(buf, buf, room, buflen)
    eq(expected, ffi.string(buf))
    cimp.xfree(buf)
  end

  local function test_copy(s, expected, room)
    room = room and room or 20
    local buf = cimp.xmalloc(ffi.sizeof('char_u') * buflen)
    local str = cimp.vim_strsave(to_cstr(s))
    cimp.trunc_string(str, buf, room, buflen)
    eq(expected, ffi.string(buf))
    cimp.xfree(buf)
    cimp.xfree(str)
  end

  local permutations = {
    { ['desc'] = 'in-place', ['func'] = test_inplace },
    { ['desc'] = 'by copy', ['func'] = test_copy },
  }

  for _,t in ipairs(permutations) do
    describe('populates buf '..t.desc, function()
      itp('with a small string', function()
        t.func('text', 'text')
      end)

      itp('with a medium string', function()
        t.func('a short text', 'a short text')
      end)

      itp('with a string of length == 1/2 room', function()
        t.func('a text that fits', 'a text that fits', 34)
      end)

      itp('with a string exactly the truncate size', function()
        t.func('a text tha just fits', 'a text tha just fits')
      end)

      itp('with a string that must be truncated', function()
        t.func('a text that nott fits', 'a text t...nott fits')
      end)
    end)
  end
end)
