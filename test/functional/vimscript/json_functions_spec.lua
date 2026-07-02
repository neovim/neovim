local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local fn = n.fn
local api = n.api
local eq = t.eq
local matches = t.matches
local eval = n.eval
local command = n.command
local pcall_err = t.pcall_err
local NIL = vim.NIL
local source = n.source

--- Assert that json_decode(str) fails with an error.
local function json_decode_fails(str)
  matches('Vim%(call%):E', pcall_err(command, ('call json_decode(%s)'):format(str)))
end

describe('json_decode() function', function()
  setup(function()
    clear()
    source([[
      language C
      function Eq(exp, act)
        let act = a:act
        let exp = a:exp
        if type(exp) != type(act)
          return 0
        endif
        if type(exp) == type({})
          if sort(keys(exp)) !=# sort(keys(act))
            return 0
          endif
          if sort(keys(exp)) ==# ['_TYPE', '_VAL']
            let exp_typ = v:msgpack_types[exp._TYPE]
            let act_typ = act._TYPE
            if exp_typ isnot act_typ
              return 0
            endif
            return Eq(exp._VAL, act._VAL)
          else
            return empty(filter(copy(exp), '!Eq(v:val, act[v:key])'))
          endif
        else
          if type(exp) == type([])
            if len(exp) != len(act)
              return 0
            endif
            return empty(filter(copy(exp), '!Eq(v:val, act[v:key])'))
          endif
          return exp ==# act
        endif
        return 1
      endfunction
      function EvalEq(exp, act_expr)
        let act = eval(a:act_expr)
        if Eq(a:exp, act)
          return 1
        else
          return string(act)
        endif
      endfunction
    ]])
  end)

  local speq = function(expected, actual_expr)
    eq(1, fn.EvalEq(expected, actual_expr))
  end

  it('accepts readfile()-style list', function()
    eq(
      { Test = 1 },
      fn.json_decode({
        '{',
        '\t"Test": 1',
        '}',
      })
    )
  end)

  it('accepts strings with newlines', function()
    eq(
      { Test = 1 },
      fn.json_decode([[
      {
        "Test": 1
      }
    ]])
    )
  end)

  it('parses null, true, false', function()
    eq(NIL, fn.json_decode('null'))
    eq(true, fn.json_decode('true'))
    eq(false, fn.json_decode('false'))
  end)

  it('fails to parse incomplete null, true, false', function()
    json_decode_fails('n')
    json_decode_fails('nu')
    json_decode_fails('nul')
    json_decode_fails('nul\\n\\t')

    json_decode_fails('t')
    json_decode_fails('tr')
    json_decode_fails('tru')
    json_decode_fails('tru\\t\\n')

    json_decode_fails('f')
    json_decode_fails('fa')
    json_decode_fails('fal')
    json_decode_fails('   fal   <')
    json_decode_fails('fals')
  end)

  it('parses integer numbers', function()
    eq(100000, fn.json_decode('100000'))
    eq(-100000, fn.json_decode('-100000'))
    eq(100000, fn.json_decode('  100000  '))
    eq(-100000, fn.json_decode('  -100000  '))
    eq(0, fn.json_decode('0'))
    eq(0, fn.json_decode('-0'))
  end)

  pending('fails to parse +numbers and .number', function()
    json_decode_fails('+1000')
    json_decode_fails('.1000')
  end)

  pending('fails to parse numbers with leading zeroes', function()
    json_decode_fails('00.1')
    json_decode_fails('01')
    json_decode_fails('-01')
    json_decode_fails('-001.0')
  end)

  it('fails to parse incomplete numbers', function()
    json_decode_fails('-.1')
    json_decode_fails('-')
    json_decode_fails('-1.')
    json_decode_fails('0.')
    json_decode_fails('0.0e')
    json_decode_fails('0.0e+')
    json_decode_fails('0.0e-')
    json_decode_fails('0.0e-')
    json_decode_fails('1.e5')
    json_decode_fails('1.e+5')
    json_decode_fails('1.e+')
  end)

  pending('parses floating-point numbers', function()
    -- Also test method call (->) syntax
    eq('100000.0', eval('"100000.0"->json_decode()->string()'))
    eq(100000.5, fn.json_decode('100000.5'))
    eq(-100000.5, fn.json_decode('-100000.5'))
    eq(-100000.5e50, fn.json_decode('-100000.5e50'))
    eq(100000.5e50, fn.json_decode('100000.5e50'))
    eq(100000.5e50, fn.json_decode('100000.5e+50'))
    eq(-100000.5e-50, fn.json_decode('-100000.5e-50'))
    eq(100000.5e-50, fn.json_decode('100000.5e-50'))
    eq(100000e-50, fn.json_decode('100000e-50'))
    eq(0.5, fn.json_decode('0.5'))
    eq(0.005, fn.json_decode('0.005'))
    eq(0.005, fn.json_decode('0.00500'))
    eq(0.5, fn.json_decode('0.00500e+002'))
    eq(0.00005, fn.json_decode('0.00500e-002'))

    eq(-0.0, fn.json_decode('-0.0'))
    eq(-0.0, fn.json_decode('-0.0e0'))
    eq(-0.0, fn.json_decode('-0.0e+0'))
    eq(-0.0, fn.json_decode('-0.0e-0'))
    eq(-0.0, fn.json_decode('-0e-0'))
    eq(-0.0, fn.json_decode('-0e-2'))
    eq(-0.0, fn.json_decode('-0e+2'))

    eq(0.0, fn.json_decode('0.0'))
    eq(0.0, fn.json_decode('0.0e0'))
    eq(0.0, fn.json_decode('0.0e+0'))
    eq(0.0, fn.json_decode('0.0e-0'))
    eq(0.0, fn.json_decode('0e-0'))
    eq(0.0, fn.json_decode('0e-2'))
    eq(0.0, fn.json_decode('0e+2'))
  end)

  pending('fails to parse numbers with spaces inside', function()
    json_decode_fails('- 1000')
    json_decode_fails('0. ')
    json_decode_fails('0. 0')
    json_decode_fails('0.0e 1')
    json_decode_fails('0.0e+ 1')
    json_decode_fails('0.0e- 1')
  end)

  it('fails to parse "," and ":"', function()
    json_decode_fails('  ,  ')
    json_decode_fails('  :  ')
  end)

  it('parses empty containers', function()
    eq({}, fn.json_decode('[]'))
    eq('[]', eval('string(json_decode("[]"))'))
  end)

  it('fails to parse "[" and "{"', function()
    json_decode_fails('{')
    json_decode_fails('[')
  end)

  it('fails to parse "}" and "]"', function()
    json_decode_fails(']')
    json_decode_fails('}')
  end)

  it('fails to parse containers which are closed by different brackets', function()
    json_decode_fails('{]')
    json_decode_fails('[}')
  end)

  it('fails to parse concat inside container', function()
    json_decode_fails('[[][]]')
    json_decode_fails('[{}{}]')
    json_decode_fails('[1 2]')
    json_decode_fails('{\\"1\\": 2 \\"3\\": 4}')
    json_decode_fails('{\\"1\\" 2, \\"3\\" 4}')
  end)

  it('fails to parse containers with leading comma or colon', function()
    json_decode_fails('{,}')
    json_decode_fails('[,]')
    json_decode_fails('[:]')
    json_decode_fails('{:}')
  end)

  pending('fails to parse containers with trailing comma', function()
    json_decode_fails('[1,]')
    json_decode_fails('{\\"1\\": 2,}')
  end)

  it('fails to parse dictionaries with missing value', function()
    json_decode_fails('{\\"1\\":}')
    json_decode_fails('{\\"1\\"}')
  end)

  it('fails to parse containers with two commas or colons', function()
    json_decode_fails('{\\"1\\": 1,, \\"2\\": 2}')
    json_decode_fails('[\\"1\\", 1,, \\"2\\", 2]')
    json_decode_fails('{\\"1\\": 1, \\"2\\":: 2}')
    json_decode_fails('{\\"1\\": 1, \\"2\\":, 2}')
    json_decode_fails('{\\"1\\": 1,: \\"2\\": 2}')
    json_decode_fails('{\\"1\\": 1:, \\"2\\": 2}')
  end)

  it('fails to parse concat of two values', function()
    json_decode_fails('{}[]')
  end)

  it('parses containers', function()
    eq({ 1 }, fn.json_decode('[1]'))
    eq({ NIL, 1 }, fn.json_decode('[null, 1]'))
    eq({ ['1'] = 2 }, fn.json_decode('{"1": 2}'))
    eq(
      { ['1'] = 2, ['3'] = { { ['4'] = { ['5'] = { {}, 1 } } } } },
      fn.json_decode('{"1": 2, "3": [{"4": {"5": [[], 1]}}]}')
    )
  end)

  it('fails to parse incomplete strings', function()
    json_decode_fails('\\t\\"')
    json_decode_fails('\\t\\"abc')
    json_decode_fails('\\t\\"abc\\\\')
    json_decode_fails('\\t\\"abc\\\\u')
    json_decode_fails('\\t\\"abc\\\\u0')
    json_decode_fails('\\t\\"abc\\\\u00')
    json_decode_fails('\\t\\"abc\\\\u000')
    json_decode_fails('\\t\\"abc\\\\u\\"    ')
    json_decode_fails('\\t\\"abc\\\\u0\\"    ')
    json_decode_fails('\\t\\"abc\\\\u00\\"    ')
    json_decode_fails('\\t\\"abc\\\\u000\\"    ')
    json_decode_fails('\\t\\"abc\\\\u0000')
  end)

  it('fails to parse unknown escape sequences', function()
    json_decode_fails('\\t\\"\\\\a\\"')
  end)

  it('parses strings properly', function()
    eq('\n', fn.json_decode('"\\n"'))
    eq('', fn.json_decode('""'))
    eq('\\/"\t\b\n\r\f', fn.json_decode([["\\\/\"\t\b\n\r\f"]]))
    eq('/a', fn.json_decode([["\/a"]]))
    -- Unicode characters: 2-byte, 3-byte, 4-byte
    eq(
      {
        '«',
        'ફ',
        '\240\144\128\128',
      },
      fn.json_decode({
        '[',
        '"«",',
        '"ફ",',
        '"\240\144\128\128"',
        ']',
      })
    )
  end)

  it('fails on strings with invalid bytes', function()
    json_decode_fails('\\t\\"\\xFF\\"')
    json_decode_fails('\\"\\n\\"')
    -- 0xC2 starts 2-byte unicode character
    json_decode_fails('\\t\\"\\xC2\\"')
    -- 0xE0 0xAA starts 3-byte unicode character
    json_decode_fails('\\t\\"\\xE0\\"')
    json_decode_fails('\\t\\"\\xE0\\xAA\\"')
    -- 0xF0 0x90 0x80 starts 4-byte unicode character
    json_decode_fails('\\t\\"\\xF0\\"')
    json_decode_fails('\\t\\"\\xF0\\x90\\"')
    json_decode_fails('\\t\\"\\xF0\\x90\\x80\\"')
    -- 0xF9 0x80 0x80 0x80 starts 5-byte unicode character
    json_decode_fails('\\t\\"\\xF9\\"')
    json_decode_fails('\\t\\"\\xF9\\x80\\"')
    json_decode_fails('\\t\\"\\xF9\\x80\\x80\\"')
    json_decode_fails('\\t\\"\\xF9\\x80\\x80\\x80\\"')
    -- 0xFC 0x90 0x80 0x80 0x80 starts 6-byte unicode character
    json_decode_fails('\\t\\"\\xFC\\"')
    json_decode_fails('\\t\\"\\xFC\\x90\\"')
    json_decode_fails('\\t\\"\\xFC\\x90\\x80\\"')
    json_decode_fails('\\t\\"\\xFC\\x90\\x80\\x80\\"')
    json_decode_fails('\\t\\"\\xFC\\x90\\x80\\x80\\x80\\"')
    -- Specification does not allow unquoted characters above 0x10FFFF
    json_decode_fails('\\t\\"\\xF9\\x80\\x80\\x80\\x80\\"')
    json_decode_fails('\\t\\"\\xFC\\x90\\x80\\x80\\x80\\x80\\"')
    -- '"\249\128\128\128\128"',
    -- '"\252\144\128\128\128\128"',
  end)

  pending('parses surrogate pairs properly', function()
    eq('\240\144\128\128', fn.json_decode('"\\uD800\\uDC00"'))
    eq('\237\160\128a\237\176\128', fn.json_decode('"\\uD800a\\uDC00"'))
    eq('\237\160\128\t\237\176\128', fn.json_decode('"\\uD800\\t\\uDC00"'))

    eq('\237\160\128', fn.json_decode('"\\uD800"'))
    eq('\237\160\128a', fn.json_decode('"\\uD800a"'))
    eq('\237\160\128\t', fn.json_decode('"\\uD800\\t"'))

    eq('\237\176\128', fn.json_decode('"\\uDC00"'))
    eq('\237\176\128a', fn.json_decode('"\\uDC00a"'))
    eq('\237\176\128\t', fn.json_decode('"\\uDC00\\t"'))

    eq('\237\176\128', fn.json_decode('"\\uDC00"'))
    eq('a\237\176\128', fn.json_decode('"a\\uDC00"'))
    eq('\t\237\176\128', fn.json_decode('"\\t\\uDC00"'))

    eq('\237\160\128¬', fn.json_decode('"\\uD800\\u00AC"'))

    eq('\237\160\128\237\160\128', fn.json_decode('"\\uD800\\uD800"'))
  end)

  local sp_decode_eq = function(expected, json)
    api.nvim_set_var('__json', json)
    speq(expected, 'json_decode(g:__json)')
    command('unlet! g:__json')
  end

  it('parses strings with NUL properly', function()
    sp_decode_eq('\000', '"\\u0000"')
    sp_decode_eq('\000\n\000', '"\\u0000\\n\\u0000"')
    sp_decode_eq('\000«\000', '"\\u0000\\u00AB\\u0000"')
  end)

  pending('parses dictionaries with duplicate keys to special maps', function()
    sp_decode_eq({ _TYPE = 'map', _VAL = { { 'a', 1 }, { 'a', 2 } } }, '{"a": 1, "a": 2}')
    sp_decode_eq(
      { _TYPE = 'map', _VAL = { { 'b', 3 }, { 'a', 1 }, { 'a', 2 } } },
      '{"b": 3, "a": 1, "a": 2}'
    )
    sp_decode_eq(
      { _TYPE = 'map', _VAL = { { 'b', 3 }, { 'a', 1 }, { 'c', 4 }, { 'a', 2 } } },
      '{"b": 3, "a": 1, "c": 4, "a": 2}'
    )
    sp_decode_eq(
      { _TYPE = 'map', _VAL = { { 'b', 3 }, { 'a', 1 }, { 'c', 4 }, { 'a', 2 }, { 'c', 4 } } },
      '{"b": 3, "a": 1, "c": 4, "a": 2, "c": 4}'
    )
    sp_decode_eq(
      { { _TYPE = 'map', _VAL = { { 'b', 3 }, { 'a', 1 }, { 'c', 4 }, { 'a', 2 }, { 'c', 4 } } } },
      '[{"b": 3, "a": 1, "c": 4, "a": 2, "c": 4}]'
    )
    sp_decode_eq({
      {
        d = {
          _TYPE = 'map',
          _VAL = { { 'b', 3 }, { 'a', 1 }, { 'c', 4 }, { 'a', 2 }, { 'c', 4 } },
        },
      },
    }, '[{"d": {"b": 3, "a": 1, "c": 4, "a": 2, "c": 4}}]')
    sp_decode_eq({
      1,
      {
        d = {
          _TYPE = 'map',
          _VAL = { { 'b', 3 }, { 'a', 1 }, { 'c', 4 }, { 'a', 2 }, { 'c', 4 } },
        },
      },
    }, '[1, {"d": {"b": 3, "a": 1, "c": 4, "a": 2, "c": 4}}]')
    sp_decode_eq({
      1,
      {
        a = {},
        d = {
          _TYPE = 'map',
          _VAL = {
            { 'b', 3 },
            { 'a', 1 },
            { 'c', 4 },
            { 'a', 2 },
            {
              'c',
              4,
            },
          },
        },
      },
    }, '[1, {"a": [], "d": {"b": 3, "a": 1, "c": 4, "a": 2, "c": 4}}]')
    sp_decode_eq(
      { _TYPE = 'map', _VAL = { { '', 3 }, { 'a', 1 }, { 'c', 4 }, { 'd', 2 }, { '', 4 } } },
      '{"": 3, "a": 1, "c": 4, "d": 2, "": 4}'
    )
    sp_decode_eq(
      { { _TYPE = 'map', _VAL = { { '', 3 }, { 'a', 1 }, { 'c', 4 }, { 'd', 2 }, { '', 4 } } } },
      '[{"": 3, "a": 1, "c": 4, "d": 2, "": 4}]'
    )
  end)

  it('parses dictionaries with empty keys', function()
    eq({ [''] = 4 }, fn.json_decode('{"": 4}'))
    eq(
      { b = 3, a = 1, c = 4, d = 2, [''] = 4 },
      fn.json_decode('{"b": 3, "a": 1, "c": 4, "d": 2, "": 4}')
    )
  end)

  pending('parses dictionaries with keys with NUL bytes to special maps', function()
    sp_decode_eq({ _TYPE = 'map', _VAL = { { 'a\000\nb', 4 } } }, '{"a\\u0000\\nb": 4}')
    sp_decode_eq({ _TYPE = 'map', _VAL = { { 'a\000\nb\n', 4 } } }, '{"a\\u0000\\nb\\n": 4}')
    sp_decode_eq({
      _TYPE = 'map',
      _VAL = {
        { 'b', 3 },
        { 'a', 1 },
        { 'c', 4 },
        { 'd', 2 },
        { '\000', 4 },
      },
    }, '{"b": 3, "a": 1, "c": 4, "d": 2, "\\u0000": 4}')
  end)

  it('parses U+00C3 correctly', function()
    eq('\195\131', fn.json_decode('"\195\131"'))
  end)

  it('fails to parse empty string', function()
    json_decode_fails('""')
    json_decode_fails('[]')
    json_decode_fails('[""]')
    json_decode_fails('" "')
    json_decode_fails('\\t')
    json_decode_fails('\\n')
    json_decode_fails(' \\t\\n \\n\\t\\t \\n\\t\\n \\n \\t\\n\\t ')
  end)

  it('accepts all spaces in every position where space may be put', function()
    local s =
      ' \t\n\r \t\r\n \n\t\r \n\r\t \r\t\n \r\n\t\t \n\r\t \r\n\t\n \r\t\n\r \t\r \n\t\r\n \n \t\r\n \r\t\n\t \r\n\t\r \n\r \t\n\r\t \r \t\n\r \n\t\r\t \n\r\t\n \r\n \t\r\n\t'
    local str = ('%s{%s"key"%s:%s[%s"val"%s,%s"val2"%s]%s,%s"key2"%s:%s1%s}%s'):gsub('%%s', s)
    eq({ key = { 'val', 'val2' }, key2 = 1 }, fn.json_decode(str))
  end)

  it('does not overflow when writing error message about decoding ["", ""]', function()
    matches('Vim%(call%):E', pcall_err(command, 'call json_decode(["", ""])'))
  end)
end)

describe('json_encode() function', function()
  setup(function()
    clear()
    command('language C')
  end)

  it('dumps strings', function()
    eq('"Test"', fn.json_encode('Test'))
    eq('""', fn.json_encode(''))
    eq('"\\t"', fn.json_encode('\t'))
    eq('"\\n"', fn.json_encode('\n'))
    eq('"\\u001b"', fn.json_encode('\27'))
    eq('"þÿþ"', fn.json_encode('þÿþ'))
  end)

  -- the C encoder converts blobs to arrays like [222,173,190,239]) because Vimscript strings can't
  -- hold NUL bytes, so couldn't round-trip arbitrary blob data.
  pending('dumps blobs', function()
    eq('[]', eval('json_encode(0z)'))
    eq('[222, 173, 190, 239]', eval('json_encode(0zDEADBEEF)'))
  end)

  it('dumps numbers', function()
    eq('0', fn.json_encode(0))
    eq('10', fn.json_encode(10))
    eq('-10', fn.json_encode(-10))
  end)

  it('dumps floats', function()
    -- Also test method call (->) syntax
    eq('0', eval('0.0->json_encode()'))
    eq('10.5', fn.json_encode(10.5))
    eq('-10.5', fn.json_encode(-10.5))
    eq('-1e-05', fn.json_encode(-1e-5))
    eq('1e+50', eval('1.0e50->json_encode()'))
  end)

  it('fails to dump NaN and infinite values', function()
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(str2float("nan"))'))
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(str2float("inf"))'))
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(-str2float("inf"))'))
  end)

  it('dumps lists', function()
    eq('[]', fn.json_encode({}))
    eq('[[]]', fn.json_encode({ {} }))
    eq('[[],[]]', fn.json_encode({ {}, {} }))
  end)

  it('dumps dictionaries', function()
    eq('{}', eval('json_encode({})'))
    eq('{"d":[]}', fn.json_encode({ d = {} }))
    eq('{"d":[],"e":[]}', fn.json_encode({ d = {}, e = {} }))
    -- Empty keys are allowed per JSON spec (and Vim dicts, and msgpack).
    eq('{"":[]}', fn.json_encode({ [''] = {} }))
  end)

  pending('cannot dump generic mapping with generic mapping keys and values', function()
    command('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": []}')
    command('let todumpv1 = {"_TYPE": v:msgpack_types.map, "_VAL": []}')
    command('let todumpv2 = {"_TYPE": v:msgpack_types.map, "_VAL": []}')
    command('call add(todump._VAL, [todumpv1, todumpv2])')
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(todump)'))
  end)

  pending('cannot dump generic mapping with ext key', function()
    command('let todump = {"_TYPE": v:msgpack_types.ext, "_VAL": [5, ["",""]]}')
    command('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [[todump, 1]]}')
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(todump)'))
  end)

  pending('cannot dump generic mapping with array key', function()
    command('let todump = {"_TYPE": v:msgpack_types.array, "_VAL": [5, [""]]}')
    command('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [[todump, 1]]}')
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(todump)'))
  end)

  pending('cannot dump generic mapping with UINT64_MAX key', function()
    command('let todump = {"_TYPE": v:msgpack_types.integer}')
    command('let todump._VAL = [1, 3, 0x7FFFFFFF, 0x7FFFFFFF]')
    command('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [[todump, 1]]}')
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(todump)'))
  end)

  pending('cannot dump generic mapping with floating-point key', function()
    command('let todump = {"_TYPE": v:msgpack_types.float, "_VAL": 0.125}')
    command('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [[todump, 1]]}')
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(todump)'))
  end)

  pending('can dump generic mapping with STR special key and NUL', function()
    command('let todump = {"_TYPE": v:msgpack_types.string, "_VAL": ["\\n"]}')
    command('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [[todump, 1]]}')
    eq('{"\\u0000": 1}', eval('json_encode(todump)'))
  end)

  pending('can dump STR special mapping with NUL and NL', function()
    command('let todump = {"_TYPE": v:msgpack_types.string, "_VAL": ["\\n", ""]}')
    eq('"\\u0000\\n"', eval('json_encode(todump)'))
  end)

  pending('cannot dump special ext mapping', function()
    command('let todump = {"_TYPE": v:msgpack_types.ext, "_VAL": [5, ["",""]]}')
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(todump)'))
  end)

  pending('can dump special array mapping', function()
    command('let todump = {"_TYPE": v:msgpack_types.array, "_VAL": [5, [""]]}')
    eq('[5, [""]]', eval('json_encode(todump)'))
  end)

  pending('can dump special UINT64_MAX mapping', function()
    command('let todump = {"_TYPE": v:msgpack_types.integer}')
    command('let todump._VAL = [1, 3, 0x7FFFFFFF, 0x7FFFFFFF]')
    eq('18446744073709551615', eval('json_encode(todump)'))
  end)

  pending('can dump special INT64_MIN mapping', function()
    command('let todump = {"_TYPE": v:msgpack_types.integer}')
    command('let todump._VAL = [-1, 2, 0, 0]')
    eq('-9223372036854775808', eval('json_encode(todump)'))
  end)

  pending('can dump special BOOLEAN true mapping', function()
    command('let todump = {"_TYPE": v:msgpack_types.boolean, "_VAL": 1}')
    eq('true', eval('json_encode(todump)'))
  end)

  pending('can dump special BOOLEAN false mapping', function()
    command('let todump = {"_TYPE": v:msgpack_types.boolean, "_VAL": 0}')
    eq('false', eval('json_encode(todump)'))
  end)

  pending('can dump special NIL mapping', function()
    command('let todump = {"_TYPE": v:msgpack_types.nil, "_VAL": 0}')
    eq('null', eval('json_encode(todump)'))
  end)

  pending('fails to dump a function reference', function()
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(function("tr"))'))
  end)

  pending('fails to dump a partial', function()
    command('function T() dict\nendfunction')
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(function("T", [1, 2], {}))'))
  end)

  pending('fails to dump a function reference in a list', function()
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode([function("tr")])'))
  end)

  pending('fails to dump a recursive list', function()
    command('let todump = [[[]]]')
    command('call add(todump[0][0], todump)')
    eq(
      'Vim(call):E724: unable to correctly dump variable with self-referencing container',
      pcall_err(command, 'call json_encode(todump)')
    )
  end)

  pending('fails to dump a recursive dict', function()
    command('let todump = {"d": {"d": {}}}')
    command('call extend(todump.d.d, {"d": todump})')
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode([todump])'))
  end)

  it('can dump dict with two same dicts inside', function()
    command('let inter = {}')
    command('let todump = {"a": inter, "b": inter}')
    eq('{"a":{},"b":{}}', eval('json_encode(todump)'))
  end)

  it('can dump list with two same lists inside', function()
    command('let inter = []')
    command('let todump = [inter, inter]')
    eq('[[],[]]', eval('json_encode(todump)'))
  end)

  pending('fails to dump a recursive list in a special dict', function()
    command('let todump = {"_TYPE": v:msgpack_types.array, "_VAL": []}')
    command('call add(todump._VAL, todump)')
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(todump)'))
  end)

  pending('fails to dump a recursive (val) map in a special dict', function()
    command('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": []}')
    command('call add(todump._VAL, ["", todump])')
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode([todump])'))
  end)

  pending('fails to dump a recursive (val) map in a special dict, _VAL reference', function()
    command('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [["", []]]}')
    command('call add(todump._VAL[0][1], todump._VAL)')
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(todump)'))
  end)

  pending('fails to dump a recursive (val) special list in a special dict', function()
    command('let todump = {"_TYPE": v:msgpack_types.array, "_VAL": []}')
    command('call add(todump._VAL, ["", todump._VAL])')
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode(todump)'))
  end)

  it('fails when called with no arguments', function()
    eq(
      'Vim(call):E119: Not enough arguments for function: json_encode',
      pcall_err(command, 'call json_encode()')
    )
  end)

  it('fails when called with two arguments', function()
    eq(
      'Vim(call):E118: Too many arguments for function: json_encode',
      pcall_err(command, 'call json_encode(["", ""], 1)')
    )
  end)

  it('ignores improper values in &isprint', function()
    api.nvim_set_option_value('isprint', '1', {})
    eq(1, eval('"\1" =~# "\\\\p"'))
    eq('"\\u0001"', fn.json_encode('\1'))
  end)

  pending('fails when using surrogate character in a UTF-8 string', function()
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode("\237\160\128")'))
    matches('Vim%(call%):E', pcall_err(command, 'call json_encode("\237\175\191")'))
  end)

  pending('dumps control characters as expected (msgpack-special-dict)', function()
    eq(
      [["\u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\b\t\n\u000B\f\r\u000E\u000F\u0010\u0011\u0012\u0013"]],
      eval(
        'json_encode({"_TYPE": v:msgpack_types.string, "_VAL": ["\n\1\2\3\4\5\6\7\8\9", "\11\12\13\14\15\16\17\18\19"]})'
      )
    )
  end)

  it('can dump NULL string', function()
    eq('""', eval('json_encode($XXX_UNEXISTENT_VAR_XXX)'))
  end)

  it('can dump NULL blob', function()
    eq('""', eval('json_encode(v:_null_blob)'))
  end)

  it('can dump NULL list', function()
    eq('[]', eval('json_encode(v:_null_list)'))
  end)

  it('can dump NULL dict', function()
    eq('{}', eval('json_encode(v:_null_dict)'))
  end)

  it('fails to parse NULL strings and lists', function()
    matches('Vim%(call%):E', pcall_err(command, 'call json_decode($XXX_UNEXISTENT_VAR_XXX)'))
    matches('Vim%(call%):E', pcall_err(command, 'call json_decode(v:_null_list)'))
  end)
end)
