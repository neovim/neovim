local helpers = require('test.unit.helpers')

local eq      = helpers.eq
local ffi     = helpers.ffi
local strings = helpers.cimport('./src/nvim/strings.h')
local to_cstr = helpers.to_cstr

-- construct an interface
local vim_strchr = function(str, c)
  return strings.vim_strchr(to_cstr(str), c)
end

local vim_strbyte = function(str, c)
  return strings.vim_strbyte(to_cstr(str), c)
end

describe('test strings functions', function()
  it("tests the vim_strchr function", function()
    local ptr = nil
    local c = 0
    strs = {
      string.char(115, 90, 52, 15, 67), -- ascii
      string.char(255, 254, 253, 210, 167), -- extended ascii
      "iamateststring" -- multibyte
    }

    for i, str in ipairs(strs) do
      c = string.byte(str, 3)

      ptr = vim_strchr(str, c)
      if ptr == nil then
        error("couldn't find char " .. c ..
        " (" .. string.char(c) .. ") in " .. str)
      end

      eq(string.char(c), ffi.string(ptr, 1))
    end
  end)

  it("tests the vim_strbyte function", function()
    local c = 0
    local ptr = nil
    str = string.char(255, 254, 253, 210, 167)

    eq(vim_strbyte(str, 0), nil)
    eq(vim_strbyte(str, 256), nil)

    for i = 1, string.len(str) do
      c = string.byte(string.sub(str, i, i))

      ptr = vim_strbyte(str, c)
      if ptr == nil then
        error("couldn't find char " .. c ..
        " (" .. string.char(c) .. ") in " .. str)
      end

      eq(string.char(c), ffi.string(ptr, 1))
    end
  end)
end)
