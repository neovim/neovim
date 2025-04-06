local t = require('test.unit.testutil')
local assert = require('luassert')

local itp = t.gen_itp(it)

local sc = t.sc

-- All of the below tests must fail. Check how exactly they fail.
if os.getenv('NVIM_TEST_RUN_TESTTEST') ~= '1' then
  return
end
describe('test code', function()
  itp('does not hang when working with lengthy errors', function()
    assert.just_fail(('x'):rep(65536))
  end)
  itp('shows trace after exiting abnormally', function()
    sc.exit(0)
  end)
end)
