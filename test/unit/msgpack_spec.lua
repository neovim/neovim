local t = require('test.unit.testutil')(after_each)
local cimport = t.cimport
local itp = t.gen_itp(it)
local lib = cimport('./src/nvim/msgpack_rpc/unpacker.h', './src/nvim/memory.h')
local ffi = t.ffi
local eq = t.eq
local to_cstr = t.to_cstr

--- @class Unpacker
--- @field read_ptr ffi.cdata*
--- @field read_size number

--- @alias Unpacker* table<number, Unpacker>
--- @return Unpacker* unpacker `unpacker[0]` to dereference
local function make_unpacker()
  return ffi.gc(ffi.cast('Unpacker*', lib.xcalloc(1, ffi.sizeof('Unpacker'))), function(unpacker)
    lib.unpacker_teardown(unpacker, nil, nil)
    lib.xfree(unpacker)
  end)
end

--- @param unpacker Unpacker*
--- @param data string
--- @param size number? *default: data:len()*
local function unpacker_goto(unpacker, data, size)
  unpacker[0].read_ptr = to_cstr(data)
  unpacker[0].read_size = size or data:len()
end

--- @param unpacker Unpacker*
--- @return boolean
local function unpacker_advance(unpacker)
  return lib.unpacker_advance(unpacker)
end

describe('msgpack', function()
  describe('unpacker', function()
    itp(
      'does not crash when paused between `cells` and `wrap` params of `grid_line` #25184',
      function()
        -- [kMessageTypeNotification, "redraw", [
        --   ["grid_line",
        --     [2, 0, 0, [[" " , 0, 77]], false]
        --   ]
        -- ]]
        local payload =
          '\x93\x02\xa6\x72\x65\x64\x72\x61\x77\x91\x92\xa9\x67\x72\x69\x64\x5f\x6c\x69\x6e\x65\x95\x02\x00\x00\x91\x93\xa1\x20\x00\x4d\xc2'

        local unpacker = make_unpacker()
        lib.unpacker_init(unpacker)

        unpacker_goto(unpacker, payload, payload:len() - 1)
        local finished = unpacker_advance(unpacker)
        eq(false, finished)

        unpacker[0].read_size = unpacker[0].read_size + 1
        finished = unpacker_advance(unpacker)
        eq(true, finished)
      end
    )

    itp('does not crash when parsing grid_line event with 0 `cells` #25184', function()
      local unpacker = make_unpacker()
      lib.unpacker_init(unpacker)

      unpacker_goto(
        unpacker,
        -- [kMessageTypeNotification, "redraw", [
        --   ["grid_line",
        --     [2, 0, 0, [], false]
        --   ]
        -- ]]
        '\x93\x02\xa6\x72\x65\x64\x72\x61\x77\x91\x92\xa9\x67\x72\x69\x64\x5f\x6c\x69\x6e\x65\x95\x02\x00\x00\x90\xc2'
      )
      local finished = unpacker_advance(unpacker)
      eq(true, finished)
    end)
  end)
end)
