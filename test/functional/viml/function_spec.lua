local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local exc_exec = helpers.exc_exec

describe('Up to MAX_FUNC_ARGS arguments are handled by', function()
  local max_func_args = 20  -- from eval.h
  local range = helpers.funcs.range

  before_each(clear)

  it('printf()', function()
    local printf = helpers.funcs.printf
    local rep = helpers.funcs['repeat']
    local expected = '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,'
    eq(expected, printf(rep('%d,', max_func_args-1), unpack(range(2, max_func_args))))
    local ret = exc_exec('call printf("", 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)')
    eq('Vim(call):E740: Too many arguments for function printf', ret)
  end)

  it('rpcnotify()', function()
    local rpcnotify = helpers.funcs.rpcnotify
    local ret = rpcnotify(0, 'foo', unpack(range(3, max_func_args)))
    eq(1, ret)
    ret = exc_exec('call rpcnotify(0, "foo", 3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)')
    eq('Vim(call):E740: Too many arguments for function rpcnotify', ret)
  end)
end)
