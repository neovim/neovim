-- Tests for "r<Tab>" with 'smarttab' and 'expandtab' set/not set.
-- Also test that dv_ works correctly

local helpers = require('test.functional.helpers')(after_each)
local feed, insert = helpers.feed, helpers.insert
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe([[performing "r<Tab>" with 'smarttab' and 'expandtab' set/not set, and "dv_"]], function()
  setup(clear)

  it('is working', function()
    insert([[
      start text
      		some test text
      test text
      		other test text
          a cde
          f ghi
      test text
        Second line beginning with whitespace]])

    execute('set smarttab expandtab ts=8 sw=4')
    -- Make sure that backspace works, no matter what termcap is used.
    execute('set t_kD=x7f t_kb=x08')

    execute('/some')
    feed('r	')
    execute('set noexpandtab')
    execute('/other')
    feed('r	<cr>')
    -- Test replacing with Tabs and then backspacing to undo it.
    feed('0wR			<bs><bs><bs><esc><cr>')
    -- Test replacing with Tabs.
    feed('0wR			<esc><cr>')
    -- Test that copyindent works with expandtab set.
    execute('set expandtab smartindent copyindent ts=8 sw=8 sts=8')
    feed('o{<cr>x<esc>')
    execute('set nosol')
    execute('/Second line/')
    -- Test "dv_"
    feed('fwdv_')

    -- Assert buffer contents.
    expect([[
      start text
      		    ome test text
      test text
      		    ther test text
          a cde
          		hi
      test text
      {
              x
        with whitespace]])
  end)
end)
