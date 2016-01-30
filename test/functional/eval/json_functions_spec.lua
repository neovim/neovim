local helpers = require('test.functional.helpers')
local clear = helpers.clear
local funcs = helpers.funcs
local eq = helpers.eq
local eval = helpers.eval
local execute = helpers.execute
local exc_exec = helpers.exc_exec

describe('jsonencode() function', function()
  before_each(clear)

  it('dumps strings', function()
    eq('"Test"', funcs.jsonencode('Test'))
    eq('""', funcs.jsonencode(''))
    eq('"\\t"', funcs.jsonencode('\t'))
    eq('"\\n"', funcs.jsonencode('\n'))
    eq('"\\u001B"', funcs.jsonencode('\27'))
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
end)
