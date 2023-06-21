local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local pcall_err = helpers.pcall_err

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
    eq('Expected object key string but found invalid token at character 2',
      pcall_err(exec_lua, [[return vim.json.decode('{a:"b"}')]]))
  end)

  it('options', function()
    local jsonstr = '{"arr":[1,2,null],"bar":[3,7],"foo":{"a":"b"},"baz":null}'
    eq({
        arr = { 1, 2, vim.NIL },
        bar = { 3, 7 },
        baz = vim.NIL,
        foo = { a = 'b' },
      },
      exec_lua([[return vim.json.decode(..., {})]], jsonstr))
    eq({
        arr = { 1, 2, vim.NIL },
        bar = { 3, 7 },
        -- baz = nil,
        foo = { a = 'b' },
      },
      exec_lua([[return vim.json.decode(..., { luanil = { object = true } })]], jsonstr))
    eq({
        arr = { 1, 2 },
        bar = { 3, 7 },
        baz = vim.NIL,
        foo = { a = 'b' },
      },
      exec_lua([[return vim.json.decode(..., { luanil = { array = true } })]], jsonstr))
    eq({
        arr = { 1, 2 },
        bar = { 3, 7 },
        -- baz = nil,
        foo = { a = 'b' },
      },
      exec_lua([[return vim.json.decode(..., { luanil = { array = true, object = true } })]], jsonstr))
  end)

  it('parses integer numbers', function()
    eq(100000, exec_lua([[return vim.json.decode('100000')]]))
    eq(-100000, exec_lua([[return vim.json.decode('-100000')]]))
    eq(100000, exec_lua([[return vim.json.decode('  100000  ')]]))
    eq(-100000, exec_lua([[return vim.json.decode('  -100000  ')]]))
    eq(0, exec_lua([[return vim.json.decode('0')]]))
    eq(0, exec_lua([[return vim.json.decode('-0')]]))
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
    eq({1}, exec_lua([[return vim.json.decode('[1]')]]))
    eq({vim.NIL, 1}, exec_lua([[return vim.json.decode('[null, 1]')]]))
    eq({['1']=2}, exec_lua([[return vim.json.decode('{"1": 2}')]]))
    eq({['1']=2, ['3']={{['4']={['5']={{}, 1}}}}},
       exec_lua([[return vim.json.decode('{"1": 2, "3": [{"4": {"5": [ [], 1]}}]}')]]))
  end)

  it('parses strings properly', function()
    eq('\n', exec_lua([=[return vim.json.decode([["\n"]])]=]))
    eq('', exec_lua([=[return vim.json.decode([[""]])]=]))
    eq('\\/"\t\b\n\r\f', exec_lua([=[return vim.json.decode([["\\\/\"\t\b\n\r\f"]])]=]))
    eq('/a', exec_lua([=[return vim.json.decode([["\/a"]])]=]))
    -- Unicode characters: 2-byte, 3-byte
    eq('«',exec_lua([=[return vim.json.decode([["«"]])]=]))
    eq('ફ',exec_lua([=[return vim.json.decode([["ફ"]])]=]))
  end)

  it('parses surrogate pairs properly', function()
    eq('\240\144\128\128', exec_lua([[return vim.json.decode('"\\uD800\\uDC00"')]]))
  end)

  it('accepts all spaces in every position where space may be put', function()
    local s = ' \t\n\r \t\r\n \n\t\r \n\r\t \r\t\n \r\n\t\t \n\r\t \r\n\t\n \r\t\n\r \t\r \n\t\r\n \n \t\r\n \r\t\n\t \r\n\t\r \n\r \t\n\r\t \r \t\n\r \n\t\r\t \n\r\t\n \r\n \t\r\n\t'
    local str = ('%s{%s"key"%s:%s[%s"val"%s,%s"val2"%s]%s,%s"key2"%s:%s1%s}%s'):gsub('%%s', s)
    eq({key={'val', 'val2'}, key2=1}, exec_lua([[return vim.json.decode(...)]], str))
  end)

end)

describe('vim.json.encode()', function()
  before_each(function()
    clear()
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
  end)

  it('dumps vim.NIL', function()
    eq('null', exec_lua([[return vim.json.encode(vim.NIL)]]))
  end)

end)
