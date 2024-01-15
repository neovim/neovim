local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local exc_exec = helpers.exc_exec
local get_win_var = helpers.api.nvim_win_get_var

describe('setqflist()', function()
  local setqflist = helpers.fn.setqflist

  before_each(clear)

  it('requires a list for {list}', function()
    eq('Vim(call):E714: List required', exc_exec('call setqflist("foo")'))
    eq('Vim(call):E714: List required', exc_exec('call setqflist(5)'))
    eq('Vim(call):E714: List required', exc_exec('call setqflist({})'))
  end)

  it('requires a string for {action}', function()
    eq('Vim(call):E928: String required', exc_exec('call setqflist([], 5)'))
    eq('Vim(call):E928: String required', exc_exec('call setqflist([], [])'))
    eq('Vim(call):E928: String required', exc_exec('call setqflist([], {})'))
  end)

  it('sets w:quickfix_title', function()
    setqflist({ '' }, 'r', 'foo')
    command('copen')
    eq('foo', get_win_var(0, 'quickfix_title'))
    setqflist({}, 'r', { ['title'] = 'qf_title' })
    eq('qf_title', get_win_var(0, 'quickfix_title'))
  end)

  it('allows string {what} for backwards compatibility', function()
    setqflist({}, 'r', '5')
    command('copen')
    eq('5', get_win_var(0, 'quickfix_title'))
  end)

  it('requires a dict for {what}', function()
    eq(
      'Vim(call):E715: Dictionary required',
      exc_exec('call setqflist([], "r", function("function"))')
    )
  end)
end)

describe('setloclist()', function()
  local setloclist = helpers.fn.setloclist

  before_each(clear)

  it('requires a list for {list}', function()
    eq('Vim(call):E714: List required', exc_exec('call setloclist(0, "foo")'))
    eq('Vim(call):E714: List required', exc_exec('call setloclist(0, 5)'))
    eq('Vim(call):E714: List required', exc_exec('call setloclist(0, {})'))
  end)

  it('requires a string for {action}', function()
    eq('Vim(call):E928: String required', exc_exec('call setloclist(0, [], 5)'))
    eq('Vim(call):E928: String required', exc_exec('call setloclist(0, [], [])'))
    eq('Vim(call):E928: String required', exc_exec('call setloclist(0, [], {})'))
  end)

  it('sets w:quickfix_title for the correct window', function()
    command('rightbelow vsplit')
    setloclist(1, {}, 'r', 'foo')
    setloclist(2, {}, 'r', 'bar')
    command('lopen')
    eq('bar', get_win_var(0, 'quickfix_title'))
    command('lclose | wincmd w | lopen')
    eq('foo', get_win_var(0, 'quickfix_title'))
  end)

  it("doesn't crash when when window is closed in the middle #13721", function()
    helpers.insert([[
    hello world]])

    command('vsplit')
    command('autocmd WinLeave * :call nvim_win_close(0, v:true)')

    command('call setloclist(0, [])')
    command('lopen')

    helpers.assert_alive()
  end)
end)
