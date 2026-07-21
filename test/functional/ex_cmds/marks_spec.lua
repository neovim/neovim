local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local command = n.command
local eq = t.eq
local exec_capture = n.exec_capture
local exec_lua = n.exec_lua
local feed = n.feed
local fn = n.fn
local matches = t.matches

describe(':marks', function()
  before_each(function()
    n.clear {}
    fn.setline(1, { 'one', 'two', 'three' })
    feed('ma')
    exec_lua(function()
      local ns = vim.api.nvim_create_namespace('my.plugin')
      vim.api.nvim_buf_set_extmark(0, ns, 1, 0, {})
      vim.api.nvim_buf_set_extmark(0, ns, 2, 1, {})
      vim.api.nvim_create_namespace('empty.ns') -- no extmarks: not completed, not mentioned
    end)
  end)

  it('completes names, lists extmarks', function()
    -- Completion offers the set marks and the buffer's extmark namespaces.
    eq({ '"', "'", '.', 'a', 'my.plugin' }, fn.getcompletion('marks ', 'cmdline'))
    -- :marks (no args) only mentions the namespaces instead of listing their extmarks.
    local out = exec_capture('marks')
    matches('mark line  col file/text', out)
    matches('Extmark namespaces %(use ":marks {ns}"%): my%.plugin', out)
    eq(nil, out:find('empty%.ns'))
    -- ":marks {ns}" lists that namespace's extmarks.
    out = exec_capture('marks my.plugin')
    matches('id%s+line%s+col text', out)
    matches('1%s+2%s+0 two', out)
    matches('2%s+3%s+1 three', out)
    -- Not a namespace: the usual mark-names filter.
    matches('mark line  col file/text', exec_capture('marks aB'))
  end)

  it(':filter on file/text column; E283; "No marks set"', function()
    fn.setpos("'b", { 0, 2, 1, 0 })
    local out = exec_capture('filter /two/ marks')
    matches(' b%s+2%s+0 two', out)
    eq(nil, out:find(' a ', 1, true)) -- mark a is on "one": filtered out
    matches('E283: No marks matching "z"', t.pcall_err(command, 'marks z'))
    -- Bare :marks with every row filtered out.
    matches('No marks set', exec_capture('filter /xxx-nomatch/ marks'))
  end)

  it("prompt buffer: ':' mark in getmarklist() and :marks", function()
    command('enew | set buftype=prompt')
    feed('ifoo<Esc>')
    local found = false
    for _, m in ipairs(fn.getmarklist(fn.bufnr(''))) do
      found = found or m.mark == "':"
    end
    eq(true, found)
    matches(' :%s+%d+%s+%d+ ', exec_capture('marks'))
  end)
end)
