local helpers = require('test.unit.helpers')(after_each)
local itp = helpers.gen_itp(it)
local eval_helpers = require('test.unit.eval.helpers')

local cimport = helpers.cimport
local to_cstr = helpers.to_cstr
local eq = helpers.eq

local list = eval_helpers.list
local lst2tbl = eval_helpers.lst2tbl
local type_key = eval_helpers.type_key
local list_type = eval_helpers.list_type
local null_string = eval_helpers.null_string

local encode = cimport('./src/nvim/eval/encode.h')

describe('encode_list_write()', function()
  local encode_list_write = function(l, s)
    return encode.encode_list_write(l, to_cstr(s), #s)
  end

  itp('writes empty string', function()
    local l = list()
    eq(0, encode_list_write(l, ''))
    eq({[type_key]=list_type}, lst2tbl(l))
  end)

  itp('writes ASCII string literal with printable characters', function()
    local l = list()
    eq(0, encode_list_write(l, 'abc'))
    eq({'abc'}, lst2tbl(l))
  end)

  itp('writes string starting with NL', function()
    local l = list()
    eq(0, encode_list_write(l, '\nabc'))
    eq({null_string, 'abc'}, lst2tbl(l))
  end)

  itp('writes string starting with NL twice', function()
    local l = list()
    eq(0, encode_list_write(l, '\nabc'))
    eq({null_string, 'abc'}, lst2tbl(l))
    eq(0, encode_list_write(l, '\nabc'))
    eq({null_string, 'abc', 'abc'}, lst2tbl(l))
  end)

  itp('writes string ending with NL', function()
    local l = list()
    eq(0, encode_list_write(l, 'abc\n'))
    eq({'abc', null_string}, lst2tbl(l))
  end)

  itp('writes string ending with NL twice', function()
    local l = list()
    eq(0, encode_list_write(l, 'abc\n'))
    eq({'abc', null_string}, lst2tbl(l))
    eq(0, encode_list_write(l, 'abc\n'))
    eq({'abc', 'abc', null_string}, lst2tbl(l))
  end)

  itp('writes string starting, ending and containing NL twice', function()
    local l = list()
    eq(0, encode_list_write(l, '\na\nb\n'))
    eq({null_string, 'a', 'b', null_string}, lst2tbl(l))
    eq(0, encode_list_write(l, '\na\nb\n'))
    eq({null_string, 'a', 'b', null_string, 'a', 'b', null_string}, lst2tbl(l))
  end)

  itp('writes string starting, ending and containing NUL with NL between twice', function()
    local l = list()
    eq(0, encode_list_write(l, '\0\n\0\n\0'))
    eq({'\n', '\n', '\n'}, lst2tbl(l))
    eq(0, encode_list_write(l, '\0\n\0\n\0'))
    eq({'\n', '\n', '\n\n', '\n', '\n'}, lst2tbl(l))
  end)

  itp('writes string starting, ending and containing NL with NUL between twice', function()
    local l = list()
    eq(0, encode_list_write(l, '\n\0\n\0\n'))
    eq({null_string, '\n', '\n', null_string}, lst2tbl(l))
    eq(0, encode_list_write(l, '\n\0\n\0\n'))
    eq({null_string, '\n', '\n', null_string, '\n', '\n', null_string}, lst2tbl(l))
  end)

  itp('writes string containing a single NL twice', function()
    local l = list()
    eq(0, encode_list_write(l, '\n'))
    eq({null_string, null_string}, lst2tbl(l))
    eq(0, encode_list_write(l, '\n'))
    eq({null_string, null_string, null_string}, lst2tbl(l))
  end)

  itp('writes string containing a few NLs twice', function()
    local l = list()
    eq(0, encode_list_write(l, '\n\n\n'))
    eq({null_string, null_string, null_string, null_string}, lst2tbl(l))
    eq(0, encode_list_write(l, '\n\n\n'))
    eq({null_string, null_string, null_string, null_string, null_string, null_string, null_string}, lst2tbl(l))
  end)
end)
