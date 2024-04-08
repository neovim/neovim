local t = require('test.functional.testutil')(after_each)

local clear = t.clear
local command = t.command
local eq = t.eq
local exc_exec = t.exc_exec
local get_win_var = t.api.nvim_win_get_var

describe('setqflist()', function()
  local setqflist = t.fn.setqflist

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
  local setloclist = t.fn.setloclist

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
    t.insert([[
    hello world]])

    command('vsplit')
    command('autocmd WinLeave * :call nvim_win_close(0, v:true)')

    command('call setloclist(0, [])')
    command('lopen')

    t.assert_alive()
  end)
end)
