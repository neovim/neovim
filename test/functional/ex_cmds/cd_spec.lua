-- Specs for
-- :cd, :tcd, :lcd

local helpers = require('test.functional.helpers')
local nvim, execute, eq, clear, eval, feed =
  helpers.nvim, helpers.execute, helpers.eq, helpers.clear, helpers.eval, helpers.feed

describe(':cd :tcd', function()
  before_each(clear)

  it('sets to local directory of the current tab', function()
    -- Store the initial working directory
    local globalDir = eval('getcwd()')

    -- Create a new tab first and verify that is has the same working dir
    execute('tabnew')
    assert.is_same(eval('getcwd()'), globalDir)
    -- Change tab-local working directory and verify it is different
    execute('tcd test')
    assert.is_same(eval('getcwd()'), globalDir .. '/test')
    -- Change back to initial tab and verify working directory has stayed
    feed('gt')
    assert.is_same(eval('getcwd()'), globalDir)
    -- Verify global changes don't affect local ones
    execute('cd build')
    assert.is_same(eval('getcwd()'), globalDir .. '/build')
    feed('gt')
    assert.is_same(eval('getcwd()'), globalDir .. '/test')
    -- Unless the global change happened in a tab with local directory
    execute('cd ..')
    assert.is_same(eval('getcwd()'), globalDir)
    feed('gt')
    assert.is_same(eval('getcwd()'), globalDir)

    -- TODO: Verify that :lcd works as well
  end)
end)

