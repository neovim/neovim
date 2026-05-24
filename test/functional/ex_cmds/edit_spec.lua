local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq, command, fn = t.eq, n.command, n.fn
local ok = t.ok
local matches = t.matches
local pcall_err = t.pcall_err
local write_file = t.write_file
local clear = n.clear
local feed = n.feed

describe(':edit', function()
  local glob_files = { 'Xedit_glob_one.js', 'Xedit_glob_two.js' }

  before_each(function()
    clear()
    for _, file in ipairs(glob_files) do
      fn.delete(file)
    end
  end)

  after_each(function()
    for _, file in ipairs(glob_files) do
      fn.delete(file)
    end
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

  it('with glob reports that glob is not allowed', function()
    for _, file in ipairs(glob_files) do
      write_file(file, '')
    end

    eq(
      'Vim(edit):E77: Too many file names (glob not allowed)',
      pcall_err(command, 'edit Xedit_glob_*.js')
    )
  end)
end)
