local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq, nvim_eval, nvim_command, nvim, exc_exec, funcs, nvim_feed, curbuf =
  helpers.eq, helpers.eval, helpers.command, helpers.nvim, helpers.exc_exec,
  helpers.funcs, helpers.feed, helpers.curbuf
local neq = helpers.neq
local read_file = helpers.read_file

local mpack = require('mpack')

local shada_helpers = require('test.functional.shada.helpers')
local get_shada_rw = shada_helpers.get_shada_rw

local function reset(shada_file)
  clear{ args={'-u', 'NORC', '-i', shada_file or 'NONE', }}
end

local mpack_eq = function(expected, mpack_result)
  local mpack_keys = {'type', 'timestamp', 'length', 'value'}

  local unpack = mpack.Unpacker()
  local actual = {}
  local cur, val
  local i = 0
  local off = 1
  while off <= #mpack_result do
    val, off = unpack(mpack_result, off)
    if i % 4 == 0 then
      cur = {}
      actual[#actual + 1] = cur
    end
    local key = mpack_keys[(i % 4) + 1]
    if key ~= 'length' then
      if key == 'timestamp' and math.abs(val - os.time()) < 2 then
        val = 'current'
      end
      cur[key] = val
    end
    i = i + 1
  end
  eq(expected, actual)
end

local wshada, _, fname = get_shada_rw('Xtest-functional-plugin-shada.shada')

local wshada_tmp, _, fname_tmp =
  get_shada_rw('Xtest-functional-plugin-shada.shada.tmp.f')

describe('autoload/shada.vim', function()
  local epoch = os.date('%Y-%m-%dT%H:%M:%S', 0)
  before_each(function()
    reset()
    nvim_command([[
    function ModifyVal(val)
      if type(a:val) == type([])
        if len(a:val) == 2 && type(a:val[0]) == type('') && a:val[0][0] is# '!' && has_key(v:msgpack_types, a:val[0][1:])
          return {'_TYPE': v:msgpack_types[ a:val[0][1:] ], '_VAL': a:val[1]}
        else
          return map(copy(a:val), 'ModifyVal(v:val)')
        endif
      elseif type(a:val) == type({})
        let keys = sort(keys(a:val))
        let ret = {'_TYPE': v:msgpack_types.map, '_VAL': []}
        for key in keys
          let k = {'_TYPE': v:msgpack_types.string, '_VAL': split(key, "\n", 1)}
          let v = ModifyVal(a:val[key])
          call add(ret._VAL, [k, v])
          unlet v
        endfor
        return ret
      elseif type(a:val) == type('')
        return {'_TYPE': v:msgpack_types.binary, '_VAL': split(a:val, "\n", 1)}
      else
        return a:val
      endif
    endfunction
    ]])
  end)

  local sp = function(typ, val)
    return ('{"_TYPE": v:msgpack_types.%s, "_VAL": %s}'):format(typ, val)
  end

  describe('function shada#mpack_to_sd', function()
    local mpack2sd = function(arg)
      return ('shada#mpack_to_sd(%s)'):format(arg)
    end

    it('works', function()
      eq({}, nvim_eval(mpack2sd('[]')))
      eq({{type=1, timestamp=5, length=1, data=7}},
         nvim_eval(mpack2sd('[1, 5, 1, 7]')))
      eq({{type=1, timestamp=5, length=1, data=7},
          {type=1, timestamp=10, length=1, data=5}},
         nvim_eval(mpack2sd('[1, 5, 1, 7, 1, 10, 1, 5]')))
      eq('zero-uint:Entry 1 has type element which is zero',
         exc_exec('call ' .. mpack2sd('[0, 5, 1, 7]')))
      eq('zero-uint:Entry 1 has type element which is zero',
         exc_exec('call ' .. mpack2sd(('[%s, 5, 1, 7]'):format(
            sp('integer', '[1, 0, 0, 0]')))))
      eq('not-uint:Entry 1 has timestamp element which is not an unsigned integer',
         exc_exec('call ' .. mpack2sd('[1, -1, 1, 7]')))
      eq('not-uint:Entry 1 has length element which is not an unsigned integer',
         exc_exec('call ' .. mpack2sd('[1, 1, -1, 7]')))
      eq('not-uint:Entry 1 has type element which is not an unsigned integer',
         exc_exec('call ' .. mpack2sd('["", 1, -1, 7]')))
    end)
  end)

  describe('function shada#sd_to_strings', function()
    local sd2strings_eq = function(expected, arg)
      if type(arg) == 'table' then
        eq(expected, funcs['shada#sd_to_strings'](arg))
      else
        eq(expected, nvim_eval(('shada#sd_to_strings(%s)'):format(arg)))
      end
    end

    it('works with empty input', function()
      sd2strings_eq({}, '[]')
    end)

    it('works with unknown items', function()
      sd2strings_eq({
        'Unknown (0x64) with timestamp ' .. epoch .. ':',
        '  = 100'
      }, {{type=100, timestamp=0, length=1, data=100}})

      sd2strings_eq({
        'Unknown (0x4000001180000006) with timestamp ' .. epoch .. ':',
        '  = 100'
      }, ('[{"type": %s, "timestamp": 0, "length": 1, "data": 100}]'):format(
        sp('integer', '[1, 1, 35, 6]')
      ))
    end)

    it('works with multiple unknown items', function()
      sd2strings_eq({
        'Unknown (0x64) with timestamp ' .. epoch .. ':',
        '  = 100',
        'Unknown (0x65) with timestamp ' .. epoch .. ':',
        '  = 500',
      }, {{type=100, timestamp=0, length=1, data=100},
          {type=101, timestamp=0, length=1, data=500}})
    end)

    it('works with header items', function()
      sd2strings_eq({
        'Header with timestamp ' .. epoch .. ':',
        '  % Key______  Value',
        '  + generator  "test"',
      }, {{type=1, timestamp=0, data={generator='test'}}})
      sd2strings_eq({
        'Header with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + a                 1',
        '  + b                 2',
        '  + c    column       3',
        '  + d                 4',
      }, {{type=1, timestamp=0, data={a=1, b=2, c=3, d=4}}})
      sd2strings_eq({
        'Header with timestamp ' .. epoch .. ':',
        '  % Key  Value',
        '  + t    "test"',
      }, {{type=1, timestamp=0, data={t='test'}}})
      sd2strings_eq({
        'Header with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      }, {{type=1, timestamp=0, data={1, 2, 3}}})
    end)

    it('processes standard keys correctly, even in header', function()
      sd2strings_eq({
        'Header with timestamp ' .. epoch .. ':',
        '  % Key  Description________  Value',
        '  + c    column               0',
        '  + f    file name            "/tmp/foo"',
        '  + l    line number          10',
        '  + n    name                 \'@\'',
        '  + rc   contents             ["abc", "def"]',
        '  + rt   type                 CHARACTERWISE',
        '  + ru   is_unnamed           FALSE',
        '  + rw   block width          10',
        '  + sb   search backward      TRUE',
        '  + sc   smartcase value      FALSE',
        '  + se   place cursor at end  TRUE',
        '  + sh   v:hlsearch value     TRUE',
        '  + sl   has line offset      FALSE',
        '  + sm   magic value          TRUE',
        '  + so   offset value         10',
        '  + sp   pattern              "100"',
        '  + ss   is :s pattern        TRUE',
        '  + su   is last used         FALSE',
      }, ([[ [{'type': 1, 'timestamp': 0, 'data': {
        'sm': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
        'sc': {'_TYPE': v:msgpack_types.boolean, '_VAL': 0},
        'sl': {'_TYPE': v:msgpack_types.boolean, '_VAL': 0},
        'se': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
        'sb': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
        'so': 10,
        'su': {'_TYPE': v:msgpack_types.boolean, '_VAL': 0},
        'ss': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
        'sh': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
        'sp': '100',
        'rt': 0,
        'rw': 10,
        'rc': ['abc', 'def'],
        'ru': {'_TYPE': v:msgpack_types.boolean, '_VAL': 0},
        'n': 0x40,
        'l': 10,
        'c': 0,
        'f': '/tmp/foo',
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Header with timestamp ' .. epoch .. ':',
        '  % Key  Description____  Value',
        '  # Expected integer',
        '  + c    column           "abc"',
        '  # Expected no NUL bytes',
        '  + f    file name        "abc\\0def"',
        '  # Value is negative',
        '  + l    line number      -10',
        '  # Value is negative',
        '  + n    name             -64',
        '  # Expected array value',
        '  + rc   contents         "10"',
        '  # Unexpected enum value: expected one of '
         .. '0 (CHARACTERWISE), 1 (LINEWISE), 2 (BLOCKWISE)',
        '  + rt   type             10',
        '  # Expected boolean',
        '  + ru   is_unnamed       10',
        '  # Expected boolean',
        '  + sc   smartcase value  NIL',
        '  # Expected boolean',
        '  + sm   magic value      "TRUE"',
        '  # Expected integer',
        '  + so   offset value     "TRUE"',
        '  # Expected binary string',
        '  + sp   pattern          ="abc"',
      }, ([[ [{'type': 1, 'timestamp': 0, 'data': {
        'sm': 'TRUE',
        'sc': {'_TYPE': v:msgpack_types.nil, '_VAL': 0},
        'so': 'TRUE',
        'sp': {'_TYPE': v:msgpack_types.string, '_VAL': ["abc"]},
        'rt': 10,
        'rc': '10',
        'ru': 10,
        'n': -0x40,
        'l': -10,
        'c': 'abc',
        'f': {'_TYPE': v:msgpack_types.binary, '_VAL': ["abc\ndef"]},
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Header with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Expected no NUL bytes',
        '  + f    file name    "abc\\0def"',
        '  # Expected array of binary strings',
        '  + rc   contents     ["abc", ="abc"]',
        '  # Expected integer',
        '  + rt   type         "ABC"',
      }, ([[ [{'type': 1, 'timestamp': 0, 'data': {
        'rt': 'ABC',
        'rc': ["abc", {'_TYPE': v:msgpack_types.string, '_VAL': ["abc"]}],
        'f': {'_TYPE': v:msgpack_types.binary, '_VAL': ["abc\ndef"]},
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Header with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Expected no NUL bytes',
        '  + rc   contents     ["abc", "a\\nd\\0"]',
      }, ([[ [{'type': 1, 'timestamp': 0, 'data': {
        'rc': ["abc", {'_TYPE': v:msgpack_types.binary, '_VAL': ["a", "d\n"]}],
      }}] ]]):gsub('\n', ''))
    end)

    it('works with search pattern items', function()
      sd2strings_eq({
        'Search pattern with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      }, {{type=2, timestamp=0, data={1, 2, 3}}})
      sd2strings_eq({
        'Search pattern with timestamp ' .. epoch .. ':',
        '  % Key  Description________  Value',
        '  + sp   pattern              "abc"',
        '  + sh   v:hlsearch value     FALSE',
        '  + ss   is :s pattern        FALSE',
        '  + sb   search backward      FALSE',
        '  + sm   magic value          TRUE',
        '  + sc   smartcase value      FALSE',
        '  + sl   has line offset      FALSE',
        '  + se   place cursor at end  FALSE',
        '  + so   offset value         0',
        '  + su   is last used         TRUE',
      }, ([[ [{'type': 2, 'timestamp': 0, 'data': {
        'sp': 'abc',
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Search pattern with timestamp ' .. epoch .. ':',
        '  % Key  Description________  Value',
        '  + sp   pattern              "abc"',
        '  + sh   v:hlsearch value     FALSE',
        '  + ss   is :s pattern        FALSE',
        '  + sb   search backward      FALSE',
        '  + sm   magic value          TRUE',
        '  + sc   smartcase value      FALSE',
        '  + sl   has line offset      FALSE',
        '  + se   place cursor at end  FALSE',
        '  + so   offset value         0',
        '  + su   is last used         TRUE',
        '  + sX                        NIL',
        '  + sY                        NIL',
        '  + sZ                        NIL',
      }, ([[ [{'type': 2, 'timestamp': 0, 'data': {
        'sp': 'abc',
        'sZ': {'_TYPE': v:msgpack_types.nil, '_VAL': 0},
        'sY': {'_TYPE': v:msgpack_types.nil, '_VAL': 0},
        'sX': {'_TYPE': v:msgpack_types.nil, '_VAL': 0},
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Search pattern with timestamp ' .. epoch .. ':',
        '  % Key  Description________  Value',
        '  + sp   pattern              "abc"',
        '  + sh   v:hlsearch value     FALSE',
        '  + ss   is :s pattern        FALSE',
        '  + sb   search backward      FALSE',
        '  + sm   magic value          TRUE',
        '  + sc   smartcase value      FALSE',
        '  + sl   has line offset      FALSE',
        '  + se   place cursor at end  FALSE',
        '  + so   offset value         0',
        '  + su   is last used         TRUE',
      }, ([[ [{'type': 2, 'timestamp': 0, 'data': {
        'sp': 'abc',
        'sh': {'_TYPE': v:msgpack_types.boolean, '_VAL': 0},
        'ss': {'_TYPE': v:msgpack_types.boolean, '_VAL': 0},
        'sb': {'_TYPE': v:msgpack_types.boolean, '_VAL': 0},
        'sm': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
        'sc': {'_TYPE': v:msgpack_types.boolean, '_VAL': 0},
        'sl': {'_TYPE': v:msgpack_types.boolean, '_VAL': 0},
        'se': {'_TYPE': v:msgpack_types.boolean, '_VAL': 0},
        'so': 0,
        'su': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Search pattern with timestamp ' .. epoch .. ':',
        '  % Key  Description________  Value',
        '  # Required key missing: sp',
        '  + sh   v:hlsearch value     FALSE',
        '  + ss   is :s pattern        FALSE',
        '  + sb   search backward      FALSE',
        '  + sm   magic value          TRUE',
        '  + sc   smartcase value      FALSE',
        '  + sl   has line offset      FALSE',
        '  + se   place cursor at end  FALSE',
        '  + so   offset value         0',
        '  + su   is last used         TRUE',
      }, ([[ [{'type': 2, 'timestamp': 0, 'data': {
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Search pattern with timestamp ' .. epoch .. ':',
        '  % Key  Description________  Value',
        '  + sp   pattern              ""',
        '  + sh   v:hlsearch value     TRUE',
        '  + ss   is :s pattern        TRUE',
        '  + sb   search backward      TRUE',
        '  + sm   magic value          FALSE',
        '  + sc   smartcase value      TRUE',
        '  + sl   has line offset      TRUE',
        '  + se   place cursor at end  TRUE',
        '  + so   offset value         -10',
        '  + su   is last used         FALSE',
      }, ([[ [{'type': 2, 'timestamp': 0, 'data': {
        'sp': '',
        'sh': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
        'ss': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
        'sb': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
        'sm': {'_TYPE': v:msgpack_types.boolean, '_VAL': 0},
        'sc': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
        'sl': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
        'se': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
        'so': -10,
        'su': {'_TYPE': v:msgpack_types.boolean, '_VAL': 0},
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Search pattern with timestamp ' .. epoch .. ':',
        '  % Key  Description________  Value',
        '  # Expected binary string',
        '  + sp   pattern              0',
        '  # Expected boolean',
        '  + sh   v:hlsearch value     0',
        '  # Expected boolean',
        '  + ss   is :s pattern        0',
        '  # Expected boolean',
        '  + sb   search backward      0',
        '  # Expected boolean',
        '  + sm   magic value          0',
        '  # Expected boolean',
        '  + sc   smartcase value      0',
        '  # Expected boolean',
        '  + sl   has line offset      0',
        '  # Expected boolean',
        '  + se   place cursor at end  0',
        '  # Expected integer',
        '  + so   offset value         ""',
        '  # Expected boolean',
        '  + su   is last used         0',
      }, ([[ [{'type': 2, 'timestamp': 0, 'data': {
        'sp': 0,
        'sh': 0,
        'ss': 0,
        'sb': 0,
        'sm': 0,
        'sc': 0,
        'sl': 0,
        'se': 0,
        'so': '',
        'su': 0,
      }}] ]]):gsub('\n', ''))
    end)

    it('works with replacement string items', function()
      sd2strings_eq({
        'Replacement string with timestamp ' .. epoch .. ':',
        '  # Unexpected type: map instead of array',
        '  = {="a": [10]}',
      }, {{type=3, timestamp=0, data={a={10}}}})
      sd2strings_eq({
        'Replacement string with timestamp ' .. epoch .. ':',
        '  @ Description__________  Value',
        '  # Expected more elements in list'
      }, ([[ [{'type': 3, 'timestamp': 0, 'data': [
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Replacement string with timestamp ' .. epoch .. ':',
        '  @ Description__________  Value',
        '  # Expected binary string',
        '  - :s replacement string  0',
      }, ([[ [{'type': 3, 'timestamp': 0, 'data': [
        0,
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Replacement string with timestamp ' .. epoch .. ':',
        '  @ Description__________  Value',
        '  # Expected no NUL bytes',
        '  - :s replacement string  "abc\\0def"',
      }, ([[ [{'type': 3, 'timestamp': 0, 'data': [
        {'_TYPE': v:msgpack_types.binary, '_VAL': ["abc\ndef"]},
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Replacement string with timestamp ' .. epoch .. ':',
        '  @ Description__________  Value',
        '  - :s replacement string  "abc\\ndef"',
      }, ([[ [{'type': 3, 'timestamp': 0, 'data': [
        {'_TYPE': v:msgpack_types.binary, '_VAL': ["abc", "def"]},
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Replacement string with timestamp ' .. epoch .. ':',
        '  @ Description__________  Value',
        '  - :s replacement string  "abc\\ndef"',
        '  -                        0',
      }, ([[ [{'type': 3, 'timestamp': 0, 'data': [
        {'_TYPE': v:msgpack_types.binary, '_VAL': ["abc", "def"]},
        0,
      ]}] ]]):gsub('\n', ''))
    end)

    it('works with history entry items', function()
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  # Unexpected type: map instead of array',
        '  = {="a": [10]}',
      }, {{type=4, timestamp=0, data={a={10}}}})
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  # Expected more elements in list'
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  # Expected integer',
        '  - history type  ""',
        '  # Expected more elements in list'
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        '',
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  # Unexpected enum value: expected one of 0 (CMD), 1 (SEARCH), '
            .. '2 (EXPR), 3 (INPUT), 4 (DEBUG)',
        '  - history type  5',
        '  - contents      ""',
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        5,
        ''
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  # Unexpected enum value: expected one of 0 (CMD), 1 (SEARCH), '
            .. '2 (EXPR), 3 (INPUT), 4 (DEBUG)',
        '  - history type  5',
        '  - contents      ""',
        '  -               32',
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        5,
        '',
        0x20
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  CMD',
        '  - contents      ""',
        '  -               32',
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        0,
        '',
        0x20
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  SEARCH',
        '  - contents      ""',
        '  - separator     \' \'',
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        1,
        '',
        0x20
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  SEARCH',
        '  - contents      ""',
        '  # Expected more elements in list',
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        1,
        '',
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  EXPR',
        '  - contents      ""',
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        2,
        '',
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  INPUT',
        '  - contents      ""',
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        3,
        '',
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  DEBUG',
        '  - contents      ""',
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        4,
        '',
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  DEBUG',
        '  # Expected binary string',
        '  - contents      10',
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        4,
        10,
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  DEBUG',
        '  # Expected no NUL bytes',
        '  - contents      "abc\\0def"',
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        4,
        {'_TYPE': v:msgpack_types.binary, '_VAL': ["abc\ndef"]},
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  SEARCH',
        '  - contents      "abc"',
        '  # Expected integer',
        '  - separator     ""',
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        1,
        'abc',
        '',
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  SEARCH',
        '  - contents      "abc"',
        '  # Value is negative',
        '  - separator     -1',
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        1,
        'abc',
        -1,
      ]}] ]]):gsub('\n', ''))
      -- Regression: NUL separator must be properly supported
      sd2strings_eq({
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  SEARCH',
        '  - contents      ""',
        '  - separator     \'\\0\'',
      }, ([[ [{'type': 4, 'timestamp': 0, 'data': [
        1,
        '',
        0x0
      ]}] ]]):gsub('\n', ''))
    end)

    it('works with register items', function()
      sd2strings_eq({
        'Register with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      }, {{type=5, timestamp=0, data={1, 2, 3}}})
      sd2strings_eq({
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: n',
        '  # Required key missing: rc',
        '  + rw   block width  0',
        '  + rt   type         CHARACTERWISE',
        '  + ru   is_unnamed   FALSE',
      }, ([[ [{'type': 5, 'timestamp': 0, 'data': {
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  # Required key missing: rc',
        '  + rw   block width  0',
        '  + rt   type         CHARACTERWISE',
        '  + ru   is_unnamed   FALSE',
      }, ([[ [{'type': 5, 'timestamp': 0, 'data': {
        'n': 0x20,
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  + rc   contents     ["abc", "def"]',
        '  + rw   block width  0',
        '  + rt   type         CHARACTERWISE',
        '  + ru   is_unnamed   FALSE',
      }, ([[ [{'type': 5, 'timestamp': 0, 'data': {
        'n': 0x20,
        'rc': ["abc", "def"],
        'ru': {'_TYPE': v:msgpack_types.boolean, '_VAL': 0},
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  + rc   contents     @',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  + rw   block width  0',
        '  + rt   type         CHARACTERWISE',
        '  + ru   is_unnamed   TRUE',
      }, ([[ [{'type': 5, 'timestamp': 0, 'data': {
        'n': 0x20,
        'rc': ['abcdefghijklmnopqrstuvwxyz', 'abcdefghijklmnopqrstuvwxyz'],
        'ru': {'_TYPE': v:msgpack_types.boolean, '_VAL': 1},
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  + rc   contents     @',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  + rw   block width  0',
        '  + rt   type         CHARACTERWISE',
        '  + ru   is_unnamed   FALSE',
      }, ([[ [{'type': 5, 'timestamp': 0, 'data': {
        'n': 0x20,
        'rc': ['abcdefghijklmnopqrstuvwxyz', 'abcdefghijklmnopqrstuvwxyz'],
        'rw': 0,
        'rt': 0,
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  + rc   contents     @',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  + rw   block width  5',
        '  + rt   type         LINEWISE',
        '  + ru   is_unnamed   FALSE',
      }, ([[ [{'type': 5, 'timestamp': 0, 'data': {
        'n': 0x20,
        'rc': ['abcdefghijklmnopqrstuvwxyz', 'abcdefghijklmnopqrstuvwxyz'],
        'rw': 5,
        'rt': 1,
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  + rc   contents     @',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  # Expected integer',
        '  + rw   block width  ""',
        '  + rt   type         BLOCKWISE',
        '  # Expected boolean',
        '  + ru   is_unnamed   ""',
      }, ([[ [{'type': 5, 'timestamp': 0, 'data': {
        'n': 0x20,
        'rc': ['abcdefghijklmnopqrstuvwxyz', 'abcdefghijklmnopqrstuvwxyz'],
        'rw': "",
        'rt': 2,
        'ru': ""
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  # Expected array value',
        '  + rc   contents     0',
        '  # Value is negative',
        '  + rw   block width  -1',
        '  # Unexpected enum value: expected one of 0 (CHARACTERWISE), '
        .. '1 (LINEWISE), 2 (BLOCKWISE)',
        '  + rt   type         10',
        '  # Expected boolean',
        '  + ru   is_unnamed   ["abc", "def"]',
      }, ([[ [{'type': 5, 'timestamp': 0, 'data': {
        'n': 0x20,
        'rc': 0,
        'rw': -1,
        'rt': 10,
        'ru': ['abc', 'def'],
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  + rc   contents     @',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  + rw   block width  5',
        '  + rt   type         LINEWISE',
        '  # Expected boolean',
        '  + ru   is_unnamed   0',
      }, ([[ [{'type': 5, 'timestamp': 0, 'data': {
        'n': 0x20,
        'rc': ['abcdefghijklmnopqrstuvwxyz', 'abcdefghijklmnopqrstuvwxyz'],
        'rw': 5,
        'rt': 1,
        'ru': 0,
      }}] ]]):gsub('\n', ''))
    end)

    it('works with variable items', function()
      sd2strings_eq({
        'Variable with timestamp ' .. epoch .. ':',
        '  # Unexpected type: map instead of array',
        '  = {="a": [10]}',
      }, {{type=6, timestamp=0, data={a={10}}}})
      sd2strings_eq({
        'Variable with timestamp ' .. epoch .. ':',
        '  @ Description  Value',
        '  # Expected more elements in list'
      }, ([[ [{'type': 6, 'timestamp': 0, 'data': [
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Variable with timestamp ' .. epoch .. ':',
        '  @ Description  Value',
        '  # Expected binary string',
        '  - name         1',
        '  # Expected more elements in list',
      }, ([[ [{'type': 6, 'timestamp': 0, 'data': [
        1
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Variable with timestamp ' .. epoch .. ':',
        '  @ Description  Value',
        '  # Expected no NUL bytes',
        '  - name         "\\0"',
        '  # Expected more elements in list',
      }, ([[ [{'type': 6, 'timestamp': 0, 'data': [
        {'_TYPE': v:msgpack_types.binary, '_VAL': ["\n"]},
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Variable with timestamp ' .. epoch .. ':',
        '  @ Description  Value',
        '  - name         "foo"',
        '  # Expected more elements in list',
      }, ([[ [{'type': 6, 'timestamp': 0, 'data': [
        {'_TYPE': v:msgpack_types.binary, '_VAL': ["foo"]},
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Variable with timestamp ' .. epoch .. ':',
        '  @ Description  Value',
        '  - name         "foo"',
        '  - value        NIL',
      }, ([[ [{'type': 6, 'timestamp': 0, 'data': [
        {'_TYPE': v:msgpack_types.binary, '_VAL': ["foo"]},
        {'_TYPE': v:msgpack_types.nil, '_VAL': ["foo"]},
      ]}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Variable with timestamp ' .. epoch .. ':',
        '  @ Description  Value',
        '  - name         "foo"',
        '  - value        NIL',
        '  -              NIL',
      }, ([[ [{'type': 6, 'timestamp': 0, 'data': [
        {'_TYPE': v:msgpack_types.binary, '_VAL': ["foo"]},
        {'_TYPE': v:msgpack_types.nil, '_VAL': ["foo"]},
        {'_TYPE': v:msgpack_types.nil, '_VAL': ["foo"]},
      ]}] ]]):gsub('\n', ''))
    end)

    it('works with global mark items', function()
      sd2strings_eq({
        'Global mark with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      }, {{type=7, timestamp=0, data={1, 2, 3}}})
      sd2strings_eq({
        'Global mark with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: n',
        '  # Required key missing: f',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 7, 'timestamp': 0, 'data': {
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Global mark with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Expected integer',
        '  + n    name         "foo"',
        '  # Required key missing: f',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 7, 'timestamp': 0, 'data': {
        'n': 'foo',
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Global mark with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: n',
        '  + f    file name    "foo"',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 7, 'timestamp': 0, 'data': {
        'f': 'foo',
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Global mark with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Value is negative',
        '  + n    name         -10',
        '  # Expected no NUL bytes',
        '  + f    file name    "\\0"',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 7, 'timestamp': 0, 'data': {
        'n': -10,
        'f': {'_TYPE': v:msgpack_types.binary, '_VAL': ["\n"]},
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Global mark with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \'\\20\'',
        '  + f    file name    "foo"',
        '  # Value is negative',
        '  + l    line number  -10',
        '  # Value is negative',
        '  + c    column       -10',
      }, ([[ [{'type': 7, 'timestamp': 0, 'data': {
        'n': 20,
        'f': 'foo',
        'l': -10,
        'c': -10,
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Global mark with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         128',
        '  + f    file name    "foo"',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 7, 'timestamp': 0, 'data': {
        'n': 128,
        'f': 'foo',
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Global mark with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \'\\20\'',
        '  + f    file name    "foo"',
        '  # Expected integer',
        '  + l    line number  "FOO"',
        '  # Expected integer',
        '  + c    column       "foo"',
        '  + mX                10',
      }, ([[ [{'type': 7, 'timestamp': 0, 'data': {
        'n': 20,
        'f': 'foo',
        'l': 'FOO',
        'c': 'foo',
        'mX': 10,
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Global mark with timestamp ' .. epoch .. ':',
        '  % Key________  Description  Value',
        '  + n            name         \'A\'',
        '  + f            file name    "foo"',
        '  + l            line number  2',
        '  + c            column       200',
        '  + mX                        10',
        '  + mYYYYYYYYYY               10',
      }, ([[ [{'type': 7, 'timestamp': 0, 'data': {
        'n': char2nr('A'),
        'f': 'foo',
        'l': 2,
        'c': 200,
        'mX': 10,
        'mYYYYYYYYYY': 10,
      }}] ]]):gsub('\n', ''))
    end)

    it('works with jump items', function()
      sd2strings_eq({
        'Jump with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      }, {{type=8, timestamp=0, data={1, 2, 3}}})
      sd2strings_eq({
        'Jump with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 8, 'timestamp': 0, 'data': {
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Jump with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  + l    line number  1',
        '  + c    column       0',
        '  # Expected integer',
        '  + n    name         "foo"',
      }, ([[ [{'type': 8, 'timestamp': 0, 'data': {
        'n': 'foo',
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Jump with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + f    file name    "foo"',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 8, 'timestamp': 0, 'data': {
        'f': 'foo',
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Jump with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Expected no NUL bytes',
        '  + f    file name    "\\0"',
        '  + l    line number  1',
        '  + c    column       0',
        '  # Value is negative',
        '  + n    name         -10',
      }, ([[ [{'type': 8, 'timestamp': 0, 'data': {
        'n': -10,
        'f': {'_TYPE': v:msgpack_types.binary, '_VAL': ["\n"]},
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Jump with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + f    file name    "foo"',
        '  # Value is negative',
        '  + l    line number  -10',
        '  # Value is negative',
        '  + c    column       -10',
      }, ([[ [{'type': 8, 'timestamp': 0, 'data': {
        'f': 'foo',
        'l': -10,
        'c': -10,
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Jump with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + f    file name    "foo"',
        '  # Expected integer',
        '  + l    line number  "FOO"',
        '  # Expected integer',
        '  + c    column       "foo"',
        '  + mX                10',
      }, ([[ [{'type': 8, 'timestamp': 0, 'data': {
        'f': 'foo',
        'l': 'FOO',
        'c': 'foo',
        'mX': 10,
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Jump with timestamp ' .. epoch .. ':',
        '  % Key________  Description  Value',
        '  + f            file name    "foo"',
        '  + l            line number  2',
        '  + c            column       200',
        '  + mX                        10',
        '  + mYYYYYYYYYY               10',
        '  + n            name         \' \'',
      }, ([[ [{'type': 8, 'timestamp': 0, 'data': {
        'n': 0x20,
        'f': 'foo',
        'l': 2,
        'c': 200,
        'mX': 10,
        'mYYYYYYYYYY': 10,
      }}] ]]):gsub('\n', ''))
    end)

    it('works with buffer list items', function()
      sd2strings_eq({
        'Buffer list with timestamp ' .. epoch .. ':',
        '  # Unexpected type: map instead of array',
        '  = {="a": [10]}',
      }, {{type=9, timestamp=0, data={a={10}}}})
      sd2strings_eq({
        'Buffer list with timestamp ' .. epoch .. ':',
        '  # Expected array of maps',
        '  = [[], []]',
      }, {{type=9, timestamp=0, data={{}, {}}}})
      sd2strings_eq({
        'Buffer list with timestamp ' .. epoch .. ':',
        '  # Expected array of maps',
        '  = [{="a": 10}, []]',
      }, {{type=9, timestamp=0, data={{a=10}, {}}}})
      sd2strings_eq({
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  + l    line number  1',
        '  + c    column       0',
        '  + a                 10',
      }, {{type=9, timestamp=0, data={{a=10}}}})
      sd2strings_eq({
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  # Expected integer',
        '  + l    line number  "10"',
        '  # Expected integer',
        '  + c    column       "10"',
        '  + a                 10',
      }, {{type=9, timestamp=0, data={{l='10', c='10', a=10}}}})
      sd2strings_eq({
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  + l    line number  10',
        '  + c    column       10',
        '  + a                 10',
      }, {{type=9, timestamp=0, data={{l=10, c=10, a=10}}}})
      sd2strings_eq({
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  # Value is negative',
        '  + l    line number  -10',
        '  # Value is negative',
        '  + c    column       -10',
      }, {{type=9, timestamp=0, data={{l=-10, c=-10}}}})
      sd2strings_eq({
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + f    file name    "abc"',
        '  + l    line number  1',
        '  + c    column       0',
      }, {{type=9, timestamp=0, data={{f='abc'}}}})
      sd2strings_eq({
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Expected binary string',
        '  + f    file name    10',
        '  + l    line number  1',
        '  + c    column       0',
        '',
        '  % Key  Description  Value',
        '  # Expected binary string',
        '  + f    file name    20',
        '  + l    line number  1',
        '  + c    column       0',
      }, {{type=9, timestamp=0, data={{f=10}, {f=20}}}})
      sd2strings_eq({
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Expected binary string',
        '  + f    file name    10',
        '  + l    line number  1',
        '  + c    column       0',
        '',
        '  % Key  Description  Value',
        '  # Expected no NUL bytes',
        '  + f    file name    "\\0"',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 9, 'timestamp': 0, 'data': [
        {'f': 10},
        {'f': {'_TYPE': v:msgpack_types.binary, '_VAL': ["\n"]}},
      ]}] ]]):gsub('\n', ''))
    end)

    it('works with local mark items', function()
      sd2strings_eq({
        'Local mark with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      }, {{type=10, timestamp=0, data={1, 2, 3}}})
      sd2strings_eq({
        'Local mark with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  + n    name         \'"\'',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 10, 'timestamp': 0, 'data': {
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Local mark with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  # Expected integer',
        '  + n    name         "foo"',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 10, 'timestamp': 0, 'data': {
        'n': 'foo',
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Local mark with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + f    file name    "foo"',
        '  + n    name         \'"\'',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 10, 'timestamp': 0, 'data': {
        'f': 'foo',
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Local mark with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Expected no NUL bytes',
        '  + f    file name    "\\0"',
        '  # Value is negative',
        '  + n    name         -10',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 10, 'timestamp': 0, 'data': {
        'n': -10,
        'f': {'_TYPE': v:msgpack_types.binary, '_VAL': ["\n"]},
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Local mark with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + f    file name    "foo"',
        '  + n    name         \'\\20\'',
        '  # Value is negative',
        '  + l    line number  -10',
        '  # Value is negative',
        '  + c    column       -10',
      }, ([[ [{'type': 10, 'timestamp': 0, 'data': {
        'n': 20,
        'f': 'foo',
        'l': -10,
        'c': -10,
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Local mark with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + f    file name    "foo"',
        '  + n    name         \'\\20\'',
        '  # Expected integer',
        '  + l    line number  "FOO"',
        '  # Expected integer',
        '  + c    column       "foo"',
        '  + mX                10',
      }, ([[ [{'type': 10, 'timestamp': 0, 'data': {
        'n': 20,
        'f': 'foo',
        'l': 'FOO',
        'c': 'foo',
        'mX': 10,
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Local mark with timestamp ' .. epoch .. ':',
        '  % Key________  Description  Value',
        '  + f            file name    "foo"',
        '  + n            name         \'a\'',
        '  + l            line number  2',
        '  + c            column       200',
        '  + mX                        10',
        '  + mYYYYYYYYYY               10',
      }, ([[ [{'type': 10, 'timestamp': 0, 'data': {
        'n': char2nr('a'),
        'f': 'foo',
        'l': 2,
        'c': 200,
        'mX': 10,
        'mYYYYYYYYYY': 10,
      }}] ]]):gsub('\n', ''))
    end)

    it('works with change items', function()
      sd2strings_eq({
        'Change with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      }, {{type=11, timestamp=0, data={1, 2, 3}}})
      sd2strings_eq({
        'Change with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 11, 'timestamp': 0, 'data': {
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Change with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  + l    line number  1',
        '  + c    column       0',
        '  # Expected integer',
        '  + n    name         "foo"',
      }, ([[ [{'type': 11, 'timestamp': 0, 'data': {
        'n': 'foo',
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Change with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + f    file name    "foo"',
        '  + l    line number  1',
        '  + c    column       0',
      }, ([[ [{'type': 11, 'timestamp': 0, 'data': {
        'f': 'foo',
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Change with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Expected no NUL bytes',
        '  + f    file name    "\\0"',
        '  + l    line number  1',
        '  + c    column       0',
        '  # Value is negative',
        '  + n    name         -10',
      }, ([[ [{'type': 11, 'timestamp': 0, 'data': {
        'n': -10,
        'f': {'_TYPE': v:msgpack_types.binary, '_VAL': ["\n"]},
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Change with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + f    file name    "foo"',
        '  # Value is negative',
        '  + l    line number  -10',
        '  # Value is negative',
        '  + c    column       -10',
      }, ([[ [{'type': 11, 'timestamp': 0, 'data': {
        'f': 'foo',
        'l': -10,
        'c': -10,
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Change with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + f    file name    "foo"',
        '  # Expected integer',
        '  + l    line number  "FOO"',
        '  # Expected integer',
        '  + c    column       "foo"',
        '  + mX                10',
      }, ([[ [{'type': 11, 'timestamp': 0, 'data': {
        'f': 'foo',
        'l': 'FOO',
        'c': 'foo',
        'mX': 10,
      }}] ]]):gsub('\n', ''))
      sd2strings_eq({
        'Change with timestamp ' .. epoch .. ':',
        '  % Key________  Description  Value',
        '  + f            file name    "foo"',
        '  + l            line number  2',
        '  + c            column       200',
        '  + mX                        10',
        '  + mYYYYYYYYYY               10',
        '  + n            name         \' \'',
      }, ([[ [{'type': 11, 'timestamp': 0, 'data': {
        'n': 0x20,
        'f': 'foo',
        'l': 2,
        'c': 200,
        'mX': 10,
        'mYYYYYYYYYY': 10,
      }}] ]]):gsub('\n', ''))
    end)
  end)

  describe('function shada#get_strings', function()
    it('works', function()
      eq({
        'Header with timestamp ' .. epoch .. ':',
        '  % Key  Value',
      }, nvim_eval('shada#get_strings(msgpackdump([1, 0, 0, {}]))'))
    end)
  end)

  describe('function shada#strings_to_sd', function()

    local strings2sd_eq = function(expected, input)
      nvim('set_var', '__input', input)
      nvim_command('let g:__actual = map(shada#strings_to_sd(g:__input), '
                        .. '"filter(v:val, \\"v:key[0] isnot# \'_\' '
                                          .. '&& v:key isnot# \'length\'\\")")')
      -- print()
      if type(expected) == 'table' then
        nvim('set_var', '__expected', expected)
        nvim_command('let g:__expected = ModifyVal(g:__expected)')
        expected = 'g:__expected'
        -- print(nvim_eval('msgpack#string(g:__expected)'))
      end
      -- print(nvim_eval('msgpack#string(g:__actual)'))
      eq(1, nvim_eval(('msgpack#equal(%s, g:__actual)'):format(expected)))
      if type(expected) == 'table' then
        nvim_command('unlet g:__expected')
      end
      nvim_command('unlet g:__input')
      nvim_command('unlet g:__actual')
    end

    it('works with multiple items', function()
      strings2sd_eq({{
        type=11, timestamp=0, data={
          f='foo',
          l=2,
          c=200,
          mX=10,
          mYYYYYYYYYY=10,
          n=(' '):byte(),
        }
      }, {
        type=1, timestamp=0, data={
          c='abc',
          f={'!binary', {'abc\ndef'}},
          l=-10,
          n=-64,
          rc='10',
          rt=10,
          sc={'!nil', 0},
          sm='TRUE',
          so='TRUE',
          sp={'!string', {'abc'}},
        }
      }}, {
        'Change with timestamp ' .. epoch .. ':',
        '  % Key________  Description  Value',
        '  + f            file name    "foo"',
        '  + l            line number  2',
        '  + c            column       200',
        '  + mX                        10',
        '  + mYYYYYYYYYY               10',
        '  + n            name         \' \'',
        'Header with timestamp ' .. epoch .. ':',
        '  % Key  Description____  Value',
        '  # Expected integer',
        '  + c    column           "abc"',
        '  # Expected no NUL bytes',
        '  + f    file name        "abc\\0def"',
        '  # Value is negative',
        '  + l    line number      -10',
        '  # Value is negative',
        '  + n    name             -64',
        '  # Expected array value',
        '  + rc   contents         "10"',
        '  # Unexpected enum value: expected one of '
         .. '0 (CHARACTERWISE), 1 (LINEWISE), 2 (BLOCKWISE)',
        '  + rt   type             10',
        '  # Expected boolean',
        '  + sc   smartcase value  NIL',
        '  # Expected boolean',
        '  + sm   magic value      "TRUE"',
        '  # Expected integer',
        '  + so   offset value     "TRUE"',
        '  # Expected binary string',
        '  + sp   pattern          ="abc"',
      })
    end)

    it('works with empty list', function()
      strings2sd_eq({}, {})
    end)

    it('works with header items', function()
      strings2sd_eq({{type=1, timestamp=0, data={
        generator='test',
      }}}, {
        'Header with timestamp ' .. epoch .. ':',
        '  % Key______  Value',
        '  + generator  "test"',
      })
      strings2sd_eq({{type=1, timestamp=0, data={
        1, 2, 3,
      }}}, {
        'Header with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      })
      strings2sd_eq({{type=1, timestamp=0, data={
        a=1, b=2, c=3, d=4,
      }}}, {
        'Header with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + a                 1',
        '  + b                 2',
        '  + c    column       3',
        '  + d                 4',
      })
      strings2sd_eq({{type=1, timestamp=0, data={
        c='abc',
        f={'!binary', {'abc\ndef'}},
        l=-10,
        n=-64,
        rc='10',
        rt=10,
        sc={'!nil', 0},
        sm='TRUE',
        so='TRUE',
        sp={'!string', {'abc'}},
      }}}, {
        'Header with timestamp ' .. epoch .. ':',
        '  % Key  Description____  Value',
        '  # Expected integer',
        '  + c    column           "abc"',
        '  # Expected no NUL bytes',
        '  + f    file name        "abc\\0def"',
        '  # Value is negative',
        '  + l    line number      -10',
        '  # Value is negative',
        '  + n    name             -64',
        '  # Expected array value',
        '  + rc   contents         "10"',
        '  # Unexpected enum value: expected one of '
         .. '0 (CHARACTERWISE), 1 (LINEWISE), 2 (BLOCKWISE)',
        '  + rt   type             10',
        '  # Expected boolean',
        '  + sc   smartcase value  NIL',
        '  # Expected boolean',
        '  + sm   magic value      "TRUE"',
        '  # Expected integer',
        '  + so   offset value     "TRUE"',
        '  # Expected binary string',
        '  + sp   pattern          ="abc"',
      })
    end)

    it('works with search pattern items', function()
      strings2sd_eq({{type=2, timestamp=0, data={
        1, 2, 3
      }}}, {
        'Search pattern with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      })
      strings2sd_eq({{type=2, timestamp=0, data={
        sp='abc',
      }}}, {
        'Search pattern with timestamp ' .. epoch .. ':',
        '  % Key  Description________  Value',
        '  + sp   pattern              "abc"',
        '  + sh   v:hlsearch value     FALSE',
        '  + ss   is :s pattern        FALSE',
        '  + sm   magic value          TRUE',
        '  + sc   smartcase value      FALSE',
        '  + sl   has line offset      FALSE',
        '  + se   place cursor at end  FALSE',
        '  + so   offset value         0',
        '  + su   is last used         TRUE',
      })
      strings2sd_eq({{type=2, timestamp=0, data={
        sp='abc',
        sX={'!nil', 0},
        sY={'!nil', 0},
        sZ={'!nil', 0},
      }}}, {
        'Search pattern with timestamp ' .. epoch .. ':',
        '  % Key  Description________  Value',
        '  + sp   pattern              "abc"',
        '  + sh   v:hlsearch value     FALSE',
        '  + ss   is :s pattern        FALSE',
        '  + sm   magic value          TRUE',
        '  + sc   smartcase value      FALSE',
        '  + sl   has line offset      FALSE',
        '  + se   place cursor at end  FALSE',
        '  + so   offset value         0',
        '  + su   is last used         TRUE',
        '  + sX                        NIL',
        '  + sY                        NIL',
        '  + sZ                        NIL',
      })
      strings2sd_eq({{type=2, timestamp=0, data={'!map', {
      }}}}, {
        'Search pattern with timestamp ' .. epoch .. ':',
        '  % Key  Description________  Value',
        '  # Required key missing: sp',
        '  + sh   v:hlsearch value     FALSE',
        '  + ss   is :s pattern        FALSE',
        '  + sm   magic value          TRUE',
        '  + sc   smartcase value      FALSE',
        '  + sl   has line offset      FALSE',
        '  + se   place cursor at end  FALSE',
        '  + so   offset value         0',
        '  + su   is last used         TRUE',
      })
      strings2sd_eq({{type=2, timestamp=0, data={
        sp='',
        sh={'!boolean', 1},
        ss={'!boolean', 1},
        sc={'!boolean', 1},
        sl={'!boolean', 1},
        se={'!boolean', 1},
        sm={'!boolean', 0},
        su={'!boolean', 0},
        so=-10,
      }}}, {
        'Search pattern with timestamp ' .. epoch .. ':',
        '  % Key  Description________  Value',
        '  + sp   pattern              ""',
        '  + sh   v:hlsearch value     TRUE',
        '  + ss   is :s pattern        TRUE',
        '  + sm   magic value          FALSE',
        '  + sc   smartcase value      TRUE',
        '  + sl   has line offset      TRUE',
        '  + se   place cursor at end  TRUE',
        '  + so   offset value         -10',
        '  + su   is last used         FALSE',
      })
      strings2sd_eq({{type=2, timestamp=0, data={
        sp=0,
        sh=0,
        ss=0,
        sc=0,
        sl=0,
        se=0,
        sm=0,
        su=0,
        so='',
      }}}, {
        'Search pattern with timestamp ' .. epoch .. ':',
        '  % Key  Description________  Value',
        '  # Expected binary string',
        '  + sp   pattern              0',
        '  # Expected boolean',
        '  + sh   v:hlsearch value     0',
        '  # Expected boolean',
        '  + ss   is :s pattern        0',
        '  # Expected boolean',
        '  + sm   magic value          0',
        '  # Expected boolean',
        '  + sc   smartcase value      0',
        '  # Expected boolean',
        '  + sl   has line offset      0',
        '  # Expected boolean',
        '  + se   place cursor at end  0',
        '  # Expected integer',
        '  + so   offset value         ""',
        '  # Expected boolean',
        '  + su   is last used         0',
      })
    end)

    it('works with replacement string items', function()
      strings2sd_eq({{type=3, timestamp=0, data={
        a={10}
      }}}, {
        'Replacement string with timestamp ' .. epoch .. ':',
        '  # Unexpected type: map instead of array',
        '  = {="a": [10]}',
      })
      strings2sd_eq({{type=3, timestamp=0, data={
      }}}, {
        'Replacement string with timestamp ' .. epoch .. ':',
        '  @ Description__________  Value',
        '  # Expected more elements in list'
      })
      strings2sd_eq({{type=3, timestamp=0, data={
        0
      }}}, {
        'Replacement string with timestamp ' .. epoch .. ':',
        '  @ Description__________  Value',
        '  # Expected binary string',
        '  - :s replacement string  0',
      })
      strings2sd_eq({{type=3, timestamp=0, data={
        'abc\ndef', 0,
      }}}, {
        'Replacement string with timestamp ' .. epoch .. ':',
        '  @ Description__________  Value',
        '  - :s replacement string  "abc\\ndef"',
        '  -                        0',
      })
      strings2sd_eq({{type=3, timestamp=0, data={
        'abc\ndef',
      }}}, {
        'Replacement string with timestamp ' .. epoch .. ':',
        '  @ Description__________  Value',
        '  - :s replacement string  "abc\\ndef"',
      })
    end)

    it('works with history entry items', function()
      strings2sd_eq({{type=4, timestamp=0, data={
        a={10},
      }}}, {
        'History entry with timestamp ' .. epoch .. ':',
        '  # Unexpected type: map instead of array',
        '  = {="a": [10]}',
      })
      strings2sd_eq({{type=4, timestamp=0, data={
      }}}, {
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  # Expected more elements in list'
      })
      strings2sd_eq({{type=4, timestamp=0, data={
        '',
      }}}, {
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  # Expected integer',
        '  - history type  ""',
        '  # Expected more elements in list'
      })
      strings2sd_eq({{type=4, timestamp=0, data={
        5, '',
      }}}, {
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  # Unexpected enum value: expected one of 0 (CMD), 1 (SEARCH), '
            .. '2 (EXPR), 3 (INPUT), 4 (DEBUG)',
        '  - history type  5',
        '  - contents      ""',
      })
      strings2sd_eq({{type=4, timestamp=0, data={
        5, '', 32,
      }}}, {
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  # Unexpected enum value: expected one of 0 (CMD), 1 (SEARCH), '
            .. '2 (EXPR), 3 (INPUT), 4 (DEBUG)',
        '  - history type  5',
        '  - contents      ""',
        '  -               32',
      })
      strings2sd_eq({{type=4, timestamp=0, data={
        0, '', 32,
      }}}, {
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  CMD',
        '  - contents      ""',
        '  -               32',
      })
      strings2sd_eq({{type=4, timestamp=0, data={
        1, '', 32,
      }}}, {
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  SEARCH',
        '  - contents      ""',
        '  - separator     \' \'',
      })
      strings2sd_eq({{type=4, timestamp=0, data={
        1, '',
      }}}, {
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  SEARCH',
        '  - contents      ""',
        '  # Expected more elements in list',
      })
      strings2sd_eq({{type=4, timestamp=0, data={
        2, '',
      }}}, {
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  EXPR',
        '  - contents      ""',
      })
      strings2sd_eq({{type=4, timestamp=0, data={
        3, ''
      }}}, {
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  INPUT',
        '  - contents      ""',
      })
      strings2sd_eq({{type=4, timestamp=0, data={
        4, ''
      }}}, {
        'History entry with timestamp ' .. epoch .. ':',
        '  @ Description_  Value',
        '  - history type  DEBUG',
        '  - contents      ""',
      })
    end)

    it('works with register items', function()
      strings2sd_eq({{type=5, timestamp=0, data={
        1, 2, 3
      }}}, {
        'Register with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      })
      strings2sd_eq({{type=5, timestamp=0, data={'!map', {
      }}}}, {
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: n',
        '  # Required key missing: rc',
        '  + rw   block width  0',
        '  + rt   type         CHARACTERWISE',
      })
      strings2sd_eq({{type=5, timestamp=0, data={
        n=(' '):byte()
      }}}, {
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  # Required key missing: rc',
        '  + rw   block width  0',
        '  + rt   type         CHARACTERWISE',
      })
      strings2sd_eq({{type=5, timestamp=0, data={
        n=(' '):byte(), rc={'abc', 'def'}
      }}}, {
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  + rc   contents     ["abc", "def"]',
        '  + rw   block width  0',
        '  + rt   type         CHARACTERWISE',
      })
      strings2sd_eq({{type=5, timestamp=0, data={
        n=(' '):byte(),
        rc={'abcdefghijklmnopqrstuvwxyz', 'abcdefghijklmnopqrstuvwxyz'},
      }}}, {
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  + rc   contents     @',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  + rw   block width  0',
        '  + rt   type         CHARACTERWISE',
      })
      strings2sd_eq({{type=5, timestamp=0, data={
        n=(' '):byte(),
        rc={'abcdefghijklmnopqrstuvwxyz', 'abcdefghijklmnopqrstuvwxyz'},
        rw=5,
        rt=1,
      }}}, {
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  + rc   contents     @',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  + rw   block width  5',
        '  + rt   type         LINEWISE',
      })
      strings2sd_eq({{type=5, timestamp=0, data={
        n=(' '):byte(),
        rc={'abcdefghijklmnopqrstuvwxyz', 'abcdefghijklmnopqrstuvwxyz'},
        rw=5,
        rt=2,
      }}}, {
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  + rc   contents     @',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  | - "abcdefghijklmnopqrstuvwxyz"',
        '  + rw   block width  5',
        '  + rt   type         BLOCKWISE',
      })
      strings2sd_eq({{type=5, timestamp=0, data={
        n=(' '):byte(),
        rc=0,
        rw=-1,
        rt=10,
      }}}, {
        'Register with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + n    name         \' \'',
        '  # Expected array value',
        '  + rc   contents     0',
        '  # Value is negative',
        '  + rw   block width  -1',
        '  # Unexpected enum value: expected one of 0 (CHARACTERWISE), '
        .. '1 (LINEWISE), 2 (BLOCKWISE)',
        '  + rt   type         10',
      })
    end)

    it('works with variable items', function()
      strings2sd_eq({{type=6, timestamp=0, data={
        a={10}
      }}}, {
        'Variable with timestamp ' .. epoch .. ':',
        '  # Unexpected type: map instead of array',
        '  = {="a": [10]}',
      })
      strings2sd_eq({{type=6, timestamp=0, data={
      }}}, {
        'Variable with timestamp ' .. epoch .. ':',
        '  @ Description  Value',
        '  # Expected more elements in list'
      })
      strings2sd_eq({{type=6, timestamp=0, data={
        'foo',
      }}}, {
        'Variable with timestamp ' .. epoch .. ':',
        '  @ Description  Value',
        '  - name         "foo"',
        '  # Expected more elements in list',
      })
      strings2sd_eq({{type=6, timestamp=0, data={
        'foo', {'!nil', 0},
      }}}, {
        'Variable with timestamp ' .. epoch .. ':',
        '  @ Description  Value',
        '  - name         "foo"',
        '  - value        NIL',
      })
      strings2sd_eq({{type=6, timestamp=0, data={
        'foo', {'!nil', 0}, {'!nil', 0}
      }}}, {
        'Variable with timestamp ' .. epoch .. ':',
        '  @ Description  Value',
        '  - name         "foo"',
        '  - value        NIL',
        '  -              NIL',
      })
    end)

    it('works with global mark items', function()
      strings2sd_eq({{type=7, timestamp=0, data={
        1, 2, 3
      }}}, {
        'Global mark with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      })
      strings2sd_eq({{type=7, timestamp=0, data={
        n=('A'):byte(), f='foo', l=2, c=200, mX=10, mYYYYYYYYYY=10,
      }}}, {
        'Global mark with timestamp ' .. epoch .. ':',
        '  % Key________  Description  Value',
        '  + n            name         \'A\'',
        '  + f            file name    "foo"',
        '  + l            line number  2',
        '  + c            column       200',
        '  + mX                        10',
        '  + mYYYYYYYYYY               10',
      })
    end)

    it('works with jump items', function()
      strings2sd_eq({{type=8, timestamp=0, data={
        1, 2, 3
      }}}, {
        'Jump with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      })
      strings2sd_eq({{type=8, timestamp=0, data={
        n=('A'):byte(), f='foo', l=2, c=200, mX=10, mYYYYYYYYYY=10,
      }}}, {
        'Jump with timestamp ' .. epoch .. ':',
        '  % Key________  Description  Value',
        '  + n            name         \'A\'',
        '  + f            file name    "foo"',
        '  + l            line number  2',
        '  + c            column       200',
        '  + mX                        10',
        '  + mYYYYYYYYYY               10',
      })
    end)

    it('works with buffer list items', function()
      strings2sd_eq({{type=9, timestamp=0, data={
        a={10}
      }}}, {
        'Buffer list with timestamp ' .. epoch .. ':',
        '  # Unexpected type: map instead of array',
        '  = {="a": [10]}',
      })
      strings2sd_eq({{type=9, timestamp=0, data={
        {a=10}, {}
      }}}, {
        'Buffer list with timestamp ' .. epoch .. ':',
        '  # Expected array of maps',
        '  = [{="a": 10}, []]',
      })
      strings2sd_eq({{type=9, timestamp=0, data={
        {a=10},
      }}}, {
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  + l    line number  1',
        '  + c    column       0',
        '  + a                 10',
      })
      strings2sd_eq({{type=9, timestamp=0, data={
        {l='10', c='10', a=10},
      }}}, {
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  # Expected integer',
        '  + l    line number  "10"',
        '  # Expected integer',
        '  + c    column       "10"',
        '  + a                 10',
      })
      strings2sd_eq({{type=9, timestamp=0, data={
        {l=10, c=10, a=10},
      }}}, {
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  + l    line number  10',
        '  + c    column       10',
        '  + a                 10',
      })
      strings2sd_eq({{type=9, timestamp=0, data={
        {l=-10, c=-10},
      }}}, {
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Required key missing: f',
        '  # Value is negative',
        '  + l    line number  -10',
        '  # Value is negative',
        '  + c    column       -10',
      })
      strings2sd_eq({{type=9, timestamp=0, data={
        {f='abc'},
      }}}, {
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  + f    file name    "abc"',
        '  + l    line number  1',
        '  + c    column       0',
      })
      strings2sd_eq({{type=9, timestamp=0, data={
        {f=10}, {f=20},
      }}}, {
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Expected binary string',
        '  + f    file name    \'\\10\'',
        '  + l    line number  1',
        '  + c    column       0',
        '',
        '  % Key  Description  Value',
        '  # Expected binary string',
        '  + f    file name    \'\\20\'',
        '  + l    line number  1',
        '  + c    column       0',
      })
      strings2sd_eq({{type=9, timestamp=0, data={
        {f=10}, {f={'!binary', {'\n'}}},
      }}}, {
        'Buffer list with timestamp ' .. epoch .. ':',
        '  % Key  Description  Value',
        '  # Expected binary string',
        '  + f    file name    \'\\10\'',
        '  + l    line number  1',
        '  + c    column       0',
        '',
        '  % Key  Description  Value',
        '  # Expected no NUL bytes',
        '  + f    file name    "\\0"',
        '  + l    line number  1',
        '  + c    column       0',
      })
    end)

    it('works with local mark items', function()
      strings2sd_eq({{type=10, timestamp=0, data={
        1, 2, 3
      }}}, {
        'Local mark with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      })
      strings2sd_eq({{type=10, timestamp=0, data={
        n=('A'):byte(), f='foo', l=2, c=200, mX=10, mYYYYYYYYYY=10,
      }}}, {
        'Local mark with timestamp ' .. epoch .. ':',
        '  % Key________  Description  Value',
        '  + n            name         \'A\'',
        '  + f            file name    "foo"',
        '  + l            line number  2',
        '  + c            column       200',
        '  + mX                        10',
        '  + mYYYYYYYYYY               10',
      })
    end)

    it('works with change items', function()
      strings2sd_eq({{type=11, timestamp=0, data={
        1, 2, 3
      }}}, {
        'Change with timestamp ' .. epoch .. ':',
        '  # Unexpected type: array instead of map',
        '  = [1, 2, 3]',
      })
      strings2sd_eq({{type=11, timestamp=0, data={
        n=('A'):byte(), f='foo', l=2, c=200, mX=10, mYYYYYYYYYY=10,
      }}}, {
        'Change with timestamp ' .. epoch .. ':',
        '  % Key________  Description  Value',
        '  + n            name         \'A\'',
        '  + f            file name    "foo"',
        '  + l            line number  2',
        '  + c            column       200',
        '  + mX                        10',
        '  + mYYYYYYYYYY               10',
      })
    end)
  end)

  describe('function shada#get_binstrings', function()
    local getbstrings_eq = function(expected, input)
      local result = funcs['shada#get_binstrings'](input)
      for i, s in ipairs(result) do
        result[i] = s:gsub('\n', '\0')
      end
      local mpack_result = table.concat(result, '\n')
      return mpack_eq(expected, mpack_result)
    end

    it('works', function()
      local version = nvim('get_vvar', 'version')
      getbstrings_eq({{timestamp='current', type=1, value={
        generator='shada.vim',
        version=version,
      }}}, {})
      getbstrings_eq({
        {timestamp='current', type=1, value={
          generator='shada.vim', version=version
        }},
        {timestamp=0, type=1, value={generator='test'}}
      }, {
        'Header with timestamp ' .. epoch .. ':',
        '  % Key______  Value',
        '  + generator  "test"',
      })
      nvim('set_var', 'shada#add_own_header', 1)
      getbstrings_eq({{timestamp='current', type=1, value={
        generator='shada.vim',
        version=version,
      }}}, {})
      getbstrings_eq({
        {timestamp='current', type=1, value={
          generator='shada.vim', version=version
        }},
        {timestamp=0, type=1, value={generator='test'}}
      }, {
        'Header with timestamp ' .. epoch .. ':',
        '  % Key______  Value',
        '  + generator  "test"',
      })
      nvim('set_var', 'shada#add_own_header', 0)
      getbstrings_eq({}, {})
      getbstrings_eq({{timestamp=0, type=1, value={generator='test'}}}, {
        'Header with timestamp ' .. epoch .. ':',
        '  % Key______  Value',
        '  + generator  "test"',
      })
      nvim('set_var', 'shada#keep_old_header', 0)
      getbstrings_eq({}, {
        'Header with timestamp ' .. epoch .. ':',
        '  % Key______  Value',
        '  + generator  "test"',
      })
      getbstrings_eq({
        {type=3, timestamp=0, value={'abc\ndef'}},
        {type=3, timestamp=0, value={'abc\ndef'}},
        {type=3, timestamp=0, value={'abc\ndef'}},
      }, {
        'Replacement string with timestamp ' .. epoch .. ':',
        '  @ Description__________  Value',
        '  - :s replacement string  "abc\\ndef"',
        'Replacement string with timestamp ' .. epoch .. ':',
        '  @ Description__________  Value',
        '  - :s replacement string  "abc\\ndef"',
        'Replacement string with timestamp ' .. epoch .. ':',
        '  @ Description__________  Value',
        '  - :s replacement string  "abc\\ndef"',
      })
    end)
  end)
end)

describe('plugin/shada.vim', function()
  local epoch = os.date('%Y-%m-%dT%H:%M:%S', 0)
  local eol = helpers.iswin() and '\r\n' or '\n'
  before_each(function()
    -- Note: reset() is called explicitly in each test.
    os.remove(fname)
    os.remove(fname .. '.tst')
    os.remove(fname_tmp)
  end)

  teardown(function()
    os.remove(fname)
    os.remove(fname_tmp)
  end)

  local shada_eq = function(expected, fname_)
    local mpack_result = read_file(fname_)
    mpack_eq(expected, mpack_result)
  end

  it('event BufReadCmd', function()
    reset()
    wshada('\004\000\009\147\000\196\002ab\196\001a')
    wshada_tmp('\004\000\009\147\000\196\002ab\196\001b')
    nvim_command('edit ' .. fname)
    eq({
      'History entry with timestamp ' .. epoch .. ':',
      '  @ Description_  Value',
      '  - history type  CMD',
      '  - contents      "ab"',
      '  -               "a"',
    }, nvim_eval('getline(1, "$")'))
    eq(false, curbuf('get_option', 'modified'))
    eq('shada', curbuf('get_option', 'filetype'))
    nvim_command('edit ' .. fname_tmp)
    eq({
      'History entry with timestamp ' .. epoch .. ':',
      '  @ Description_  Value',
      '  - history type  CMD',
      '  - contents      "ab"',
      '  -               "b"',
    }, nvim_eval('getline(1, "$")'))
    eq(false, curbuf('get_option', 'modified'))
    eq('shada', curbuf('get_option', 'filetype'))
    eq('++opt not supported', exc_exec('edit ++enc=latin1 ' .. fname))
    neq({
      'History entry with timestamp ' .. epoch .. ':',
      '  @ Description_  Value',
      '  - history type  CMD',
      '  - contents      "ab"',
      '  -               "a"',
    }, nvim_eval('getline(1, "$")'))
    neq(true, curbuf('get_option', 'modified'))
  end)

  it('event FileReadCmd', function()
    reset()
    wshada('\004\000\009\147\000\196\002ab\196\001a')
    wshada_tmp('\004\000\009\147\000\196\002ab\196\001b')
    nvim_command('$read ' .. fname)
    eq({
      '',
      'History entry with timestamp ' .. epoch .. ':',
      '  @ Description_  Value',
      '  - history type  CMD',
      '  - contents      "ab"',
      '  -               "a"',
    }, nvim_eval('getline(1, "$")'))
    eq(true, curbuf('get_option', 'modified'))
    neq('shada', curbuf('get_option', 'filetype'))
    nvim_command('1,$read ' .. fname_tmp)
    eq({
      '',
      'History entry with timestamp ' .. epoch .. ':',
      '  @ Description_  Value',
      '  - history type  CMD',
      '  - contents      "ab"',
      '  -               "a"',
      'History entry with timestamp ' .. epoch .. ':',
      '  @ Description_  Value',
      '  - history type  CMD',
      '  - contents      "ab"',
      '  -               "b"',
    }, nvim_eval('getline(1, "$")'))
    eq(true, curbuf('get_option', 'modified'))
    neq('shada', curbuf('get_option', 'filetype'))
    curbuf('set_option', 'modified', false)
    eq('++opt not supported', exc_exec('$read ++enc=latin1 ' .. fname))
    eq({
      '',
      'History entry with timestamp ' .. epoch .. ':',
      '  @ Description_  Value',
      '  - history type  CMD',
      '  - contents      "ab"',
      '  -               "a"',
      'History entry with timestamp ' .. epoch .. ':',
      '  @ Description_  Value',
      '  - history type  CMD',
      '  - contents      "ab"',
      '  -               "b"',
    }, nvim_eval('getline(1, "$")'))
    neq(true, curbuf('get_option', 'modified'))
  end)

  it('event BufWriteCmd', function()
    reset()
    nvim('set_var', 'shada#add_own_header', 0)
    curbuf('set_lines', 0, 1, true, {
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
      '  + f            file name    ["foo"]',
      '  + l            line number  2',
      '  + c            column       -200',
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
      '  + f            file name    ["foo"]',
      '  + l            line number  2',
      '  + c            column       -200',
    })
    nvim_command('w ' .. fname .. '.tst')
    nvim_command('w ' .. fname)
    nvim_command('w ' .. fname_tmp)
    eq('++opt not supported', exc_exec('w! ++enc=latin1 ' .. fname))
    eq(table.concat({
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
      '  + f            file name    ["foo"]',
      '  + l            line number  2',
      '  + c            column       -200',
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
      '  + f            file name    ["foo"]',
      '  + l            line number  2',
      '  + c            column       -200',
    }, eol) .. eol, read_file(fname .. '.tst'))
    shada_eq({{
      timestamp=0,
      type=8,
      value={c=-200, f={'foo'}, l=2, n=('A'):byte()},
    }, {
      timestamp=0,
      type=8,
      value={c=-200, f={'foo'}, l=2, n=('A'):byte()},
    }}, fname)
    shada_eq({{
      timestamp=0,
      type=8,
      value={c=-200, f={'foo'}, l=2, n=('A'):byte()},
    }, {
      timestamp=0,
      type=8,
      value={c=-200, f={'foo'}, l=2, n=('A'):byte()},
    }}, fname_tmp)
  end)

  it('event FileWriteCmd', function()
    reset()
    nvim('set_var', 'shada#add_own_header', 0)
    curbuf('set_lines', 0, 1, true, {
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
      '  + f            file name    ["foo"]',
      '  + l            line number  2',
      '  + c            column       -200',
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
      '  + f            file name    ["foo"]',
      '  + l            line number  2',
      '  + c            column       -200',
    })
    nvim_command('1,3w ' .. fname .. '.tst')
    nvim_command('1,3w ' .. fname)
    nvim_command('1,3w ' .. fname_tmp)
    eq('++opt not supported', exc_exec('1,3w! ++enc=latin1 ' .. fname))
    eq(table.concat({
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
    }, eol) .. eol, read_file(fname .. '.tst'))
    shada_eq({{
      timestamp=0,
      type=8,
      value={n=('A'):byte()},
    }}, fname)
    shada_eq({{
      timestamp=0,
      type=8,
      value={n=('A'):byte()},
    }}, fname_tmp)
  end)

  it('event FileAppendCmd', function()
    reset()
    nvim('set_var', 'shada#add_own_header', 0)
    curbuf('set_lines', 0, 1, true, {
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
      '  + f            file name    ["foo"]',
      '  + l            line number  2',
      '  + c            column       -200',
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
      '  + f            file name    ["foo"]',
      '  + l            line number  2',
      '  + c            column       -200',
    })
    funcs.writefile({''}, fname .. '.tst', 'b')
    funcs.writefile({''}, fname, 'b')
    funcs.writefile({''}, fname_tmp, 'b')
    nvim_command('1,3w >> ' .. fname .. '.tst')
    nvim_command('1,3w >> ' .. fname)
    nvim_command('1,3w >> ' .. fname_tmp)
    nvim_command('w >> ' .. fname .. '.tst')
    nvim_command('w >> ' .. fname)
    nvim_command('w >> ' .. fname_tmp)
    eq('++opt not supported', exc_exec('1,3w! ++enc=latin1 >> ' .. fname))
    eq(table.concat({
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
      '  + f            file name    ["foo"]',
      '  + l            line number  2',
      '  + c            column       -200',
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
      '  + f            file name    ["foo"]',
      '  + l            line number  2',
      '  + c            column       -200',
    }, eol) .. eol, read_file(fname .. '.tst'))
    shada_eq({{
      timestamp=0,
      type=8,
      value={n=('A'):byte()},
    }, {
      timestamp=0,
      type=8,
      value={c=-200, f={'foo'}, l=2, n=('A'):byte()},
    }, {
      timestamp=0,
      type=8,
      value={c=-200, f={'foo'}, l=2, n=('A'):byte()},
    }}, fname)
    shada_eq({{
      timestamp=0,
      type=8,
      value={n=('A'):byte()},
    }, {
      timestamp=0,
      type=8,
      value={c=-200, f={'foo'}, l=2, n=('A'):byte()},
    }, {
      timestamp=0,
      type=8,
      value={c=-200, f={'foo'}, l=2, n=('A'):byte()},
    }}, fname_tmp)
  end)

  it('event SourceCmd', function()
    reset(fname)
    wshada('\004\000\006\146\000\196\002ab')
    wshada_tmp('\004\001\006\146\000\196\002bc')
    eq(0, exc_exec('source ' .. fname))
    eq(0, exc_exec('source ' .. fname_tmp))
    eq('bc', funcs.histget(':', -1))
    eq('ab', funcs.histget(':', -2))
  end)
end)

describe('ftplugin/shada.vim', function()
  local epoch = os.date('%Y-%m-%dT%H:%M:%S', 0)
  before_each(reset)

  it('sets indentexpr correctly', function()
    nvim_command('filetype plugin indent on')
    nvim_command('setlocal filetype=shada')
    funcs.setline(1, {
      'Jump with timestamp ' .. epoch .. ':',
      '% Key________  Description  Value',
      '+ n            name         \'A\'',
      '+ f            file name    "foo"',
      '+ l            line number  2',
      '+ c            column       200',
      '+ mX                        10',
      '+ mYYYYYYYYYY               10',
      'Register with timestamp ' .. epoch .. ':',
      '% Key  Description  Value',
      '+ n    name         \' \'',
      '+ rc   contents     @',
      '| - "abcdefghijklmnopqrstuvwxyz"',
      '| - "abcdefghijklmnopqrstuvwxyz"',
      '+ rw   block width  0',
      '+ rt   type         CHARACTERWISE',
      'Replacement string with timestamp ' .. epoch .. ':',
      '    @ Description__________  Value',
      '    - :s replacement string  "abc\\ndef"',
      '   Buffer list with timestamp ' .. epoch .. ':',
      '    # Expected array of maps',
      '= [{="a": 10}, []]',
      '    Buffer list with timestamp ' .. epoch .. ':',
      '   % Key  Description  Value',
      '  # Expected binary string',
      '+ f    file name    10',
      ' + l    line number  1',
      '   + c    column       0',
      '',
      ' % Key  Description  Value',
      '    # Expected binary string',
      ' + f    file name    20',
      '+ l    line number  1',
      '    + c    column       0',
    })
    nvim_command('normal! gg=G')
    eq({
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
      '  + f            file name    "foo"',
      '  + l            line number  2',
      '  + c            column       200',
      '  + mX                        10',
      '  + mYYYYYYYYYY               10',
      'Register with timestamp ' .. epoch .. ':',
      '  % Key  Description  Value',
      '  + n    name         \' \'',
      '  + rc   contents     @',
      '  | - "abcdefghijklmnopqrstuvwxyz"',
      '  | - "abcdefghijklmnopqrstuvwxyz"',
      '  + rw   block width  0',
      '  + rt   type         CHARACTERWISE',
      'Replacement string with timestamp ' .. epoch .. ':',
      '  @ Description__________  Value',
      '  - :s replacement string  "abc\\ndef"',
      'Buffer list with timestamp ' .. epoch .. ':',
      '  # Expected array of maps',
      '  = [{="a": 10}, []]',
      'Buffer list with timestamp ' .. epoch .. ':',
      '  % Key  Description  Value',
      '  # Expected binary string',
      '  + f    file name    10',
      '  + l    line number  1',
      '  + c    column       0',
      '',
      '  % Key  Description  Value',
      '  # Expected binary string',
      '  + f    file name    20',
      '  + l    line number  1',
      '  + c    column       0',
    }, funcs.getline(1, funcs.line('$')))
  end)

  it('sets options correctly', function()
    nvim_command('filetype plugin indent on')
    nvim_command('setlocal filetype=shada')
    eq(true, curbuf('get_option', 'expandtab'))
    eq(2, curbuf('get_option', 'tabstop'))
    eq(2, curbuf('get_option', 'softtabstop'))
    eq(2, curbuf('get_option', 'shiftwidth'))
  end)

  it('sets indentkeys correctly', function()
    nvim_command('filetype plugin indent on')
    nvim_command('setlocal filetype=shada')
    funcs.setline(1, '  Replacement with timestamp ' .. epoch)
    nvim_feed('ggA:\027')
    eq('Replacement with timestamp ' .. epoch .. ':', curbuf('get_lines', 0, 1, true)[1])
    nvim_feed('o-\027')
    eq({'  -'}, curbuf('get_lines', 1, 2, true))
    nvim_feed('ggO+\027')
    eq({'+'}, curbuf('get_lines', 0, 1, true))
    nvim_feed('GO*\027')
    eq({'  *'}, curbuf('get_lines', 2, 3, true))
    nvim_feed('ggO  /\027')
    eq({'  /'}, curbuf('get_lines', 0, 1, true))
    nvim_feed('ggOx\027')
    eq({'x'}, curbuf('get_lines', 0, 1, true))
  end)
end)

describe('syntax/shada.vim', function()
  local epoch = os.date('%Y-%m-%dT%H:%M:%S', 0)
  before_each(reset)

  it('works', function()
    nvim_command('syntax on')
    nvim_command('setlocal syntax=shada')
    nvim_command('set laststatus&')
    curbuf('set_lines', 0, 1, true, {
      'Header with timestamp ' .. epoch .. ':',
      '  % Key  Value',
      '  + t    "test"',
      'Jump with timestamp ' .. epoch .. ':',
      '  % Key________  Description  Value',
      '  + n            name         \'A\'',
      '  + f            file name    ["foo"]',
      '  + l            line number  2',
      '  + c            column       -200',
      'Register with timestamp ' .. epoch .. ':',
      '  % Key  Description  Value',
      '  + rc   contents     @',
      '  | - {"abcdefghijklmnopqrstuvwxyz": 1.0}',
      '  + rt   type         CHARACTERWISE',
      '  + rt   type         LINEWISE',
      '  + rt   type         BLOCKWISE',
      'Replacement string with timestamp ' .. epoch .. ':',
      '  @ Description__________  Value',
      '  - :s replacement string  CMD',
      '  - :s replacement string  SEARCH',
      '  - :s replacement string  EXPR',
      '  - :s replacement string  INPUT',
      '  - :s replacement string  DEBUG',
      'Buffer list with timestamp ' .. epoch .. ':',
      '  # Expected array of maps',
      '  = [{="a": +(10)"ac\\0df\\ngi\\"tt\\.", TRUE: FALSE}, [NIL, +(-10)""]]',
      'Buffer list with timestamp ' .. epoch .. ':',
      '  % Key  Description  Value',
      '',
      '  % Key  Description  Value',
      'Header with timestamp ' .. epoch .. ':',
      '  % Key  Description________  Value',
      '  + se   place cursor at end  TRUE',
    })
    nvim_command([[
      function GetSyntax()
        let lines = []
        for l in range(1, line('$'))
          let columns = []
          let line = getline(l)
          for c in range(1, col([l, '$']) - 1)
            let synstack = map(synstack(l, c), 'synIDattr(v:val, "name")')
            if !empty(columns) && columns[-1][0] ==# synstack
              let columns[-1][1] .= line[c - 1]
            else
              call add(columns, [ synstack, line[c - 1] ])
            endif
          endfor
          call add(lines, columns)
        endfor
        return lines
      endfunction
    ]])
    local hname = function(s) return {{'ShaDaEntryHeader', 'ShaDaEntryName'},
                                      s} end
    local h = function(s) return {{'ShaDaEntryHeader'}, s} end
    local htsnum = function(s) return {
      {'ShaDaEntryHeader', 'ShaDaEntryTimestamp', 'ShaDaEntryTimestampNumber'},
      s
    } end
    local synhtssep = function(s)
      return {{'ShaDaEntryHeader', 'ShaDaEntryTimestamp'}, s}
    end
    local synepoch = {
      year = htsnum(os.date('%Y', 0)),
      month = htsnum(os.date('%m', 0)),
      day = htsnum(os.date('%d', 0)),
      hour = htsnum(os.date('%H', 0)),
      minute = htsnum(os.date('%M', 0)),
      second = htsnum(os.date('%S', 0)),
    }
    local msh = function(s) return {{'ShaDaEntryMapShort',
                                     'ShaDaEntryMapHeader'}, s} end
    local mlh = function(s) return {{'ShaDaEntryMapLong',
                                     'ShaDaEntryMapHeader'}, s} end
    local ah = function(s) return {{'ShaDaEntryArray',
                                    'ShaDaEntryArrayHeader'}, s} end
    -- luacheck: ignore
    local mses = function(s) return {{'ShaDaEntryMapShort',
                                      'ShaDaEntryMapShortEntryStart'}, s} end
    local mles = function(s) return {{'ShaDaEntryMapLong',
                                      'ShaDaEntryMapLongEntryStart'}, s} end
    local act = funcs.GetSyntax()
    local ms = function(syn)
      return {
        {'ShaDaEntryMap' .. syn, 'ShaDaEntryMap' .. syn .. 'EntryStart'}, '  + '
      }
    end
    local as = function()
      return {{'ShaDaEntryArray', 'ShaDaEntryArrayEntryStart'}, '  - '}
    end
    local ad = function(s) return {{'ShaDaEntryArray',
                                    'ShaDaEntryArrayDescription'}, s} end
    local mbas = function(syn)
      return {
        {'ShaDaEntryMap' .. syn, 'ShaDaEntryMapBinArrayStart'},
        '  | - '
      }
    end
    local msk = function(s) return {{'ShaDaEntryMapShort',
                                     'ShaDaEntryMapShortKey'}, s} end
    local mlk = function(s) return {{'ShaDaEntryMapLong',
                                     'ShaDaEntryMapLongKey'}, s} end
    local mld = function(s) return {{'ShaDaEntryMapLong',
                                     'ShaDaEntryMapLongDescription'}, s} end
    local c = function(s) return {{'ShaDaComment'}, s} end
    local exp = {
      {
        hname('Header'), h(' with timestamp '),
        synepoch.year, synhtssep('-'), synepoch.month, synhtssep('-'),
        synepoch.day, synhtssep('T'), synepoch.hour, synhtssep(':'),
        synepoch.minute, synhtssep(':'), synepoch.second, h(':'),
      },
      {
        msh('  % Key  Value'),
      },
      {
        ms('Short'), msk('t    '),
        {{'ShaDaEntryMapShort', 'ShaDaMsgpackBinaryString',
          'ShaDaMsgpackStringQuotes'}, '"'},
        {{'ShaDaEntryMapShort', 'ShaDaMsgpackBinaryString'}, 'test'},
        {{'ShaDaEntryMapShort', 'ShaDaMsgpackStringQuotes'}, '"'},
      },
      {
        hname('Jump'), h(' with timestamp '),
        synepoch.year, synhtssep('-'), synepoch.month, synhtssep('-'),
        synepoch.day, synhtssep('T'), synepoch.hour, synhtssep(':'),
        synepoch.minute, synhtssep(':'), synepoch.second, h(':'),
      },
      {
        mlh('  % Key________  Description  Value'),
      },
      {
        ms('Long'), mlk('n            '), mld('name         '),
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackCharacter'}, '\'A\''},
      },
      {
        ms('Long'), mlk('f            '), mld('file name    '),
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackArray',
          'ShaDaMsgpackArrayBraces'}, '['},
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackArray', 'ShaDaMsgpackBinaryString',
          'ShaDaMsgpackStringQuotes'}, '"'},
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackArray', 'ShaDaMsgpackBinaryString'},
         'foo'},
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackArray', 'ShaDaMsgpackStringQuotes'},
         '"'},
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackArrayBraces'}, ']'},
      },
      {
        ms('Long'), mlk('l            '), mld('line number  '),
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackInteger'}, '2'},
      },
      {
        ms('Long'), mlk('c            '), mld('column       '),
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackInteger'}, '-200'},
      },
      {
        hname('Register'), h(' with timestamp '),
        synepoch.year, synhtssep('-'), synepoch.month, synhtssep('-'),
        synepoch.day, synhtssep('T'), synepoch.hour, synhtssep(':'),
        synepoch.minute, synhtssep(':'), synepoch.second, h(':'),
      },
      {
        mlh('  % Key  Description  Value'),
      },
      {
        ms('Long'), mlk('rc   '), mld('contents     '),
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackMultilineArray'}, '@'},
      },
      {
        mbas('Long'),
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackMap', 'ShaDaMsgpackMapBraces'},
         '{'},
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackMap', 'ShaDaMsgpackBinaryString',
          'ShaDaMsgpackStringQuotes'}, '"'},
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackMap', 'ShaDaMsgpackBinaryString'},
         'abcdefghijklmnopqrstuvwxyz'},
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackMap', 'ShaDaMsgpackStringQuotes'},
         '"'},
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackMap', 'ShaDaMsgpackColon'}, ':'},
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackMap'}, ' '},
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackMap', 'ShaDaMsgpackFloat'}, '1.0'},
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackMapBraces'}, '}'},
      },
      {
        ms('Long'), mlk('rt   '), mld('type         '),
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackShaDaKeyword'}, 'CHARACTERWISE'},
      },
      {
        ms('Long'), mlk('rt   '), mld('type         '),
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackShaDaKeyword'}, 'LINEWISE'},
      },
      {
        ms('Long'), mlk('rt   '), mld('type         '),
        {{'ShaDaEntryMapLong', 'ShaDaMsgpackShaDaKeyword'}, 'BLOCKWISE'},
      },
      {
        hname('Replacement string'), h(' with timestamp '),
        synepoch.year, synhtssep('-'), synepoch.month, synhtssep('-'),
        synepoch.day, synhtssep('T'), synepoch.hour, synhtssep(':'),
        synepoch.minute, synhtssep(':'), synepoch.second, h(':'),
      },
      {
        ah('  @ Description__________  Value'),
      },
      {
        as(), ad(':s replacement string  '),
        {{'ShaDaEntryArray', 'ShaDaMsgpackShaDaKeyword'}, 'CMD'},
      },
      {
        as(), ad(':s replacement string  '),
        {{'ShaDaEntryArray', 'ShaDaMsgpackShaDaKeyword'}, 'SEARCH'},
      },
      {
        as(), ad(':s replacement string  '),
        {{'ShaDaEntryArray', 'ShaDaMsgpackShaDaKeyword'}, 'EXPR'},
      },
      {
        as(), ad(':s replacement string  '),
        {{'ShaDaEntryArray', 'ShaDaMsgpackShaDaKeyword'}, 'INPUT'},
      },
      {
        {{'ShaDaEntryArrayEntryStart'}, '  - '},
        {{'ShaDaEntryArrayDescription'}, ':s replacement string  '},
        {{'ShaDaMsgpackShaDaKeyword'}, 'DEBUG'},
      },
      {
        hname('Buffer list'), h(' with timestamp '),
        synepoch.year, synhtssep('-'), synepoch.month, synhtssep('-'),
        synepoch.day, synhtssep('T'), synepoch.hour, synhtssep(':'),
        synepoch.minute, synhtssep(':'), synepoch.second, h(':'),
      },
      {
        c('  # Expected array of maps'),
      },
      {
        {{'ShaDaEntryRawMsgpack'}, '  = '},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackArrayBraces'}, '['},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackMapBraces'},
         '{'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackString'}, '='},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackBinaryString',
          'ShaDaMsgpackStringQuotes'}, '"'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackBinaryString'},
         'a'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackStringQuotes'},
         '"'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackColon'}, ':'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap'}, ' '},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackExt'}, '+('},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackExt',
          'ShaDaMsgpackExtType'}, '10'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackExt'}, ')'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackBinaryString',
          'ShaDaMsgpackStringQuotes'}, '"'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackBinaryString'},
         'ac'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackBinaryString',
          'ShaDaMsgpackBinaryStringEscape'},
         '\\0'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackBinaryString'},
         'df'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackBinaryString',
          'ShaDaMsgpackBinaryStringEscape'},
         '\\n'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackBinaryString'},
         'gi'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackBinaryString',
          'ShaDaMsgpackBinaryStringEscape'},
         '\\"'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackBinaryString'},
         'tt\\.'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackStringQuotes'},
         '"'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackComma'}, ','},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap'}, ' '},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackKeyword'},
         'TRUE'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackColon'}, ':'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap'}, ' '},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMap', 'ShaDaMsgpackKeyword'},
         'FALSE'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackMapBraces'}, '}'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackComma'}, ','},
        {{'ShaDaMsgpackArray'}, ' '},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackArray', 'ShaDaMsgpackArrayBraces'},
         '['},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackArray', 'ShaDaMsgpackKeyword'},
         'NIL'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackArray', 'ShaDaMsgpackComma'}, ','},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackArray'}, ' '},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackArray', 'ShaDaMsgpackExt'}, '+('},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackArray', 'ShaDaMsgpackExt',
          'ShaDaMsgpackExtType'}, '-10'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackArray', 'ShaDaMsgpackExt'}, ')'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackArray', 'ShaDaMsgpackBinaryString',
          'ShaDaMsgpackStringQuotes'}, '"'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackArray', 'ShaDaMsgpackStringQuotes'},
         '"'},
        {{'ShaDaMsgpackArray', 'ShaDaMsgpackArrayBraces'}, ']'},
        {{'ShaDaMsgpackArrayBraces'}, ']'},
      },
      {
        hname('Buffer list'), h(' with timestamp '),
        synepoch.year, synhtssep('-'), synepoch.month, synhtssep('-'),
        synepoch.day, synhtssep('T'), synepoch.hour, synhtssep(':'),
        synepoch.minute, synhtssep(':'), synepoch.second, h(':'),
      },
      {
        mlh('  % Key  Description  Value'),
      },
      {
      },
      {
        mlh('  % Key  Description  Value'),
      },
      {
        hname('Header'), h(' with timestamp '),
        synepoch.year, synhtssep('-'), synepoch.month, synhtssep('-'),
        synepoch.day, synhtssep('T'), synepoch.hour, synhtssep(':'),
        synepoch.minute, synhtssep(':'), synepoch.second, h(':'),
      },
      {
        mlh('  % Key  Description________  Value'),
      },
      {
        {{'ShaDaEntryMapLongEntryStart'}, '  + '},
        {{'ShaDaEntryMapLongKey'}, 'se   '},
        {{'ShaDaEntryMapLongDescription'}, 'place cursor at end  '},
        {{'ShaDaMsgpackKeyword'}, 'TRUE'},
      },
    }
    eq(exp, act)
  end)
end)
