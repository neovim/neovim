local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local exists = helpers.funcs.exists

describe('exists()', function()
  it('handles empty env variable', function()
    clear({env={EMPTY_VAR=""}})
    eq(1, exists('$EMPTY_VAR'))
    eq(0, exists('$DOES_NOT_EXIST'))
  end)
end)
