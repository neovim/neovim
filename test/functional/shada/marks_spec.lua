-- ShaDa marks saving/reading support
local helpers = require('test.functional.helpers')
local nvim, nvim_window, nvim_curwin, nvim_command, nvim_eval, eq =
  helpers.nvim, helpers.window, helpers.curwin, helpers.command, helpers.eval,
  helpers.eq

local shada_helpers = require('test.functional.shada.helpers')
local reset, set_additional_cmd, clear =
  shada_helpers.reset, shada_helpers.set_additional_cmd,
  shada_helpers.clear

local nvim_current_line = function()
  return nvim_window('get_cursor', nvim_curwin())[1]
end

describe('ShaDa support code', function()
  testfilename = 'Xtestfile-functional-shada-marks'
  before_each(function()
    reset()
    local fd = io.open(testfilename, 'w')
    fd:write('test\n')
    fd:write('test2\n')
    fd:close()
  end)
  after_each(function()
    clear()
    os.remove(testfilename)
  end)

  it('is able to dump and read back global mark', function()
    nvim_command('edit ' .. testfilename)
    nvim_command('mark A')
    nvim_command('2')
    nvim_command('kB')
    nvim_command('wviminfo')
    reset()
    nvim_command('rviminfo')
    nvim_command('normal! `A')
    eq(testfilename, nvim_eval('fnamemodify(@%, ":t")'))
    eq(1, nvim_current_line())
    nvim_command('normal! `B')
    eq(2, nvim_current_line())
  end)

  it('does not read back global mark without `f0` in viminfo', function()
    nvim_command('edit ' .. testfilename)
    nvim_command('mark A')
    nvim_command('2')
    nvim_command('kB')
    nvim_command('wviminfo')
    set_additional_cmd('set viminfo+=f0')
    reset()
    nvim_command('language C')
    nvim_command([[
      try
        execute "normal! `A"
      catch
        let exception = v:exception
      endtry]])
    eq('Vim(normal):E20: Mark not set', nvim('get_var', 'exception'))
  end)

  it('is able to dump and read back local mark', function()
    nvim_command('edit ' .. testfilename)
    nvim_command('mark a')
    nvim_command('2')
    nvim_command('kb')
    nvim_command('qall')
    reset()
    nvim_command('edit ' .. testfilename)
    nvim_command('normal! `a')
    eq(testfilename, nvim_eval('fnamemodify(@%, ":t")'))
    eq(1, nvim_current_line())
    nvim_command('normal! `b')
    eq(2, nvim_current_line())
  end)
end)
