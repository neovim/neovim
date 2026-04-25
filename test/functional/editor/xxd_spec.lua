local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local clear = n.clear
local fn = n.fn
local testprg = n.testprg

describe('xxd', function()
  before_each(clear)

  it('works', function()
    t.skip(t.is_arch('s390x'), 'FIXME: xxd not built correctly on s390x with QEMU?')
    -- Round-trip test: encode then decode should return original
    local input = 'hello'
    local encoded = fn.system({ testprg('xxd') }, input)
    local decoded = fn.system({ testprg('xxd'), '-r' }, encoded)
    eq(input, decoded)
  end)
end)
