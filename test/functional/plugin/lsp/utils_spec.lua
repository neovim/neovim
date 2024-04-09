local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local feed = t.feed

local eq = t.eq
local exec_lua = t.exec_lua

describe('vim.lsp.util', function()
  before_each(t.clear)

  describe('stylize_markdown', function()
    local stylize_markdown = function(content, opts)
      return exec_lua(
        [[
        local bufnr = vim.uri_to_bufnr("file:///fake/uri")
        vim.fn.bufload(bufnr)

        local args = { ... }
        local content = args[1]
        local opts = args[2]
        local stripped_content = vim.lsp.util.stylize_markdown(bufnr, content, opts)

        return stripped_content
      ]],
        content,
        opts
      )
    end

    it('code fences', function()
      local lines = {
        '```lua',
        "local hello = 'world'",
        '```',
      }
      local expected = {
        "local hello = 'world'",
      }
      local opts = {}
      eq(expected, stylize_markdown(lines, opts))
    end)

    it('code fences with whitespace surrounded info string', function()
      local lines = {
        '```   lua   ',
        "local hello = 'world'",
        '```',
      }
      local expected = {
        "local hello = 'world'",
      }
      local opts = {}
      eq(expected, stylize_markdown(lines, opts))
    end)

    it('adds separator after code block', function()
      local lines = {
        '```lua',
        "local hello = 'world'",
        '```',
        '',
        'something',
      }
      local expected = {
        "local hello = 'world'",
        '─────────────────────',
        'something',
      }
      local opts = { separator = true }
      eq(expected, stylize_markdown(lines, opts))
    end)

    it('replaces supported HTML entities', function()
      local lines = {
        '1 &lt; 2',
        '3 &gt; 2',
        '&quot;quoted&quot;',
        '&apos;apos&apos;',
        '&ensp; &emsp;',
        '&amp;',
      }
      local expected = {
        '1 < 2',
        '3 > 2',
        '"quoted"',
        "'apos'",
        '   ',
        '&',
      }
      local opts = {}
      eq(expected, stylize_markdown(lines, opts))
    end)
  end)

  describe('normalize_markdown', function()
    it('collapses consecutive blank lines', function()
      local result = exec_lua [[
        local lines = {
          'foo',
          '',
          '',
          '',
          'bar',
          '',
          'baz'
        }
        return vim.lsp.util._normalize_markdown(lines)
      ]]
      local expected = { 'foo', '', 'bar', '', 'baz' }
      eq(expected, result)
    end)

    it('removes preceding and trailing empty lines', function()
      local result = exec_lua [[
        local lines = {
          '',
          'foo',
          'bar',
          '',
          ''
        }
        return vim.lsp.util._normalize_markdown(lines)
      ]]
      local expected = { 'foo', 'bar' }
      eq(expected, result)
    end)
  end)

  describe('make_floating_popup_options', function()
    local function assert_anchor(anchor_bias, expected_anchor)
      local opts = exec_lua(
        [[
          local args = { ... }
          local anchor_bias = args[1]
          return vim.lsp.util.make_floating_popup_options(30, 10, { anchor_bias = anchor_bias })
        ]],
        anchor_bias
      )

      eq(expected_anchor, string.sub(opts.anchor, 1, 1))
    end

    local screen
    before_each(function()
      t.clear()
      screen = Screen.new(80, 80)
      screen:attach()
      feed('79i<CR><Esc>') -- fill screen with empty lines
    end)

    describe('when on the first line it places window below', function()
      before_each(function()
        feed('gg')
      end)

      it('for anchor_bias = "auto"', function()
        assert_anchor('auto', 'N')
      end)

      it('for anchor_bias = "above"', function()
        assert_anchor('above', 'N')
      end)

      it('for anchor_bias = "below"', function()
        assert_anchor('below', 'N')
      end)
    end)

    describe('when on the last line it places window above', function()
      before_each(function()
        feed('G')
      end)

      it('for anchor_bias = "auto"', function()
        assert_anchor('auto', 'S')
      end)

      it('for anchor_bias = "above"', function()
        assert_anchor('above', 'S')
      end)

      it('for anchor_bias = "below"', function()
        assert_anchor('below', 'S')
      end)
    end)

    describe('with 20 lines above, 59 lines below', function()
      before_each(function()
        feed('gg20j')
      end)

      it('places window below for anchor_bias = "auto"', function()
        assert_anchor('auto', 'N')
      end)

      it('places window above for anchor_bias = "above"', function()
        assert_anchor('above', 'S')
      end)

      it('places window below for anchor_bias = "below"', function()
        assert_anchor('below', 'N')
      end)
    end)

    describe('with 59 lines above, 20 lines below', function()
      before_each(function()
        feed('G20k')
      end)

      it('places window above for anchor_bias = "auto"', function()
        assert_anchor('auto', 'S')
      end)

      it('places window above for anchor_bias = "above"', function()
        assert_anchor('above', 'S')
      end)

      it('places window below for anchor_bias = "below"', function()
        assert_anchor('below', 'N')
      end)

      it('bordered window truncates dimensions correctly', function()
        local opts = exec_lua([[
          return vim.lsp.util.make_floating_popup_options(100, 100, { border = 'single' })
        ]])

        eq(56, opts.height)
      end)
    end)
  end)
end)
