local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local exec_lua = helpers.exec_lua

describe('vim.lsp.util', function()
  before_each(helpers.clear)

  describe('stylize_markdown', function()
    local stylize_markdown = function(content, opts)
      return exec_lua([[
        local bufnr = vim.uri_to_bufnr("file:///fake/uri")
        vim.fn.bufload(bufnr)

        local args = { ... }
        local content = args[1]
        local opts = args[2]
        local stripped_content = vim.lsp.util.stylize_markdown(bufnr, content, opts)

        return stripped_content
      ]], content, opts)
    end

    it('code fences', function()
      local lines = {
        "```lua",
        "local hello = 'world'",
        "```",
      }
      local expected = {
        "local hello = 'world'",
      }
      local opts = {}
      eq(expected, stylize_markdown(lines, opts))
    end)

    it('adds separator after code block', function()
      local lines = {
        "```lua",
        "local hello = 'world'",
        "```",
        "",
        "something",
      }
      local expected = {
        "local hello = 'world'",
        "─────────────────────",
        "something",
      }
      local opts = { separator = true }
      eq(expected, stylize_markdown(lines, opts))
    end)

    it('replaces supported HTML entities', function()
      local lines = {
        "1 &lt; 2",
        "3 &gt; 2",
        "&quot;quoted&quot;",
        "&apos;apos&apos;",
        "&ensp; &emsp;",
        "&amp;",
      }
      local expected = {
        "1 < 2",
        "3 > 2",
        '"quoted"',
        "'apos'",
        "   ",
        "&",
      }
      local opts = {}
      eq(expected, stylize_markdown(lines, opts))
    end)
  end)
end)
