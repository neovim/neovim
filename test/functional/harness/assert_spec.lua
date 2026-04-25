local assert = require('test.assert')

describe('test.assert', function()
  it('ignores aliasing differences', function()
    local shared = {}

    assert.eq({ 1, shared, 1, shared }, { 1, {}, 1, {} })
    assert.eq({ 1, {}, 1, {} }, { 1, shared, 1, shared })
  end)

  it('handles cyclic tables', function()
    local expected = {}
    local actual = {}

    expected[1] = expected
    actual[1] = actual

    assert.eq(expected, actual)
  end)

  it('still rejects different structures', function()
    local expected = {}

    expected[1] = expected

    assert.neq(expected, { {} })
  end)
end)
