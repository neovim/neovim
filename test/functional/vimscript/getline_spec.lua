local t = require('test.functional.testutil')(after_each)

local call = t.call
local clear = t.clear
local eq = t.eq
local expect = t.expect

describe('getline()', function()
  before_each(function()
    clear()
    call('setline', 1, { 'a', 'b', 'c' })
    expect([[
      a
      b
      c]])
  end)

  it('returns empty string for invalid line', function()
    eq('', call('getline', -1))
    eq('', call('getline', 0))
    eq('', call('getline', 4))
  end)

  it('returns empty list for invalid range', function()
    eq({}, call('getline', 2, 1))
    eq({}, call('getline', -1, 1))
    eq({}, call('getline', 4, 4))
  end)

  it('returns value of valid line', function()
    eq('b', call('getline', 2))
    eq('a', call('getline', '.'))
  end)

  it('returns value of valid range', function()
    eq({ 'a', 'b' }, call('getline', 1, 2))
    eq({ 'a', 'b', 'c' }, call('getline', 1, 4))
  end)
end)
