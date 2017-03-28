-- Tests for :setlocal and :setglobal

local helpers = require('test.functional.helpers')(after_each)
local clear, execute, eval, eq, nvim =
  helpers.clear, helpers.execute, helpers.eval, helpers.eq, helpers.nvim

local function get_num_option_global(opt)
  return nvim('command_output', 'setglobal ' .. opt .. '?'):match('%d+')
end

local function should_fail(opt, value, errmsg)
  execute('let v:errmsg = ""')
  execute('setglobal ' .. opt .. '=' .. value)
  eq(errmsg, eval("v:errmsg"):match("E%d*"))
  execute('let v:errmsg = ""')
  execute('setlocal ' .. opt .. '=' .. value)
  eq(errmsg, eval("v:errmsg"):match("E%d*"))
  execute('let v:errmsg = ""')
end

describe(':setlocal', function()
  before_each(clear)

  it('setlocal sets only local value', function()
    eq('0', get_num_option_global('iminsert'))
    execute('setlocal iminsert=1')
    eq('0', get_num_option_global('iminsert'))
    eq('0', get_num_option_global('imsearch'))
    execute('setlocal imsearch=1')
    eq('0', get_num_option_global('imsearch'))
  end)
end)

describe(':set validation', function()
  before_each(clear)

  it('setlocal and setglobal validate values', function()
    should_fail('shiftwidth', -10, 'E487')
    should_fail('tabstop', -10, 'E487')
    should_fail('winheight', -10, 'E487')
    should_fail('helpheight', -10, 'E487')
    should_fail('maxcombine', 10, 'E474')
    should_fail('history', 1000000, 'E474')
    should_fail('regexpengine', 3, 'E474')

    should_fail('foldlevel', -5, 'E487')
    should_fail('foldcolumn', 100, 'E474')
    should_fail('conceallevel', 4, 'E474')
    should_fail('numberwidth', 20, 'E474')
  end)

  it('set wmh/wh wmw/wiw checks', function()
    execute('set winheight=2')
    execute('set winminheight=3')
    eq('E591', eval("v:errmsg"):match("E%d*"))

    execute('set winwidth=2')
    execute('set winminwidth=3')
    eq('E592', eval("v:errmsg"):match("E%d*"))
  end)
end)
