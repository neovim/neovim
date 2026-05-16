local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local exec_lua = n.exec_lua
local poke_eventloop = n.poke_eventloop
local api = n.api
local eval = n.eval

local eq = t.eq

describe('TabMoved', function()
  before_each(function()
    clear()
  end)

  it('sets <amatch>, event-data', function()
    -- start on tabpage 1, create 2 more so tabpage 3 is "current tab"
    command('tabnew')
    command('tabnew')

    exec_lua([[
      _G.tm_events = {}
      vim.api.nvim_create_autocmd('TabMoved', {
        callback = function(ev)
          table.insert(_G.tm_events, ev)
        end,
      })
    ]])

    command('tabmove 0')
    poke_eventloop()
    local events = exec_lua('return _G.tm_events')
    eq('3', events[1].match)
    eq({ tabnr_new = 1, tabnr_old = 3 }, events[1].data)

    command('tabnext 2')
    command('tabmove $')
    poke_eventloop()
    events = exec_lua('return _G.tm_events')
    eq('2', events[2].match)
    eq({ tabnr_new = 3, tabnr_old = 2 }, events[2].data)

    command('tabmove -1')
    poke_eventloop()
    events = exec_lua('return _G.tm_events')
    eq('3', events[3].match)
    eq({ tabnr_new = 2, tabnr_old = 3 }, events[3].data)
  end)

  it('does not trigger when a tab is moved to same position', function()
    command('tabnew')
    command('tabnew')
    command('let g:test = 0')
    command('au! TabMoved * let g:test += 1')

    command('tabmove $') -- already at last position, no-op
    poke_eventloop()
    eq(0, eval('g:test'))
  end)

  it('is not triggered when creating or closing tabs', function()
    command('let g:test = 0')
    command('au! TabMoved * let g:test += 1')
    command('file Xtestfile1')
    command('0tabedit Xtestfile2')
    command('tabclose')
    poke_eventloop()
    eq(0, eval('g:test'))
  end)

  it('handles mouse interactions on the tabline', function()
    local function setup()
      Screen.new(25, 5)
      command('set mouse=a')
      command('tabnew')
      command('tabnew')
      exec_lua([[
        _G.tm_events = {}
        vim.api.nvim_create_autocmd('TabMoved', {
          callback = function(ev)
            table.insert(_G.tm_events, ev)
          end,
        })
      ]])
    end

    -- clicking tab 2 shouldn't trigger the event.
    setup()
    api.nvim_input_mouse('left', 'press', '', 0, 0, 5)
    api.nvim_input_mouse('left', 'release', '', 0, 0, 5)
    poke_eventloop()
    eq({}, exec_lua('return _G.tm_events'))
    clear()

    -- dragging tab 1 to the right should trigger the event.
    setup()
    api.nvim_input_mouse('left', 'press', '', 0, 0, 4)
    poke_eventloop()
    eq(0, #exec_lua('return _G.tm_events'))
    api.nvim_input_mouse('left', 'drag', '', 0, 0, 14)
    poke_eventloop()
    local events = exec_lua('return _G.tm_events')
    eq(1, #events)
    eq({ tabnr_new = 2, tabnr_old = 1 }, events[1].data)
  end)
end)
