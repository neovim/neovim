-- Specs for
-- :cd, :tcd, :lcd

local helpers = require('test.functional.helpers')
local nvim execute, eq, clear, eval, feed =
  helpers.nvim, helpers.execute, helpers.eq, helpers.clear, helpers.eval, helpers.feed

describe(':tcd', function()
  before_each(clear)

  it('sets to local directory of the current tab', function()
    local globalDir = eval('getcwd()')
    execute('tabnew') -- Create a new tab first
    -- assert.is_same(eval('getcwd()'), globalDir) -- Confirm nothing changed
    -- feed('tcd test') -- Change the tab directory
  end)
end)

