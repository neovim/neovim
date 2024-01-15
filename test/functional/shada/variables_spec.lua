-- ShaDa variables saving/reading support
local helpers = require('test.functional.helpers')(after_each)
local api, fn, nvim_command, eq, eval =
  helpers.api, helpers.fn, helpers.command, helpers.eq, helpers.eval
local expect_exit = helpers.expect_exit

local shada_helpers = require('test.functional.shada.helpers')
local reset, clear = shada_helpers.reset, shada_helpers.clear

describe('ShaDa support code', function()
  before_each(reset)
  after_each(clear)

  it('is able to dump and read back string variable', function()
    api.nvim_set_var('STRVAR', 'foo')
    nvim_command('set shada+=!')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq('foo', api.nvim_get_var('STRVAR'))
  end)

  local autotest = function(tname, varname, varval, val_is_expr)
    it('is able to dump and read back ' .. tname .. ' variable automatically', function()
      reset('set shada+=!')
      if val_is_expr then
        nvim_command('let g:' .. varname .. ' = ' .. varval)
        varval = api.nvim_get_var(varname)
      else
        api.nvim_set_var(varname, varval)
      end
      local vartype = eval('type(g:' .. varname .. ')')
      -- Exit during `reset` is not a regular exit: it does not write shada
      -- automatically
      expect_exit(nvim_command, 'qall')
      reset('set shada+=!')
      eq(vartype, eval('type(g:' .. varname .. ')'))
      eq(varval, api.nvim_get_var(varname))
    end)
  end

  autotest('string', 'STRVAR', 'foo')
  autotest('number', 'NUMVAR', 42)
  autotest('float', 'FLTVAR', 42.5)
  autotest('dictionary', 'DCTVAR', { a = 10 })
  autotest('list', 'LSTVAR', { { a = 10 }, { b = 10.5 }, { c = 'str' } })
  autotest('true', 'TRUEVAR', true)
  autotest('false', 'FALSEVAR', false)
  autotest('null', 'NULLVAR', 'v:null', true)
  autotest('ext', 'EXTVAR', '{"_TYPE": v:msgpack_types.ext, "_VAL": [2, ["", ""]]}', true)
  autotest('blob', 'BLOBVAR', '0z12ab34cd', true)
  autotest('blob (with NULs)', 'BLOBVARNULS', '0z004e554c7300', true)

  it('does not read back variables without `!` in &shada', function()
    api.nvim_set_var('STRVAR', 'foo')
    nvim_command('set shada+=!')
    nvim_command('wshada')
    reset('set shada-=!')
    nvim_command('rshada')
    eq(0, fn.exists('g:STRVAR'))
  end)

  it('does not dump variables without `!` in &shada', function()
    nvim_command('set shada-=!')
    api.nvim_set_var('STRVAR', 'foo')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq(0, fn.exists('g:STRVAR'))
  end)

  it('does not dump session variables', function()
    nvim_command('set shada+=!')
    api.nvim_set_var('StrVar', 'foo')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq(0, fn.exists('g:StrVar'))
  end)

  it('does not dump regular variables', function()
    nvim_command('set shada+=!')
    api.nvim_set_var('str_var', 'foo')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq(0, fn.exists('g:str_var'))
  end)

  it('dumps and loads variables correctly with utf-8 strings', function()
    reset()
    api.nvim_set_var('STRVAR', '«')
    api.nvim_set_var('LSTVAR', { '«' })
    api.nvim_set_var('DCTVAR', { ['«'] = '«' })
    api.nvim_set_var('NESTEDVAR', { ['«'] = { { '«' }, { ['«'] = '«' }, { a = 'Test' } } })
    expect_exit(nvim_command, 'qall')
    reset()
    eq('«', api.nvim_get_var('STRVAR'))
    eq({ '«' }, api.nvim_get_var('LSTVAR'))
    eq({ ['«'] = '«' }, api.nvim_get_var('DCTVAR'))
    eq({ ['«'] = { { '«' }, { ['«'] = '«' }, { a = 'Test' } } }, api.nvim_get_var('NESTEDVAR'))
  end)

  it('dumps and loads variables correctly with 8-bit strings', function()
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    -- This is invalid unicode, but we should still dump and restore it.
    api.nvim_set_var('STRVAR', '\171')
    api.nvim_set_var('LSTVAR', { '\171' })
    api.nvim_set_var('DCTVAR', { ['«\171'] = '«\171' })
    api.nvim_set_var(
      'NESTEDVAR',
      { ['\171'] = { { '\171«' }, { ['\171'] = '\171' }, { a = 'Test' } } }
    )
    expect_exit(nvim_command, 'qall')
    reset()
    eq('\171', api.nvim_get_var('STRVAR'))
    eq({ '\171' }, api.nvim_get_var('LSTVAR'))
    eq({ ['«\171'] = '«\171' }, api.nvim_get_var('DCTVAR'))
    eq(
      { ['\171'] = { { '\171«' }, { ['\171'] = '\171' }, { a = 'Test' } } },
      api.nvim_get_var('NESTEDVAR')
    )
  end)

  it('ignore when a funcref is stored in a variable', function()
    nvim_command('let F = function("tr")')
    api.nvim_set_var('U', '10')
    nvim_command('set shada+=!')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq('10', api.nvim_get_var('U'))
  end)

  it('ignore when a partial is stored in a variable', function()
    nvim_command('let P = { -> 1 }')
    api.nvim_set_var('U', '10')
    nvim_command('set shada+=!')
    nvim_command('wshada')
    reset()
    nvim_command('set shada+=!')
    nvim_command('rshada')
    eq('10', api.nvim_get_var('U'))
  end)

  it('ignore when a self-referencing list is stored in a variable', function()
    api.nvim_set_var('L', {})
    nvim_command('call add(L, L)')
    api.nvim_set_var('U', '10')
    nvim_command('set shada+=!')
    nvim_command('wshada')
    reset()
    nvim_command('rshada')
    eq('10', api.nvim_get_var('U'))
  end)
end)
