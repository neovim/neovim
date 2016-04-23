local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local exc_exec = helpers.exc_exec
local get_cur_win_var = helpers.curwinmeths.get_var

describe('setqflist()', function()
  local setqflist = helpers.funcs.setqflist

  before_each(clear)

  it('requires a list for {list}', function()
    eq('Vim(call):E714: List required', exc_exec('call setqflist("foo")'))
    eq('Vim(call):E714: List required', exc_exec('call setqflist(5)'))
    eq('Vim(call):E714: List required', exc_exec('call setqflist({})'))
  end)

  it('requires a string for {action}', function()
    eq('Vim(call):E114: String required', exc_exec('call setqflist([], 5)'))
    eq('Vim(call):E114: String required', exc_exec('call setqflist([], [])'))
    eq('Vim(call):E114: String required', exc_exec('call setqflist([], {})'))
  end)

  it('sets w:quickfix_title', function()
    setqflist({''}, 'r', 'foo')
    command('copen')
    eq(':foo', get_cur_win_var('quickfix_title'))
  end)

  it('requires string or number for {title}', function()
    command('copen')
    setqflist({}, 'r', '5')
    eq(':5', get_cur_win_var('quickfix_title'))
    setqflist({}, 'r', 6)
    eq(':6', get_cur_win_var('quickfix_title'))
    local exc = exc_exec('call setqflist([], "r", function("function"))')
    eq('Vim(call):E729: using Funcref as a String', exc)
    exc = exc_exec('call setqflist([], "r", [])')
    eq('Vim(call):E730: using List as a String', exc)
    exc = exc_exec('call setqflist([], "r", {})')
    eq('Vim(call):E731: using Dictionary as a String', exc)
  end)
end)

describe('setloclist()', function()
  local setloclist = helpers.funcs.setloclist

  before_each(clear)

  it('requires a list for {list}', function()
    eq('Vim(call):E714: List required', exc_exec('call setloclist(0, "foo")'))
    eq('Vim(call):E714: List required', exc_exec('call setloclist(0, 5)'))
    eq('Vim(call):E714: List required', exc_exec('call setloclist(0, {})'))
  end)

  it('requires a string for {action}', function()
    eq('Vim(call):E114: String required', exc_exec('call setloclist(0, [], 5)'))
    eq('Vim(call):E114: String required', exc_exec('call setloclist(0, [], [])'))
    eq('Vim(call):E114: String required', exc_exec('call setloclist(0, [], {})'))
  end)

  it('sets w:quickfix_title for the correct window', function()
    command('rightbelow vsplit')
    setloclist(1, {}, 'r', 'foo')
    setloclist(2, {}, 'r', 'bar')
    command('lopen')
    eq(':bar', get_cur_win_var('quickfix_title'))
    command('lclose | wincmd w | lopen')
    eq(':foo', get_cur_win_var('quickfix_title'))
  end)
end)
