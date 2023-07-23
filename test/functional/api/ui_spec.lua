local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local exec = helpers.exec
local feed = helpers.feed
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

  it('validation', function()
    eq('No such UI option: foo',
      pcall_err(meths.ui_attach, 80, 24, { foo={'foo'} }))

    eq("Invalid 'ext_linegrid': expected Boolean, got Array",
      pcall_err(meths.ui_attach, 80, 24, { ext_linegrid={} }))
    eq("Invalid 'override': expected Boolean, got Array",
      pcall_err(meths.ui_attach, 80, 24, { override={} }))
    eq("Invalid 'rgb': expected Boolean, got Array",
      pcall_err(meths.ui_attach, 80, 24, { rgb={} }))
    eq("Invalid 'term_name': expected String, got Boolean",
      pcall_err(meths.ui_attach, 80, 24, { term_name=true }))
    eq("Invalid 'term_colors': expected Integer, got Boolean",
      pcall_err(meths.ui_attach, 80, 24, { term_colors=true }))
    eq("Invalid 'term_background': expected String, got Boolean",
      pcall_err(meths.ui_attach, 80, 24, { term_background=true }))
    eq("Invalid 'stdin_fd': expected Integer, got String",
      pcall_err(meths.ui_attach, 80, 24, { stdin_fd='foo' }))
    eq("Invalid 'stdin_tty': expected Boolean, got String",
      pcall_err(meths.ui_attach, 80, 24, { stdin_tty='foo' }))
    eq("Invalid 'stdout_tty': expected Boolean, got String",
      pcall_err(meths.ui_attach, 80, 24, { stdout_tty='foo' }))

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
      '--cmd', 'autocmd UIEnter * :call add(g:evs, "UIEnter") | let g:uienter_ev = deepcopy(v:event)',
      '--cmd', 'autocmd UILeave * :call add(g:evs, "UILeave") | let g:uileave_ev = deepcopy(v:event)',
      '--cmd', 'autocmd VimEnter * :call add(g:evs, "VimEnter")',
    }}
  local screen = Screen.new()
  screen:attach()
  eq({chan=1}, eval('g:uienter_ev'))
  screen:detach()
  eq({chan=1}, eval('g:uileave_ev'))
  eq({
    'VimEnter',
    'UIEnter',
    'UILeave',
  }, eval('g:evs'))
end)

it('autocmds VimSuspend/VimResume #22041', function()
  clear()
  local screen = Screen.new()
  screen:attach()
  exec([[
    let g:ev = []
    autocmd VimResume  * :call add(g:ev, 'r')
    autocmd VimSuspend * :call add(g:ev, 's')
  ]])

  eq(false, screen.suspended)
  feed('<C-Z>')
  screen:expect(function() eq(true, screen.suspended) end)
  eq({ 's' }, eval('g:ev'))
  screen.suspended = false
  feed('<Ignore>')
  eq({ 's', 'r' }, eval('g:ev'))

  command('suspend')
  screen:expect(function() eq(true, screen.suspended) end)
  eq({ 's', 'r', 's' }, eval('g:ev'))
  screen.suspended = false
  meths.input_mouse('move', '', '', 0, 0, 0)
  eq({ 's', 'r', 's', 'r' }, eval('g:ev'))

  feed('<C-Z><C-Z><C-Z>')
  screen:expect(function() eq(true, screen.suspended) end)
  meths.ui_set_focus(false)
  eq({ 's', 'r', 's', 'r', 's' }, eval('g:ev'))
  screen.suspended = false
  meths.ui_set_focus(true)
  eq({ 's', 'r', 's', 'r', 's', 'r' }, eval('g:ev'))

  command('suspend | suspend | suspend')
  screen:expect(function() eq(true, screen.suspended) end)
  screen:detach()
  eq({ 's', 'r', 's', 'r', 's', 'r', 's' }, eval('g:ev'))
  screen.suspended = false
  screen:attach()
  eq({ 's', 'r', 's', 'r', 's', 'r', 's', 'r' }, eval('g:ev'))
end)
