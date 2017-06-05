-- First a simple test to check if the test script works.
-- If Vim was not compiled with the +eval feature, the small.vim script will be
-- set to copy the test.ok file to test.out, so that it looks like the test
-- succeeded.  Otherwise an empty small.vim is written.  small.vim is sourced by
-- tests that require the +eval feature or other features that are missing in the
-- small version.
-- If Vim was not compiled with the +windows feature, the tiny.vim script will be
-- set like small.vim above.  tiny.vim is sourced by tests that require the
-- +windows feature or other features that are missing in the tiny version.
-- If Vim was not compiled with the +multi_byte feature, the mbyte.vim script will
-- be set like small.vim above.  mbyte.vim is sourced by tests that require the
-- +multi_byte feature.
-- Similar logic is applied to the +mzscheme feature, using mzscheme.vim.
-- Similar logic is applied to the +lua feature, using lua.vim.

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('test script', function()
  setup(clear)

  it('is working', function()

    feed("athis is a test<esc>")
    -- Assert buffer contents.
    expect([[
      this is a test]])
  end)
end)
