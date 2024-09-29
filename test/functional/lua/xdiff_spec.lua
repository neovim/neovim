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
    local a1 = 'Hello\n'
    local b1 = 'Helli\n'

    local a2 = 'Hello\nbye\nfoo\n'
    local b2 = 'Helli\nbye\nbar\nbaz\n'

    it('with no callback', function()
      eq(
        table.concat({
          '@@ -1 +1 @@',
          '-Hello',
          '+Helli',
          '',
        }, '\n'),
        exec_lua(function()
          return vim.diff(a1, b1)
        end)
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
        exec_lua(function()
          return vim.diff(a2, b2)
        end)
      )
    end)

    it('with callback', function()
      eq(
        { { 1, 1, 1, 1 } },
        exec_lua(function()
          local exp = {} --- @type table[]
          assert(vim.diff(a1, b1, {
            on_hunk = function(...)
              exp[#exp + 1] = { ... }
            end,
          }) == nil)
          return exp
        end)
      )

      eq(
        { { 1, 1, 1, 1 }, { 3, 1, 3, 2 } },
        exec_lua(function()
          local exp = {} --- @type table[]
          assert(vim.diff(a2, b2, {
            on_hunk = function(...)
              exp[#exp + 1] = { ... }
            end,
          }) == nil)
          return exp
        end)
      )

      -- gives higher precedence to on_hunk over result_type
      eq(
        { { 1, 1, 1, 1 }, { 3, 1, 3, 2 } },
        exec_lua(function()
          local exp = {} --- @type table[]
          assert(vim.diff(a2, b2, {
            on_hunk = function(...)
              exp[#exp + 1] = { ... }
            end,
            result_type = 'indices',
          }) == nil)
          return exp
        end)
      )
    end)

    it('with error callback', function()
      eq(
        [[.../xdiff_spec.lua:0: error running function on_hunk: .../xdiff_spec.lua:0: ERROR1]],
        pcall_err(exec_lua, function()
          vim.diff(a1, b1, {
            on_hunk = function()
              error('ERROR1')
            end,
          })
        end)
      )
    end)

    it('with hunk_lines', function()
      eq(
        { { 1, 1, 1, 1 } },
        exec_lua(function()
          return vim.diff(a1, b1, { result_type = 'indices' })
        end)
      )

      eq(
        { { 1, 1, 1, 1 }, { 3, 1, 3, 2 } },
        exec_lua(function()
          return vim.diff(a2, b2, { result_type = 'indices' })
        end)
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
        exec_lua(function()
          return vim.diff(a, b, {
            algorithm = 'patience',
          })
        end)
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

  it('can handle strings with embedded NUL characters (GitHub #30305)', function()
    eq(
      { { 0, 0, 1, 1 }, { 1, 0, 3, 2 } },
      exec_lua(function()
        return vim.diff('\n', '\0\n\n\nb', { linematch = true, result_type = 'indices' })
      end)
    )
  end)
end)
