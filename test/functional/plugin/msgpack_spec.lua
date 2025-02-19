local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local api = n.api
local eq = t.eq
local nvim_eval = n.eval
local nvim_command = n.command
local exc_exec = n.exc_exec
local ok = t.ok
local NIL = vim.NIL

describe('autoload/msgpack.vim', function()
  before_each(function()
    clear { args = { '-u', 'NORC' } }
  end)

  local sp = function(typ, val)
    return ('{"_TYPE": v:msgpack_types.%s, "_VAL": %s}'):format(typ, val)
  end
  local mapsp = function(...)
    local val = ''
    for i = 1, (select('#', ...) / 2) do
      val = ('%s[%s,%s],'):format(val, select(i * 2 - 1, ...), select(i * 2, ...))
    end
    return sp('map', '[' .. val .. ']')
  end

  local nan = -(1.0 / 0.0 - 1.0 / 0.0)
  local inf = 1.0 / 0.0
  local minus_inf = -(1.0 / 0.0)

  describe('function msgpack#equal', function()
    local msgpack_eq = function(expected, a, b)
      eq(expected, nvim_eval(('msgpack#equal(%s, %s)'):format(a, b)))
      if a ~= b then
        eq(expected, nvim_eval(('msgpack#equal(%s, %s)'):format(b, a)))
      end
    end
    it('compares raw integers correctly', function()
      msgpack_eq(1, '1', '1')
      msgpack_eq(0, '1', '0')
    end)
    it('compares integer specials correctly', function()
      msgpack_eq(1, sp('integer', '[-1, 1, 0, 0]'), sp('integer', '[-1, 1, 0, 0]'))
      msgpack_eq(0, sp('integer', '[-1, 1, 0, 0]'), sp('integer', '[ 1, 1, 0, 0]'))
    end)
    it('compares integer specials with raw integer correctly', function()
      msgpack_eq(1, sp('integer', '[-1, 0, 0, 1]'), '-1')
      msgpack_eq(0, sp('integer', '[-1, 0, 0, 1]'), '1')
      msgpack_eq(0, sp('integer', '[ 1, 0, 0, 1]'), '-1')
      msgpack_eq(1, sp('integer', '[ 1, 0, 0, 1]'), '1')
    end)
    it('compares integer with float correctly', function()
      msgpack_eq(0, '0', '0.0')
    end)
    it('compares raw binaries correctly', function()
      msgpack_eq(1, '"abc\\ndef"', '"abc\\ndef"')
      msgpack_eq(0, '"abc\\ndef"', '"abc\\nghi"')
    end)
    it('compares string specials correctly', function()
      msgpack_eq(1, sp('string', '["abc\\n", "def"]'), sp('string', '["abc\\n", "def"]'))
      msgpack_eq(0, sp('string', '["abc", "def"]'), sp('string', '["abc\\n", "def"]'))
      msgpack_eq(1, sp('string', '["abc", "def"]'), '"abc\\ndef"')
      msgpack_eq(1, '"abc\\ndef"', sp('string', '["abc", "def"]'))
    end)
    it('compares ext specials correctly', function()
      msgpack_eq(1, sp('ext', '[1, ["", "ac"]]'), sp('ext', '[1, ["", "ac"]]'))
      msgpack_eq(0, sp('ext', '[2, ["", "ac"]]'), sp('ext', '[1, ["", "ac"]]'))
      msgpack_eq(0, sp('ext', '[1, ["", "ac"]]'), sp('ext', '[1, ["", "abc"]]'))
    end)
    it('compares raw maps correctly', function()
      msgpack_eq(1, '{"a": 1, "b": 2}', '{"b": 2, "a": 1}')
      msgpack_eq(1, '{}', '{}')
      msgpack_eq(0, '{}', '{"a": 1}')
      msgpack_eq(0, '{"a": 2}', '{"a": 1}')
      msgpack_eq(0, '{"a": 1}', '{"b": 1}')
      msgpack_eq(0, '{"a": 1}', '{"a": 1, "b": 1}')
      msgpack_eq(0, '{"a": 1, "b": 1}', '{"b": 1}')
    end)
    it('compares map specials correctly', function()
      msgpack_eq(1, mapsp(), mapsp())
      msgpack_eq(
        1,
        mapsp(mapsp('1', '1'), mapsp('1', '1')),
        mapsp(mapsp('1', '1'), mapsp('1', '1'))
      )
      msgpack_eq(0, mapsp(), mapsp('1', '1'))
      msgpack_eq(
        0,
        mapsp(mapsp('1', '1'), mapsp('1', '1')),
        mapsp(sp('string', '[""]'), mapsp('1', '1'))
      )
      msgpack_eq(
        0,
        mapsp(mapsp('1', '1'), mapsp('1', '1')),
        mapsp(mapsp('2', '1'), mapsp('1', '1'))
      )
      msgpack_eq(
        0,
        mapsp(mapsp('1', '1'), mapsp('1', '1')),
        mapsp(mapsp('1', '2'), mapsp('1', '1'))
      )
      msgpack_eq(
        0,
        mapsp(mapsp('1', '1'), mapsp('1', '1')),
        mapsp(mapsp('1', '1'), mapsp('2', '1'))
      )
      msgpack_eq(
        0,
        mapsp(mapsp('1', '1'), mapsp('1', '1')),
        mapsp(mapsp('1', '1'), mapsp('1', '2'))
      )
      msgpack_eq(
        1,
        mapsp(mapsp('2', '1'), mapsp('1', '1'), mapsp('1', '1'), mapsp('1', '1')),
        mapsp(mapsp('1', '1'), mapsp('1', '1'), mapsp('2', '1'), mapsp('1', '1'))
      )
    end)
    it('compares map specials with raw maps correctly', function()
      msgpack_eq(1, mapsp(), '{}')
      msgpack_eq(1, mapsp(sp('string', '["1"]'), '1'), '{"1": 1}')
      msgpack_eq(1, mapsp(sp('string', '["1"]'), sp('integer', '[1, 0, 0, 1]')), '{"1": 1}')
      msgpack_eq(0, mapsp(sp('integer', '[1, 0, 0, 1]'), sp('string', '["1"]')), '{1: "1"}')
      msgpack_eq(1, mapsp('"1"', sp('integer', '[1, 0, 0, 1]')), '{"1": 1}')
      msgpack_eq(0, mapsp(sp('string', '["1"]'), '1', sp('string', '["2"]'), '2'), '{"1": 1}')
      msgpack_eq(0, mapsp(sp('string', '["1"]'), '1'), '{"1": 1, "2": 2}')
    end)
    it('compares raw arrays correctly', function()
      msgpack_eq(1, '[]', '[]')
      msgpack_eq(0, '[]', '[1]')
      msgpack_eq(1, '[1]', '[1]')
      msgpack_eq(1, '[[[1]]]', '[[[1]]]')
      msgpack_eq(0, '[[[2]]]', '[[[1]]]')
    end)
    it('compares array specials correctly', function()
      msgpack_eq(1, sp('array', '[]'), sp('array', '[]'))
      msgpack_eq(0, sp('array', '[]'), sp('array', '[1]'))
      msgpack_eq(1, sp('array', '[1]'), sp('array', '[1]'))
      msgpack_eq(1, sp('array', '[[[1]]]'), sp('array', '[[[1]]]'))
      msgpack_eq(0, sp('array', '[[[1]]]'), sp('array', '[[[2]]]'))
    end)
    it('compares array specials with raw arrays correctly', function()
      msgpack_eq(1, sp('array', '[]'), '[]')
      msgpack_eq(0, sp('array', '[]'), '[1]')
      msgpack_eq(1, sp('array', '[1]'), '[1]')
      msgpack_eq(1, sp('array', '[[[1]]]'), '[[[1]]]')
      msgpack_eq(0, sp('array', '[[[1]]]'), '[[[2]]]')
    end)
    it('compares raw floats correctly', function()
      msgpack_eq(1, '0.0', '0.0')
      msgpack_eq(1, '(1.0/0.0-1.0/0.0)', '(1.0/0.0-1.0/0.0)')
      -- both (1.0/0.0-1.0/0.0) and -(1.0/0.0-1.0/0.0) now return
      -- str2float('nan'). ref: @18d1ba3422d
      msgpack_eq(1, '(1.0/0.0-1.0/0.0)', '-(1.0/0.0-1.0/0.0)')
      msgpack_eq(1, '-(1.0/0.0-1.0/0.0)', '-(1.0/0.0-1.0/0.0)')
      msgpack_eq(1, '1.0/0.0', '1.0/0.0')
      msgpack_eq(1, '-(1.0/0.0)', '-(1.0/0.0)')
      msgpack_eq(1, '0.0', '0.0')
      msgpack_eq(0, '0.0', '1.0')
      msgpack_eq(0, '0.0', '(1.0/0.0-1.0/0.0)')
      msgpack_eq(0, '0.0', '1.0/0.0')
      msgpack_eq(0, '0.0', '-(1.0/0.0)')
      msgpack_eq(0, '1.0/0.0', '-(1.0/0.0)')
      msgpack_eq(0, '(1.0/0.0-1.0/0.0)', '-(1.0/0.0)')
      msgpack_eq(0, '(1.0/0.0-1.0/0.0)', '1.0/0.0')
    end)
    it('compares float specials with raw floats correctly', function()
      msgpack_eq(1, sp('float', '0.0'), '0.0')
      msgpack_eq(1, sp('float', '(1.0/0.0-1.0/0.0)'), '(1.0/0.0-1.0/0.0)')
      msgpack_eq(1, sp('float', '(1.0/0.0-1.0/0.0)'), '-(1.0/0.0-1.0/0.0)')
      msgpack_eq(1, sp('float', '-(1.0/0.0-1.0/0.0)'), '(1.0/0.0-1.0/0.0)')
      msgpack_eq(1, sp('float', '-(1.0/0.0-1.0/0.0)'), '-(1.0/0.0-1.0/0.0)')
      msgpack_eq(1, sp('float', '1.0/0.0'), '1.0/0.0')
      msgpack_eq(1, sp('float', '-(1.0/0.0)'), '-(1.0/0.0)')
      msgpack_eq(1, sp('float', '0.0'), '0.0')
      msgpack_eq(0, sp('float', '0.0'), '1.0')
      msgpack_eq(0, sp('float', '0.0'), '(1.0/0.0-1.0/0.0)')
      msgpack_eq(0, sp('float', '0.0'), '1.0/0.0')
      msgpack_eq(0, sp('float', '0.0'), '-(1.0/0.0)')
      msgpack_eq(0, sp('float', '1.0/0.0'), '-(1.0/0.0)')
      msgpack_eq(0, sp('float', '(1.0/0.0-1.0/0.0)'), '-(1.0/0.0)')
      msgpack_eq(0, sp('float', '(1.0/0.0-1.0/0.0)'), '1.0/0.0')
    end)
    it('compares float specials correctly', function()
      msgpack_eq(1, sp('float', '0.0'), sp('float', '0.0'))
      msgpack_eq(1, sp('float', '(1.0/0.0-1.0/0.0)'), sp('float', '(1.0/0.0-1.0/0.0)'))
      msgpack_eq(1, sp('float', '1.0/0.0'), sp('float', '1.0/0.0'))
      msgpack_eq(1, sp('float', '-(1.0/0.0)'), sp('float', '-(1.0/0.0)'))
      msgpack_eq(1, sp('float', '0.0'), sp('float', '0.0'))
      msgpack_eq(0, sp('float', '0.0'), sp('float', '1.0'))
      msgpack_eq(0, sp('float', '0.0'), sp('float', '(1.0/0.0-1.0/0.0)'))
      msgpack_eq(0, sp('float', '0.0'), sp('float', '1.0/0.0'))
      msgpack_eq(0, sp('float', '0.0'), sp('float', '-(1.0/0.0)'))
      msgpack_eq(0, sp('float', '1.0/0.0'), sp('float', '-(1.0/0.0)'))
      msgpack_eq(0, sp('float', '(1.0/0.0-1.0/0.0)'), sp('float', '-(1.0/0.0)'))
      msgpack_eq(1, sp('float', '(1.0/0.0-1.0/0.0)'), sp('float', '-(1.0/0.0-1.0/0.0)'))
      msgpack_eq(1, sp('float', '-(1.0/0.0-1.0/0.0)'), sp('float', '-(1.0/0.0-1.0/0.0)'))
      msgpack_eq(0, sp('float', '(1.0/0.0-1.0/0.0)'), sp('float', '1.0/0.0'))
    end)
    it('compares boolean specials correctly', function()
      msgpack_eq(1, sp('boolean', '1'), sp('boolean', '1'))
      msgpack_eq(0, sp('boolean', '1'), sp('boolean', '0'))
    end)
    it('compares nil specials correctly', function()
      msgpack_eq(1, sp('nil', '1'), sp('nil', '0'))
    end)
    it('compares nil, boolean and integer values with each other correctly', function()
      msgpack_eq(0, sp('boolean', '1'), '1')
      msgpack_eq(0, sp('boolean', '1'), sp('nil', '0'))
      msgpack_eq(0, sp('boolean', '1'), sp('nil', '1'))
      msgpack_eq(0, sp('boolean', '0'), sp('nil', '0'))
      msgpack_eq(0, sp('boolean', '0'), '0')
      msgpack_eq(0, sp('boolean', '0'), sp('integer', '[1, 0, 0, 0]'))
      msgpack_eq(0, sp('boolean', '0'), sp('integer', '[1, 0, 0, 1]'))
      msgpack_eq(0, sp('boolean', '1'), sp('integer', '[1, 0, 0, 1]'))
      msgpack_eq(0, sp('nil', '0'), sp('integer', '[1, 0, 0, 0]'))
      msgpack_eq(0, sp('nil', '0'), '0')
    end)
  end)

  describe('function msgpack#is_int', function()
    it('works', function()
      eq(1, nvim_eval('msgpack#is_int(1)'))
      eq(1, nvim_eval('msgpack#is_int(-1)'))
      eq(1, nvim_eval(('msgpack#is_int(%s)'):format(sp('integer', '[1, 0, 0, 1]'))))
      eq(1, nvim_eval(('msgpack#is_int(%s)'):format(sp('integer', '[-1, 0, 0, 1]'))))
      eq(0, nvim_eval(('msgpack#is_int(%s)'):format(sp('float', '0.0'))))
      eq(0, nvim_eval(('msgpack#is_int(%s)'):format(sp('boolean', '0'))))
      eq(0, nvim_eval(('msgpack#is_int(%s)'):format(sp('nil', '0'))))
      eq(0, nvim_eval('msgpack#is_int("")'))
    end)
  end)

  describe('function msgpack#is_uint', function()
    it('works', function()
      eq(1, nvim_eval('msgpack#is_uint(1)'))
      eq(0, nvim_eval('msgpack#is_uint(-1)'))
      eq(1, nvim_eval(('msgpack#is_uint(%s)'):format(sp('integer', '[1, 0, 0, 1]'))))
      eq(0, nvim_eval(('msgpack#is_uint(%s)'):format(sp('integer', '[-1, 0, 0, 1]'))))
      eq(0, nvim_eval(('msgpack#is_uint(%s)'):format(sp('float', '0.0'))))
      eq(0, nvim_eval(('msgpack#is_uint(%s)'):format(sp('boolean', '0'))))
      eq(0, nvim_eval(('msgpack#is_uint(%s)'):format(sp('nil', '0'))))
      eq(0, nvim_eval('msgpack#is_uint("")'))
    end)
  end)

  describe('function msgpack#strftime', function()
    it('works', function()
      local epoch = os.date('%Y-%m-%dT%H:%M:%S', 0)
      eq(epoch, nvim_eval('msgpack#strftime("%Y-%m-%dT%H:%M:%S", 0)'))
      eq(
        epoch,
        nvim_eval(
          ('msgpack#strftime("%%Y-%%m-%%dT%%H:%%M:%%S", %s)'):format(sp('integer', '[1, 0, 0, 0]'))
        )
      )
    end)
  end)

  describe('function msgpack#strptime', function()
    it('works', function()
      for _, v in ipairs({ 0, 10, 100000, 204, 1000000000 }) do
        local time = os.date('%Y-%m-%dT%H:%M:%S', v)
        eq(v, nvim_eval('msgpack#strptime("%Y-%m-%dT%H:%M:%S", ' .. '"' .. time .. '")'))
      end
    end)
  end)

  describe('function msgpack#type', function()
    local type_eq = function(expected, val)
      eq(expected, nvim_eval(('msgpack#type(%s)'):format(val)))
    end

    it('works for special dictionaries', function()
      type_eq('string', sp('string', '[""]'))
      type_eq('ext', sp('ext', '[1, [""]]'))
      type_eq('array', sp('array', '[]'))
      type_eq('map', sp('map', '[]'))
      type_eq('integer', sp('integer', '[1, 0, 0, 0]'))
      type_eq('float', sp('float', '0.0'))
      type_eq('boolean', sp('boolean', '0'))
      type_eq('nil', sp('nil', '0'))
    end)

    it('works for regular values', function()
      type_eq('string', '""')
      type_eq('array', '[]')
      type_eq('map', '{}')
      type_eq('integer', '1')
      type_eq('float', '0.0')
      type_eq('float', '(1.0/0.0)')
      type_eq('float', '-(1.0/0.0)')
      type_eq('float', '(1.0/0.0-1.0/0.0)')
    end)
  end)

  describe('function msgpack#special_type', function()
    local sp_type_eq = function(expected, val)
      eq(expected, nvim_eval(('msgpack#special_type(%s)'):format(val)))
    end

    it('works for special dictionaries', function()
      sp_type_eq('string', sp('string', '[""]'))
      sp_type_eq('ext', sp('ext', '[1, [""]]'))
      sp_type_eq('array', sp('array', '[]'))
      sp_type_eq('map', sp('map', '[]'))
      sp_type_eq('integer', sp('integer', '[1, 0, 0, 0]'))
      sp_type_eq('float', sp('float', '0.0'))
      sp_type_eq('boolean', sp('boolean', '0'))
      sp_type_eq('nil', sp('nil', '0'))
    end)

    it('works for regular values', function()
      sp_type_eq(0, '""')
      sp_type_eq(0, '[]')
      sp_type_eq(0, '{}')
      sp_type_eq(0, '1')
      sp_type_eq(0, '0.0')
      sp_type_eq(0, '(1.0/0.0)')
      sp_type_eq(0, '-(1.0/0.0)')
      sp_type_eq(0, '(1.0/0.0-1.0/0.0)')
    end)
  end)

  describe('function msgpack#string', function()
    local string_eq = function(expected, val)
      eq(expected, nvim_eval(('msgpack#string(%s)'):format(val)))
    end

    it('works for special dictionaries', function()
      string_eq('""', sp('string', '[""]'))
      string_eq('"\\n"', sp('string', '["", ""]'))
      string_eq('"ab\\0c\\nde"', sp('string', '["ab\\nc", "de"]'))
      string_eq('+(2)""', sp('ext', '[2, [""]]'))
      string_eq('+(2)"\\n"', sp('ext', '[2, ["", ""]]'))
      string_eq('+(2)"ab\\0c\\nde"', sp('ext', '[2, ["ab\\nc", "de"]]'))
      string_eq('[]', sp('array', '[]'))
      string_eq('[[[[{}]]]]', sp('array', '[[[[{}]]]]'))
      string_eq('{}', sp('map', '[]'))
      string_eq('{2: 10}', sp('map', '[[2, 10]]'))
      string_eq(
        '{{1: 1}: {1: 1}, {2: 1}: {1: 1}}',
        mapsp(mapsp('2', '1'), mapsp('1', '1'), mapsp('1', '1'), mapsp('1', '1'))
      )
      string_eq(
        '{{1: 1}: {1: 1}, {2: 1}: {1: 1}}',
        mapsp(mapsp('1', '1'), mapsp('1', '1'), mapsp('2', '1'), mapsp('1', '1'))
      )
      string_eq(
        '{[1, 2, {{1: 2}: 1}]: [1, 2, {{1: 2}: 1}]}',
        mapsp(
          ('[1, 2, %s]'):format(mapsp(mapsp('1', '2'), '1')),
          ('[1, 2, %s]'):format(mapsp(mapsp('1', '2'), '1'))
        )
      )
      string_eq('0x0000000000000000', sp('integer', '[1, 0, 0, 0]'))
      string_eq('-0x0000000100000000', sp('integer', '[-1, 0, 2, 0]'))
      string_eq('0x123456789abcdef0', sp('integer', '[ 1, 0,  610839793, 448585456]'))
      string_eq('-0x123456789abcdef0', sp('integer', '[-1, 0,  610839793, 448585456]'))
      string_eq('0xf23456789abcdef0', sp('integer', '[ 1, 3, 1684581617, 448585456]'))
      string_eq('-0x723456789abcdef0', sp('integer', '[-1, 1, 1684581617, 448585456]'))
      string_eq('0.0', sp('float', '0.0'))
      string_eq('inf', sp('float', '(1.0/0.0)'))
      string_eq('-inf', sp('float', '-(1.0/0.0)'))
      string_eq('nan', sp('float', '(1.0/0.0-1.0/0.0)'))
      string_eq('nan', sp('float', '-(1.0/0.0-1.0/0.0)'))
      string_eq('FALSE', sp('boolean', '0'))
      string_eq('TRUE', sp('boolean', '1'))
      string_eq('NIL', sp('nil', '0'))
    end)

    it('works for regular values', function()
      string_eq('""', '""')
      string_eq('"\\n"', '"\\n"')
      string_eq('[]', '[]')
      string_eq('[[[{}]]]', '[[[{}]]]')
      string_eq('{}', '{}')
      string_eq('{"2": 10}', '{2: 10}')
      string_eq('{"2": [{}]}', '{2: [{}]}')
      string_eq('1', '1')
      string_eq('0.0', '0.0')
      string_eq('inf', '(1.0/0.0)')
      string_eq('-inf', '-(1.0/0.0)')
      string_eq('nan', '(1.0/0.0-1.0/0.0)')
      string_eq('nan', '-(1.0/0.0-1.0/0.0)')
    end)

    it('works for special v: values like v:true', function()
      string_eq('TRUE', 'v:true')
      string_eq('FALSE', 'v:false')
      string_eq('NIL', 'v:null')
    end)
  end)

  describe('function msgpack#deepcopy', function()
    it('works for special dictionaries', function()
      nvim_command('let sparr = ' .. sp('array', '[[[]]]'))
      nvim_command('let spmap = ' .. mapsp('"abc"', '[[]]'))
      nvim_command('let spint = ' .. sp('integer', '[1, 0, 0, 0]'))
      nvim_command('let spflt = ' .. sp('float', '1.0'))
      nvim_command('let spext = ' .. sp('ext', '[2, ["abc", "def"]]'))
      nvim_command('let spstr = ' .. sp('string', '["abc", "def"]'))
      nvim_command('let spbln = ' .. sp('boolean', '0'))
      nvim_command('let spnil = ' .. sp('nil', '0'))

      nvim_command('let sparr2 = msgpack#deepcopy(sparr)')
      nvim_command('let spmap2 = msgpack#deepcopy(spmap)')
      nvim_command('let spint2 = msgpack#deepcopy(spint)')
      nvim_command('let spflt2 = msgpack#deepcopy(spflt)')
      nvim_command('let spext2 = msgpack#deepcopy(spext)')
      nvim_command('let spstr2 = msgpack#deepcopy(spstr)')
      nvim_command('let spbln2 = msgpack#deepcopy(spbln)')
      nvim_command('let spnil2 = msgpack#deepcopy(spnil)')

      eq('array', nvim_eval('msgpack#type(sparr2)'))
      eq('map', nvim_eval('msgpack#type(spmap2)'))
      eq('integer', nvim_eval('msgpack#type(spint2)'))
      eq('float', nvim_eval('msgpack#type(spflt2)'))
      eq('ext', nvim_eval('msgpack#type(spext2)'))
      eq('string', nvim_eval('msgpack#type(spstr2)'))
      eq('boolean', nvim_eval('msgpack#type(spbln2)'))
      eq('nil', nvim_eval('msgpack#type(spnil2)'))

      nvim_command('call add(sparr._VAL, 0)')
      nvim_command('call add(sparr._VAL[0], 0)')
      nvim_command('call add(sparr._VAL[0][0], 0)')
      nvim_command('call add(spmap._VAL, [0, 0])')
      nvim_command('call add(spmap._VAL[0][1], 0)')
      nvim_command('call add(spmap._VAL[0][1][0], 0)')
      nvim_command('let spint._VAL[1] = 1')
      nvim_command('let spflt._VAL = 0.0')
      nvim_command('let spext._VAL[0] = 3')
      nvim_command('let spext._VAL[1][0] = "gh"')
      nvim_command('let spstr._VAL[0] = "gh"')
      nvim_command('let spbln._VAL = 1')
      nvim_command('let spnil._VAL = 1')

      eq({ _TYPE = {}, _VAL = { { {} } } }, nvim_eval('sparr2'))
      eq({ _TYPE = {}, _VAL = { { 'abc', { {} } } } }, nvim_eval('spmap2'))
      eq({ _TYPE = {}, _VAL = { 1, 0, 0, 0 } }, nvim_eval('spint2'))
      eq({ _TYPE = {}, _VAL = 1.0 }, nvim_eval('spflt2'))
      eq({ _TYPE = {}, _VAL = { 2, { 'abc', 'def' } } }, nvim_eval('spext2'))
      eq({ _TYPE = {}, _VAL = { 'abc', 'def' } }, nvim_eval('spstr2'))
      eq({ _TYPE = {}, _VAL = 0 }, nvim_eval('spbln2'))
      eq({ _TYPE = {}, _VAL = 0 }, nvim_eval('spnil2'))

      nvim_command('let sparr._TYPE = []')
      nvim_command('let spmap._TYPE = []')
      nvim_command('let spint._TYPE = []')
      nvim_command('let spflt._TYPE = []')
      nvim_command('let spext._TYPE = []')
      nvim_command('let spstr._TYPE = []')
      nvim_command('let spbln._TYPE = []')
      nvim_command('let spnil._TYPE = []')

      eq('array', nvim_eval('msgpack#special_type(sparr2)'))
      eq('map', nvim_eval('msgpack#special_type(spmap2)'))
      eq('integer', nvim_eval('msgpack#special_type(spint2)'))
      eq('float', nvim_eval('msgpack#special_type(spflt2)'))
      eq('ext', nvim_eval('msgpack#special_type(spext2)'))
      eq('string', nvim_eval('msgpack#special_type(spstr2)'))
      eq('boolean', nvim_eval('msgpack#special_type(spbln2)'))
      eq('nil', nvim_eval('msgpack#special_type(spnil2)'))
    end)

    it('works for regular values', function()
      nvim_command('let arr = [[[]]]')
      nvim_command('let map = {1: {}}')
      nvim_command('let int = 1')
      nvim_command('let flt = 2.0')
      nvim_command('let bin = "abc"')

      nvim_command('let arr2 = msgpack#deepcopy(arr)')
      nvim_command('let map2 = msgpack#deepcopy(map)')
      nvim_command('let int2 = msgpack#deepcopy(int)')
      nvim_command('let flt2 = msgpack#deepcopy(flt)')
      nvim_command('let bin2 = msgpack#deepcopy(bin)')

      eq('array', nvim_eval('msgpack#type(arr2)'))
      eq('map', nvim_eval('msgpack#type(map2)'))
      eq('integer', nvim_eval('msgpack#type(int2)'))
      eq('float', nvim_eval('msgpack#type(flt2)'))
      eq('string', nvim_eval('msgpack#type(bin2)'))

      nvim_command('call add(arr, 0)')
      nvim_command('call add(arr[0], 0)')
      nvim_command('call add(arr[0][0], 0)')
      nvim_command('let map.a = 1')
      nvim_command('let map.1.a = 1')
      nvim_command('let int = 2')
      nvim_command('let flt = 3.0')
      nvim_command('let bin = ""')

      eq({ { {} } }, nvim_eval('arr2'))
      eq({ ['1'] = {} }, nvim_eval('map2'))
      eq(1, nvim_eval('int2'))
      eq(2.0, nvim_eval('flt2'))
      eq('abc', nvim_eval('bin2'))
    end)

    it('works for special v: values like v:true', function()
      api.nvim_set_var('true', true)
      api.nvim_set_var('false', false)
      api.nvim_set_var('nil', NIL)

      nvim_command('let true2 = msgpack#deepcopy(true)')
      nvim_command('let false2 = msgpack#deepcopy(false)')
      nvim_command('let nil2 = msgpack#deepcopy(nil)')

      eq(true, api.nvim_get_var('true'))
      eq(false, api.nvim_get_var('false'))
      eq(NIL, api.nvim_get_var('nil'))
    end)
  end)

  describe('function msgpack#eval', function()
    local eval_eq = function(expected_type, expected_val, str, ...)
      nvim_command(
        ("let g:__val = msgpack#eval('%s', %s)"):format(str:gsub("'", "''"), select(1, ...) or '{}')
      )
      eq(expected_type, nvim_eval('msgpack#type(g:__val)'))
      local expected_val_full = expected_val
      if
        not (({ float = true, integer = true })[expected_type] and type(expected_val) ~= 'table')
        and expected_type ~= 'array'
      then
        expected_val_full = { _TYPE = {}, _VAL = expected_val_full }
      end
      if expected_val_full == expected_val_full then
        eq(expected_val_full, nvim_eval('g:__val'))
      else -- NaN
        local nvim_nan = tostring(nvim_eval('g:__val'))
        -- -NaN is a hardware-specific detail, there's no need to test for it.
        -- Accept ether 'nan' or '-nan' as the response.
        ok(nvim_nan == 'nan' or nvim_nan == '-nan')
      end
      nvim_command('unlet g:__val')
    end

    it('correctly loads strings', function()
      eval_eq('string', { 'abcdef' }, '="abcdef"')
      eval_eq('string', { 'abc', 'def' }, '="abc\\ndef"')
      eval_eq('string', { 'abc\ndef' }, '="abc\\0def"')
      eval_eq('string', { '\nabc\ndef\n' }, '="\\0abc\\0def\\0"')
      eval_eq('string', { 'abc\n\n\ndef' }, '="abc\\0\\0\\0def"')
      eval_eq('string', { 'abc\n', '\ndef' }, '="abc\\0\\n\\0def"')
      eval_eq('string', { 'abc', '', '', 'def' }, '="abc\\n\\n\\ndef"')
      eval_eq('string', { 'abc', '', '', 'def', '' }, '="abc\\n\\n\\ndef\\n"')
      eval_eq('string', { '', 'abc', '', '', 'def' }, '="\\nabc\\n\\n\\ndef"')
      eval_eq('string', { '' }, '=""')
      eval_eq('string', { '"' }, '="\\""')
      eval_eq('string', { 'py3 print(sys.version_info)' }, '="py3 print(sys.version_info)"')
    end)

    it('correctly loads ext values', function()
      eval_eq('ext', { 0, { 'abcdef' } }, '+(0)"abcdef"')
      eval_eq('ext', { 0, { 'abc', 'def' } }, '+(0)"abc\\ndef"')
      eval_eq('ext', { 0, { 'abc\ndef' } }, '+(0)"abc\\0def"')
      eval_eq('ext', { 0, { '\nabc\ndef\n' } }, '+(0)"\\0abc\\0def\\0"')
      eval_eq('ext', { 0, { 'abc\n\n\ndef' } }, '+(0)"abc\\0\\0\\0def"')
      eval_eq('ext', { 0, { 'abc\n', '\ndef' } }, '+(0)"abc\\0\\n\\0def"')
      eval_eq('ext', { 0, { 'abc', '', '', 'def' } }, '+(0)"abc\\n\\n\\ndef"')
      eval_eq('ext', { 0, { 'abc', '', '', 'def', '' } }, '+(0)"abc\\n\\n\\ndef\\n"')
      eval_eq('ext', { 0, { '', 'abc', '', '', 'def' } }, '+(0)"\\nabc\\n\\n\\ndef"')
      eval_eq('ext', { 0, { '' } }, '+(0)""')
      eval_eq('ext', { 0, { '"' } }, '+(0)"\\""')

      eval_eq('ext', { -1, { 'abcdef' } }, '+(-1)"abcdef"')
      eval_eq('ext', { -1, { 'abc', 'def' } }, '+(-1)"abc\\ndef"')
      eval_eq('ext', { -1, { 'abc\ndef' } }, '+(-1)"abc\\0def"')
      eval_eq('ext', { -1, { '\nabc\ndef\n' } }, '+(-1)"\\0abc\\0def\\0"')
      eval_eq('ext', { -1, { 'abc\n\n\ndef' } }, '+(-1)"abc\\0\\0\\0def"')
      eval_eq('ext', { -1, { 'abc\n', '\ndef' } }, '+(-1)"abc\\0\\n\\0def"')
      eval_eq('ext', { -1, { 'abc', '', '', 'def' } }, '+(-1)"abc\\n\\n\\ndef"')
      eval_eq('ext', { -1, { 'abc', '', '', 'def', '' } }, '+(-1)"abc\\n\\n\\ndef\\n"')
      eval_eq('ext', { -1, { '', 'abc', '', '', 'def' } }, '+(-1)"\\nabc\\n\\n\\ndef"')
      eval_eq('ext', { -1, { '' } }, '+(-1)""')
      eval_eq('ext', { -1, { '"' } }, '+(-1)"\\""')

      eval_eq(
        'ext',
        { 42, { 'py3 print(sys.version_info)' } },
        '+(42)"py3 print(sys.version_info)"'
      )
    end)

    it('correctly loads floats', function()
      eval_eq('float', inf, 'inf')
      eval_eq('float', minus_inf, '-inf')
      eval_eq('float', nan, 'nan')
      eval_eq('float', 1.0e10, '1.0e10')
      eval_eq('float', 1.0e10, '1.0e+10')
      eval_eq('float', -1.0e10, '-1.0e+10')
      eval_eq('float', 1.0, '1.0')
      eval_eq('float', -1.0, '-1.0')
      eval_eq('float', 1.0e-10, '1.0e-10')
      eval_eq('float', -1.0e-10, '-1.0e-10')
    end)

    it('correctly loads integers', function()
      eval_eq('integer', 10, '10')
      eval_eq('integer', -10, '-10')
      eval_eq('integer', { 1, 0, 610839793, 448585456 }, ' 0x123456789ABCDEF0')
      eval_eq('integer', { -1, 0, 610839793, 448585456 }, '-0x123456789ABCDEF0')
      eval_eq('integer', { 1, 3, 1684581617, 448585456 }, ' 0xF23456789ABCDEF0')
      eval_eq('integer', { -1, 1, 1684581617, 448585456 }, '-0x723456789ABCDEF0')
      eval_eq('integer', { 1, 0, 0, 0x100 }, '0x100')
      eval_eq('integer', { -1, 0, 0, 0x100 }, '-0x100')

      eval_eq('integer', ('a'):byte(), "'a'")
      eval_eq('integer', 0xAB, "'«'")
      eval_eq('integer', 0, "'\\0'")
      eval_eq('integer', 10246567, "'\\10246567'")
    end)

    it('correctly loads constants', function()
      eval_eq('boolean', 1, 'TRUE')
      eval_eq('boolean', 0, 'FALSE')
      eval_eq('nil', 0, 'NIL')
      eval_eq('nil', 0, 'NIL', '{"NIL": 1, "nan": 2, "T": 3}')
      eval_eq('float', nan, 'nan', '{"NIL": "1", "nan": "2", "T": "3"}')
      eval_eq('integer', 3, 'T', '{"NIL": "1", "nan": "2", "T": "3"}')
      eval_eq(
        'integer',
        { 1, 0, 0, 0 },
        'T',
        ('{"NIL": "1", "nan": "2", "T": \'%s\'}'):format(sp('integer', '[1, 0, 0, 0]'))
      )
    end)

    it('correctly loads maps', function()
      eval_eq('map', {}, '{}')
      eval_eq(
        'map',
        { { { _TYPE = {}, _VAL = { { 1, 2 } } }, { _TYPE = {}, _VAL = { { 3, 4 } } } } },
        '{{1: 2}: {3: 4}}'
      )
      eval_eq(
        'map',
        { { { _TYPE = {}, _VAL = { { 1, 2 } } }, { _TYPE = {}, _VAL = { { 3, 4 } } } }, { 1, 2 } },
        '{{1: 2}: {3: 4}, 1: 2}'
      )

      eval_eq('map', {
        {
          {
            _TYPE = {},
            _VAL = {
              { { _TYPE = {}, _VAL = { 'py3 print(sys.version_info)' } }, 2 },
            },
          },
          { _TYPE = {}, _VAL = { { 3, 4 } } },
        },
        { 1, 2 },
      }, '{{"py3 print(sys.version_info)": 2}: {3: 4}, 1: 2}')
    end)

    it('correctly loads arrays', function()
      eval_eq('array', {}, '[]')
      eval_eq('array', { 1 }, '[1]')
      eval_eq('array', { { _TYPE = {}, _VAL = 1 } }, '[TRUE]')
      eval_eq(
        'array',
        { { { _TYPE = {}, _VAL = { { 1, 2 } } } }, { _TYPE = {}, _VAL = { { 3, 4 } } } },
        '[[{1: 2}], {3: 4}]'
      )

      eval_eq(
        'array',
        { { _TYPE = {}, _VAL = { 'py3 print(sys.version_info)' } } },
        '["py3 print(sys.version_info)"]'
      )
    end)

    it('errors out when needed', function()
      eq('empty:Parsed string is empty', exc_exec('call msgpack#eval("", {})'))
      eq('unknown:Invalid non-space character: ^', exc_exec('call msgpack#eval("^", {})'))
      eq(
        "char-invalid:Invalid integer character literal format: ''",
        exc_exec('call msgpack#eval("\'\'", {})')
      )
      eq(
        "char-invalid:Invalid integer character literal format: 'ab'",
        exc_exec('call msgpack#eval("\'ab\'", {})')
      )
      eq(
        "char-invalid:Invalid integer character literal format: '",
        exc_exec('call msgpack#eval("\'", {})')
      )
      eq('"-invalid:Invalid string: "', exc_exec('call msgpack#eval("\\"", {})'))
      eq('"-invalid:Invalid string: ="', exc_exec('call msgpack#eval("=\\"", {})'))
      eq('"-invalid:Invalid string: +(0)"', exc_exec('call msgpack#eval("+(0)\\"", {})'))
      eq(
        '0.-nodigits:Decimal dot must be followed by digit(s): .e1',
        exc_exec('call msgpack#eval("0.e1", {})')
      )
      eq(
        '0x-long:Must have at most 16 hex digits: FEDCBA98765432100',
        exc_exec('call msgpack#eval("0xFEDCBA98765432100", {})')
      )
      eq('0x-empty:Must have number after 0x: ', exc_exec('call msgpack#eval("0x", {})'))
      eq('name-unknown:Unknown name FOO: FOO', exc_exec('call msgpack#eval("FOO", {})'))

      eq(
        'name-unknown:Unknown name py3: py3 print(sys.version_info)',
        exc_exec('call msgpack#eval("py3 print(sys.version_info)", {})')
      )
      eq('name-unknown:Unknown name o: o', exc_exec('call msgpack#eval("-info", {})'))
    end)
  end)
end)
