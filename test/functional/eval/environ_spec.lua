local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local environ = helpers.funcs.environ

describe('environ()', function()
  it('handles empty env variable', function()
    clear({env={EMPTY_VAR=""}})
    eq("", environ()['EMPTY_VAR'])
    eq(nil, environ()['DOES_NOT_EXIST'])
  end)
end)
