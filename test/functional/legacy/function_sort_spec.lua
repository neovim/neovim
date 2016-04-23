local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local execute = helpers.execute
local exc_exec = helpers.exc_exec
local neq = helpers.neq

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
    execute('func Compare1(a, b) abort')
    execute([[call sort(range(3), 'Compare2')]])
    execute('return a:a - a:b')
    execute('endfunc')

    execute('func Compare2(a, b) abort')
    execute('return a:a - a:b')
    execute('endfunc')
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
