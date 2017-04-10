-- Tests for :sort command.

local helpers = require('test.functional.helpers')(after_each)

local insert, command, clear, expect, eq, wait = helpers.insert,
  helpers.command, helpers.clear, helpers.expect, helpers.eq, helpers.wait
local exc_exec = helpers.exc_exec

describe(':sort', function()
  local text = [[
    abc
    ab
    a
    a321
    a123
    a122
    b321
    b123
    c123d
     123b
    c321d
    b322b
    b321
    b321b
    ]]
  before_each(clear)

  it('alphabetical', function()
    insert(text)
    wait()
    command('sort')
    expect([[

       123b
      a
      a122
      a123
      a321
      ab
      abc
      b123
      b321
      b321
      b321b
      b322b
      c123d
      c321d]])
  end)

  it('numerical', function()
    insert([[
      abc
      ab
      a321
      a123
      a122
      a
      x-22
      b321
      b123
      c123d
      -24
       123b
      c321d
      0
      b322b
      b321
      b321b
      ]])
    wait()
    command('sort n')
    expect([[
      abc
      ab
      a

      -24
      x-22
      0
      a122
      a123
      b123
      c123d
       123b
      a321
      b321
      c321d
      b321
      b321b
      b322b]])
  end)

  it('hexadecimal', function()
    insert(text)
    wait()
    command('sort x')
    expect([[

      a
      ab
      abc
       123b
      a122
      a123
      a321
      b123
      b321
      b321
      b321b
      b322b
      c123d
      c321d]])
  end)

  it('alphabetical, unique', function()
    insert(text)
    wait()
    command('sort u')
    expect([[

       123b
      a
      a122
      a123
      a321
      ab
      abc
      b123
      b321
      b321b
      b322b
      c123d
      c321d]])
  end)

  it('alphabetical, reverse', function()
    insert(text)
    wait()
    command('sort!')
    expect([[
      c321d
      c123d
      b322b
      b321b
      b321
      b321
      b123
      abc
      ab
      a321
      a123
      a122
      a
       123b
      ]])
  end)

  it('numerical, reverse', function()
    insert(text)
    wait()
    command('sort! n')
    expect([[
      b322b
      b321b
      b321
      c321d
      b321
      a321
       123b
      c123d
      b123
      a123
      a122

      a
      ab
      abc]])
  end)

  it('unique, reverse', function()
    insert(text)
    wait()
    command('sort! u')
    expect([[
      c321d
      c123d
      b322b
      b321b
      b321
      b123
      abc
      ab
      a321
      a123
      a122
      a
       123b
      ]])
  end)

  it('octal', function()
    insert(text)
    wait()
    command('sort o')
    expect([[
      abc
      ab
      a

      a122
      a123
      b123
      c123d
       123b
      a321
      b321
      c321d
      b321
      b321b
      b322b]])
  end)

  it('reverse, hexadecimal', function()
    insert(text)
    wait()
    command('sort! x')
    expect([[
      c321d
      c123d
      b322b
      b321b
      b321
      b321
      b123
      a321
      a123
      a122
       123b
      abc
      ab
      a
      ]])
  end)

  it('alphabetical, skip first character', function()
    insert(text)
    wait()
    command('sort/./')
    expect([[
      a

      a122
      a123
      b123
       123b
      c123d
      a321
      b321
      b321
      b321b
      c321d
      b322b
      ab
      abc]])
  end)

  it('alphabetical, skip first 2 characters', function()
    insert(text)
    wait()
    command('sort/../')
    expect([[
      ab
      a

      a321
      b321
      b321
      b321b
      c321d
      a122
      b322b
      a123
      b123
       123b
      c123d
      abc]])
  end)

  it('alphabetical, unique, skip first 2 characters', function()
    insert(text)
    wait()
    command('sort/../u')
    expect([[
      ab
      a

      a321
      b321
      b321b
      c321d
      a122
      b322b
      a123
      b123
       123b
      c123d
      abc]])
  end)

  it('numerical, skip first character', function()
    insert(text)
    wait()
    command('sort/./n')
    expect([[
      abc
      ab
      a

      a122
      a123
      b123
      c123d
       123b
      a321
      b321
      c321d
      b321
      b321b
      b322b]])
  end)

  it('alphabetical, sort on first character', function()
    insert(text)
    wait()
    command('sort/./r')
    expect([[

       123b
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      b322b
      b321
      b321b
      c123d
      c321d]])
  end)

  it('alphabetical, sort on first 2 characters', function()
    insert(text)
    wait()
    command('sort/../r')
    expect([[
      a

       123b
      a123
      a122
      a321
      abc
      ab
      b123
      b321
      b322b
      b321
      b321b
      c123d
      c321d]])
  end)

  it('numerical, sort on first character', function()
    insert(text)
    wait()
    command('sort/./rn')
    expect([[
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      ]])
  end)

  it('alphabetical, skip past first digit', function()
    insert(text)
    wait()
    command([[sort/\d/]])
    expect([[
      abc
      ab
      a

      a321
      b321
      b321
      b321b
      c321d
      a122
      b322b
      a123
      b123
       123b
      c123d]])
  end)

  it('alphabetical, sort on first digit', function()
    insert(text)
    wait()
    command([[sort/\d/r]])
    expect([[
      abc
      ab
      a

      a123
      a122
      b123
      c123d
       123b
      a321
      b321
      c321d
      b322b
      b321
      b321b]])
  end)

  it('numerical, skip past first digit', function()
    insert(text)
    wait()
    command([[sort/\d/n]])
    expect([[
      abc
      ab
      a

      a321
      b321
      c321d
      b321
      b321b
      a122
      b322b
      a123
      b123
      c123d
       123b]])
  end)

  it('numerical, sort on first digit', function()
    insert(text)
    wait()
    command([[sort/\d/rn]])
    expect([[
      abc
      ab
      a

      a123
      a122
      b123
      c123d
       123b
      a321
      b321
      c321d
      b322b
      b321
      b321b]])
  end)

  it('alphabetical, skip past first 2 digits', function()
    insert(text)
    wait()
    command([[sort/\d\d/]])
    expect([[
      abc
      ab
      a

      a321
      b321
      b321
      b321b
      c321d
      a122
      b322b
      a123
      b123
       123b
      c123d]])
  end)

  it('numerical, skip past first 2 digits', function()
    insert(text)
    wait()
    command([[sort/\d\d/n]])
    expect([[
      abc
      ab
      a

      a321
      b321
      c321d
      b321
      b321b
      a122
      b322b
      a123
      b123
      c123d
       123b]])
  end)

  it('hexadecimal, skip past first 2 digits', function()
    insert(text)
    wait()
    command([[sort/\d\d/x]])
    expect([[
      abc
      ab
      a

      a321
      b321
      b321
      a122
      a123
      b123
      b321b
      c321d
      b322b
       123b
      c123d]])
  end)

  it('alpha, on first 2 digits', function()
    insert(text)
    wait()
    command([[sort/\d\d/r]])
    expect([[
      abc
      ab
      a

      a123
      a122
      b123
      c123d
       123b
      a321
      b321
      c321d
      b322b
      b321
      b321b]])
  end)

  it('numeric, on first 2 digits', function()
    insert(text)
    wait()
    command([[sort/\d\d/rn]])
    expect([[
      abc
      ab
      a

      a123
      a122
      b123
      c123d
       123b
      a321
      b321
      c321d
      b322b
      b321
      b321b]])
  end)

  it('hexadecimal, on first 2 digits', function()
    insert(text)
    wait()
    command([[sort/\d\d/rx]])
    expect([[
      abc
      ab
      a

      a123
      a122
      b123
      c123d
       123b
      a321
      b321
      c321d
      b322b
      b321
      b321b]])
  end)

  it('fails with wrong arguments', function()
    insert(text)
    -- This should fail with "E474: Invalid argument".
    eq('Vim(sort):E474: Invalid argument', exc_exec('sort no'))
    expect(text)
  end)

  it('binary', function()
    insert([[
      0b111000
      0b101100
      0b101001
      0b101001
      0b101000
      0b000000
      0b001000
      0b010000
      0b101000
      0b100000
      0b101010
      0b100010
      0b100100
      0b100010]])
    wait()
    command([[sort b]])
    expect([[
      0b000000
      0b001000
      0b010000
      0b100000
      0b100010
      0b100010
      0b100100
      0b101000
      0b101000
      0b101001
      0b101001
      0b101010
      0b101100
      0b111000]])
  end)

  it('binary with leading characters', function()
    insert([[
      0b100010
      0b010000
       0b101001
      b0b101100
      0b100010
       0b100100
      a0b001000
      0b101000
      0b101000
      a0b101001
      ab0b100000
      0b101010
      0b000000
      b0b111000]])
    wait()
    command([[sort b]])
    expect([[
      0b000000
      a0b001000
      0b010000
      ab0b100000
      0b100010
      0b100010
       0b100100
      0b101000
      0b101000
       0b101001
      a0b101001
      0b101010
      b0b101100
      b0b111000]])
  end)

  it('float', function()
    insert([[
      1.234
      0.88
      123.456
      1.15e-6
      -1.1e3
      -1.01e3]])
    wait()
    command([[sort f]])
    expect([[
      -1.1e3
      -1.01e3
      1.15e-6
      0.88
      1.234
      123.456]])
  end)
end)
