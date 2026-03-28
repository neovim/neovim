local assert = require('luassert')

describe('luassert shim', function()
  it('ignores aliasing differences', function()
    local shared = {}

    assert.same({ 1, shared, 1, shared }, { 1, {}, 1, {} })
    assert.same({ 1, {}, 1, {} }, { 1, shared, 1, shared })
  end)

  it('handles cyclic tables', function()
    local expected = {}
    local actual = {}

    expected[1] = expected
    actual[1] = actual

    assert.same(expected, actual)
  end)

  it('still rejects different structures', function()
    local expected = {}

    expected[1] = expected

    assert.neq(expected, { {} })
  end)
end)
