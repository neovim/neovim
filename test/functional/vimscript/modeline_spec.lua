local t = require('test.functional.testutil')()
local assert_alive = t.assert_alive
local clear, command, write_file = t.clear, t.command, t.write_file

describe('modeline', function()
  local tempfile = t.tmpname()
  before_each(clear)

  after_each(function()
    os.remove(tempfile)
  end)

  it('does not crash with a large version number', function()
    write_file(tempfile, 'vim100000000000000000000000')
    command('e! ' .. tempfile)

    assert_alive()
  end)
end)
