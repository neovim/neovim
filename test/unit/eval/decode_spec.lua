local helpers = require('test.unit.helpers')(after_each)
local itp = helpers.gen_itp(it)

local cimport = helpers.cimport
local eq = helpers.eq
local neq = helpers.neq
local ffi = helpers.ffi

local decode = cimport('./src/nvim/eval/decode.h', './src/nvim/eval/typval.h',
                       './src/nvim/globals.h', './src/nvim/memory.h',
                       './src/nvim/message.h')

describe('json_decode_string()', function()
  local char = function(c)
    return ffi.gc(decode.xmemdup(c, 1), decode.xfree)
  end

  itp('does not overflow when running with `n…`, `t…`, `f…`', function()
    local rettv = ffi.new('typval_T', {v_type=decode.VAR_UNKNOWN})
    decode.emsg_silent = 1
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

  itp('does not overflow and crash when running with `n`, `t`, `f`', function()
    local rettv = ffi.new('typval_T', {v_type=decode.VAR_UNKNOWN})
    decode.emsg_silent = 1
    eq(0, decode.json_decode_string(char('n'), 1, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string(char('t'), 1, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string(char('f'), 1, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
  end)

  itp('does not overflow when running with `"…`', function()
    local rettv = ffi.new('typval_T', {v_type=decode.VAR_UNKNOWN})
    decode.emsg_silent = 1
    eq(0, decode.json_decode_string('"t"', 2, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    eq(0, decode.json_decode_string('""', 1, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
  end)

  local check_failure = function(s, len, msg)
    local rettv = ffi.new('typval_T', {v_type=decode.VAR_UNKNOWN})
    eq(0, decode.json_decode_string(s, len, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
    neq(nil, decode.last_msg_hist)
    eq(msg, ffi.string(decode.last_msg_hist.msg))
  end

  itp('does not overflow in error messages', function()
    collectgarbage('restart')
    check_failure(']test', 1, 'E474: No container to close: ]')
    check_failure('[}test', 2, 'E474: Closing list with curly bracket: }')
    check_failure('{]test', 2,
                  'E474: Closing dictionary with square bracket: ]')
    check_failure('[1,]test', 4, 'E474: Trailing comma: ]')
    check_failure('{"1":}test', 6, 'E474: Expected value after colon: }')
    check_failure('{"1"}test', 5, 'E474: Expected value: }')
    check_failure(',test', 1, 'E474: Comma not inside container: ,')
    check_failure('[1,,1]test', 6, 'E474: Duplicate comma: ,1]')
    check_failure('{"1":,}test', 7, 'E474: Comma after colon: ,}')
    check_failure('{"1",}test', 6, 'E474: Using comma in place of colon: ,}')
    check_failure('{,}test', 3, 'E474: Leading comma: ,}')
    check_failure('[,]test', 3, 'E474: Leading comma: ,]')
    check_failure(':test', 1, 'E474: Colon not inside container: :')
    check_failure('[:]test', 3, 'E474: Using colon not in dictionary: :]')
    check_failure('{:}test', 3, 'E474: Unexpected colon: :}')
    check_failure('{"1"::1}test', 8, 'E474: Duplicate colon: :1}')
    check_failure('ntest', 1, 'E474: Expected null: n')
    check_failure('ttest', 1, 'E474: Expected true: t')
    check_failure('ftest', 1, 'E474: Expected false: f')
    check_failure('"\\test', 2, 'E474: Unfinished escape sequence: "\\')
    check_failure('"\\u"test', 4,
                  'E474: Unfinished unicode escape sequence: "\\u"')
    check_failure('"\\uXXXX"est', 8,
                  'E474: Expected four hex digits after \\u: \\uXXXX"')
    check_failure('"\\?"test', 4, 'E474: Unknown escape sequence: \\?"')
    check_failure(
        '"\t"test', 3,
        'E474: ASCII control characters cannot be present inside string: \t"')
    check_failure('"\194"test', 3, 'E474: Only UTF-8 strings allowed: \194"')
    check_failure('"\252\144\128\128\128\128"test', 8, 'E474: Only UTF-8 code points up to U+10FFFF are allowed to appear unescaped: \252\144\128\128\128\128"')
    check_failure('"test', 1, 'E474: Expected string end: "')
    check_failure('-test', 1, 'E474: Missing number after minus sign: -')
    check_failure('-1.test', 3, 'E474: Missing number after decimal dot: -1.')
    check_failure('-1.0etest', 5, 'E474: Missing exponent: -1.0e')
    check_failure('?test', 1, 'E474: Unidentified byte: ?')
    check_failure('1?test', 2, 'E474: Trailing characters: ?')
    check_failure('[1test', 2, 'E474: Unexpected end of input: [1')
  end)

  itp('does not overflow with `-`', function()
    check_failure('-0', 1, 'E474: Missing number after minus sign: -')
  end)

  itp('does not overflow and crash when running with `"`', function()
    local rettv = ffi.new('typval_T', {v_type=decode.VAR_UNKNOWN})
    decode.emsg_silent = 1
    eq(0, decode.json_decode_string(char('"'), 1, rettv))
    eq(decode.VAR_UNKNOWN, rettv.v_type)
  end)
end)
