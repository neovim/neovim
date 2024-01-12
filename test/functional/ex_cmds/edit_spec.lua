local helpers = require('test.functional.helpers')(after_each)
local eq, command, fn = helpers.eq, helpers.command, helpers.fn
local ok = helpers.ok
local clear = helpers.clear
local feed = helpers.feed

describe(':edit', function()
  before_each(function()
    clear()
  end)

  it('without arguments does not restart :terminal buffer', function()
    command('terminal')
    feed([[<C-\><C-N>]])
    local bufname_before = fn.bufname('%')
    local bufnr_before = fn.bufnr('%')
    helpers.ok(nil ~= string.find(bufname_before, '^term://')) -- sanity

    command('edit')

    local bufname_after = fn.bufname('%')
    local bufnr_after = fn.bufnr('%')
    ok(fn.line('$') > 1)
    eq(bufname_before, bufname_after)
    eq(bufnr_before, bufnr_after)
  end)
end)
