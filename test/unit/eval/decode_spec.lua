local ffi = require('ffi')
local helpers = require('test.unit.helpers')
local eval_helpers = require('test.unit.eval.helpers')

local cimport = helpers.cimport
local to_cstr = helpers.to_cstr
local eq = helpers.eq

local list = eval_helpers.list
local lst2tbl = eval_helpers.lst2tbl
local type_key = eval_helpers.type_key
local list_type = eval_helpers.list_type
local null_string = eval_helpers.null_string

local decode = cimport('./src/nvim/eval/decode.h', './src/nvim/eval_defs.h',
                       './src/nvim/globals.h', './src/nvim/memory.h')

describe('json_decode_string()', function()
  after_each(function()
    decode.emsg_silent = 0
  end)

  it('does not overflow when running with `n…`, `t…`, `f…`', function()
    local rettv = ffi.new('typval_T')
    decode.emsg_silent = 1
    rettv.v_type = decode.VAR_UNKNOWN
    -- This will not crash, but if `len` argument will be ignored it will parse 
    -- `null` as `null` and if not it will parse `null` as `n`.
    eq(0, decode.json_decode_string('null', 1, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string('true', 1, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string('false', 1, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string('null', 2, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string('true', 2, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string('false', 2, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string('null', 3, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string('true', 3, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string('false', 3, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string('false', 4, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
  end)

  it('does not overflow and crash when running with `n`, `t`, `f`', function()
    local rettv = ffi.new('typval_T')
    decode.emsg_silent = 1
    rettv.v_type = decode.VAR_UNKNOWN
    local char = function(c)
      return ffi.gc(decode.xmemdup(c, 1), decode.xfree)
    end
    eq(0, decode.json_decode_string(char('n'), 1, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string(char('t'), 1, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string(char('f'), 1, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
  end)
end)
