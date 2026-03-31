local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')
local retry = t.retry

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
      })
      vim.lsp.on_type_formatting.enable(true, { client_id = _G.server_id })
    end)

    insert(text)
  end)

  it('enables formatting on type', function()
    exec_lua(function()
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_cursor(win, { 2, 0 })
    end)
    feed('A = 5')
    retry(2, nil, function()
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
  end)

  it('works with multiple clients', function()
    exec_lua(function()
      vim.lsp.on_type_formatting.enable(true)
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
      })
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_cursor(win, { 2, 0 })
    end)
    feed('A =')
    retry(nil, 100, function()
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
  end)

  it('can be disabled', function()
    exec_lua(function()
      vim.lsp.on_type_formatting.enable(false, { client_id = _G.server_id })
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

  it('attaches to new buffers', function()
    exec_lua(function()
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        'int main() {',
        '  int hi',
        '}',
      })
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_cursor(win, { 2, 0 })
      vim.lsp.buf_attach_client(buf, _G.server_id)
    end)
    feed('A = 5')
    retry(nil, 100, function()
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
  end)
end)
