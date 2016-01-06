-- ShaDa variables saving/reading support
local helpers = require('test.functional.helpers')
local meths, funcs, nvim_command, eq, exc_exec =
  helpers.meths, helpers.funcs, helpers.command, helpers.eq, helpers.exc_exec

local shada_helpers = require('test.functional.shada.helpers')
local reset, set_additional_cmd, clear =
  shada_helpers.reset, shada_helpers.set_additional_cmd,
  shada_helpers.clear

describe('ShaDa support code', function()
  before_each(reset)
  after_each(clear)

  it('is able to dump and read back string variable', function()
    meths.set_var('STRVAR', 'foo')
    nvim_command('set shada+=!')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq('foo', meths.get_var('STRVAR'))
  end)

  local autotest = function(tname, varname, varval)
    it('is able to dump and read back ' .. tname .. ' variable automatically',
    function()
      set_additional_cmd('set shada+=!')
      reset()
      meths.set_var(varname, varval)
      -- Exit during `reset` is not a regular exit: it does not write shada 
      -- automatically
      nvim_command('qall')
      reset()
      eq(varval, meths.get_var(varname))
    end)
  end

  autotest('string', 'STRVAR', 'foo')
  autotest('number', 'NUMVAR', 42)
  autotest('float', 'FLTVAR', 42.5)
  autotest('dictionary', 'DCTVAR', {a=10})
  autotest('list', 'LSTVAR', {{a=10}, {b=10.5}, {c='str'}})

  it('does not read back variables without `!` in &shada', function()
    meths.set_var('STRVAR', 'foo')
    nvim_command('set shada+=!')
    nvim_command('wshada')
    set_additional_cmd('set shada-=!')
    reset()
    nvim_command('rshada')
    eq(0, funcs.exists('g:STRVAR'))
  end)

  it('does not dump variables without `!` in &shada', function()
    nvim_command('set shada-=!')
    meths.set_var('STRVAR', 'foo')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq(0, funcs.exists('g:STRVAR'))
  end)

  it('does not dump session variables', function()
    nvim_command('set shada+=!')
    meths.set_var('StrVar', 'foo')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq(0, funcs.exists('g:StrVar'))
  end)

  it('does not dump regular variables', function()
    nvim_command('set shada+=!')
    meths.set_var('str_var', 'foo')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq(0, funcs.exists('g:str_var'))
  end)

  it('dumps and loads variables correctly when &encoding is not UTF-8',
  function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    meths.set_var('STRVAR', '\171')
    meths.set_var('LSTVAR', {'\171'})
    meths.set_var('DCTVAR', {['\171']='\171'})
    meths.set_var('NESTEDVAR', {['\171']={{'\171'}, {['\171']='\171'},
                                {a='Test'}}})
    nvim_command('qall')
    reset()
    eq('\171', meths.get_var('STRVAR'))
    eq({'\171'}, meths.get_var('LSTVAR'))
    eq({['\171']='\171'}, meths.get_var('DCTVAR'))
    eq({['\171']={{'\171'}, {['\171']='\171'}, {a='Test'}}},
       meths.get_var('NESTEDVAR'))
  end)

  it('dumps and loads variables correctly when &encoding /= UTF-8 when dumping',
  function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    meths.set_var('STRVAR', '\171')
    meths.set_var('LSTVAR', {'\171'})
    meths.set_var('DCTVAR', {['\171']='\171'})
    meths.set_var('NESTEDVAR', {['\171']={{'\171'}, {['\171']='\171'},
                                {a='Test'}}})
    set_additional_cmd('')
    nvim_command('qall')
    reset()
    eq('«', meths.get_var('STRVAR'))
    eq({'«'}, meths.get_var('LSTVAR'))
    eq({['«']='«'}, meths.get_var('DCTVAR'))
    eq({['«']={{'«'}, {['«']='«'}, {a='Test'}}}, meths.get_var('NESTEDVAR'))
  end)

  it('dumps and loads variables correctly when &encoding /= UTF-8 when loading',
  function()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    meths.set_var('STRVAR', '«')
    meths.set_var('LSTVAR', {'«'})
    meths.set_var('DCTVAR', {['«']='«'})
    meths.set_var('NESTEDVAR', {['«']={{'«'}, {['«']='«'}, {a='Test'}}})
    set_additional_cmd('set encoding=latin1')
    nvim_command('qall')
    reset()
    eq('\171', meths.get_var('STRVAR'))
    eq({'\171'}, meths.get_var('LSTVAR'))
    eq({['\171']='\171'}, meths.get_var('DCTVAR'))
    eq({['\171']={{'\171'}, {['\171']='\171'}, {a='Test'}}},
       meths.get_var('NESTEDVAR'))
  end)

  it('errors and writes when a funcref is stored in a variable',
  function()
    nvim_command('let F = function("tr")')
    meths.set_var('U', '10')
    nvim_command('set shada+=!')
    set_additional_cmd('set shada+=!')
    eq('Vim(wshada):E951: Error while dumping variable g:F, itself: attempt to dump function reference',
       exc_exec('wshada'))
    meths.set_option('shada', '')
    reset()
    eq('10', meths.get_var('U'))
  end)

  it('errors and writes when a self-referencing list is stored in a variable',
  function()
    meths.set_var('L', {})
    nvim_command('call add(L, L)')
    meths.set_var('U', '10')
    nvim_command('set shada+=!')
    eq('Vim(wshada):E952: Unable to dump variable g:L: container references itself in index 0',
       exc_exec('wshada'))
    meths.set_option('shada', '')
    set_additional_cmd('set shada+=!')
    reset()
    eq('10', meths.get_var('U'))
  end)
end)
