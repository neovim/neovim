local t = require('test.functional.testutil')()
local eq = t.eq
local ok = t.ok
local call = t.call
local clear = t.clear
local is_os = t.is_os

describe('hostname()', function()
  before_each(clear)

  it('returns hostname string', function()
    local actual = call('hostname')
    ok(string.len(actual) > 0)
    if call('executable', 'hostname') == 1 then
      local expected = string.gsub(call('system', 'hostname'), '[\n\r]', '')
      eq(
        (is_os('win') and expected:upper() or expected),
        (is_os('win') and actual:upper() or actual)
      )
    end
  end)
end)
