-- ShaDa registers saving/reading support
local helpers = require('test.functional.helpers')
local nvim_command, funcs, eq = helpers.command, helpers.funcs, helpers.eq

local shada_helpers = require('test.functional.shada.helpers')
local reset, set_additional_cmd, clear =
  shada_helpers.reset, shada_helpers.set_additional_cmd,
  shada_helpers.clear

local setreg = function(name, contents, typ)
  if type(contents) == 'string' then
    contents = {contents}
  end
  funcs.setreg(name, contents, typ)
end

local getreg = function(name)
  return {
    funcs.getreg(name, 1, 1),
    funcs.getregtype(name),
  }
end

describe('ShaDa support code', function()
  before_each(reset)
  after_each(clear)

  it('is able to dump and restore registers and their type', function()
    setreg('c', {'d', 'e', ''}, 'c')
    setreg('l', {'a', 'b', 'cde'}, 'l')
    setreg('b', {'bca', 'abc', 'cba'}, 'b3')
    nvim_command('qall')
    reset()
    eq({{'d', 'e', ''}, 'v'}, getreg('c'))
    eq({{'a', 'b', 'cde'}, 'V'}, getreg('l'))
    eq({{'bca', 'abc', 'cba'}, '\0223'}, getreg('b'))
  end)

  it('does not dump registers with zero <', function()
    nvim_command('set shada=\'0,<0')
    setreg('c', {'d', 'e', ''}, 'c')
    setreg('l', {'a', 'b', 'cde'}, 'l')
    setreg('b', {'bca', 'abc', 'cba'}, 'b3')
    nvim_command('qall')
    reset()
    eq({nil, ''}, getreg('c'))
    eq({nil, ''}, getreg('l'))
    eq({nil, ''}, getreg('b'))
  end)

  it('does restore registers with zero <', function()
    setreg('c', {'d', 'e', ''}, 'c')
    setreg('l', {'a', 'b', 'cde'}, 'l')
    setreg('b', {'bca', 'abc', 'cba'}, 'b3')
    set_additional_cmd('set shada=\'0,<0')
    nvim_command('qall')
    reset()
    eq({{'d', 'e', ''}, 'v'}, getreg('c'))
    eq({{'a', 'b', 'cde'}, 'V'}, getreg('l'))
    eq({{'bca', 'abc', 'cba'}, '\0223'}, getreg('b'))
  end)

  it('does not dump registers with zero "', function()
    nvim_command('set shada=\'0,\\"0')
    setreg('c', {'d', 'e', ''}, 'c')
    setreg('l', {'a', 'b', 'cde'}, 'l')
    setreg('b', {'bca', 'abc', 'cba'}, 'b3')
    nvim_command('qall')
    reset()
    eq({nil, ''}, getreg('c'))
    eq({nil, ''}, getreg('l'))
    eq({nil, ''}, getreg('b'))
  end)

  it('does restore registers with zero "', function()
    setreg('c', {'d', 'e', ''}, 'c')
    setreg('l', {'a', 'b', 'cde'}, 'l')
    setreg('b', {'bca', 'abc', 'cba'}, 'b3')
    set_additional_cmd('set shada=\'0,\\"0')
    nvim_command('qall')
    reset()
    eq({{'d', 'e', ''}, 'v'}, getreg('c'))
    eq({{'a', 'b', 'cde'}, 'V'}, getreg('l'))
    eq({{'bca', 'abc', 'cba'}, '\0223'}, getreg('b'))
  end)

  it('does dump registers with zero ", but non-zero <', function()
    nvim_command('set shada=\'0,\\"0,<50')
    setreg('c', {'d', 'e', ''}, 'c')
    setreg('l', {'a', 'b', 'cde'}, 'l')
    setreg('b', {'bca', 'abc', 'cba'}, 'b3')
    nvim_command('qall')
    reset()
    eq({{'d', 'e', ''}, 'v'}, getreg('c'))
    eq({{'a', 'b', 'cde'}, 'V'}, getreg('l'))
    eq({{'bca', 'abc', 'cba'}, '\0223'}, getreg('b'))
  end)

  it('does limit number of lines according to <', function()
    nvim_command('set shada=\'0,<2')
    setreg('o', {'d'}, 'c')
    setreg('t', {'a', 'b', 'cde'}, 'l')
    nvim_command('qall')
    reset()
    eq({{'d'}, 'v'}, getreg('o'))
    eq({nil, ''}, getreg('t'))
  end)

  it('does limit number of lines according to "', function()
    nvim_command('set shada=\'0,\\"2')
    setreg('o', {'d'}, 'c')
    setreg('t', {'a', 'b', 'cde'}, 'l')
    nvim_command('qall')
    reset()
    eq({{'d'}, 'v'}, getreg('o'))
    eq({nil, ''}, getreg('t'))
  end)

  it('does limit number of lines according to < rather then "', function()
    nvim_command('set shada=\'0,\\"2,<3')
    setreg('o', {'d'}, 'c')
    setreg('t', {'a', 'b', 'cde'}, 'l')
    setreg('h', {'abc', 'acb', 'bac', 'bca', 'cab', 'cba'}, 'b3')
    nvim_command('qall')
    reset()
    eq({{'d'}, 'v'}, getreg('o'))
    eq({{'a', 'b', 'cde'}, 'V'}, getreg('t'))
    eq({nil, ''}, getreg('h'))
  end)

  it('dumps and loads register correctly when &encoding is not UTF-8',
  function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    setreg('e', {'\171'}, 'c')
    nvim_command('qall')
    reset()
    eq({{'\171'}, 'v'}, getreg('e'))
  end)

  it('dumps and loads history correctly when &encoding /= UTF-8 when dumping',
  function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    setreg('e', {'\171'}, 'c')
    set_additional_cmd('')
    nvim_command('qall')
    reset()
    eq({{'«'}, 'v'}, getreg('e'))
  end)

  it('dumps and loads history correctly when &encoding /= UTF-8 when loading',
  function()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    setreg('e', {'«'}, 'c')
    set_additional_cmd('set encoding=latin1')
    nvim_command('qall')
    reset()
    eq({{'\171'}, 'v'}, getreg('e'))
  end)
end)
