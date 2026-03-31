local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_lua = n.exec_lua
local eq = t.eq
local pcall_err = t.pcall_err

describe('vim.json.decode()', function()
  before_each(function()
    clear()
  end)

  it('parses null, true, false', function()
    eq(vim.NIL, exec_lua([[return vim.json.decode('null')]]))
    eq(true, exec_lua([[return vim.json.decode('true')]]))
    eq(false, exec_lua([[return vim.json.decode('false')]]))
  end)

  it('validation', function()
    eq(
      'Expected object key string but found invalid token at character 2',
      pcall_err(exec_lua, [[return vim.json.decode('{a:"b"}')]])
    )
  end)

  it('options', function()
    local jsonstr = '{"arr":[1,2,null],"bar":[3,7],"foo":{"a":"b"},"baz":null}'
    eq({
      arr = { 1, 2, vim.NIL },
      bar = { 3, 7 },
      baz = vim.NIL,
      foo = { a = 'b' },
    }, exec_lua([[return vim.json.decode(..., {})]], jsonstr))
    eq(
      {
        arr = { 1, 2, vim.NIL },
        bar = { 3, 7 },
        baz = vim.NIL,
        foo = { a = 'b' },
      },
      exec_lua(
        [[return vim.json.decode(..., { luanil = { array = false, object = false } })]],
        jsonstr
      )
    )
    eq({
      arr = { 1, 2, vim.NIL },
      bar = { 3, 7 },
      -- baz = nil,
      foo = { a = 'b' },
    }, exec_lua([[return vim.json.decode(..., { luanil = { object = true } })]], jsonstr))
    eq({
      arr = { 1, 2 },
      bar = { 3, 7 },
      baz = vim.NIL,
      foo = { a = 'b' },
    }, exec_lua([[return vim.json.decode(..., { luanil = { array = true } })]], jsonstr))
    eq(
      {
        arr = { 1, 2 },
        bar = { 3, 7 },
        -- baz = nil,
        foo = { a = 'b' },
      },
      exec_lua(
        [[return vim.json.decode(..., { luanil = { array = true, object = true } })]],
        jsonstr
      )
    )
  end)

  it('parses integer numbers', function()
    eq(100000, exec_lua([[return vim.json.decode('100000')]]))
    eq(-100000, exec_lua([[return vim.json.decode('-100000')]]))
    eq(100000, exec_lua([[return vim.json.decode('  100000  ')]]))
    eq(-100000, exec_lua([[return vim.json.decode('  -100000  ')]]))
    eq(0, exec_lua([[return vim.json.decode('0')]]))
    eq(0, exec_lua([[return vim.json.decode('-0')]]))
    eq(3053700806959403, exec_lua([[return vim.json.decode('3053700806959403')]]))
  end)

  it('parses floating-point numbers', function()
    -- This behavior differs from vim.fn.json_decode, which return '100000.0'
    eq('100000', exec_lua([[return tostring(vim.json.decode('100000.0'))]]))
    eq(100000.5, exec_lua([[return vim.json.decode('100000.5')]]))
    eq(-100000.5, exec_lua([[return vim.json.decode('-100000.5')]]))
    eq(-100000.5e50, exec_lua([[return vim.json.decode('-100000.5e50')]]))
    eq(100000.5e50, exec_lua([[return vim.json.decode('100000.5e50')]]))
    eq(100000.5e50, exec_lua([[return vim.json.decode('100000.5e+50')]]))
    eq(-100000.5e-50, exec_lua([[return vim.json.decode('-100000.5e-50')]]))
    eq(100000.5e-50, exec_lua([[return vim.json.decode('100000.5e-50')]]))
    eq(100000e-50, exec_lua([[return vim.json.decode('100000e-50')]]))
    eq(0.5, exec_lua([[return vim.json.decode('0.5')]]))
    eq(0.005, exec_lua([[return vim.json.decode('0.005')]]))
    eq(0.005, exec_lua([[return vim.json.decode('0.00500')]]))
    eq(0.5, exec_lua([[return vim.json.decode('0.00500e+002')]]))
    eq(0.00005, exec_lua([[return vim.json.decode('0.00500e-002')]]))

    eq(-0.0, exec_lua([[return vim.json.decode('-0.0')]]))
    eq(-0.0, exec_lua([[return vim.json.decode('-0.0e0')]]))
    eq(-0.0, exec_lua([[return vim.json.decode('-0.0e+0')]]))
    eq(-0.0, exec_lua([[return vim.json.decode('-0.0e-0')]]))
    eq(-0.0, exec_lua([[return vim.json.decode('-0e-0')]]))
    eq(-0.0, exec_lua([[return vim.json.decode('-0e-2')]]))
    eq(-0.0, exec_lua([[return vim.json.decode('-0e+2')]]))

    eq(0.0, exec_lua([[return vim.json.decode('0.0')]]))
    eq(0.0, exec_lua([[return vim.json.decode('0.0e0')]]))
    eq(0.0, exec_lua([[return vim.json.decode('0.0e+0')]]))
    eq(0.0, exec_lua([[return vim.json.decode('0.0e-0')]]))
    eq(0.0, exec_lua([[return vim.json.decode('0e-0')]]))
    eq(0.0, exec_lua([[return vim.json.decode('0e-2')]]))
    eq(0.0, exec_lua([[return vim.json.decode('0e+2')]]))
  end)

  it('parses containers', function()
    eq({ 1 }, exec_lua([[return vim.json.decode('[1]')]]))
    eq({ vim.NIL, 1 }, exec_lua([[return vim.json.decode('[null, 1]')]]))
    eq({ ['1'] = 2 }, exec_lua([[return vim.json.decode('{"1": 2}')]]))
    eq(
      { ['1'] = 2, ['3'] = { { ['4'] = { ['5'] = { {}, 1 } } } } },
      exec_lua([[return vim.json.decode('{"1": 2, "3": [{"4": {"5": [ [], 1]}}]}')]])
    )
    -- Empty string is a valid key. #20757
    eq({ [''] = 42 }, exec_lua([[return vim.json.decode('{"": 42}')]]))
  end)

  it('parses strings properly', function()
    eq('\n', exec_lua([=[return vim.json.decode([["\n"]])]=]))
    eq('', exec_lua([=[return vim.json.decode([[""]])]=]))
    eq('\\/"\t\b\n\r\f', exec_lua([=[return vim.json.decode([["\\\/\"\t\b\n\r\f"]])]=]))
    eq('/a', exec_lua([=[return vim.json.decode([["\/a"]])]=]))
    -- Unicode characters: 2-byte, 3-byte
    eq('«', exec_lua([=[return vim.json.decode([["«"]])]=]))
    eq('ફ', exec_lua([=[return vim.json.decode([["ફ"]])]=]))
  end)

  it('parses surrogate pairs properly', function()
    eq('\240\144\128\128', exec_lua([[return vim.json.decode('"\\uD800\\uDC00"')]]))
  end)

  it('accepts all spaces in every position where space may be put', function()
    local s =
      ' \t\n\r \t\r\n \n\t\r \n\r\t \r\t\n \r\n\t\t \n\r\t \r\n\t\n \r\t\n\r \t\r \n\t\r\n \n \t\r\n \r\t\n\t \r\n\t\r \n\r \t\n\r\t \r \t\n\r \n\t\r\t \n\r\t\n \r\n \t\r\n\t'
    local str = ('%s{%s"key"%s:%s[%s"val"%s,%s"val2"%s]%s,%s"key2"%s:%s1%s}%s'):gsub('%%s', s)
    eq({ key = { 'val', 'val2' }, key2 = 1 }, exec_lua([[return vim.json.decode(...)]], str))
  end)

  it('skip_comments', function()
    eq({}, exec_lua([[return vim.json.decode('{//comment\n}', { skip_comments = true })]]))
    eq({}, exec_lua([[return vim.json.decode('{//comment\r\n}', { skip_comments = true })]]))
    eq(
      'test // /* */ string',
      exec_lua(
        [[return vim.json.decode('"test // /* */ string"//comment', { skip_comments = true })]]
      )
    )
    eq(
      {},
      exec_lua([[return vim.json.decode('{/* A multi-line\ncomment*/}', { skip_comments = true })]])
    )
    eq(
      { a = 1 },
      exec_lua([[return vim.json.decode('{"a" /* Comment */: 1}', { skip_comments = true })]])
    )
    eq(
      { a = 1 },
      exec_lua([[return vim.json.decode('{"a": /* Comment */ 1}', { skip_comments = true })]])
    )
    eq({}, exec_lua([[return vim.json.decode('/*first*//*second*/{}', { skip_comments = true })]]))
    eq(
      'Expected the end but found unclosed multi-line comment at character 13',
      pcall_err(exec_lua, [[return vim.json.decode('{}/*Unclosed', { skip_comments = true })]])
    )
    eq(
      'Expected comma or object end but found T_INTEGER at character 12',
      pcall_err(exec_lua, [[return vim.json.decode('{"a":1/*x*/0}', { skip_comments = true })]])
    )
  end)
end)

describe('vim.json.encode()', function()
  before_each(function()
    clear()
  end)

  it('escape_slash', function()
    -- With slash
    eq('"Test\\/"', exec_lua([[return vim.json.encode('Test/', { escape_slash = true })]]))
    eq(
      'Test/',
      exec_lua([[return vim.json.decode(vim.json.encode('Test/', { escape_slash = true }))]])
    )

    -- Without slash
    eq('"Test/"', exec_lua([[return vim.json.encode('Test/')]]))
    eq('"Test/"', exec_lua([[return vim.json.encode('Test/', {})]]))
    eq('"Test/"', exec_lua([[return vim.json.encode('Test/', { _invalid = true })]]))
    eq('"Test/"', exec_lua([[return vim.json.encode('Test/', { escape_slash = false })]]))
    eq(
      '"Test/"',
      exec_lua([[return vim.json.encode('Test/', { _invalid = true, escape_slash = false })]])
    )
    eq(
      'Test/',
      exec_lua([[return vim.json.decode(vim.json.encode('Test/', { escape_slash = false }))]])
    )

    -- Checks for for global side-effects
    eq(
      '"Test/"',
      exec_lua([[
        vim.json.encode('Test/', { escape_slash = true })
        return vim.json.encode('Test/')
      ]])
    )
    eq(
      '"Test\\/"',
      exec_lua([[
        vim.json.encode('Test/', { escape_slash = false })
        return vim.json.encode('Test/', { escape_slash = true })
      ]])
    )
  end)

  it('indent', function()
    eq('"Test"', exec_lua([[return vim.json.encode('Test', { indent = "  " })]]))
    eq('[]', exec_lua([[return vim.json.encode({}, { indent = "  " })]]))
    eq('{}', exec_lua([[return vim.json.encode(vim.empty_dict(), { indent = "  " })]]))
    eq(
      '[\n  {\n    "a": "a"\n  },\n  {\n    "b": "b"\n  }\n]',
      exec_lua([[return vim.json.encode({ { a = "a" }, { b = "b" } }, { indent = "  " })]])
    )
    eq(
      '{\n  "a": {\n    "b": 1\n  }\n}',
      exec_lua([[return vim.json.encode({ a = { b = 1 } }, { indent = "  " })]])
    )
    eq(
      '[{"a":"a"},{"b":"b"}]',
      exec_lua([[return vim.json.encode({ { a = "a" }, { b = "b" } }, { indent = "" })]])
    )
    eq(
      '[\n  [\n    1,\n    2\n  ],\n  [\n    3,\n    4\n  ]\n]',
      exec_lua([[return vim.json.encode({ { 1, 2 }, { 3, 4 } }, { indent = "  " })]])
    )
    eq(
      '{\nabc"a": {\nabcabc"b": 1\nabc}\n}',
      exec_lua([[return vim.json.encode({ a = { b = 1 } }, { indent = "abc" })]])
    )

    -- Checks for for global side-effects
    eq(
      '[{"a":"a"},{"b":"b"}]',
      exec_lua([[
        vim.json.encode('', { indent = "  " })
        return vim.json.encode({ { a = "a" }, { b = "b" } })
      ]])
    )
  end)

  it('sort_keys', function()
    eq('"string"', exec_lua([[return vim.json.encode('string', { sort_keys = true })]]))
    eq('[]', exec_lua([[return vim.json.encode({}, { sort_keys = true })]]))
    eq('{}', exec_lua([[return vim.json.encode(vim.empty_dict(), { sort_keys = true })]]))
    eq(
      '{"$":0,"%":0,"1":0,"4":0,"a":0,"ab":0,"b":0}',
      exec_lua(
        [[return vim.json.encode({ a = 0, b = 0, ab = 0, [1] = 0, ["$"] = 0, [4] = 0, ["%"] = 0 }, { sort_keys = true })]]
      )
    )
    eq(
      '{"aa":1,"ab":2,"ba":3,"bc":4,"cc":5}',
      exec_lua(
        [[return vim.json.encode({ aa = 1, ba = 3, ab = 2, bc = 4, cc = 5 }, { sort_keys = true })]]
      )
    )
    eq(
      '{"a":{"a":1,"b":2,"c":3},"b":{"a":{"a":0,"b":0},"b":{"a":0,"b":0}},"c":0}',
      exec_lua(
        [[return vim.json.encode({ a = { b = 2, a = 1, c = 3 }, c = 0, b = { b = { a = 0, b = 0 }, a = { a = 0, b = 0 } } }, { sort_keys = true })]]
      )
    )
    eq(
      '[{"1":0,"4":0,"a":0,"b":0},{"10":0,"5":0,"f":0,"x":0},{"-2":0,"2":0,"c":0,"d":0}]',
      exec_lua([[return vim.json.encode({
        { a = 0, [1] = 0, [4] = 0, b = 0 },
        { f = 0, [5] = 0, [10] = 0, x = 0 },
        { c = 0, [-2] = 0, [2] = 0, d = 0 },
      }, { sort_keys = true })]])
    )
    eq(
      '{"a":2,"ß":3,"é":1,"中":4}',
      exec_lua(
        [[return vim.json.encode({ ["é"] = 1, ["a"] = 2, ["ß"] = 3, ["中"] = 4 }, { sort_keys = true })]]
      )
    )
  end)

  it('dumps strings', function()
    eq('"Test"', exec_lua([[return vim.json.encode('Test')]]))
    eq('""', exec_lua([[return vim.json.encode('')]]))
    eq('"\\t"', exec_lua([[return vim.json.encode('\t')]]))
    eq('"\\n"', exec_lua([[return vim.json.encode('\n')]]))
    -- vim.fn.json_encode return \\u001B
    eq('"\\u001b"', exec_lua([[return vim.json.encode('\27')]]))
    eq('"þÿþ"', exec_lua([[return vim.json.encode('þÿþ')]]))
  end)

  it('dumps numbers', function()
    eq('0', exec_lua([[return vim.json.encode(0)]]))
    eq('10', exec_lua([[return vim.json.encode(10)]]))
    eq('-10', exec_lua([[return vim.json.encode(-10)]]))
  end)

  it('dumps floats', function()
    eq('3053700806959403', exec_lua([[return vim.json.encode(3053700806959403)]]))
    eq('10.5', exec_lua([[return vim.json.encode(10.5)]]))
    eq('-10.5', exec_lua([[return vim.json.encode(-10.5)]]))
    eq('-1e-05', exec_lua([[return vim.json.encode(-1e-5)]]))
  end)

  it('dumps lists', function()
    eq('[]', exec_lua([[return vim.json.encode({})]]))
    eq('[[]]', exec_lua([[return vim.json.encode({{}})]]))
    eq('[[],[]]', exec_lua([[return vim.json.encode({{}, {}})]]))
  end)

  it('dumps dictionaries', function()
    eq('{}', exec_lua([[return vim.json.encode(vim.empty_dict())]]))
    eq('{"d":[]}', exec_lua([[return vim.json.encode({d={}})]]))
    -- Empty string is a valid key. #20757
    eq('{"":42}', exec_lua([[return vim.json.encode({['']=42})]]))
  end)

  it('dumps vim.NIL', function()
    eq('null', exec_lua([[return vim.json.encode(vim.NIL)]]))
  end)
end)
