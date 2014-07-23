-- This file contains tests for value creation and various kinds of 
-- subscripting. Need a better name I guess.

describe('Dictionaries', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  ito('Generates dictionaries', [[
    echo string({})
    echo string({'a': 1})
    echo string({"A": 2})
    echo string({1 : 2})
    echo string({1:2})
    echo string({1:{1:{1:2}}})
  ]], {
    '{}',
    '{\'a\': 1}',
    '{\'A\': 2}',
    '{\'1\': 2}',
    '{\'1\': 2}',
    '{\'1\': {\'1\': {\'1\': 2}}}',
  })
  ito('Accepts dictionary subscripts', [[
    echo {'a': 1}['a']
    echo {'a': 2}.a
    echo {0x10 : 3}[16]
    echo {0x10 : 4}[0x10]
    echo {0x10 : 5}['16']
  ]], {
    1, 2, 3, 4, 5,
  })
  itoe('Raises an error when trying to check missing key', {
    'echo {}[\'a\']',
    'echo {}.a',
    'echo {"0x10": 1}.16',
    'echo {"0x10": 1}[0x10]',
    'echo {"0x10": 1}["16"]',
  }, {
    'Vim(echo):E716: Key not present in Dictionary: a',
    'Vim(echo):E716: Key not present in Dictionary: a',
    'Vim(echo):E716: Key not present in Dictionary: 16',
    'Vim(echo):E716: Key not present in Dictionary: 16',
    'Vim(echo):E716: Key not present in Dictionary: 16',
  })
  itoe('Raises an error when trying to slice dictionary', {
    'echo {}[:]',
    'echo {}[0:]',
    'echo {}[:0]',
    'echo {}[0:0]',
  }, {
    'Vim(echo):E719: Cannot use [:] with a Dictionary',
    'Vim(echo):E719: Cannot use [:] with a Dictionary',
    'Vim(echo):E719: Cannot use [:] with a Dictionary',
    'Vim(echo):E719: Cannot use [:] with a Dictionary',
  })
end)

describe('Lists', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  ito('Generates lists', [[
    echo string([])
    echo string([ [ [ ] ] ])
    echo string([1, 2])
  ]], {
    '[]',
    '[[[]]]',
    '[1, 2]',
  })
  ito('Accepts list subscripts', [[
    echo [1][0]
    echo [2, 3][1]
    echo [4, 5]['0x0']
    echo [6, 7]['0x1']
  ]], {1, 3, 4, 7})
  ito('Accepts empty slices', [[
    echo [][:]
    echo [1][:]
    echo [2, 3][:]
  ]], {
    {_t='list'}, {1}, {2, 3},
  })
  ito('Accepts slices only with start', [[
    echo [4, 5, 6][1:]
    echo [7, 8, 9][-1:]
    echo [10, 11, 12][-4:]
    echo [13, 14, 15][3:]
  ]], {
    {5, 6}, {9}, {_t='list'}, {_t='list'},
  })
  ito('Accepts slices only with end', [[
    echo [16, 17, 18][:0]
    echo [19, 20, 21][:1]
    echo [22, 23, 24][:-1]
    echo [25, 26, 27][:3]
    echo [28, 29, 30][:100]
    echo [31, 32, 33][:-4]
    echo [34, 35, 36][:-100]
  ]], {
    {16}, {19, 20}, {22, 23, 24}, {25, 26, 27}, {28, 29, 30},
    {_t='list'}, {_t='list'},
  })
  ito('Accepts slices with both ends', [[
    echo [16, 17, 18][0:0]
    echo [19, 20, 21][0:1]
    echo [22, 23, 24][0:-1]
    echo [25, 26, 27][0:3]
    echo [28, 29, 30][0:100]

    echo [31, 32, 33][0:-4]
    echo [34, 35, 36][0:-100]

    echo [4, 5, 6][1:-1]
    echo [7, 8, 9][-1:-1]
    echo [10, 11, 12][-4:-1]
    echo [13, 14, 15][3:-1]

    echo [4, 5, 6][1:100]
    echo [7, 8, 9][-1:100]
    echo [10, 11, 12][-4:100]
    echo [13, 14, 15][3:100]

    echo [1, 2, 3][1:0]
    echo [1, 2, 3][-2:1]
    echo [1, 2, 3][-2:0]
  ]], {
    {16}, {19, 20}, {22, 23, 24}, {25, 26, 27}, {28, 29, 30},
    {_t='list'}, {_t='list'},
    {5, 6}, {9}, {_t='list'}, {_t='list'},
    {5, 6}, {9}, {_t='list'}, {_t='list'},
    {_t='list'}, {2}, {_t='list'},
  })
  ito('Accepts strings in slices', [[
    echo [1, 2, 3]['-1':]
    echo [1, 2, 3]['-0x0':]

    echo [1, 2, 3][:'-1']
    echo [1, 2, 3][:'0x0']

    echo [1, 2, 3]['1':'-1']
    echo [1, 2, 3]['0x1':'0x2']
  ]], {
    {3}, {1, 2, 3},
    {1, 2, 3}, {1},
    {2, 3}, {2, 3},
  })
end)

describe('Numbers', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  ito('Generates numbers', [[
    echo 0
    echo 0x0
    echo 00
    echo 000
    echo 0000

    echo 10
    echo 0x10
    echo 010
    echo 0010

    echo 13
    echo 0x13
    echo 013
    echo 019
  ]], {
    0, 0, 0, 0, 0,
    10, 16, 8, 8,
    13, 19, 11, 19,
  })
  ito('Accepts number subscripts', [[
    echo 0x10[0]
    echo 0x20[1]

    echo 0x30[-1]
  ]], {'1', '2', ''})
  ito('Accepts empty number slices', [[
    echo 0x10[:]
  ]], {'16'})
  ito('Accepts number slices with one end', [[
    echo 0x200[-1:]
    echo 0x300[1:]

    echo 0x400[:-2]
    echo 0x500[:2]

    echo 0x600[20:]
    echo 0x700[-20:]

    echo 0x800[:20]
    echo 0x900[:-20]
  ]], {
    '2', '68',
    '102', '128',
    '', '',
    '2048', '',
  })
  ito('Accepts number slices with both ends', [[
    echo 0xA00[0:-1]
    echo 0xB00[1:3]

    echo 0xC00[-1000:1]
    echo 0xD00[1:-10000]

    echo 0xE00[1000:4]
    echo 0xF00[2:1000]

    echo 0x101[-2:-1]
    echo 0x202[-3:1]
  ]], {
    '2560', '816',
    '', '',
    '', '40',
    '57', '51',
  })
end)

describe('Strings', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  ito('Accepts single-quoted strings', table.concat({
    "echo 'abc'",

    "echo 'a\\eb'",
    "echo 'a''b'",

    "echo 'a\027b'",
  }, '\n'), {
    'abc',
    'a\\eb', 'a\'b',
    'a\027b'
  })
  ito('Accepts double-quoted strings', table.concat({
    'echo "a\\eb"',

    'echo "a\\"b"',
    'echo "a\\nb"',
    'echo "a\\rb"',
    'echo "a\\fb"',
    'echo "a\\bb"',

    'echo "a\\\'b"',
    'echo "a\'b"',

    -- FIXME The following cannot be tested until :set is implemented or UTF-8 
    --       is made default.
    -- 'echo "a\\u00abb"',
    -- 'echo "a\\U00abb"',

    'echo "a\\u0010b"',
    'echo "a\\U0010b"',
    'echo "a\\u10x"',
    'echo "a\\U10x"',


    'echo "a\\Xffb"',
    'echo "a\\xFFb"',
    'echo "a\\xFFb"',
    'echo "a\\Xffb"',
    'echo "a\255b"',
    'echo "a\\777b"',

    'echo "a\\1b"',
    'echo "a\\10b"',
    'echo "a\\100b"',
    'echo "a\\1000b"',

    'echo "a\\8b"',
    'echo "a\\9b"',

    'echo "a\\ux"',
    'echo "a\\Ux"',

    'echo "a\\<CR>b"',
  }, '|'), {
    'a\027b',
    'a"b', 'a\10b', 'a\13b', 'a\12b', 'a\8b',
    'a\'b', 'a\'b',
    -- 'a«b', 'a«b',
    'a\016b', 'a\016b', 'a\016x', 'a\016x',
    'a\255b', 'a\255b', 'a\255b', 'a\255b', 'a\255b', 'a\255b',
    'a\001b', 'a\008b', 'a\064b', 'a\0640b',
    'a8b', 'a9b',
    'aux', 'aUx',
    'a\13b',
  })
  ito('Accepts string subscripts', [[
    echo '10'[0]
    echo '20'[1]

    echo '30'[-1]
  ]], {'1', '0', ''})
  ito('Accepts empty string slices', [[
    echo '0x10'[:]
  ]], {'0x10'})
  ito('Accepts string slices with one end', [[
    echo '512'[-1:]
    echo '768'[1:]

    echo '1024'[:-2]
    echo '1280'[:2]

    echo '1536'[20:]
    echo '1792'[-20:]

    echo '2048'[:20]
    echo '2304'[:-20]
  ]], {
    '2', '68',
    '102', '128',
    '', '',
    '2048', '',
  })
  ito('Accepts string slices with both ends', [[
    echo '2560'[0:-1]
    echo '2816'[1:3]

    echo '3072'[-1000:1]
    echo '3328'[1:-10000]

    echo '3584'[1000:4]
    echo '3840'[2:1000]

    echo '257'[-2:-1]
    echo '514'[-3:1]
  ]], {
    '2560', '816',
    '', '',
    '', '40',
    '57', '51',
  })
end)

describe('Float', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  ito('Generates floats', [[
    echo 1.0

    echo 1.0e1
    echo 1.0e+1
    echo 1.0e-1

    echo 1.0e01
    echo 1.0e+01
    echo 1.0e-01
  ]], {
    f(1),
    f(10), f(10), f(0.1),
    f(10), f(10), f(0.1),
  })
  itoe('Does not allow float subscripting and slicing', {
    'echo 1.0[0]',
    'echo 1.0[:]',
    'echo 1.0[0:]',
    'echo 1.0[:-1]',
    'echo 1.0[0:-1]',
  }, {
    'Vim(echo):E806: Using Float as a String',
    'Vim(echo):E806: Using Float as a String',
    'Vim(echo):E806: Using Float as a String',
    'Vim(echo):E806: Using Float as a String',
    'Vim(echo):E806: Using Float as a String',
  })
end)

describe('Funcref', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  itoe('Does not allow funcref subscripting and slicing', {
    'echo function("function")[0]',
    'echo function("function")[:]',
    'echo function("function")[0:]',
    'echo function("function")[:-1]',
    'echo function("function")[0:-1]',
  }, {
    'Vim(echo):E695: Cannot index a Funcref',
    'Vim(echo):E695: Cannot index a Funcref',
    'Vim(echo):E695: Cannot index a Funcref',
    'Vim(echo):E695: Cannot index a Funcref',
    'Vim(echo):E695: Cannot index a Funcref',
  })
end)
