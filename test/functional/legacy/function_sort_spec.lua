local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local neq = helpers.neq
local eval = helpers.eval
local clear = helpers.clear
local source = helpers.source
local exc_exec = helpers.exc_exec

describe('sort', function()
  before_each(clear)

  it('numbers compared as strings', function()
    eq({1, 2, 3}, eval('sort([3, 2, 1])'))
    eq({13, 28, 3}, eval('sort([3, 28, 13])'))
  end)

  it('numbers compared as numeric', function()
    eq({1, 2, 3}, eval("sort([3, 2, 1], 'n')"))
    eq({3, 13, 28}, eval("sort([3, 28, 13], 'n')"))
    -- Strings are not sorted.
    eq({'13', '28', '3'}, eval("sort(['13', '28', '3'], 'n')"))
  end)

  it('numbers compared as numbers', function()
    eq({3, 13, 28}, eval("sort([13, 28, 3], 'N')"))
    eq({'3', '13', '28'}, eval("sort(['13', '28', '3'], 'N')"))
  end)

  it('numbers compared as float', function()
    eq({0.28, 3, 13.5}, eval("sort([13.5, 0.28, 3], 'f')"))
  end)

  it('ability to call sort() from a compare function', function()
    source([[
      function Compare1(a, b) abort
        call sort(range(3), 'Compare2')
        return a:a - a:b
      endfunc

      function Compare2(a, b) abort
        return a:a - a:b
      endfunc
    ]])

    eq({1, 3, 5}, eval("sort([3, 1, 5], 'Compare1')"))
  end)

  it('default sort', function()
    -- docs say omitted, empty or zero argument sorts on string representation
    eq({'2', 'A', 'AA', 'a', 1, 3.3}, eval('sort([3.3, 1, "2", "A", "a", "AA"])'))
    eq({'2', 'A', 'AA', 'a', 1, 3.3}, eval([[sort([3.3, 1, "2", "A", "a", "AA"], '')]]))
    eq({'2', 'A', 'AA', 'a', 1, 3.3}, eval('sort([3.3, 1, "2", "A", "a", "AA"], 0)'))
    eq({'2', 'A', 'a', 'AA', 1, 3.3}, eval('sort([3.3, 1, "2", "A", "a", "AA"], 1)'))
    neq(exc_exec('call sort([3.3, 1, "2"], 3)'):find('E474:'), nil)
  end)
end)
