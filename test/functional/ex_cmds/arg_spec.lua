local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq, command, fn = t.eq, n.command, n.fn
local ok = t.ok
local matches = t.matches
local clear = n.clear

describe(':argument', function()
  before_each(function()
    clear()
  end)

  it('does not restart :terminal buffer', function()
    command('terminal')
    n.feed([[<C-\><C-N>]])
    command('argadd')
    n.feed([[<C-\><C-N>]])
    local bufname_before = fn.bufname('%')
    local bufnr_before = fn.bufnr('%')
    matches('^term://', bufname_before) -- sanity

    command('argument 1')
    n.feed([[<C-\><C-N>]])

    local bufname_after = fn.bufname('%')
    local bufnr_after = fn.bufnr('%')
    eq('[' .. bufname_before .. ']', n.eval('trim(execute("args"))'))
    ok(fn.line('$') > 1)
    eq(bufname_before, bufname_after)
    eq(bufnr_before, bufnr_after)
  end)
end)
