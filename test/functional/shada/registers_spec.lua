-- ShaDa registers saving/reading support
local helpers = require('test.functional.helpers')(after_each)
local nvim_command, funcs, eq = helpers.command, helpers.funcs, helpers.eq

local shada_helpers = require('test.functional.shada.helpers')
local reset, clear = shada_helpers.reset, shada_helpers.clear

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
    eq({{}, ''}, getreg('c'))
    eq({{}, ''}, getreg('l'))
    eq({{}, ''}, getreg('b'))
  end)

  it('does restore registers with zero <', function()
    setreg('c', {'d', 'e', ''}, 'c')
    setreg('l', {'a', 'b', 'cde'}, 'l')
    setreg('b', {'bca', 'abc', 'cba'}, 'b3')
    nvim_command('qall')
    reset('set shada=\'0,<0')
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
    eq({{}, ''}, getreg('c'))
    eq({{}, ''}, getreg('l'))
    eq({{}, ''}, getreg('b'))
  end)

  it('does restore registers with zero "', function()
    setreg('c', {'d', 'e', ''}, 'c')
    setreg('l', {'a', 'b', 'cde'}, 'l')
    setreg('b', {'bca', 'abc', 'cba'}, 'b3')
    nvim_command('qall')
    reset('set shada=\'0,\\"0')
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
    eq({{}, ''}, getreg('t'))
  end)

  it('does limit number of lines according to "', function()
    nvim_command('set shada=\'0,\\"2')
    setreg('o', {'d'}, 'c')
    setreg('t', {'a', 'b', 'cde'}, 'l')
    nvim_command('qall')
    reset()
    eq({{'d'}, 'v'}, getreg('o'))
    eq({{}, ''}, getreg('t'))
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
    eq({{}, ''}, getreg('h'))
  end)

  it('dumps and loads register correctly with utf-8 contents',
  function()
    reset()
    setreg('e', {'«'}, 'c')
    nvim_command('qall')
    reset()
    eq({{'«'}, 'v'}, getreg('e'))
  end)

  it('dumps and loads history correctly with 8-bit single-byte',
  function()
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    setreg('e', {'\171«'}, 'c')
    nvim_command('qall')
    reset()
    eq({{'\171«'}, 'v'}, getreg('e'))
  end)

  it('has a blank unnamed register if it wasn\'t set and register 0 is empty',
  function()
    setreg('1', {'one'}, 'c')
    setreg('2', {'two'}, 'c')
    setreg('a', {'a'}, 'c')
    nvim_command('qall')
    reset()
    eq({{}, ''}, getreg('0'))
    eq({{'one'}, 'v'}, getreg('1'))
    eq({{}, ''}, getreg('"'))
    eq({{'a'}, 'v'}, getreg('a'))
  end)

  it('defaults the unnamed register to register 0 if it wasn\'t set',
  function()
    setreg('0', {'zero'}, 'c')
    setreg('1', {'one'}, 'c')
    setreg('2', {'two'}, 'c')
    nvim_command('qall')
    reset()
    eq({{'zero'}, 'v'}, getreg('0'))
    eq({{'one'}, 'v'}, getreg('1'))
    eq({{'zero'}, 'v'}, getreg('"'))
  end)

  it('remembers which register was the unnamed register when loading',
  function()
    setreg('0', {'zero'}, 'c')
    setreg('1', {'one'}, 'cu')
    setreg('2', {'two'}, 'c')
    nvim_command('qall')
    reset()
    eq({{'zero'}, 'v'}, getreg('0'))
    eq({{'one'}, 'v'}, getreg('1'))
    eq({{'one'}, 'v'}, getreg('"'))
  end)
end)
