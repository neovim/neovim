-- Tests for :setlocal and :setglobal

local helpers = require('test.functional.helpers')(after_each)
local clear, execute, eval, eq, nvim =
  helpers.clear, helpers.execute, helpers.eval, helpers.eq, helpers.nvim

local function get_num_option_global(opt)
  return nvim('command_output', 'setglobal ' .. opt .. '?'):match('%d+')
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
