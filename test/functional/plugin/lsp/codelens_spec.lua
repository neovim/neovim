local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local exec_lua = n.exec_lua
local eq = t.eq

describe('vim.lsp.codelens', function()
  before_each(function()
    n.clear()
    exec_lua('require("vim.lsp")')
  end)
  after_each(n.clear)

  it('on_codelens_stores_and_displays_lenses', function()
    local fake_uri = 'file:///fake/uri'
    local bufnr = exec_lua(function()
      local bufnr = vim.uri_to_bufnr(fake_uri)
      local lines = { 'So', 'many', 'lines' }
      vim.fn.bufload(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      return bufnr
    end)

    exec_lua(function()
      local lenses = {
        {
          range = {
            start = { line = 0, character = 0 },
            ['end'] = { line = 0, character = 0 },
          },
          command = { title = 'Lens1', command = 'Dummy' },
        },
      }
      vim.lsp.codelens.on_codelens(
        nil,
        lenses,
        { method = 'textDocument/codeLens', client_id = 1, bufnr = bufnr }
      )
    end)

    local stored_lenses = exec_lua(function()
      return vim.lsp.codelens.get(bufnr)
    end)
    local expected = {
      {
        range = {
          start = { line = 0, character = 0 },
          ['end'] = { line = 0, character = 0 },
        },
        command = {
          title = 'Lens1',
          command = 'Dummy',
        },
      },
    }
    eq(expected, stored_lenses)

    local virtual_text_chunks = exec_lua(function()
      local ns = vim.lsp.codelens.__namespaces[1]
      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
      return vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, extmarks[1][1], { details = true })[3].virt_text
    end)

    eq({ [1] = { 'Lens1', 'LspCodeLens' } }, virtual_text_chunks)
  end)

  it('can clear all lens', function()
    local fake_uri = 'file:///fake/uri'
    local bufnr = exec_lua(function()
      local bufnr = vim.uri_to_bufnr(fake_uri)
      local lines = { 'So', 'many', 'lines' }
      vim.fn.bufload(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      return bufnr
    end)

    exec_lua(function()
      local lenses = {
        {
          range = {
            start = { line = 0, character = 0 },
            ['end'] = { line = 0, character = 0 },
          },
          command = { title = 'Lens1', command = 'Dummy' },
        },
      }
      vim.lsp.codelens.on_codelens(
        nil,
        lenses,
        { method = 'textDocument/codeLens', client_id = 1, bufnr = bufnr }
      )
    end)

    local stored_lenses = exec_lua(function()
      return vim.lsp.codelens.get(bufnr)
    end)
    eq(1, #stored_lenses)

    exec_lua(function()
      vim.lsp.codelens.clear()
    end)

    stored_lenses = exec_lua(function()
      return vim.lsp.codelens.get(bufnr)
    end)
    eq(0, #stored_lenses)
  end)
end)
