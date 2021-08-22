local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local pcall_err = helpers.pcall_err

describe('xdiff bindings', function()
  before_each(function()
    clear()
  end)

  describe('can diff text', function()
    before_each(function()
      exec_lua[[
        a1 = 'Hello\n'
        b1 = 'Helli\n'

        a2 = 'Hello\nbye\nfoo\n'
        b2 = 'Helli\nbye\nbar\nbaz\n'
      ]]
    end)

    it('with no callback', function()

      eq(
        table.concat({
          '@@ -1 +1 @@',
          '-Hello',
          '+Helli',
          ''
        }, '\n'),
        exec_lua("return vim.diff(a1, b1)")
      )

      eq(
        table.concat({
          '@@ -1 +1 @@',
          '-Hello',
          '+Helli',
          '@@ -3 +3,2 @@',
          '-foo',
          '+bar',
          '+baz',
          ''
        }, '\n'),
        exec_lua("return vim.diff(a2, b2)")
      )

    end)

    it('with callback', function()
      exec_lua([[on_hunk = function(sa, ca, sb, cb)
          exp[#exp+1] = {sa, ca, sb, cb}
        end]])

      eq({{1, 1, 1, 1}}, exec_lua[[
          exp = {}
          assert(vim.diff(a1, b1, {on_hunk = on_hunk}) == nil)
          return exp
        ]])

      eq({{1, 1, 1, 1}, {3, 1, 3, 2}}, exec_lua[[
          exp = {}
          assert(vim.diff(a2, b2, {on_hunk = on_hunk}) == nil)
          return exp
        ]])

      -- gives higher precedence to on_hunk over result_type
      eq({{1, 1, 1, 1}, {3, 1, 3, 2}}, exec_lua[[
          exp = {}
          assert(vim.diff(a2, b2, {on_hunk = on_hunk, result_type='indices'}) == nil)
          return exp
        ]])
    end)

    it('with error callback', function()
      exec_lua([[on_hunk = function(sa, ca, sb, cb)
          error('ERROR1')
        end]])

      eq([[Error executing lua: [string "<nvim>"]:0: error running function on_hunk: [string "<nvim>"]:0: ERROR1]],
        pcall_err(exec_lua, [[vim.diff(a1, b1, {on_hunk = on_hunk})]]))
    end)

    it('with hunk_lines', function()
      eq({{1, 1, 1, 1}},
        exec_lua([[return vim.diff(a1, b1, {result_type = 'indices'})]]))

      eq({{1, 1, 1, 1}, {3, 1, 3, 2}},
        exec_lua([[return vim.diff(a2, b2, {result_type = 'indices'})]]))
    end)

  end)

  it('can handle bad args', function()
    eq([[Error executing lua: [string "<nvim>"]:0: Expected at least 2 arguments]],
      pcall_err(exec_lua, [[vim.diff('a')]]))

    eq([[Error executing lua: [string "<nvim>"]:0: bad argument #1 to 'diff' (expected string)]],
      pcall_err(exec_lua, [[vim.diff(1, 2)]]))

    eq([[Error executing lua: [string "<nvim>"]:0: bad argument #3 to 'diff' (expected table)]],
      pcall_err(exec_lua, [[vim.diff('a', 'b', true)]]))

    eq([[Error executing lua: [string "<nvim>"]:0: unexpected key: bad_key]],
      pcall_err(exec_lua, [[vim.diff('a', 'b', { bad_key = true })]]))

    eq([[Error executing lua: [string "<nvim>"]:0: on_hunk is not a function]],
      pcall_err(exec_lua, [[vim.diff('a', 'b', { on_hunk = true })]]))

  end)
end)
