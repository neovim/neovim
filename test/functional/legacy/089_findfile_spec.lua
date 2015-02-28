-- - Some tests for findfile() function

local helpers = require('test.functional.helpers')
local feed = helpers.feed
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('findfile', function()
  setup(clear)

  it('is working', function()
    -- Assume test is being run from project root
    execute([[$put ='Testing findfile']])
    execute([[$put ='']])
    execute('set ssl')
    execute([[$put =findfile('vim.c','src/nvim/ap*')]])
    execute('cd src/nvim')
    execute([[$put =findfile('vim.c','ap*')]])
    execute([[$put =findfile('vim.c','api')]])

    -- Remove empty line
    feed('ggdd')

    expect([[
      Testing findfile
      
      src/nvim/api/vim.c
      api/vim.c
      api/vim.c]])
  end)
end)
