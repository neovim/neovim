local t = require('test.unit.testutil')
local describe = t.describe
local itp = t.gen_itp(t.it)

local cimport = t.cimport
local ffi = t.ffi
local eq = t.eq
local to_cstr = t.to_cstr

local api = cimport(
  './src/nvim/api/private/defs.h',
  './src/nvim/api/private/helpers.h',
  './src/nvim/api/private/validate.h',
  './src/nvim/globals.h',
  './src/nvim/memory.h'
)

local function make_string_array(strs)
  local n = #strs
  local items = ffi.cast('Object *', api.xmalloc(n * ffi.sizeof('Object')))
  for i, s in ipairs(strs) do
    items[i - 1] = ffi.new('Object', {
      ['type'] = api.kObjectTypeString,
      data = { string = { data = api.xmemdupz(to_cstr(s), #s), size = #s } },
    })
  end
  return ffi.new('Array', { items = items, size = n, capacity = n })
end

describe('check_string_array()', function()
  itp('does not clobber IObuff', function()
    local sentinel = 'abcdef'
    ffi.copy(api.IObuff, sentinel)

    local arr = make_string_array({ 'a', 'b', 'c' })
    local err = ffi.new('Error', { type = api.kErrorTypeNone })
    eq(true, api.check_string_array(arr, to_cstr('lines'), false, err))
    eq(sentinel, ffi.string(api.IObuff))
  end)
end)
