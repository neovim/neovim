-- ShaDa variables saving/reading support
local helpers = require('test.functional.helpers')(after_each)
local meths, funcs, nvim_command, eq, exc_exec =
  helpers.meths, helpers.funcs, helpers.command, helpers.eq, helpers.exc_exec

local shada_helpers = require('test.functional.shada.helpers')
local reset, clear = shada_helpers.reset, shada_helpers.clear

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

  local autotest = function(tname, varname, varval, val_is_expr)
    it('is able to dump and read back ' .. tname .. ' variable automatically',
    function()
      reset('set shada+=!')
      if val_is_expr then
        nvim_command('let g:' .. varname .. ' = ' .. varval)
        varval = meths.get_var(varname)
      else
        meths.set_var(varname, varval)
      end
      -- Exit during `reset` is not a regular exit: it does not write shada
      -- automatically
      nvim_command('qall')
      reset('set shada+=!')
      eq(varval, meths.get_var(varname))
    end)
  end

  autotest('string', 'STRVAR', 'foo')
  autotest('number', 'NUMVAR', 42)
  autotest('float', 'FLTVAR', 42.5)
  autotest('dictionary', 'DCTVAR', {a=10})
  autotest('list', 'LSTVAR', {{a=10}, {b=10.5}, {c='str'}})
  autotest('true', 'TRUEVAR', true)
  autotest('false', 'FALSEVAR', false)
  autotest('null', 'NULLVAR', 'v:null', true)
  autotest('ext', 'EXTVAR', '{"_TYPE": v:msgpack_types.ext, "_VAL": [2, ["", ""]]}', true)

  it('does not read back variables without `!` in &shada', function()
    meths.set_var('STRVAR', 'foo')
    nvim_command('set shada+=!')
    nvim_command('wshada')
    reset('set shada-=!')
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

  it('dumps and loads variables correctly with utf-8 strings',
  function()
    reset()
    meths.set_var('STRVAR', '«')
    meths.set_var('LSTVAR', {'«'})
    meths.set_var('DCTVAR', {['«']='«'})
    meths.set_var('NESTEDVAR', {['«']={{'«'}, {['«']='«'}, {a='Test'}}})
    nvim_command('qall')
    reset()
    eq('«', meths.get_var('STRVAR'))
    eq({'«'}, meths.get_var('LSTVAR'))
    eq({['«']='«'}, meths.get_var('DCTVAR'))
    eq({['«']={{'«'}, {['«']='«'}, {a='Test'}}}, meths.get_var('NESTEDVAR'))
  end)

  it('dumps and loads variables correctly with 8-bit strings',
  function()
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    -- This is invalid unicode, but we should still dump and restore it.
    meths.set_var('STRVAR', '\171')
    meths.set_var('LSTVAR', {'\171'})
    meths.set_var('DCTVAR', {['«\171']='«\171'})
    meths.set_var('NESTEDVAR', {['\171']={{'\171«'}, {['\171']='\171'},
                                {a='Test'}}})
    nvim_command('qall')
    reset()
    eq('\171', meths.get_var('STRVAR'))
    eq({'\171'}, meths.get_var('LSTVAR'))
    eq({['«\171']='«\171'}, meths.get_var('DCTVAR'))
    eq({['\171']={{'\171«'}, {['\171']='\171'}, {a='Test'}}},
       meths.get_var('NESTEDVAR'))
  end)

  it('errors and writes when a funcref is stored in a variable',
  function()
    nvim_command('let F = function("tr")')
    meths.set_var('U', '10')
    nvim_command('set shada+=!')
    eq('Vim(wshada):E5004: Error while dumping variable g:F, itself: attempt to dump function reference',
       exc_exec('wshada'))
    meths.set_option('shada', '')
    reset('set shada+=!')
    eq('10', meths.get_var('U'))
  end)

  it('errors and writes when a self-referencing list is stored in a variable',
  function()
    meths.set_var('L', {})
    nvim_command('call add(L, L)')
    meths.set_var('U', '10')
    nvim_command('set shada+=!')
    eq('Vim(wshada):E5005: Unable to dump variable g:L: container references itself in index 0',
       exc_exec('wshada'))
    meths.set_option('shada', '')
    reset('set shada+=!')
    eq('10', meths.get_var('U'))
  end)
end)
