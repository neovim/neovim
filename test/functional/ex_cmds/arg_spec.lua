local t = require('test.functional.testutil')(after_each)
local eq, command, fn = t.eq, t.command, t.fn
local ok = t.ok
local matches = t.matches
local clear = t.clear

describe(':argument', function()
  before_each(function()
    clear()
  end)

  it('does not restart :terminal buffer', function()
    command('terminal')
    t.feed([[<C-\><C-N>]])
    command('argadd')
    t.feed([[<C-\><C-N>]])
    local bufname_before = fn.bufname('%')
    local bufnr_before = fn.bufnr('%')
    matches('^term://', bufname_before) -- sanity

    command('argument 1')
    t.feed([[<C-\><C-N>]])

    local bufname_after = fn.bufname('%')
    local bufnr_after = fn.bufnr('%')
    eq('[' .. bufname_before .. ']', t.eval('trim(execute("args"))'))
    ok(fn.line('$') > 1)
    eq(bufname_before, bufname_after)
    eq(bufnr_before, bufnr_after)
  end)
end)
