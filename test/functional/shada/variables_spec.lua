-- ShaDa variables saving/reading support
local helpers = require('test.functional.helpers')
local nvim, nvim_command, nvim_eval, eq =
  helpers.nvim, helpers.command, helpers.eval, helpers.eq

local shada_helpers = require('test.functional.shada.helpers')
local reset, set_additional_cmd, clear =
  shada_helpers.reset, shada_helpers.set_additional_cmd,
  shada_helpers.clear

describe('ShaDa support code', function()
  before_each(reset)
  after_each(clear)

  it('is able to dump and read back string variable', function()
    nvim('set_var', 'STRVAR', 'foo')
    nvim_command('set viminfo+=!')
    nvim_command('wviminfo')
    reset()
    nvim_command('set viminfo+=!')
    nvim_command('rviminfo')
    eq('foo', nvim('get_var', 'STRVAR'))
  end)

  local autotest = function(tname, varname, varval)
    it('is able to dump and read back ' .. tname .. ' variable automatically',
    function()
      set_additional_cmd('set viminfo+=!')
      reset()
      nvim('set_var', varname, varval)
      -- Exit during `reset` is not a regular exit: it does not write viminfo 
      -- automatically
      nvim_command('qall')
      reset()
      eq(varval, nvim('get_var', varname))
    end)
  end

  autotest('string', 'STRVAR', 'foo')
  autotest('number', 'NUMVAR', 42)
  autotest('float', 'FLTVAR', 42.5)
  autotest('dictionary', 'DCTVAR', {a=10})
  autotest('list', 'LSTVAR', {{a=10}, {b=10.5}, {c='str'}})

  it('does not read back variables without `!` in &viminfo', function()
    nvim('set_var', 'STRVAR', 'foo')
    nvim_command('set viminfo+=!')
    nvim_command('wviminfo')
    set_additional_cmd('set viminfo-=!')
    reset()
    nvim_command('rviminfo')
    eq(0, nvim_eval('exists("g:STRVAR")'))
  end)

  it('does not dump variables without `!` in &viminfo', function()
    nvim_command('set viminfo-=!')
    nvim('set_var', 'STRVAR', 'foo')
    nvim_command('wviminfo')
    reset()
    nvim_command('set viminfo+=!')
    nvim_command('rviminfo')
    eq(0, nvim_eval('exists("g:STRVAR")'))
  end)

  it('does not dump session variables', function()
    nvim_command('set viminfo+=!')
    nvim('set_var', 'StrVar', 'foo')
    nvim_command('wviminfo')
    reset()
    nvim_command('set viminfo+=!')
    nvim_command('rviminfo')
    eq(0, nvim_eval('exists("g:StrVar")'))
  end)

  it('does not dump regular variables', function()
    nvim_command('set viminfo+=!')
    nvim('set_var', 'str_var', 'foo')
    nvim_command('wviminfo')
    reset()
    nvim_command('set viminfo+=!')
    nvim_command('rviminfo')
    eq(0, nvim_eval('exists("g:str_var")'))
  end)
end)
