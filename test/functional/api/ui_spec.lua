local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
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
    local screen = Screen.new()
    local status, rv = pcall(function() screen:attach({foo={'foo'}}) end)
    eq(false, status)
    eq('No such UI option', rv:match("No such .*"))
  end)
  it('validates channel arg', function()
    assert.has_error(function() request('nvim_ui_try_resize', 40, 10) end,
                     'UI not attached to channel: 1')
    assert.has_error(function() request('nvim_ui_set_option', 'rgb', true) end,
                     'UI not attached to channel: 1')
    assert.has_error(function() request('nvim_ui_detach') end,
                     'UI not attached to channel: 1')

    local screen = Screen.new()
    screen:attach({rgb=false})
    assert.has_error(function()
      request('nvim_ui_attach', 40, 10, { rgb=false })
    end,
    'UI already attached to channel: 1')
  end)
end)
