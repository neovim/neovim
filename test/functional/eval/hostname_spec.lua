local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local ok = helpers.ok
local call = helpers.call
local clear = helpers.clear
local iswin = helpers.iswin

describe('hostname()', function()
  before_each(clear)

  it('returns hostname string', function()
    local actual = call('hostname')
    ok(string.len(actual) > 0)
    if call('executable', 'hostname') == 1 then
      local expected = string.gsub(call('system', 'hostname'), '[\n\r]', '')
      eq((iswin() and expected:upper() or expected),
         (iswin() and actual:upper() or actual))
    end
  end)
end)
