local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local environ = helpers.funcs.environ
local exists = helpers.funcs.exists
local command = helpers.command
local nvim_prog = helpers.nvim_prog
local setenv = helpers.funcs.setenv
local system = helpers.funcs.system
local eval = helpers.eval

describe('environment variables', function()
  it('environ() handles empty env variable', function()
    clear({env={EMPTY_VAR=""}})
    eq("", environ()['EMPTY_VAR'])
    eq(nil, environ()['DOES_NOT_EXIST'])
  end)

  it('exists() handles empty env variable', function()
    clear({env={EMPTY_VAR=""}})
    eq(1, exists('$EMPTY_VAR'))
    eq(0, exists('$DOES_NOT_EXIST'))
  end)
end)
