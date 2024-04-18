local t = require('test.functional.testutil')()

local exec_lua = t.exec_lua
local eq = t.eq

describe('vim.lsp.codelens', function()
  before_each(function()
    t.clear()
    exec_lua('require("vim.lsp")')
  end)
  after_each(t.clear)

  it('on_codelens_stores_and_displays_lenses', function()
    local fake_uri = 'file:///fake/uri'
    local bufnr = exec_lua(
      [[
      fake_uri = ...
      local bufnr = vim.uri_to_bufnr(fake_uri)
      local lines = {'So', 'many', 'lines'}
      vim.fn.bufload(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      return bufnr
    ]],
      fake_uri
    )

    exec_lua(
      [[
      local bufnr = ...
      local lenses = {
        {
          range = {
            start = { line = 0, character = 0, },
            ['end'] = { line = 0, character = 0 }
          },
          command = { title = 'Lens1', command = 'Dummy' }
        },
      }
      vim.lsp.codelens.on_codelens(nil, lenses, {method='textDocument/codeLens', client_id=1, bufnr=bufnr})
    ]],
      bufnr
    )

    local stored_lenses = exec_lua('return vim.lsp.codelens.get(...)', bufnr)
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

    local virtual_text_chunks = exec_lua(
      [[
      local bufnr = ...
      local ns = vim.lsp.codelens.__namespaces[1]
      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
      return vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, extmarks[1][1], { details = true })[3].virt_text
    ]],
      bufnr
    )

    eq({ [1] = { 'Lens1', 'LspCodeLens' } }, virtual_text_chunks)
  end)

  it('can clear all lens', function()
    local fake_uri = 'file:///fake/uri'
    local bufnr = exec_lua(
      [[
      fake_uri = ...
      local bufnr = vim.uri_to_bufnr(fake_uri)
      local lines = {'So', 'many', 'lines'}
      vim.fn.bufload(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      return bufnr
    ]],
      fake_uri
    )

    exec_lua(
      [[
      local bufnr = ...
      local lenses = {
        {
          range = {
            start = { line = 0, character = 0, },
            ['end'] = { line = 0, character = 0 }
          },
          command = { title = 'Lens1', command = 'Dummy' }
        },
      }
      vim.lsp.codelens.on_codelens(nil, lenses, {method='textDocument/codeLens', client_id=1, bufnr=bufnr})
    ]],
      bufnr
    )

    local stored_lenses = exec_lua('return vim.lsp.codelens.get(...)', bufnr)
    eq(1, #stored_lenses)

    exec_lua([[
      vim.lsp.codelens.clear()
    ]])

    stored_lenses = exec_lua('return vim.lsp.codelens.get(...)', bufnr)
    eq(0, #stored_lenses)
  end)
end)
