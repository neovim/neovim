local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq, command, fn = t.eq, n.command, n.fn
local ok = t.ok
local matches = t.matches
local clear = n.clear
local feed = n.feed

describe(':edit', function()
  before_each(function()
    clear()
  end)

  it('without arguments does not restart :terminal buffer', function()
    command('terminal')
    feed([[<C-\><C-N>]])
    local bufname_before = fn.bufname('%')
    local bufnr_before = fn.bufnr('%')
    matches('^term://', bufname_before) -- sanity

    command('edit')

    local bufname_after = fn.bufname('%')
    local bufnr_after = fn.bufnr('%')
    ok(fn.line('$') > 1)
    eq(bufname_before, bufname_after)
    eq(bufnr_before, bufnr_after)
  end)
end)
