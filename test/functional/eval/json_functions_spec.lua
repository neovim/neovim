local helpers = require('test.functional.helpers')
local clear = helpers.clear
local funcs = helpers.funcs
local meths = helpers.meths
local eq = helpers.eq
local eval = helpers.eval
local execute = helpers.execute
local exc_exec = helpers.exc_exec

describe('jsondecode() function', function()
  local restart = function(cmd)
    clear(cmd)
    execute([[
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
    ]])
    execute([[
      function EvalEq(exp, act_expr)
        let act = eval(a:act_expr)
        if Eq(a:exp, act)
          return 1
        else
          return string(act)
        endif
      endfunction
    ]])
  end
  before_each(restart)

  local speq = function(expected, actual_expr)
    eq(1, funcs.EvalEq(expected, actual_expr))
  end

  it('accepts readfile()-style list', function()
    eq({Test=1}, funcs.jsondecode({
      '{',
      '\t"Test": 1',
      '}',
    }))
  end)

  it('accepts strings with newlines', function()
    eq({Test=1}, funcs.jsondecode([[
      {
        "Test": 1
      }
    ]]))
  end)

  it('parses null, true, false', function()
    eq(nil, funcs.jsondecode('null'))
    eq(true, funcs.jsondecode('true'))
    eq(false, funcs.jsondecode('false'))
  end)

  it('fails to parse incomplete null, true, false', function()
    eq('Vim(call):E474: Expected null: n',
       exc_exec('call jsondecode("n")'))
    eq('Vim(call):E474: Expected null: nu',
       exc_exec('call jsondecode("nu")'))
    eq('Vim(call):E474: Expected null: nul',
       exc_exec('call jsondecode("nul")'))
    eq('Vim(call):E474: Expected null: nul\n\t',
       exc_exec('call jsondecode("nul\\n\\t")'))

    eq('Vim(call):E474: Expected true: t',
       exc_exec('call jsondecode("t")'))
    eq('Vim(call):E474: Expected true: tr',
       exc_exec('call jsondecode("tr")'))
    eq('Vim(call):E474: Expected true: tru',
       exc_exec('call jsondecode("tru")'))
    eq('Vim(call):E474: Expected true: tru\t\n',
       exc_exec('call jsondecode("tru\\t\\n")'))

    eq('Vim(call):E474: Expected false: f',
       exc_exec('call jsondecode("f")'))
    eq('Vim(call):E474: Expected false: fa',
       exc_exec('call jsondecode("fa")'))
    eq('Vim(call):E474: Expected false: fal',
       exc_exec('call jsondecode("fal")'))
    eq('Vim(call):E474: Expected false: fal   <',
       exc_exec('call jsondecode("   fal   <")'))
    eq('Vim(call):E474: Expected false: fals',
       exc_exec('call jsondecode("fals")'))
  end)

  it('parses integer numbers', function()
    eq(100000, funcs.jsondecode('100000'))
    eq(-100000, funcs.jsondecode('-100000'))
    eq(100000, funcs.jsondecode('  100000  '))
    eq(-100000, funcs.jsondecode('  -100000  '))
  end)

  it('fails to parse +numbers', function()
    eq('Vim(call):E474: Unidentified byte: +1000',
       exc_exec('call jsondecode("+1000")'))
  end)

  it('fails to parse negative numbers with space after -', function()
    eq('Vim(call):E474: Missing number after minus sign: - 1000',
       exc_exec('call jsondecode("- 1000")'))
  end)

  it('fails to parse -', function()
    eq('Vim(call):E474: Missing number after minus sign: -',
       exc_exec('call jsondecode("-")'))
  end)

  it('parses floating-point numbers', function()
    eq('100000.0', eval('string(jsondecode("100000.0"))'))
    eq(100000.5, funcs.jsondecode('100000.5'))
    eq(-100000.5, funcs.jsondecode('-100000.5'))
    eq(-100000.5e50, funcs.jsondecode('-100000.5e50'))
    eq(100000.5e50, funcs.jsondecode('100000.5e50'))
    eq(100000.5e50, funcs.jsondecode('100000.5e+50'))
    eq(-100000.5e-50, funcs.jsondecode('-100000.5e-50'))
    eq(100000.5e-50, funcs.jsondecode('100000.5e-50'))
  end)

  it('fails to parse incomplete floating-point numbers', function()
    eq('Vim(call):E474: Missing number after decimal dot: 0.',
       exc_exec('call jsondecode("0.")'))
    eq('Vim(call):E474: Missing exponent: 0.0e',
       exc_exec('call jsondecode("0.0e")'))
    eq('Vim(call):E474: Missing exponent: 0.0e+',
       exc_exec('call jsondecode("0.0e+")'))
    eq('Vim(call):E474: Missing exponent: 0.0e-',
       exc_exec('call jsondecode("0.0e-")'))
  end)

  it('fails to parse floating-point numbers with spaces inside', function()
    eq('Vim(call):E474: Missing number after decimal dot: 0. ',
       exc_exec('call jsondecode("0. ")'))
    eq('Vim(call):E474: Missing number after decimal dot: 0. 0',
       exc_exec('call jsondecode("0. 0")'))
    eq('Vim(call):E474: Missing exponent: 0.0e 1',
       exc_exec('call jsondecode("0.0e 1")'))
    eq('Vim(call):E474: Missing exponent: 0.0e+ 1',
       exc_exec('call jsondecode("0.0e+ 1")'))
    eq('Vim(call):E474: Missing exponent: 0.0e- 1',
       exc_exec('call jsondecode("0.0e- 1")'))
  end)

  it('fails to parse "," and ":"', function()
    eq('Vim(call):E474: Comma not inside container: ,  ',
       exc_exec('call jsondecode("  ,  ")'))
    eq('Vim(call):E474: Colon not inside container: :  ',
       exc_exec('call jsondecode("  :  ")'))
  end)

  it('parses empty containers', function()
    eq({}, funcs.jsondecode('[]'))
    eq('[]', eval('string(jsondecode("[]"))'))
  end)

  it('fails to parse "[" and "{"', function()
    eq('Vim(call):E474: Unexpected end of input: {',
       exc_exec('call jsondecode("{")'))
    eq('Vim(call):E474: Unexpected end of input: [',
       exc_exec('call jsondecode("[")'))
  end)

  it('fails to parse "}" and "]"', function()
    eq('Vim(call):E474: No container to close: ]',
       exc_exec('call jsondecode("]")'))
    eq('Vim(call):E474: No container to close: }',
       exc_exec('call jsondecode("}")'))
  end)

  it('fails to parse containers which are closed by different brackets',
  function()
    eq('Vim(call):E474: Closing dictionary with bracket: ]',
       exc_exec('call jsondecode("{]")'))
    eq('Vim(call):E474: Closing list with figure brace: }',
       exc_exec('call jsondecode("[}")'))
  end)

  it('fails to parse concat inside container', function()
    eq('Vim(call):E474: Expected comma before list item: []]',
       exc_exec('call jsondecode("[[][]]")'))
    eq('Vim(call):E474: Expected comma before list item: {}]',
       exc_exec('call jsondecode("[{}{}]")'))
    eq('Vim(call):E474: Expected comma before list item: ]',
       exc_exec('call jsondecode("[1 2]")'))
    eq('Vim(call):E474: Expected comma before dictionary key: ": 4}',
       exc_exec('call jsondecode("{\\"1\\": 2 \\"3\\": 4}")'))
    eq('Vim(call):E474: Expected colon before dictionary value: , "3" 4}',
       exc_exec('call jsondecode("{\\"1\\" 2, \\"3\\" 4}")'))
  end)

  it('fails to parse containers with leading comma or colon', function()
    eq('Vim(call):E474: Leading comma: ,}',
       exc_exec('call jsondecode("{,}")'))
    eq('Vim(call):E474: Leading comma: ,]',
       exc_exec('call jsondecode("[,]")'))
    eq('Vim(call):E474: Using colon not in dictionary: :]',
       exc_exec('call jsondecode("[:]")'))
    eq('Vim(call):E474: Unexpected colon: :}',
       exc_exec('call jsondecode("{:}")'))
  end)

  it('fails to parse containers with trailing comma', function()
    eq('Vim(call):E474: Trailing comma: ]',
       exc_exec('call jsondecode("[1,]")'))
    eq('Vim(call):E474: Trailing comma: }',
       exc_exec('call jsondecode("{\\"1\\": 2,}")'))
  end)

  it('fails to parse dictionaries with missing value', function()
    eq('Vim(call):E474: Expected value after colon: }',
       exc_exec('call jsondecode("{\\"1\\":}")'))
    eq('Vim(call):E474: Expected value: }',
       exc_exec('call jsondecode("{\\"1\\"}")'))
  end)

  it('fails to parse containers with two commas or colons', function()
    eq('Vim(call):E474: Duplicate comma: , "2": 2}',
       exc_exec('call jsondecode("{\\"1\\": 1,, \\"2\\": 2}")'))
    eq('Vim(call):E474: Duplicate comma: , "2", 2]',
       exc_exec('call jsondecode("[\\"1\\", 1,, \\"2\\", 2]")'))
    eq('Vim(call):E474: Duplicate colon: : 2}',
       exc_exec('call jsondecode("{\\"1\\": 1, \\"2\\":: 2}")'))
    eq('Vim(call):E474: Comma after colon: , 2}',
       exc_exec('call jsondecode("{\\"1\\": 1, \\"2\\":, 2}")'))
    eq('Vim(call):E474: Unexpected colon: : "2": 2}',
       exc_exec('call jsondecode("{\\"1\\": 1,: \\"2\\": 2}")'))
    eq('Vim(call):E474: Unexpected colon: :, "2": 2}',
       exc_exec('call jsondecode("{\\"1\\": 1:, \\"2\\": 2}")'))
  end)

  it('fails to parse concat of two values', function()
    eq('Vim(call):E474: Trailing characters: []',
       exc_exec('call jsondecode("{}[]")'))
  end)

  it('parses containers', function()
    eq({1}, funcs.jsondecode('[1]'))
    eq({nil, 1}, funcs.jsondecode('[null, 1]'))
    eq({['1']=2}, funcs.jsondecode('{"1": 2}'))
    eq({['1']=2, ['3']={{['4']={['5']={{}, 1}}}}},
       funcs.jsondecode('{"1": 2, "3": [{"4": {"5": [[], 1]}}]}'))
  end)

  it('fails to parse incomplete strings', function()
    eq('Vim(call):E474: Expected string end: \t"',
       exc_exec('call jsondecode("\\t\\"")'))
    eq('Vim(call):E474: Expected string end: \t"abc',
       exc_exec('call jsondecode("\\t\\"abc")'))
    eq('Vim(call):E474: Unfinished escape sequence: \t"abc\\',
       exc_exec('call jsondecode("\\t\\"abc\\\\")'))
    eq('Vim(call):E474: Unfinished unicode escape sequence: \t"abc\\u',
       exc_exec('call jsondecode("\\t\\"abc\\\\u")'))
    eq('Vim(call):E474: Unfinished unicode escape sequence: \t"abc\\u0',
       exc_exec('call jsondecode("\\t\\"abc\\\\u0")'))
    eq('Vim(call):E474: Unfinished unicode escape sequence: \t"abc\\u00',
       exc_exec('call jsondecode("\\t\\"abc\\\\u00")'))
    eq('Vim(call):E474: Unfinished unicode escape sequence: \t"abc\\u000',
       exc_exec('call jsondecode("\\t\\"abc\\\\u000")'))
    eq('Vim(call):E474: Expected four hex digits after \\u: \\u"    ',
       exc_exec('call jsondecode("\\t\\"abc\\\\u\\"    ")'))
    eq('Vim(call):E474: Expected four hex digits after \\u: \\u0"    ',
       exc_exec('call jsondecode("\\t\\"abc\\\\u0\\"    ")'))
    eq('Vim(call):E474: Expected four hex digits after \\u: \\u00"    ',
       exc_exec('call jsondecode("\\t\\"abc\\\\u00\\"    ")'))
    eq('Vim(call):E474: Expected four hex digits after \\u: \\u000"    ',
       exc_exec('call jsondecode("\\t\\"abc\\\\u000\\"    ")'))
    eq('Vim(call):E474: Expected string end: \t"abc\\u0000',
       exc_exec('call jsondecode("\\t\\"abc\\\\u0000")'))
  end)

  it('fails to parse unknown escape sequnces', function()
    eq('Vim(call):E474: Unknown escape sequence: \\a"',
       exc_exec('call jsondecode("\\t\\"\\\\a\\"")'))
  end)

  it('parses strings properly', function()
    eq('\n', funcs.jsondecode('"\\n"'))
    eq('', funcs.jsondecode('""'))
    eq('\\/"\t\b\n\r\f', funcs.jsondecode([["\\\/\"\t\b\n\r\f"]]))
    eq('/a', funcs.jsondecode([["\/a"]]))
    -- Unicode characters: 2-byte, 3-byte, 4-byte
    eq({
      '«',
      'ફ',
      '\xF0\x90\x80\x80',
    }, funcs.jsondecode({
      '[',
      '"«",',
      '"ફ",',
      '"\xF0\x90\x80\x80"',
      ']',
    }))
  end)

  it('fails on strings with invalid bytes', function()
    eq('Vim(call):E474: Only UTF-8 strings allowed: \255"',
       exc_exec('call jsondecode("\\t\\"\\xFF\\"")'))
    eq('Vim(call):E474: ASCII control characters cannot be present inside string: ',
       exc_exec('call jsondecode(["\\"\\n\\""])'))
    -- 0xC2 starts 2-byte unicode character
    eq('Vim(call):E474: Only UTF-8 strings allowed: \194"',
       exc_exec('call jsondecode("\\t\\"\\xC2\\"")'))
    -- 0xE0 0xAA starts 3-byte unicode character
    eq('Vim(call):E474: Only UTF-8 strings allowed: \224"',
       exc_exec('call jsondecode("\\t\\"\\xE0\\"")'))
    eq('Vim(call):E474: Only UTF-8 strings allowed: \224\170"',
       exc_exec('call jsondecode("\\t\\"\\xE0\\xAA\\"")'))
    -- 0xF0 0x90 0x80 starts 4-byte unicode character
    eq('Vim(call):E474: Only UTF-8 strings allowed: \240"',
       exc_exec('call jsondecode("\\t\\"\\xF0\\"")'))
    eq('Vim(call):E474: Only UTF-8 strings allowed: \240\144"',
       exc_exec('call jsondecode("\\t\\"\\xF0\\x90\\"")'))
    eq('Vim(call):E474: Only UTF-8 strings allowed: \240\144\128"',
       exc_exec('call jsondecode("\\t\\"\\xF0\\x90\\x80\\"")'))
    -- 0xF9 0x80 0x80 0x80 starts 5-byte unicode character
    eq('Vim(call):E474: Only UTF-8 strings allowed: \xF9"',
       exc_exec('call jsondecode("\\t\\"\\xF9\\"")'))
    eq('Vim(call):E474: Only UTF-8 strings allowed: \xF9\x80"',
       exc_exec('call jsondecode("\\t\\"\\xF9\\x80\\"")'))
    eq('Vim(call):E474: Only UTF-8 strings allowed: \xF9\x80\x80"',
       exc_exec('call jsondecode("\\t\\"\\xF9\\x80\\x80\\"")'))
    eq('Vim(call):E474: Only UTF-8 strings allowed: \xF9\x80\x80\x80"',
       exc_exec('call jsondecode("\\t\\"\\xF9\\x80\\x80\\x80\\"")'))
    -- 0xFC 0x90 0x80 0x80 0x80 starts 6-byte unicode character
    eq('Vim(call):E474: Only UTF-8 strings allowed: \xFC"',
       exc_exec('call jsondecode("\\t\\"\\xFC\\"")'))
    eq('Vim(call):E474: Only UTF-8 strings allowed: \xFC\x90"',
       exc_exec('call jsondecode("\\t\\"\\xFC\\x90\\"")'))
    eq('Vim(call):E474: Only UTF-8 strings allowed: \xFC\x90\x80"',
       exc_exec('call jsondecode("\\t\\"\\xFC\\x90\\x80\\"")'))
    eq('Vim(call):E474: Only UTF-8 strings allowed: \xFC\x90\x80\x80"',
       exc_exec('call jsondecode("\\t\\"\\xFC\\x90\\x80\\x80\\"")'))
    eq('Vim(call):E474: Only UTF-8 strings allowed: \xFC\x90\x80\x80\x80"',
       exc_exec('call jsondecode("\\t\\"\\xFC\\x90\\x80\\x80\\x80\\"")'))
    -- Specification does not allow unquoted characters above 0x10FFFF
    eq('Vim(call):E474: Only UTF-8 code points up to U+10FFFF are allowed to appear unescaped: \xF9\x80\x80\x80\x80"',
       exc_exec('call jsondecode("\\t\\"\\xF9\\x80\\x80\\x80\\x80\\"")'))
    eq('Vim(call):E474: Only UTF-8 code points up to U+10FFFF are allowed to appear unescaped: \xFC\x90\x80\x80\x80\x80"',
       exc_exec('call jsondecode("\\t\\"\\xFC\\x90\\x80\\x80\\x80\\x80\\"")'))
    -- '"\xF9\x80\x80\x80\x80"',
    -- '"\xFC\x90\x80\x80\x80\x80"',
  end)

  it('parses surrogate pairs properly', function()
    eq('\xF0\x90\x80\x80', funcs.jsondecode('"\\uD800\\uDC00"'))
    eq('\xED\xA0\x80a\xED\xB0\x80', funcs.jsondecode('"\\uD800a\\uDC00"'))
    eq('\xED\xA0\x80\t\xED\xB0\x80', funcs.jsondecode('"\\uD800\\t\\uDC00"'))

    eq('\xED\xA0\x80', funcs.jsondecode('"\\uD800"'))
    eq('\xED\xA0\x80a', funcs.jsondecode('"\\uD800a"'))
    eq('\xED\xA0\x80\t', funcs.jsondecode('"\\uD800\\t"'))

    eq('\xED\xB0\x80', funcs.jsondecode('"\\uDC00"'))
    eq('\xED\xB0\x80a', funcs.jsondecode('"\\uDC00a"'))
    eq('\xED\xB0\x80\t', funcs.jsondecode('"\\uDC00\\t"'))

    eq('\xED\xB0\x80', funcs.jsondecode('"\\uDC00"'))
    eq('a\xED\xB0\x80', funcs.jsondecode('"a\\uDC00"'))
    eq('\t\xED\xB0\x80', funcs.jsondecode('"\\t\\uDC00"'))
  end)

  local sp_decode_eq = function(expected, json)
    meths.set_var('__json', json)
    speq(expected, 'jsondecode(g:__json)')
    execute('unlet! g:__json')
  end

  it('parses strings with NUL properly', function()
    sp_decode_eq({_TYPE='string', _VAL={'\n'}}, '"\\u0000"')
    sp_decode_eq({_TYPE='string', _VAL={'\n', '\n'}}, '"\\u0000\\n\\u0000"')
    sp_decode_eq({_TYPE='string', _VAL={'\n«\n'}}, '"\\u0000\\u00AB\\u0000"')
  end)

  it('parses dictionaries with duplicate keys to special maps', function()
    sp_decode_eq({_TYPE='map', _VAL={{'a', 1}, {'a', 2}}},
                 '{"a": 1, "a": 2}')
    sp_decode_eq({_TYPE='map', _VAL={{'b', 3}, {'a', 1}, {'a', 2}}},
                 '{"b": 3, "a": 1, "a": 2}')
    sp_decode_eq({_TYPE='map', _VAL={{'b', 3}, {'a', 1}, {'c', 4}, {'a', 2}}},
                 '{"b": 3, "a": 1, "c": 4, "a": 2}')
    sp_decode_eq({_TYPE='map', _VAL={{'b', 3}, {'a', 1}, {'c', 4}, {'a', 2}, {'c', 4}}},
                 '{"b": 3, "a": 1, "c": 4, "a": 2, "c": 4}')
    sp_decode_eq({{_TYPE='map', _VAL={{'b', 3}, {'a', 1}, {'c', 4}, {'a', 2}, {'c', 4}}}},
                 '[{"b": 3, "a": 1, "c": 4, "a": 2, "c": 4}]')
    sp_decode_eq({{d={_TYPE='map', _VAL={{'b', 3}, {'a', 1}, {'c', 4}, {'a', 2}, {'c', 4}}}}},
                 '[{"d": {"b": 3, "a": 1, "c": 4, "a": 2, "c": 4}}]')
    sp_decode_eq({1, {d={_TYPE='map', _VAL={{'b', 3}, {'a', 1}, {'c', 4}, {'a', 2}, {'c', 4}}}}},
                 '[1, {"d": {"b": 3, "a": 1, "c": 4, "a": 2, "c": 4}}]')
    sp_decode_eq({1, {a={}, d={_TYPE='map', _VAL={{'b', 3}, {'a', 1}, {'c', 4}, {'a', 2}, {'c', 4}}}}},
                 '[1, {"a": [], "d": {"b": 3, "a": 1, "c": 4, "a": 2, "c": 4}}]')
  end)

  it('parses dictionaries with empty keys to special maps', function()
    sp_decode_eq({_TYPE='map', _VAL={{'', 4}}},
                 '{"": 4}')
    sp_decode_eq({_TYPE='map', _VAL={{'b', 3}, {'a', 1}, {'c', 4}, {'d', 2}, {'', 4}}},
                 '{"b": 3, "a": 1, "c": 4, "d": 2, "": 4}')
    sp_decode_eq({_TYPE='map', _VAL={{'', 3}, {'a', 1}, {'c', 4}, {'d', 2}, {'', 4}}},
                 '{"": 3, "a": 1, "c": 4, "d": 2, "": 4}')
    sp_decode_eq({{_TYPE='map', _VAL={{'', 3}, {'a', 1}, {'c', 4}, {'d', 2}, {'', 4}}}},
                 '[{"": 3, "a": 1, "c": 4, "d": 2, "": 4}]')
  end)

  it('parses dictionaries with keys with NUL bytes to special maps', function()
    sp_decode_eq({_TYPE='map', _VAL={{{_TYPE='string', _VAL={'a\n', 'b'}}, 4}}},
                 '{"a\\u0000\\nb": 4}')
    sp_decode_eq({_TYPE='map', _VAL={{{_TYPE='string', _VAL={'a\n', 'b', ''}}, 4}}},
                 '{"a\\u0000\\nb\\n": 4}')
    sp_decode_eq({_TYPE='map', _VAL={{'b', 3}, {'a', 1}, {'c', 4}, {'d', 2}, {{_TYPE='string', _VAL={'\n'}}, 4}}},
                 '{"b": 3, "a": 1, "c": 4, "d": 2, "\\u0000": 4}')
  end)

  it('converts strings to latin1 when &encoding is latin1', function()
    restart('set encoding=latin1')
    eq('\xAB', funcs.jsondecode('"\\u00AB"'))
    sp_decode_eq({_TYPE='string', _VAL={'\n\xAB\n'}}, '"\\u0000\\u00AB\\u0000"')
  end)
end)

describe('jsonencode() function', function()
  before_each(clear)

  it('dumps strings', function()
    eq('"Test"', funcs.jsonencode('Test'))
    eq('""', funcs.jsonencode(''))
    eq('"\\t"', funcs.jsonencode('\t'))
    eq('"\\n"', funcs.jsonencode('\n'))
    eq('"\\u001B"', funcs.jsonencode('\27'))
    eq('"þÿþ"', funcs.jsonencode('þÿþ'))
  end)

  it('dumps numbers', function()
    eq('0', funcs.jsonencode(0))
    eq('10', funcs.jsonencode(10))
    eq('-10', funcs.jsonencode(-10))
  end)

  it('dumps floats', function()
    eq('0.0', eval('jsonencode(0.0)'))
    eq('10.5', funcs.jsonencode(10.5))
    eq('-10.5', funcs.jsonencode(-10.5))
    eq('-1.0e-5', funcs.jsonencode(-1e-5))
    eq('1.0e50', eval('jsonencode(1.0e50)'))
  end)

  it('dumps lists', function()
    eq('[]', funcs.jsonencode({}))
    eq('[[]]', funcs.jsonencode({{}}))
    eq('[[], []]', funcs.jsonencode({{}, {}}))
  end)

  it('dumps dictionaries', function()
    eq('{}', eval('jsonencode({})'))
    eq('{"d": []}', funcs.jsonencode({d={}}))
    eq('{"d": [], "e": []}', funcs.jsonencode({d={}, e={}}))
  end)

  it('cannot dump generic mapping with generic mapping keys and values',
  function()
    execute('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": []}')
    execute('let todumpv1 = {"_TYPE": v:msgpack_types.map, "_VAL": []}')
    execute('let todumpv2 = {"_TYPE": v:msgpack_types.map, "_VAL": []}')
    execute('call add(todump._VAL, [todumpv1, todumpv2])')
    eq('Vim(call):E474: Invalid key in special dictionary', exc_exec('call jsonencode(todump)'))
  end)

  it('cannot dump generic mapping with ext key', function()
    execute('let todump = {"_TYPE": v:msgpack_types.ext, "_VAL": [5, ["",""]]}')
    execute('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [[todump, 1]]}')
    eq('Vim(call):E474: Invalid key in special dictionary', exc_exec('call jsonencode(todump)'))
  end)

  it('cannot dump generic mapping with array key', function()
    execute('let todump = {"_TYPE": v:msgpack_types.array, "_VAL": [5, [""]]}')
    execute('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [[todump, 1]]}')
    eq('Vim(call):E474: Invalid key in special dictionary', exc_exec('call jsonencode(todump)'))
  end)

  it('cannot dump generic mapping with UINT64_MAX key', function()
    execute('let todump = {"_TYPE": v:msgpack_types.integer}')
    execute('let todump._VAL = [1, 3, 0x7FFFFFFF, 0x7FFFFFFF]')
    execute('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [[todump, 1]]}')
    eq('Vim(call):E474: Invalid key in special dictionary', exc_exec('call jsonencode(todump)'))
  end)

  it('cannot dump generic mapping with floating-point key', function()
    execute('let todump = {"_TYPE": v:msgpack_types.float, "_VAL": 0.125}')
    execute('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [[todump, 1]]}')
    eq('Vim(call):E474: Invalid key in special dictionary', exc_exec('call jsonencode(todump)'))
  end)

  it('can dump generic mapping with STR special key and NUL', function()
    execute('let todump = {"_TYPE": v:msgpack_types.string, "_VAL": ["\\n"]}')
    execute('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [[todump, 1]]}')
    eq('{"\\u0000": 1}', eval('jsonencode(todump)'))
  end)

  it('can dump generic mapping with BIN special key and NUL', function()
    execute('let todump = {"_TYPE": v:msgpack_types.binary, "_VAL": ["\\n"]}')
    execute('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [[todump, 1]]}')
    eq('{"\\u0000": 1}', eval('jsonencode(todump)'))
  end)

  it('can dump STR special mapping with NUL and NL', function()
    execute('let todump = {"_TYPE": v:msgpack_types.string, "_VAL": ["\\n", ""]}')
    eq('"\\u0000\\n"', eval('jsonencode(todump)'))
  end)

  it('can dump BIN special mapping with NUL and NL', function()
    execute('let todump = {"_TYPE": v:msgpack_types.binary, "_VAL": ["\\n", ""]}')
    eq('"\\u0000\\n"', eval('jsonencode(todump)'))
  end)

  it('cannot dump special ext mapping', function()
    execute('let todump = {"_TYPE": v:msgpack_types.ext, "_VAL": [5, ["",""]]}')
    eq('Vim(call):E474: Unable to convert EXT string to JSON', exc_exec('call jsonencode(todump)'))
  end)

  it('can dump special array mapping', function()
    execute('let todump = {"_TYPE": v:msgpack_types.array, "_VAL": [5, [""]]}')
    eq('[5, [""]]', eval('jsonencode(todump)'))
  end)

  it('can dump special UINT64_MAX mapping', function()
    execute('let todump = {"_TYPE": v:msgpack_types.integer}')
    execute('let todump._VAL = [1, 3, 0x7FFFFFFF, 0x7FFFFFFF]')
    eq('18446744073709551615', eval('jsonencode(todump)'))
  end)

  it('can dump special INT64_MIN mapping', function()
    execute('let todump = {"_TYPE": v:msgpack_types.integer}')
    execute('let todump._VAL = [-1, 2, 0, 0]')
    eq('-9223372036854775808', eval('jsonencode(todump)'))
  end)

  it('can dump special BOOLEAN true mapping', function()
    execute('let todump = {"_TYPE": v:msgpack_types.boolean, "_VAL": 1}')
    eq('true', eval('jsonencode(todump)'))
  end)

  it('can dump special BOOLEAN false mapping', function()
    execute('let todump = {"_TYPE": v:msgpack_types.boolean, "_VAL": 0}')
    eq('false', eval('jsonencode(todump)'))
  end)

  it('can dump special NIL mapping', function()
    execute('let todump = {"_TYPE": v:msgpack_types.nil, "_VAL": 0}')
    eq('null', eval('jsonencode(todump)'))
  end)

  it('fails to dump a function reference', function()
    eq('Vim(call):E474: Error while dumping encode_tv2json() argument, itself: attempt to dump function reference',
       exc_exec('call jsonencode(function("tr"))'))
  end)

  it('fails to dump a function reference in a list', function()
    eq('Vim(call):E474: Error while dumping encode_tv2json() argument, index 0: attempt to dump function reference',
       exc_exec('call jsonencode([function("tr")])'))
  end)

  it('fails to dump a recursive list', function()
    execute('let todump = [[[]]]')
    execute('call add(todump[0][0], todump)')
    eq('Vim(call):E724: unable to correctly dump variable with self-referencing container',
       exc_exec('call jsonencode(todump)'))
  end)

  it('fails to dump a recursive dict', function()
    execute('let todump = {"d": {"d": {}}}')
    execute('call extend(todump.d.d, {"d": todump})')
    eq('Vim(call):E724: unable to correctly dump variable with self-referencing container',
       exc_exec('call jsonencode([todump])'))
  end)

  it('can dump dict with two same dicts inside', function()
    execute('let inter = {}')
    execute('let todump = {"a": inter, "b": inter}')
    eq('{"a": {}, "b": {}}', eval('jsonencode(todump)'))
  end)

  it('can dump list with two same lists inside', function()
    execute('let inter = []')
    execute('let todump = [inter, inter]')
    eq('[[], []]', eval('jsonencode(todump)'))
  end)

  it('fails to dump a recursive list in a special dict', function()
    execute('let todump = {"_TYPE": v:msgpack_types.array, "_VAL": []}')
    execute('call add(todump._VAL, todump)')
    eq('Vim(call):E724: unable to correctly dump variable with self-referencing container',
       exc_exec('call jsonencode(todump)'))
  end)

  it('fails to dump a recursive (val) map in a special dict', function()
    execute('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": []}')
    execute('call add(todump._VAL, ["", todump])')
    eq('Vim(call):E724: unable to correctly dump variable with self-referencing container',
       exc_exec('call jsonencode([todump])'))
  end)

  it('fails to dump a recursive (val) map in a special dict, _VAL reference', function()
    execute('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [["", []]]}')
    execute('call add(todump._VAL[0][1], todump._VAL)')
    eq('Vim(call):E724: unable to correctly dump variable with self-referencing container',
       exc_exec('call jsonencode(todump)'))
  end)

  it('fails to dump a recursive (val) special list in a special dict',
  function()
    execute('let todump = {"_TYPE": v:msgpack_types.array, "_VAL": []}')
    execute('call add(todump._VAL, ["", todump._VAL])')
    eq('Vim(call):E724: unable to correctly dump variable with self-referencing container',
       exc_exec('call jsonencode(todump)'))
  end)

  it('fails when called with no arguments', function()
    eq('Vim(call):E119: Not enough arguments for function: jsonencode',
       exc_exec('call jsonencode()'))
  end)

  it('fails when called with two arguments', function()
    eq('Vim(call):E118: Too many arguments for function: jsonencode',
       exc_exec('call jsonencode(["", ""], 1)'))
  end)

  it('converts strings from latin1 when &encoding is latin1', function()
    clear('set encoding=latin1')
    eq('"\\u00AB"', funcs.jsonencode('\xAB'))
    eq('"\\u0000\\u00AB\\u0000"', eval('jsonencode({"_TYPE": v:msgpack_types.string, "_VAL": ["\\n\xAB\\n"]})'))
  end)

  it('ignores improper values in &isprint', function()
    meths.set_option('isprint', '1')
    eq(1, eval('"\x01" =~# "\\\\p"'))
    eq('"\\u0001"', funcs.jsonencode('\x01'))
  end)
end)
