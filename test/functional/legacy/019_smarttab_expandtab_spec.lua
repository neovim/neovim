-- Tests for "r<Tab>" with 'smarttab' and 'expandtab' set/not set.
-- Also test that dv_ works correctly

local t = require('test.functional.testutil')(after_each)
local feed, insert = t.feed, t.insert
local clear, feed_command, expect = t.clear, t.feed_command, t.expect

describe([[performing "r<Tab>" with 'smarttab' and 'expandtab' set/not set, and "dv_"]], function()
  setup(clear)

  -- luacheck: ignore 621 (Indentation)
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

    feed_command('set smarttab expandtab ts=8 sw=4')
    -- Make sure that backspace works, no matter what termcap is used.
    feed_command('set t_kD=x7f t_kb=x08')

    feed_command('/some')
    feed('r	')
    feed_command('set noexpandtab')
    feed_command('/other')
    feed('r	<cr>')
    -- Test replacing with Tabs and then backspacing to undo it.
    feed('0wR			<bs><bs><bs><esc><cr>')
    -- Test replacing with Tabs.
    feed('0wR			<esc><cr>')
    -- Test that copyindent works with expandtab set.
    feed_command('set expandtab smartindent copyindent ts=8 sw=8 sts=8')
    feed('o{<cr>x<esc>')
    feed_command('set nosol')
    feed_command('/Second line/')
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
