local t = require('test.unit.testutil')
local itp = t.gen_itp(it)
local t_eval = require('test.unit.eval.testutil')
local api_t = require('test.unit.api.testutil')

local cimport = t.cimport
local NULL = t.NULL
local eq = t.eq

local lua2typvalt = t_eval.lua2typvalt
local typvalt2lua = t_eval.typvalt2lua
local typvalt = t_eval.typvalt

local nil_value = api_t.nil_value
local list_type = api_t.list_type
local int_type = api_t.int_type
local type_key = api_t.type_key
local obj2lua = api_t.obj2lua
local func_type = api_t.func_type

local api = cimport('./src/nvim/api/private/helpers.h', './src/nvim/api/private/converter.h')

describe('vim_to_object', function()
  local vim_to_object = function(l)
    return obj2lua(api.vim_to_object(lua2typvalt(l), nil, false))
  end

  local different_output_test = function(name, input, output)
    itp(name, function()
      eq(output, vim_to_object(input))
    end)
  end

  local simple_test = function(name, l)
    different_output_test(name, l, l)
  end

  simple_test('converts true', true)
  simple_test('converts false', false)
  simple_test('converts nil', nil_value)
  simple_test('converts 1', 1)
  simple_test('converts -1.5', -1.5)
  simple_test('converts empty string', '')
  simple_test('converts non-empty string', 'foobar')
  simple_test('converts integer 10', { [type_key] = int_type, value = 10 })
  simple_test('converts empty dict', {})
  simple_test('converts dict with scalar values', { test = 10, test2 = true, test3 = 'test' })
  simple_test('converts dict with containers inside', { test = {}, test2 = { 1, 2 } })
  simple_test('converts empty list', { [type_key] = list_type })
  simple_test('converts list with scalar values', { 1, 2, 'test', 'foo' })
  simple_test(
    'converts list with containers inside',
    { {}, { test = {}, test3 = { test4 = true } } }
  )

  local dct = {}
  dct.dct = dct
  different_output_test('outputs nil for nested dictionaries (1 level)', dct, { dct = nil_value })

  local lst = {}
  lst[1] = lst
  different_output_test('outputs nil for nested lists (1 level)', lst, { nil_value })

  local dct2 = { test = true, dict = nil_value }
  dct2.dct = { dct2 }
  different_output_test(
    'outputs nil for nested dictionaries (2 level, in list)',
    dct2,
    { dct = { nil_value }, test = true, dict = nil_value }
  )

  local dct3 = { test = true, dict = nil_value }
  dct3.dct = { dctin = dct3 }
  different_output_test(
    'outputs nil for nested dictionaries (2 level, in dict)',
    dct3,
    { dct = { dctin = nil_value }, test = true, dict = nil_value }
  )

  local lst2 = {}
  lst2[1] = { lst2 }
  different_output_test('outputs nil for nested lists (2 level, in list)', lst2, { { nil_value } })

  local lst3 = { nil, true, false, 'ttest' }
  lst3[1] = { lst = lst3 }
  different_output_test(
    'outputs nil for nested lists (2 level, in dict)',
    lst3,
    { { lst = nil_value }, true, false, 'ttest' }
  )

  itp('outputs empty list for NULL list', function()
    local tt = typvalt('VAR_LIST', { v_list = NULL })
    eq(nil, tt.vval.v_list)
    eq({ [type_key] = list_type }, obj2lua(api.vim_to_object(tt, nil, false)))
  end)

  itp('outputs empty dict for NULL dict', function()
    local tt = typvalt('VAR_DICT', { v_dict = NULL })
    eq(nil, tt.vval.v_dict)
    eq({}, obj2lua(api.vim_to_object(tt, nil, false)))
  end)

  itp('regression: partials in a list', function()
    local llist = {
      {
        [type_key] = func_type,
        value = 'printf',
        args = { '%s' },
        dict = { v = 1 },
      },
      {},
    }
    local list = lua2typvalt(llist)
    eq(llist, typvalt2lua(list))
    eq({ nil_value, {} }, obj2lua(api.vim_to_object(list, nil, false)))
  end)
end)
