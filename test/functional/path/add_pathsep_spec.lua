local helpers = require('test.functional.helpers')
local execute, eq, clear, eval, feed, ok =
  helpers.execute, helpers.eq, helpers.clear, helpers.eval,
  helpers.feed, helpers.ok

describe('add_pathsep function', function()
  local test_dir = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
  before_each(function()
    clear()
    lfs.mkdir(test_dir)
  end)
  after_each(function()
    lfs.rmdir(test_dir)
  end)

  it("add_pathsep()", function()
    execute('cd ' .. test_dir)
    execute("echo fnamemodify('', ':p')")
    feed('<cr>')
  end)

end)
