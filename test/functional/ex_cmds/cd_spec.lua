-- Specs for
-- :cd, :tcd, :lcd

local helpers = require('test.functional.helpers')
local nvim execute, eq, clear, eval, feed =
  helpers.nvim, helpers.execute, helpers.eq, helpers.clear, helpers.eval, helpers.feed

describe(':tcd', function()
  before_each(clear)

  it('sets to local directory of the current tab', function()
    assert.is_nil(nvim.globaldir)
    assert.is_nil(curtab.localdir)
    execute('tcd test') -- Change the directory
  end)
end)

