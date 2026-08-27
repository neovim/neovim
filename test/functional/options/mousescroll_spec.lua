local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local command = n.command
local clear = n.clear
local eval = n.eval
local eq = t.eq
local pcall_err = t.pcall_err
local feed = n.feed

local scroll = function(direction)
  return n.request('nvim_input_mouse', 'wheel', direction, '', 0, 2, 2)
end

local screenrow = function()
  return n.call('screenrow')
end

local screencol = function()
  return n.call('screencol')
end

describe("'mousescroll'", function()
  local function should_fail(val, msg)
    eq(msg, pcall_err(command, 'set mousescroll=' .. val))
  end

  local function should_succeed(val)
    command('set mousescroll=' .. val)
  end

  before_each(function()
    clear()
    command('set nowrap lines=20 columns=20 virtualedit=all')
    feed('100o<Esc>50G10|')
  end)

  it('handles invalid values', function()
    -- empty string (no direction set)
    should_fail('', 'Vim(set):E474: Invalid argument: mousescroll=')
    -- unknown direction
    should_fail('foo:123', "Vim(set):E474: Unknown item 'foo': mousescroll=foo:123")
    -- integer overflow
    should_fail(
      'ver:99999999999999999999',
      "Vim(set):E474: 'ver' number is out of range: mousescroll=ver:99999999999999999999"
    )
    -- expected digit
    should_fail('ver:bar', "Vim(set):E474: 'ver' requires a number: mousescroll=ver:bar")
    -- negative count
    should_fail('ver:-1', "Vim(set):E474: 'ver' requires a number: mousescroll=ver:-1")
  end)

  it('handles valid values', function()
    should_succeed('hor:1,ver:1') -- both directions set
    should_succeed('hor:1') -- only horizontal
    should_succeed('ver:1') -- only vertical
    should_succeed('hor:0,ver:0') -- zero
    should_succeed('hor:2147483647') -- large count
    should_succeed('hor:1,hor:2') -- duplicate direction: last wins
  end)

  it('default set correctly', function()
    eq('ver:3,hor:6', eval('&mousescroll'))

    eq(10, screenrow())
    scroll('up')
    eq(13, screenrow())
    scroll('down')
    eq(10, screenrow())

    eq(10, screencol())
    scroll('right')
    eq(4, screencol())
    scroll('left')
    eq(10, screencol())
  end)

  it('vertical scrolling falls back to default value', function()
    command('set mousescroll=hor:1')
    eq(10, screenrow())
    scroll('up')
    eq(13, screenrow())
  end)

  it('horizontal scrolling falls back to default value', function()
    command('set mousescroll=ver:1')
    eq(10, screencol())
    scroll('right')
    eq(4, screencol())
  end)

  it('count of zero disables mouse scrolling', function()
    command('set mousescroll=hor:0,ver:0')

    eq(10, screenrow())
    scroll('up')
    eq(10, screenrow())
    scroll('down')
    eq(10, screenrow())

    eq(10, screencol())
    scroll('right')
    eq(10, screencol())
    scroll('left')
    eq(10, screencol())

    -- vertical scrolling is still disabled with non-zero 'scrolloff' value
    command('set scrolloff=1')

    eq(10, screenrow())
    scroll('up')
    eq(10, screenrow())
    scroll('down')
    eq(10, screenrow())

    -- also in insert mode
    feed('i')

    eq(10, screenrow())
    scroll('up')
    eq(10, screenrow())
    scroll('down')
    eq(10, screenrow())
  end)

  local test_vertical_scrolling = function()
    eq(10, screenrow())

    command('set mousescroll=ver:1')
    scroll('up')
    eq(11, screenrow())

    command('set mousescroll=ver:2')
    scroll('down')
    eq(9, screenrow())

    command('set mousescroll=ver:5')
    scroll('up')
    eq(14, screenrow())
  end

  it('controls vertical scrolling in normal mode', function()
    test_vertical_scrolling()
  end)

  it('controls vertical scrolling in insert mode', function()
    feed('i')
    test_vertical_scrolling()
  end)

  local test_horizontal_scrolling = function()
    eq(10, screencol())

    command('set mousescroll=hor:1')
    scroll('right')
    eq(9, screencol())

    command('set mousescroll=hor:3')
    scroll('right')
    eq(6, screencol())

    command('set mousescroll=hor:2')
    scroll('left')
    eq(8, screencol())
  end

  it('controls horizontal scrolling in normal mode', function()
    test_horizontal_scrolling()
  end)

  it('controls horizontal scrolling in insert mode', function()
    feed('i')
    test_horizontal_scrolling()
  end)
end)
