local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local feed = n.feed
local eq = t.eq
local exec_lua = n.exec_lua

describe('vim.lsp.util', function()
  before_each(n.clear)

  describe('stylize_markdown', function()
    local stylize_markdown = function(content, opts)
      return exec_lua(function()
        local bufnr = vim.uri_to_bufnr('file:///fake/uri')
        vim.fn.bufload(bufnr)
        return vim.lsp.util.stylize_markdown(bufnr, content, opts)
      end)
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

  it('convert_input_to_markdown_lines', function()
    local r = exec_lua(function()
      local hover_data = {
        kind = 'markdown',
        value = '```lua\nfunction vim.api.nvim_buf_attach(buffer: integer, send_buffer: boolean, opts: vim.api.keyset.buf_attach)\n  -> boolean\n```\n\n---\n\n Activates buffer-update events. Example:\n\n\n\n ```lua\n events = {}\n vim.api.nvim_buf_attach(0, false, {\n   on_lines = function(...)\n     table.insert(events, {...})\n   end,\n })\n ```\n\n\n @see `nvim_buf_detach()`\n @see `api-buffer-updates-lua`\n@*param* `buffer` — Buffer handle, or 0 for current buffer\n\n\n\n@*param* `send_buffer` — True if whole buffer.\n Else the first notification will be `nvim_buf_changedtick_event`.\n\n\n@*param* `opts` — Optional parameters.\n\n - on_lines: Lua callback. Args:\n   - the string "lines"\n   - buffer handle\n   - b:changedtick\n@*return* — False if foo;\n\n otherwise True.\n\n@see foo\n@see bar\n\n',
      }
      return vim.lsp.util.convert_input_to_markdown_lines(hover_data)
    end)
    local expected = {
      '```lua',
      'function vim.api.nvim_buf_attach(buffer: integer, send_buffer: boolean, opts: vim.api.keyset.buf_attach)',
      '  -> boolean',
      '```',
      '',
      '---',
      '',
      ' Activates buffer-update events. Example:',
      '',
      '',
      '',
      ' ```lua',
      ' events = {}',
      ' vim.api.nvim_buf_attach(0, false, {',
      '   on_lines = function(...)',
      '     table.insert(events, {...})',
      '   end,',
      ' })',
      ' ```',
      '',
      '',
      ' @see `nvim_buf_detach()`',
      ' @see `api-buffer-updates-lua`',
      '',
      -- For each @param/@return: #30695
      --  - Separate each by one empty line.
      --  - Remove all other blank lines.
      '@*param* `buffer` — Buffer handle, or 0 for current buffer',
      '',
      '@*param* `send_buffer` — True if whole buffer.',
      ' Else the first notification will be `nvim_buf_changedtick_event`.',
      '',
      '@*param* `opts` — Optional parameters.',
      ' - on_lines: Lua callback. Args:',
      '   - the string "lines"',
      '   - buffer handle',
      '   - b:changedtick',
      '',
      '@*return* — False if foo;',
      ' otherwise True.',
      '@see foo',
      '@see bar',
    }
    eq(expected, r)
  end)

  describe('_normalize_markdown', function()
    it('collapses consecutive blank lines', function()
      local result = exec_lua(function()
        local lines = {
          'foo',
          '',
          '',
          '',
          'bar',
          '',
          'baz',
        }
        return vim.lsp.util._normalize_markdown(lines)
      end)
      local expected = { 'foo', '', 'bar', '', 'baz' }
      eq(expected, result)
    end)

    it('removes preceding and trailing empty lines', function()
      local result = exec_lua(function()
        local lines = {
          '',
          'foo',
          'bar',
          '',
          '',
        }
        return vim.lsp.util._normalize_markdown(lines)
      end)
      local expected = { 'foo', 'bar' }
      eq(expected, result)
    end)
  end)

  describe('make_floating_popup_options', function()
    local function assert_anchor(anchor_bias, expected_anchor)
      local opts = exec_lua(function()
        return vim.lsp.util.make_floating_popup_options(30, 10, { anchor_bias = anchor_bias })
      end)

      eq(expected_anchor, string.sub(opts.anchor, 1, 1))
    end

    before_each(function()
      n.clear()
      local _ = Screen.new(80, 80)
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
        local opts = exec_lua(function()
          return vim.lsp.util.make_floating_popup_options(100, 100, { border = 'single' })
        end)

        eq(56, opts.height)
      end)
    end)
  end)
end)
