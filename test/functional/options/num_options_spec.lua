-- Tests for :setlocal and :setglobal

local t = require('test.functional.testutil')(after_each)
local clear, feed_command, eval, eq, api = t.clear, t.feed_command, t.eval, t.eq, t.api

local function should_fail(opt, value, errmsg)
  feed_command('setglobal ' .. opt .. '=' .. value)
  eq(errmsg, eval('v:errmsg'):match('E%d*'))
  feed_command('let v:errmsg = ""')
  feed_command('setlocal ' .. opt .. '=' .. value)
  eq(errmsg, eval('v:errmsg'):match('E%d*'))
  feed_command('let v:errmsg = ""')
  local status, err = pcall(api.nvim_set_option_value, opt, value, {})
  eq(false, status)
  eq(errmsg, err:match('E%d*'))
  eq('', eval('v:errmsg'))
end

local function should_succeed(opt, value)
  feed_command('setglobal ' .. opt .. '=' .. value)
  feed_command('setlocal ' .. opt .. '=' .. value)
  api.nvim_set_option_value(opt, value, {})
  eq(value, api.nvim_get_option_value(opt, {}))
  eq('', eval('v:errmsg'))
end

describe(':setlocal', function()
  before_each(clear)

  it('setlocal sets only local value', function()
    eq(0, api.nvim_get_option_value('iminsert', { scope = 'global' }))
    feed_command('setlocal iminsert=1')
    eq(0, api.nvim_get_option_value('iminsert', { scope = 'global' }))
    eq(-1, api.nvim_get_option_value('imsearch', { scope = 'global' }))
    feed_command('setlocal imsearch=1')
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
    feed_command('setglobal window=-10')
    api.nvim_set_option_value('window', -10, {})
    eq(23, api.nvim_get_option_value('window', {}))
    eq('', eval('v:errmsg'))

    -- 'scrolloff' and 'sidescrolloff' can have a -1 value when
    -- set for the current window, but not globally
    feed_command('setglobal scrolloff=-1')
    eq('E487', eval('v:errmsg'):match('E%d*'))

    feed_command('setglobal sidescrolloff=-1')
    eq('E487', eval('v:errmsg'):match('E%d*'))

    feed_command('let v:errmsg=""')

    feed_command('setlocal scrolloff=-1')
    eq('', eval('v:errmsg'))

    feed_command('setlocal sidescrolloff=-1')
    eq('', eval('v:errmsg'))
  end)

  it('set wmh/wh wmw/wiw checks', function()
    feed_command('set winheight=2')
    feed_command('set winminheight=3')
    eq('E591', eval('v:errmsg'):match('E%d*'))

    feed_command('set winwidth=2')
    feed_command('set winminwidth=3')
    eq('E592', eval('v:errmsg'):match('E%d*'))
  end)

  it('set maxcombine resets to 6', function()
    local function setto(value)
      feed_command('setglobal maxcombine=' .. value)
      feed_command('setlocal maxcombine=' .. value)
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
