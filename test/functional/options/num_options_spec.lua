-- Tests for :setlocal and :setglobal

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, command, eval, eq, api = n.clear, n.command, n.eval, t.eq, n.api
local matches, pcall_err = t.matches, t.pcall_err

local function should_fail(opt, value, errmsg)
  matches(errmsg .. ':', pcall_err(command, 'setglobal ' .. opt .. '=' .. value))
  matches(errmsg .. ':', pcall_err(command, 'setlocal ' .. opt .. '=' .. value))
  matches(errmsg .. ':', pcall_err(api.nvim_set_option_value, opt, value, {}))
end

local function should_succeed(opt, value)
  command('setglobal ' .. opt .. '=' .. value)
  command('setlocal ' .. opt .. '=' .. value)
  api.nvim_set_option_value(opt, value, {})
  eq(value, api.nvim_get_option_value(opt, {}))
end

describe(':setlocal', function()
  before_each(clear)

  it('setlocal sets only local value', function()
    eq(0, api.nvim_get_option_value('iminsert', { scope = 'global' }))
    command('setlocal iminsert=1')
    eq(0, api.nvim_get_option_value('iminsert', { scope = 'global' }))
    eq(-1, api.nvim_get_option_value('imsearch', { scope = 'global' }))
    command('setlocal imsearch=1')
    eq(-1, api.nvim_get_option_value('imsearch', { scope = 'global' }))
  end)
end)

describe(':set validation', function()
  before_each(clear)

  it('setlocal and setglobal validate values', function()
    should_fail('shiftwidth', -10, 'E487')
    should_succeed('shiftwidth', 0)
    should_fail('tabstop', -10, 'E487')
    should_fail('winheight', -10, 'E487')
    should_fail('winheight', 0, 'E487')
    should_fail('winminheight', -1, 'E487')
    should_succeed('winminheight', 0)
    should_fail('winwidth', 0, 'E487')
    should_fail('helpheight', -1, 'E487')
    should_fail('iminsert', 3, 'E474')
    should_fail('imsearch', 3, 'E474')
    should_fail('titlelen', -1, 'E487')
    should_fail('cmdheight', -1, 'E487')
    should_fail('updatecount', -1, 'E487')
    should_fail('textwidth', -1, 'E487')
    should_fail('tabstop', 0, 'E487')
    should_fail('timeoutlen', -1, 'E487')
    should_fail('history', 1000000, 'E474')
    should_fail('regexpengine', -1, 'E474')
    should_fail('regexpengine', 3, 'E474')
    should_succeed('regexpengine', 2)
    should_fail('report', -1, 'E487')
    should_succeed('report', 0)
    should_fail('sidescroll', -1, 'E487')
    should_fail('cmdwinheight', 0, 'E487')
    should_fail('updatetime', -1, 'E487')

    should_fail('foldlevel', -5, 'E487')
    should_fail('foldcolumn', '13', 'E474')
    should_fail('conceallevel', 4, 'E474')
    should_fail('numberwidth', 21, 'E474')
    should_fail('numberwidth', 0, 'E487')

    -- If smaller than 1 this one is set to 'lines'-1
    command('setglobal window=-10')
    api.nvim_set_option_value('window', -10, {})
    eq(23, api.nvim_get_option_value('window', {}))
    eq('', eval('v:errmsg'))

    -- 'scrolloff' and 'sidescrolloff' can have a -1 value when
    -- set for the current window, but not globally
    matches('E487:', pcall_err(command, 'setglobal scrolloff=-1'))
    matches('E487:', pcall_err(command, 'setglobal sidescrolloff=-1'))

    eq(true, pcall(command, 'setlocal scrolloff=-1'))
    eq(true, pcall(command, 'setlocal sidescrolloff=-1'))
  end)

  it('set wmh/wh wmw/wiw checks', function()
    command('set winheight=2')
    matches('E591:', pcall_err(command, 'set winminheight=3'))

    command('set winwidth=2')
    matches('E592:', pcall_err(command, 'set winminwidth=3'))
  end)

  it('set maxcombine resets to 6', function()
    local function setto(value)
      command('setglobal maxcombine=' .. value)
      command('setlocal maxcombine=' .. value)
      api.nvim_set_option_value('maxcombine', value, {})
      eq(6, api.nvim_get_option_value('maxcombine', {}))
      eq('', eval('v:errmsg'))
    end
    setto(0)
    setto(1)
    setto(6)
    setto(7)
  end)
end)
