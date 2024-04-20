local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_lua = n.exec_lua
local eq = t.eq
local pcall_err = t.pcall_err

describe('xdiff bindings', function()
  before_each(function()
    clear()
  end)

  describe('can diff text', function()
    before_each(function()
      exec_lua [[
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
          '',
        }, '\n'),
        exec_lua('return vim.diff(a1, b1)')
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
          '',
        }, '\n'),
        exec_lua('return vim.diff(a2, b2)')
      )
    end)

    it('with callback', function()
      exec_lua([[on_hunk = function(sa, ca, sb, cb)
          exp[#exp+1] = {sa, ca, sb, cb}
        end]])

      eq(
        { { 1, 1, 1, 1 } },
        exec_lua [[
          exp = {}
          assert(vim.diff(a1, b1, {on_hunk = on_hunk}) == nil)
          return exp
        ]]
      )

      eq(
        { { 1, 1, 1, 1 }, { 3, 1, 3, 2 } },
        exec_lua [[
          exp = {}
          assert(vim.diff(a2, b2, {on_hunk = on_hunk}) == nil)
          return exp
        ]]
      )

      -- gives higher precedence to on_hunk over result_type
      eq(
        { { 1, 1, 1, 1 }, { 3, 1, 3, 2 } },
        exec_lua [[
          exp = {}
          assert(vim.diff(a2, b2, {on_hunk = on_hunk, result_type='indices'}) == nil)
          return exp
        ]]
      )
    end)

    it('with error callback', function()
      exec_lua [[
        on_hunk = function(sa, ca, sb, cb)
          error('ERROR1')
        end
      ]]

      eq(
        [[error running function on_hunk: [string "<nvim>"]:0: ERROR1]],
        pcall_err(exec_lua, [[vim.diff(a1, b1, {on_hunk = on_hunk})]])
      )
    end)

    it('with hunk_lines', function()
      eq({ { 1, 1, 1, 1 } }, exec_lua([[return vim.diff(a1, b1, {result_type = 'indices'})]]))

      eq(
        { { 1, 1, 1, 1 }, { 3, 1, 3, 2 } },
        exec_lua([[return vim.diff(a2, b2, {result_type = 'indices'})]])
      )
    end)

    it('can run different algorithms', function()
      local a = table.concat({
        '.foo1 {',
        '    margin: 0;',
        '}',
        '',
        '.bar {',
        '    margin: 0;',
        '}',
        '',
      }, '\n')

      local b = table.concat({
        '.bar {',
        '    margin: 0;',
        '}',
        '',
        '.foo1 {',
        '    margin: 0;',
        '    color: green;',
        '}',
        '',
      }, '\n')

      eq(
        table.concat({
          '@@ -1,4 +0,0 @@',
          '-.foo1 {',
          '-    margin: 0;',
          '-}',
          '-',
          '@@ -7,0 +4,5 @@',
          '+',
          '+.foo1 {',
          '+    margin: 0;',
          '+    color: green;',
          '+}',
          '',
        }, '\n'),
        exec_lua(
          [[
          local args = {...}
          return vim.diff(args[1], args[2], {
            algorithm = 'patience'
          })
        ]],
          a,
          b
        )
      )
    end)
  end)

  it('can handle bad args', function()
    eq([[Expected at least 2 arguments]], pcall_err(exec_lua, [[vim.diff('a')]]))

    eq([[bad argument #1 to 'diff' (expected string)]], pcall_err(exec_lua, [[vim.diff(1, 2)]]))

    eq(
      [[bad argument #3 to 'diff' (expected table)]],
      pcall_err(exec_lua, [[vim.diff('a', 'b', true)]])
    )

    eq([[invalid key: bad_key]], pcall_err(exec_lua, [[vim.diff('a', 'b', { bad_key = true })]]))

    eq(
      [[on_hunk is not a function]],
      pcall_err(exec_lua, [[vim.diff('a', 'b', { on_hunk = true })]])
    )
  end)
end)
