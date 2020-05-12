local helpers = require('test.unit.helpers')(after_each)
local eval_helpers = require('test.unit.eval.helpers')

local itp = helpers.gen_itp(it)

local cimport = helpers.cimport
local eq = helpers.eq

local eval0 = eval_helpers.eval0

local eval = cimport('./src/nvim/eval.h', './src/nvim/eval/typval.h',
                     './src/nvim/memory.h')

describe('NULL typval_T', function()
  itp('is produced by $XXX_UNEXISTENT_VAR_XXX', function()
    -- Required for various tests which need to check whether typval_T with NULL
    -- string works correctly. This test checks that unexistent environment
    -- variable produces NULL string, not that some specific environment
    -- variable does not exist. Last bit is left for the test writers.
    local unexistent_env = 'XXX_UNEXISTENT_VAR_XXX'
    while os.getenv(unexistent_env) ~= nil do
      unexistent_env = unexistent_env .. '_XXX'
    end
    local rettv = eval0('$' .. unexistent_env)
    eq(eval.VAR_STRING, rettv.v_type)
    eq(nil, rettv.vval.v_string)
  end)

  itp('is produced by v:_null_list', function()
    local rettv = eval0('v:_null_list')
    eq(eval.VAR_LIST, rettv.v_type)
    eq(nil, rettv.vval.v_list)
  end)

  itp('is produced by v:_null_dict', function()
    local rettv = eval0('v:_null_dict')
    eq(eval.VAR_DICT, rettv.v_type)
    eq(nil, rettv.vval.v_dict)
  end)
end)
