local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
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

it('autocmds UIEnter/UILeave', function()
  clear{
    args_rm={'--headless'},
    args={
      '--cmd', 'let g:evs = []',
      '--cmd', 'autocmd UIEnter * :call add(g:evs, "UIEnter-".expand("<afile>")) | let g:uienter_ev = deepcopy(v:event)',
      '--cmd', 'autocmd UILeave * :call add(g:evs, "UILeave-".expand("<afile>")) | let g:uileave_ev = deepcopy(v:event)',
      '--cmd', 'autocmd UIEnter testui :call add(g:evs, "UIEnter-matches-pattern")',
      '--cmd', 'autocmd UILeave testui :call add(g:evs, "UILeave-matches-pattern")',
      '--cmd', 'autocmd UIEnter bogus :call add(g:evs, "UIEnter-does-NOT-match")',
      '--cmd', 'autocmd UILeave bogus :call add(g:evs, "UILeave-does-NOT-match")',
      '--cmd', 'autocmd VimEnter * :call add(g:evs, "VimEnter")',
    }}
  meths.set_client_info("testui",
                        {},
                        'ui',
                        {do_stuff={n_args={2,3}}},
                        {license= 'Apache2'})
  local screen = Screen.new()
  screen:attach()
  eq({chan=1, name='testui'}, eval('g:uienter_ev'))
  screen:detach()
  eq({chan=1, name='testui'}, eval('g:uileave_ev'))
  eq({
    'VimEnter',
    'UIEnter-testui',
    'UIEnter-matches-pattern',
    'UILeave-testui',
    'UILeave-matches-pattern',
  }, eval('g:evs'))
end)
