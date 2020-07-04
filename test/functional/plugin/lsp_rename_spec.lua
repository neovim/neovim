local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('Rename', function()
  local bufnr, fake_uri

  before_each(function()
    fake_uri = "file://fake/uri"

    bufnr = exec_lua([[
      fake_uri = ...
      bufnr = vim.uri_to_bufnr(fake_uri)
      local lines = {"line 1"; "line 2"; "what"; "else"; "do"; "you"; "want"}
      vim.fn.bufload(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
      return bufnr
    ]], fake_uri)
  end)

  after_each(function()
    clear()
  end)

  describe('vim.lsp.buf.rename', function()
    it('should use <cword> in input if server doesnt support prepareRename', function()

    end)
  end)
end)
