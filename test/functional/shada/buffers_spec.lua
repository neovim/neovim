-- ShaDa buffer list saving/reading support
local helpers = require('test.functional.helpers')
local nvim_command, funcs, eq =
  helpers.command, helpers.funcs, helpers.eq

local shada_helpers = require('test.functional.shada.helpers')
local reset, set_additional_cmd, clear =
  shada_helpers.reset, shada_helpers.set_additional_cmd,
  shada_helpers.clear

describe('ShaDa support code', function()
  testfilename = 'Xtestfile-functional-shada-buffers'
  testfilename_2 = 'Xtestfile-functional-shada-buffers-2'
  before_each(reset)
  after_each(clear)

  it('is able to dump and restore buffer list', function()
    set_additional_cmd('set shada+=%')
    reset()
    nvim_command('edit ' .. testfilename)
    nvim_command('edit ' .. testfilename_2)
    nvim_command('qall')
    reset()
    eq(3, funcs.bufnr('$'))
    eq('', funcs.bufname(1))
    eq(testfilename, funcs.bufname(2))
    eq(testfilename_2, funcs.bufname(3))
  end)

  it('does not restore buffer list without % in &shada', function()
    set_additional_cmd('set shada+=%')
    reset()
    nvim_command('edit ' .. testfilename)
    nvim_command('edit ' .. testfilename_2)
    set_additional_cmd('')
    nvim_command('qall')
    reset()
    eq(1, funcs.bufnr('$'))
    eq('', funcs.bufname(1))
  end)

  it('does not dump buffer list without % in &shada', function()
    nvim_command('edit ' .. testfilename)
    nvim_command('edit ' .. testfilename_2)
    set_additional_cmd('set shada+=%')
    nvim_command('qall')
    reset()
    eq(1, funcs.bufnr('$'))
    eq('', funcs.bufname(1))
  end)
end)
