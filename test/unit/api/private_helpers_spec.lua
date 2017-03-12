local helpers = require('test.unit.helpers')(after_each)
local itp = helpers.gen_itp(it)
local eval_helpers = require('test.unit.eval.helpers')
local api_helpers = require('test.unit.api.helpers')

local cimport = helpers.cimport
local NULL = helpers.NULL
local eq = helpers.eq

local lua2typvalt = eval_helpers.lua2typvalt
local typvalt2lua = eval_helpers.typvalt2lua
local typvalt = eval_helpers.typvalt

local nil_value = api_helpers.nil_value
local list_type = api_helpers.list_type
local int_type = api_helpers.int_type
local type_key = api_helpers.type_key
local obj2lua = api_helpers.obj2lua
local func_type = api_helpers.func_type

local api = cimport('./src/nvim/api/private/helpers.h')

describe('vim_to_object', function()
  local vim_to_object = function(l)
    return obj2lua(api.vim_to_object(lua2typvalt(l)))
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
  simple_test('converts integer 10', {[type_key]=int_type, value=10})
  simple_test('converts empty dictionary', {})
  simple_test('converts dictionary with scalar values', {test=10, test2=true, test3='test'})
  simple_test('converts dictionary with containers inside', {test={}, test2={1, 2}})
  simple_test('converts empty list', {[type_key]=list_type})
  simple_test('converts list with scalar values', {1, 2, 'test', 'foo'})
  simple_test('converts list with containers inside', {{}, {test={}, test3={test4=true}}})

  local dct = {}
  dct.dct = dct
  different_output_test('outputs nil for nested dictionaries (1 level)', dct, {dct=nil_value})

  local lst = {}
  lst[1] = lst
  different_output_test('outputs nil for nested lists (1 level)', lst, {nil_value})

  local dct2 = {test=true, dict=nil_value}
  dct2.dct = {dct2}
  different_output_test('outputs nil for nested dictionaries (2 level, in list)',
                        dct2, {dct={nil_value}, test=true, dict=nil_value})

  local dct3 = {test=true, dict=nil_value}
  dct3.dct = {dctin=dct3}
  different_output_test('outputs nil for nested dictionaries (2 level, in dict)',
                        dct3, {dct={dctin=nil_value}, test=true, dict=nil_value})

  local lst2 = {}
  lst2[1] = {lst2}
  different_output_test('outputs nil for nested lists (2 level, in list)', lst2, {{nil_value}})

  local lst3 = {nil, true, false, 'ttest'}
  lst3[1] = {lst=lst3}
  different_output_test('outputs nil for nested lists (2 level, in dict)',
                        lst3, {{lst=nil_value}, true, false, 'ttest'})

  itp('outputs empty list for NULL list', function()
    local tt = typvalt('VAR_LIST', {v_list=NULL})
    eq(nil, tt.vval.v_list)
    eq({[type_key]=list_type}, obj2lua(api.vim_to_object(tt)))
  end)

  itp('outputs empty dict for NULL dict', function()
    local tt = typvalt('VAR_DICT', {v_dict=NULL})
    eq(nil, tt.vval.v_dict)
    eq({}, obj2lua(api.vim_to_object(tt)))
  end)

  itp('regression: partials in a list', function()
    local llist = {
      {
        [type_key]=func_type,
        value='printf',
        args={'%s'},
        dict={v=1},
      },
      {},
    }
    local list = lua2typvalt(llist)
    eq(llist, typvalt2lua(list))
    eq({nil_value, {}}, obj2lua(api.vim_to_object(list)))
  end)
end)
