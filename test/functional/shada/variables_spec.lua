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
    nvim_command('set shada+=!')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq('foo', nvim('get_var', 'STRVAR'))
  end)

  local autotest = function(tname, varname, varval)
    it('is able to dump and read back ' .. tname .. ' variable automatically',
    function()
      set_additional_cmd('set shada+=!')
      reset()
      nvim('set_var', varname, varval)
      -- Exit during `reset` is not a regular exit: it does not write shada 
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

  it('does not read back variables without `!` in &shada', function()
    nvim('set_var', 'STRVAR', 'foo')
    nvim_command('set shada+=!')
    nvim_command('wshada')
    set_additional_cmd('set shada-=!')
    reset()
    nvim_command('rshada')
    eq(0, nvim_eval('exists("g:STRVAR")'))
  end)

  it('does not dump variables without `!` in &shada', function()
    nvim_command('set shada-=!')
    nvim('set_var', 'STRVAR', 'foo')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq(0, nvim_eval('exists("g:STRVAR")'))
  end)

  it('does not dump session variables', function()
    nvim_command('set shada+=!')
    nvim('set_var', 'StrVar', 'foo')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq(0, nvim_eval('exists("g:StrVar")'))
  end)

  it('does not dump regular variables', function()
    nvim_command('set shada+=!')
    nvim('set_var', 'str_var', 'foo')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq(0, nvim_eval('exists("g:str_var")'))
  end)

  it('dumps and loads variables correctly when &encoding is not UTF-8',
  function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim('set_var', 'STRVAR', '\171')
    nvim('set_var', 'LSTVAR', {'\171'})
    nvim('set_var', 'DCTVAR', {['\171']='\171'})
    nvim('set_var', 'NESTEDVAR', {['\171']={{'\171'}, {['\171']='\171'},
                                  {a='Test'}}})
    nvim_command('qall')
    reset()
    eq('\171', nvim('get_var', 'STRVAR'))
    eq({'\171'}, nvim('get_var', 'LSTVAR'))
    eq({['\171']='\171'}, nvim('get_var', 'DCTVAR'))
    eq({['\171']={{'\171'}, {['\171']='\171'}, {a='Test'}}},
       nvim('get_var', 'NESTEDVAR'))
  end)

  it('dumps and loads variables correctly when &encoding /= UTF-8 when dumping',
  function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim('set_var', 'STRVAR', '\171')
    nvim('set_var', 'LSTVAR', {'\171'})
    nvim('set_var', 'DCTVAR', {['\171']='\171'})
    nvim('set_var', 'NESTEDVAR', {['\171']={{'\171'}, {['\171']='\171'},
                                  {a='Test'}}})
    set_additional_cmd('')
    nvim_command('qall')
    reset()
    eq('«', nvim('get_var', 'STRVAR'))
    eq({'«'}, nvim('get_var', 'LSTVAR'))
    eq({['«']='«'}, nvim('get_var', 'DCTVAR'))
    eq({['«']={{'«'}, {['«']='«'}, {a='Test'}}}, nvim('get_var', 'NESTEDVAR'))
  end)

  it('dumps and loads variables correctly when &encoding /= UTF-8 when loading',
  function()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim('set_var', 'STRVAR', '«')
    nvim('set_var', 'LSTVAR', {'«'})
    nvim('set_var', 'DCTVAR', {['«']='«'})
    nvim('set_var', 'NESTEDVAR', {['«']={{'«'}, {['«']='«'}, {a='Test'}}})
    set_additional_cmd('set encoding=latin1')
    nvim_command('qall')
    reset()
    eq('\171', nvim('get_var', 'STRVAR'))
    eq({'\171'}, nvim('get_var', 'LSTVAR'))
    eq({['\171']='\171'}, nvim('get_var', 'DCTVAR'))
    eq({['\171']={{'\171'}, {['\171']='\171'}, {a='Test'}}},
       nvim('get_var', 'NESTEDVAR'))
  end)
end)
