local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local eq = t.eq
local clear = n.clear
local command = n.command
local feed = n.feed
local eval = n.eval
local api = n.api
local poke_eventloop = n.poke_eventloop

describe('VisualChanged', function()
  before_each(function()
    clear()
    api.nvim_buf_set_lines(0, 0, -1, true, { 'foo bar', 'baz qux', 'x' })
    command([=[
      let g:events = []
      autocmd VisualChanged * call add(g:events, [mode(), getpos('v')[1:2], getpos('.')[1:2]])
    ]=])
  end)

  --- Returns the events recorded since the last call.
  local function events()
    poke_eventloop()
    local ev = eval('g:events')
    command('let g:events = []')
    return ev
  end

  it('fires when Visual mode starts or changes, not when it ends', function()
    feed('v')
    eq({ { 'v', { 1, 1 }, { 1, 1 } } }, events())
    feed('V')
    eq({ { 'V', { 1, 1 }, { 1, 1 } } }, events())
    feed('<C-V>')
    eq({ { '\22', { 1, 1 }, { 1, 1 } } }, events())
    feed('<Esc>')
    eq({}, events())
    -- Same position as before: still fires because Visual mode (re)started.
    feed('v')
    eq({ { 'v', { 1, 1 }, { 1, 1 } } }, events())
  end)

  it('fires when the cursor moves', function()
    feed('v')
    events()
    feed('l')
    eq({ { 'v', { 1, 1 }, { 1, 2 } } }, events())
    feed('j')
    eq({ { 'v', { 1, 1 }, { 2, 2 } } }, events())
  end)

  it('fires when only the anchor moves (cursor stays)', function()
    -- Cursor on the last char of "foo": "viw" moves the anchor, not the cursor.
    api.nvim_win_set_cursor(0, { 1, 2 })
    feed('v')
    eq({ { 'v', { 1, 3 }, { 1, 3 } } }, events())
    feed('iw')
    eq({ { 'v', { 1, 1 }, { 1, 3 } } }, events())
    feed('o')
    eq({ { 'v', { 1, 3 }, { 1, 1 } } }, events())
  end)

  it('fires on "$" in blockwise Visual mode', function()
    -- Empty line: "$" does not move the cursor, but extends the block to
    -- the end of each line.
    api.nvim_buf_set_lines(0, -1, -1, true, { '' })
    api.nvim_win_set_cursor(0, { 4, 0 })
    feed('<C-V>')
    events()
    feed('$')
    eq({ { '\22', { 4, 1 }, { 4, 1 } } }, events())
    feed('$')
    eq({}, events())
  end)

  it('does not fire if the selection did not change', function()
    feed('v')
    events()
    feed('k') -- already on the first line
    feed('h') -- already in the first column
    eq({}, events())
  end)

  it('does not fire outside Visual mode', function()
    feed('lj')
    feed('iabc<Esc>')
    eq({}, events())
  end)

  it('fires in Select mode', function()
    feed('gh')
    eq({ { 's', { 1, 1 }, { 1, 1 } } }, events())
    feed('<S-Right>')
    eq({ { 's', { 1, 1 }, { 1, 5 } } }, events())
    feed('<C-G>') -- switch to Visual mode
    eq({ { 'v', { 1, 1 }, { 1, 5 } } }, events())
  end)

  it('fires for gv', function()
    feed('vjl<Esc>gg')
    events()
    feed('gv')
    eq({ { 'v', { 1, 1 }, { 2, 2 } } }, events())
  end)

  it('handler can get the region with getregionpos()', function()
    command([=[
      let g:region = []
      autocmd VisualChanged * let g:region = getregionpos(getpos('v'), getpos('.'), #{type: mode()})
    ]=])
    feed('Vj')
    poke_eventloop()
    eq({
      { { 1, 1, 1, 0 }, { 1, 1, 7, 0 } },
      { { 1, 2, 1, 0 }, { 1, 2, 7, 0 } },
    }, eval('g:region'))
  end)
end)
