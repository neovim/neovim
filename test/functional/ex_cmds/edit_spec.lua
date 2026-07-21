local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, finally = t.describe, t.it, t.before_each, t.finally
local eq, command, fn = t.eq, n.command, n.fn
local ok = t.ok
local matches = t.matches
local pcall_err = t.pcall_err
local clear = n.clear
local feed = n.feed

describe(':edit', function()
  before_each(function()
    clear()
  end)

  it('E77 message', function()
    local glob_files = { 'Xedit-glob-one.js', 'Xedit-glob-two.js' }

    finally(function()
      for _, file in ipairs(glob_files) do
        os.remove(file)
      end
    end)

    for _, file in ipairs(glob_files) do
      t.write_file(file, '')
    end

    eq(
      'Vim(edit):E77: Too many file names (glob not allowed)',
      pcall_err(command, 'edit Xedit-glob-*.js')
    )
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
