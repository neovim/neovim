local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq

describe('vim.text', function()
  before_each(clear)

  describe('indent()', function()
    it('validation', function()
      t.matches('size%: expected number, got string', t.pcall_err(vim.text.indent, 'x', 'x'))
      t.matches('size%: expected number, got nil', t.pcall_err(vim.text.indent, nil, 'x'))
      t.matches('opts%: expected table, got string', t.pcall_err(vim.text.indent, 0, 'x', 'z'))
    end)

    it('basic cases', function()
      -- Basic cases.
      eq({ '', 0 }, { vim.text.indent(0, '') })
      eq({ '', 0 }, { vim.text.indent(2, '') })
      eq({ '  a', 4 }, { vim.text.indent(2, '    a') })
      eq({ '  a\n  b', 4 }, { vim.text.indent(2, '    a\n    b') })
      eq({ '\t\ta', 1 }, { vim.text.indent(2, '\ta') })
      eq({ ' a\n\n', 5 }, { vim.text.indent(1, '     a\n\n') })
      -- Indent 1 (tab) => 0. Starting with empty + blank lines.
      eq({ '\n\naa a aa', 1 }, { vim.text.indent(0, '\n	\n	aa a aa') })
      -- Indent 1 (tab) => 2 (tabs). Starting with empty + blank lines, 1-tab indent.
      eq({ '\n\t\t\n\t\taa a aa', 1 }, { vim.text.indent(2, '\n\t\n\taa a aa') })

      -- Indent 4 => 2, expandtab=false preserves tabs after the common indent.
      eq(
        { '  foo\n    bar\n  \tbaz\n', 4 },
        { vim.text.indent(2, '    foo\n      bar\n    \tbaz\n') }
      )
      -- Indent 9 => 3, expandtab=true.
      eq(
        { '    foo\n\n   bar \t baz\n', 9 },
        { vim.text.indent(3, '\t  foo\n\n         bar \t baz\n', { expandtab = 8 }) }
      )
      -- Indent 9 => 8, expandtab=true.
      eq(
        { '         foo\n\n        bar\n', 9 },
        { vim.text.indent(8, '\t  foo\n\n         bar\n', { expandtab = 8 }) }
      )
      -- Dedent: 5 => 0.
      eq({ '  foo\n\nbar\n', 5 }, { vim.text.indent(0, '       foo\n\n     bar\n') })
      -- Dedent: 1 => 0. Empty lines are ignored when deciding "common indent".
      eq(
        { ' \n  \nfoo\n\nbar\nbaz\n    \n', 1 },
        { vim.text.indent(0, '  \n   \n foo\n\n bar\n baz\n     \n') }
      )
    end)

    it('real-world cases', function()
      -- Dedent.
      eq({
        [[
bufs:
nvim args: 3
lua args: {
  [0] = "foo.lua"
}
]],
        10,
      }, {
        vim.text.indent(
          0,
          [[
          bufs:
          nvim args: 3
          lua args: {
            [0] = "foo.lua"
          }
          ]]
        ),
      })

      -- Indent 0 => 2.
      eq({
        [[
  # yay

  local function foo()
    if true then
      # yay
    end
  end

  return
]],
        0,
      }, {
        vim.text.indent(
          2,
          [[
# yay

local function foo()
  if true then
    # yay
  end
end

return
]]
        ),
      })

      -- 1-tab indent, last line spaces < tabsize.
      -- Preserves tab char immediately following the indent.
      eq({ 'text\n\tmatch\nmatch\ntext\n', 1 }, {
        vim.text.indent(0, (([[
	text
		match
	match
	text
]]):gsub('\n%s-([\n]?)$', '\n%1'))),
      })

      -- 1-tab indent, last line spaces=tabsize.
      eq({ 'text\n      match\nmatch\ntext\n', 6 }, {
        vim.text.indent(
          0,
          [[
	text
		match
	match
	text
      ]],
          { expandtab = 6 }
        ),
      })
    end)
  end)

  describe('hexencode(), hexdecode()', function()
    it('works', function()
      local cases = {
        { 'Hello world!', '48656C6C6F20776F726C6421' },
        { '😂', 'F09F9882' },
      }

      for _, v in ipairs(cases) do
        local input, output = unpack(v)
        eq(output, vim.text.hexencode(input))
        eq(input, vim.text.hexdecode(output))
      end
    end)

    it('with very large strings', function()
      local input, output = string.rep('😂', 2 ^ 16), string.rep('F09F9882', 2 ^ 16)
      eq(output, vim.text.hexencode(input))
      eq(input, vim.text.hexdecode(output))
    end)

    it('invalid input', function()
      -- Odd number of hex characters
      do
        local res, err = vim.text.hexdecode('ABC')
        eq(nil, res)
        eq('string must have an even number of hex characters', err)
      end

      -- Non-hexadecimal input
      do
        local res, err = vim.text.hexdecode('nothex')
        eq(nil, res)
        eq('string must contain only hex characters', err)
      end
    end)
  end)
end)
