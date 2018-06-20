local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local expect_err = helpers.expect_err
local meths = helpers.meths
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
    expect_err('No such UI option: foo',
               meths.ui_attach, 80, 24, { foo={'foo'} })
  end)
  it('validates channel arg', function()
    expect_err('UI not attached to channel: 1',
               request, 'nvim_ui_try_resize', 40, 10)
    expect_err('UI not attached to channel: 1',
               request, 'nvim_ui_set_option', 'rgb', true)
    expect_err('UI not attached to channel: 1',
               request, 'nvim_ui_detach')

    local screen = Screen.new()
    screen:attach({rgb=false})
    expect_err('UI already attached to channel: 1',
               request, 'nvim_ui_attach', 40, 10, { rgb=false })
  end)
end)
