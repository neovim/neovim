local helpers = require('test.unit.helpers')

local cimport = helpers.cimport
local to_cstr = helpers.to_cstr
local ffi = helpers.ffi
local eq = helpers.eq

local eval = cimport('./src/nvim/eval.h', './src/nvim/memory.h')

local eval_expr = function(expr)
  return ffi.gc(eval.eval_expr(to_cstr(expr), nil), function(tv)
    eval.clear_tv(tv)
    eval.xfree(tv)
  end)
end

describe('NULL typval_T', function()
  it('is produced by $XXX_UNEXISTENT_VAR_XXX', function()
    -- Required for various tests which need to check whether typval_T with NULL
    -- string works correctly. This test checks that unexistent environment
    -- variable produces NULL string, not that some specific environment
    -- variable does not exist. Last bit is left for the test writers.
    local unexistent_env = 'XXX_UNEXISTENT_VAR_XXX'
    while os.getenv(unexistent_env) ~= nil do
      unexistent_env = unexistent_env .. '_XXX'
    end
    local rettv = eval_expr('$' .. unexistent_env)
    eq(eval.VAR_STRING, rettv.v_type)
    eq(nil, rettv.vval.v_string)
  end)

  it('is produced by v:_null_list', function()
    local rettv = eval_expr('v:_null_list')
    eq(eval.VAR_LIST, rettv.v_type)
    eq(nil, rettv.vval.v_list)
  end)

  it('is produced by v:_null_dict', function()
    local rettv = eval_expr('v:_null_dict')
    eq(eval.VAR_DICT, rettv.v_type)
    eq(nil, rettv.vval.v_dict)
  end)
end)
