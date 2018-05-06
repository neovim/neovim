local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local funcs = helpers.funcs
local request = helpers.request

describe('nvim_ui_attach()', function()
  before_each(function()
    clear()
  end)
  it('handles very large width/height #2180', function()
    local screen = Screen.new(999, 999)
    screen:attach()
    eq(999, eval('&lines'))
    eq(999, eval('&columns'))
  end)
  it('invalid option returns error', function()
    local status, rv = pcall(request, 'nvim_ui_attach', 80, 24, {foo={'foo'}})
    eq(false, status)
    eq('No such UI option', rv:match("No such .*"))
  end)
  it('validates channel arg', function()
    -- eq({ false, 'UI not attached to channel: 1' },
    --    { pcall(request, 'nvim_ui_try_resize', 40, 10) })
    -- eq({ false, 'UI not attached to channel: 1' },
    --    { pcall(request, 'nvim_ui_set_option', 'rgb', true) })
    -- eq({ false, 'UI not attached to channel: 1' },
    --    { pcall(request, 'nvim_ui_detach') })

    local screen = Screen.new()
    screen:attach({rgb=false})
    assert.has_error(function()
      request('nvim_ui_attach', 40, 10, { rgb=false })
    end,
    'UI already attached to channel: 1')
  end)

  -- it('TUI', function()
  --   assert.has_error(function()
  --     eval('nvim_ui_attach(0, 0, {})')
  --   end,
  --   'TUI already attached')
  -- end)
end)
