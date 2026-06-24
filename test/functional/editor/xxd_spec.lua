local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local eval = n.eval
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

  it('handles long lines in revert mode', function()
    t.skip(t.is_arch('s390x'), 'FIXME: xxd not built correctly on s390x with QEMU?')
    local long_line = ('4'):rep(512) .. '\n'
    fn.system({ testprg('xxd'), '-r' }, long_line)
    eq(0, eval('v:shell_error'))
  end)
end)
