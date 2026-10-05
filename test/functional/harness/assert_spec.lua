local assert = require('test.assert')
local t = require('test.testutil')

local describe, it = t.describe, t.it
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

describe('test.assert.eq_partial', function()
  it('checks selected nested fields and reports missing or wrong values', function()
    local expected = { opts = { enabled = false }, name = 'test' }
    local actual = { opts = { enabled = false, priority = 10 }, name = 'test', id = 1 }
    local expected_copy, actual_copy = vim.deepcopy(expected), vim.deepcopy(actual)

    t.eq_partial(expected, actual)
    t.eq(expected_copy, expected)
    t.eq(actual_copy, actual)

    actual.opts.enabled = true
    local err = t.pcall_err(t.eq_partial, expected, actual, 'options')
    t.matches('options: actual.opts.enabled:', err, true)
    t.pcall_err(t.eq_partial, expected, { opts = {}, name = 'test' })
  end)

  it('requires the same list length and order while allowing extra record fields', function()
    local expected = { { name = 'first' }, { name = 'second' } }
    local actual = { { name = 'first', id = 1 }, { name = 'second', id = 2 } }
    t.eq_partial(expected, actual)

    t.pcall_err(t.eq_partial, expected, { actual[2], actual[1] })
    t.pcall_err(t.eq_partial, expected, { actual[1] })
    t.pcall_err(t.eq_partial, expected, { actual[1], actual[2], actual[2] })
    t.pcall_err(t.eq_partial, expected, { actual[1], actual[2], extra = true })
  end)

  it('requires empty tables to be empty, including nested results', function()
    local expected = { results = {} }
    t.eq_partial(expected, { results = {}, extra = true })
    t.pcall_err(t.eq_partial, expected, { results = { { name = 'extra' } } })
    t.pcall_err(t.eq_partial, expected, { results = { extra = true } })
  end)

  it('handles cycles and shared tables without skipping different values', function()
    local expected, actual = { name = 'test' }, { name = 'test', extra = true }
    expected.self, actual.self = expected, actual
    t.eq_partial({ expected, expected }, { actual, vim.deepcopy(actual) })
    t.eq_partial({ expected, vim.deepcopy(expected) }, { actual, actual })
    t.pcall_err(t.eq_partial, { expected, expected }, { actual, { name = 'wrong' } })
    actual.name = 'wrong'
    t.pcall_err(t.eq_partial, expected, actual)
  end)
end)
