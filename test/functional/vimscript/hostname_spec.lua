local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local ok = helpers.ok
local call = helpers.call
local clear = helpers.clear
local is_os = helpers.is_os

describe('hostname()', function()
  before_each(clear)

  it('returns hostname string', function()
    local actual = call('hostname')
    ok(string.len(actual) > 0)
    if call('executable', 'hostname') == 1 then
      local expected = string.gsub(call('system', 'hostname'), '[\n\r]', '')
      eq((is_os('win') and expected:upper() or expected),
         (is_os('win') and actual:upper() or actual))
    end
  end)
end)
