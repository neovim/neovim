-- /* vim: set cin ts=4 sw=4 : */
-- Test for 'cindent'

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('cindent', function()
  setup(clear)

  it('indents blocks correctly', function()
    insert([[
    ]])

    execute('so small.vim')
    execute('set nocompatible viminfo+=nviminfo modeline')
    -- Read modeline.
    execute('edit')
    execute('/start of AUTO')
    feed('=/end of AUTO<cr>')

    expect([[
    ]])

  end)

end)
