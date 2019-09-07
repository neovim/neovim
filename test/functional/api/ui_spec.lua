local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local meths = helpers.meths
local request = helpers.request
local pcall_err = helpers.pcall_err

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
    eq('No such UI option: foo',
      pcall_err(meths.ui_attach, 80, 24, { foo={'foo'} }))
  end)
  it('validates channel arg', function()
    eq('UI not attached to channel: 1',
      pcall_err(request, 'nvim_ui_try_resize', 40, 10))
    eq('UI not attached to channel: 1',
      pcall_err(request, 'nvim_ui_set_option', 'rgb', true))
    eq('UI not attached to channel: 1',
      pcall_err(request, 'nvim_ui_detach'))

    local screen = Screen.new()
    screen:attach({rgb=false})
    eq('UI already attached to channel: 1',
      pcall_err(request, 'nvim_ui_attach', 40, 10, { rgb=false }))
  end)
end)
