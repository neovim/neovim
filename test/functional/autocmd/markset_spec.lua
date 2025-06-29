local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api = n.api
local clear = n.clear
local command = n.command
local feed = n.feed
local poke_eventloop = n.poke_eventloop
local eval = n.eval

local eq = t.eq

describe('MarkSet', function()
  before_each(function()
    clear()
    command("autocmd MarkSet * let g:autocmd ..= 'M'")
    command([[let g:autocmd = '']])
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'foo\0bar',
      'baz text',
    })
  end)

  it('is called after a lowercase mark is set', function()
    feed('ma')
    poke_eventloop()
    feed('j')
    poke_eventloop()
    feed('mb')
    poke_eventloop()

    eq('MM', eval('g:autocmd'))
  end)

  it('is called after an uppercase mark is set', function()
    feed('mA')
    poke_eventloop()
    feed('l')
    poke_eventloop()
    feed('mB')
    poke_eventloop()
    feed('j')
    poke_eventloop()
    feed('mC')
    poke_eventloop()

    eq('MMM', eval('g:autocmd'))
  end)
end)
