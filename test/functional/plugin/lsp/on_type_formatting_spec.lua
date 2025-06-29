local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')

local eq = t.eq
local dedent = t.dedent
local exec_lua = n.exec_lua
local insert = n.insert
local feed = n.feed

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition

describe('vim.lsp.on_type_formatting', function()
  local text = dedent([[
  int main() {
    int hi
  }]])

  before_each(function()
    clear_notrace()

    exec_lua(create_server_definition)
    exec_lua(function()
      _G.server = _G._create_server({
        capabilities = {
          documentOnTypeFormattingProvider = {
            firstTriggerCharacter = '=',
          },
        },
        handlers = {
          ---@param params lsp.DocumentOnTypeFormattingParams
          ---@param callback fun(err?: lsp.ResponseError, result?: lsp.TextEdit[])
          ['textDocument/onTypeFormatting'] = function(_, params, callback)
            callback(nil, {
              {
                newText = ';',
                range = {
                  start = params.position,
                  ['end'] = params.position,
                },
              },
            })
          end,
        },
      })

      _G.server_id = vim.lsp.start({
        name = 'dummy',
        cmd = _G.server.cmd,
        on_attach = function(client, bufnr)
          vim.lsp.on_type_formatting.enable(true, bufnr, client.id)
        end,
      })
    end)

    insert(text)
  end)

  it('enables formatting on type', function()
    exec_lua(function()
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_cursor(win, { 2, 0 })
    end)
    feed('A = 5')
    exec_lua(function()
      vim.wait(1000, function()
        return #_G.server.messages > 1
      end)
    end)
    eq(
      {
        'int main() {',
        '  int hi = 5;',
        '}',
      },
      exec_lua(function()
        return vim.api.nvim_buf_get_lines(0, 0, -1, false)
      end)
    )
  end)

  it('works with multiple clients', function()
    exec_lua(function()
      _G.server2 = _G._create_server({
        capabilities = {
          documentOnTypeFormattingProvider = {
            firstTriggerCharacter = '.',
            moreTriggerCharacter = { '=' },
          },
        },
        handlers = {
          ---@param params lsp.DocumentOnTypeFormattingParams
          ---@param callback fun(err?: lsp.ResponseError, result?: lsp.TextEdit[])
          ['textDocument/onTypeFormatting'] = function(_, params, callback)
            callback(nil, {
              {
                newText = ';',
                range = {
                  start = params.position,
                  ['end'] = params.position,
                },
              },
            })
          end,
        },
      })

      vim.lsp.start({
        name = 'dummy2',
        cmd = _G.server2.cmd,
        on_attach = function(client, bufnr)
          vim.lsp.on_type_formatting.enable(true, bufnr, client.id)
        end,
      })
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_cursor(win, { 2, 0 })
    end)
    feed('A =')
    exec_lua(function()
      vim.wait(1000, function()
        return #_G.server2.messages > 1 and #_G.server.messages > 1
      end)
    end)
    eq(
      {
        'int main() {',
        '  int hi =;;',
        '}',
      },
      exec_lua(function()
        return vim.api.nvim_buf_get_lines(0, 0, -1, false)
      end)
    )
  end)

  it('can be disabled', function()
    exec_lua(function()
      vim.lsp.on_type_formatting.enable(false, 0, _G.server_id)
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_cursor(win, { 2, 0 })
    end)
    feed('A = 5')
    eq(
      {
        'int main() {',
        '  int hi = 5',
        '}',
      },
      exec_lua(function()
        return vim.api.nvim_buf_get_lines(0, 0, -1, false)
      end)
    )
  end)
end)
