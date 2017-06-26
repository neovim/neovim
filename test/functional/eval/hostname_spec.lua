local helpers = require('test.functional.helpers')(after_each)
local ok = helpers.ok
local call = helpers.call
local clear = helpers.clear

describe('hostname()', function()
  before_each(clear)

  it('returns hostname string', function()
    local actual = call('hostname')
    ok(string.len(actual) > 1)
    if call('executable', 'hostname') == 1 then
      local expected = string.gsub(call('system', 'hostname'), '[\n\r]', '')
      helpers.eq(expected, actual)
    end
  end)
end)
