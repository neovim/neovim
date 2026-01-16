local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq

describe('vim._ordereddict', function()
  before_each(n.clear)

  local ordereddict = require('vim._ordereddict')

  it('preserves insertion order and supports set/get/len', function()
    local d = ordereddict.new()
    d:set('a', 1)
    d:set('b', 2)
    d:set('c', 3)

    eq(1, d:get('a'))
    eq(2, d:get('b'))
    eq(3, d:get('c'))
    eq(3, d:len())
    eq({'a', 'b', 'c'}, vim.iter(d()):enumerate():totable())
    -- eq({1, 2, 3}, d:values())
  end)

  it('overwrites value without changing order', function()
    local d = ordereddict.new()
    d:set('x', 10)
    d:set('y', 20)
    d:set('x', 99)

    eq(99, d:get('x'))
    eq({'x', 'y'}, d:keys())
    eq({99, 20}, d:values())
  end)

  it('removes existing keys', function()
    local d = ordereddict.new()
    d:set('a', 1)
    d:set('b', 2)

    local removed = d:remove('a')
    eq(true, removed)
    eq(nil, d:get('a'))
    eq({'b'}, d:keys())
    eq({2}, d:values())
    eq(1, d:len())
  end)

  it('returns false when removing non-existent keys', function()
    local d = ordereddict.new()
    eq(false, d:remove('missing'))
  end)

  it('pop removes and returns the last item', function()
    local d = ordereddict.new()
    d:set('one', 1)
    d:set('two', 2)

    local k, v = d:pop()
    eq('two', k)
    eq(2, v)
    eq({'one'}, d:keys())
    eq({1}, d:values())
    eq(1, d:len())
  end)

  it('pop returns nil when empty', function()
    local d = ordereddict.new()
    local k, v = d:pop()
    eq(nil, k)
    eq(nil, v)
  end)

  it('iterates in insertion order', function()
    local d = ordereddict.new()
    d:set('k1', 'v1')
    d:set('k2', 'v2')
    d:set('k3', 'v3')

    local items = {}
    for k, v in d:items() do
      table.insert(items, {k, v})
    end

    eq({{'k1', 'v1'}, {'k2', 'v2'}, {'k3', 'v3'}}, items)
  end)

end)

