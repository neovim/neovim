local helpers = require('test.functional.helpers')(after_each)
local assert_alive = helpers.assert_alive
local clear, command, write_file = helpers.clear, helpers.command, helpers.write_file

describe("modeline", function()
  local tempfile = helpers.tmpname()
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
