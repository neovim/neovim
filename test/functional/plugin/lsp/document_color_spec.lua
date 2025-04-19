local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')

local exec_lua = n.exec_lua

local create_server_definition = t_lsp.create_server_definition

describe('vim.lsp.document_color', function()
  before_each(function()
    exec_lua(create_server_definition)

    local bufnr = n.api.nvim_get_current_buf()
    exec_lua(function()
      _G.server = _G._create_server({
        capabilities = {
          colorProvider = true,
        },
      })

      return vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
    end)

    exec_lua(function()
      vim.lsp.document_color.enable(true, { bufnr = bufnr })
    end)
  end)
end)
