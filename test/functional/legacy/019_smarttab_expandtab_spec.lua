-- Tests for "r<Tab>" with 'smarttab' and 'expandtab' set/not set.
-- Also test that dv_ works correctly

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local describe, it, setup = t.describe, t.it, t.setup
local feed, insert = n.feed, n.insert
local clear, feed_command, expect = n.clear, n.feed_command, n.expect
local eq = t.eq

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

describe([['expandtabalign']], function()
  setup(clear)
  it('is working', function()
    insert([[
      first
      second
      third
      fourth
      fifth
      sixth
      eight
    ]])

    feed_command('set noexpandtab expandtabalign ts=4 sw=4')
    feed_command('/first')
    feed('i		<esc>', '$', 'a		line<esc>')
    -- Test copyindent
    feed_command('set copyindent smartindent')
    feed('o{<cr>some		text<esc>')
    feed_command('set nocopyindent nosmartindent')
    -- Test non-leading
    feed_command('/second')
    feed('$', 'a	line<esc>')
    -- Test Backspace (make sure it works no matter what termcap is loaded)
    feed_command('/third')
    feed_command('set t_kD=x7f t_kb=x08')
    feed('i			<bs><esc>', '$', 'a	line<esc>')
    -- Test < > indent commands
    feed_command('/fourth')
    feed_command('>', '>', '>', '<', '<')
    feed('3la	<esc>', '$')
    -- Test ^V<tab>
    feed_command('/fifth')
    feed('$', 'a<tab>line<esc>')
    -- Test ts != sw
    feed_command('set ts=4 sw=3')
    feed_command('/sixth')
    feed('i		<esc>', '$', 'a	line<esc>')
    -- Test vartabstop
    feed_command('set ts=4 sw=4 vts=4,8,16 noexpandtab expandtabalign')
    feed('a<cr>		seventh	line		x<esc>')
    -- No effect with expandtab
    feed_command('set expandtab ts=2 sw=2 vts=')
    feed_command('/eight')
    feed('i		<esc>', '$', 'a		line<esc>')

    -- Assert buffer contents.
    expect([[
    		first       line
    		{
    			some        text
    second  line
    		third   line
    	four    th
    fifth	line
    	  sixth line
    	    seventh             line                            x
        eight   line
    ]])
  end)

  for _, v in ipairs({ 'paste', 'bin' }) do
    it('is off in ' .. v .. ' mode', function()
      feed_command('set noexpandtab expandtabalign')
      feed_command('set ' .. v)
      eq(0, n.eval('&expandtabalign'))
      feed_command('set no' .. v)
      eq(1, n.eval('&expandtabalign'))
    end)
  end
end)
