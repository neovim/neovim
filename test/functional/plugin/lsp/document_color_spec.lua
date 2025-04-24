local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')
local Screen = require('test.functional.ui.screen')

local dedent = t.dedent
local eq = t.eq

local api = n.api
local exec_lua = n.exec_lua
local insert = n.insert

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition

describe('vim.lsp.document_color', function()
  local text = dedent([[
body {
  color: #FFF;
  background-color: rgb(0, 255, 255);
}
]])

  local grid_without_colors = [[
  body {                                               |
    color: #FFF;                                       |
    background-color: rgb(0, 255, 255);                |
  }                                                    |
  ^                                                     |
  {1:~                                                    }|*8
                                                       |
  ]]

  local grid_with_colors = [[
  body {                                               |
    color: {2:#FFF};                                       |
    background-color: {3:rgb(0, 255, 255)};                |
  }                                                    |
  ^                                                     |
  {1:~                                                    }|*8
                                                       |
  ]]

  --- @type test.functional.ui.screen
  local screen

  --- @type integer
  local client_id

  --- @type integer
  local bufnr

  before_each(function()
    clear_notrace()
    exec_lua(create_server_definition)

    screen = Screen.new()
    screen:set_default_attr_ids {
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { background = Screen.colors.Gray100, foreground = Screen.colors.Gray0 },
      [3] = { background = Screen.colors.Cyan1, foreground = Screen.colors.Gray0 },
      [4] = { foreground = Screen.colors.Grey100 },
      [5] = { foreground = Screen.colors.Cyan1 },
    }

    bufnr = n.api.nvim_get_current_buf()
    client_id = exec_lua(function()
      _G.server = _G._create_server({
        capabilities = {
          colorProvider = true,
        },
        handlers = {
          ['textDocument/documentColor'] = function(_, _, callback)
            callback(nil, {
              {
                range = {
                  start = { line = 1, character = 9 },
                  ['end'] = { line = 1, character = 13 },
                },
                color = { red = 1, green = 1, blue = 1 },
              },
              {
                range = {
                  start = { line = 2, character = 20 },
                  ['end'] = { line = 2, character = 36 },
                },
                color = { red = 0, green = 1, blue = 1 },
              },
            })
          end,
        },
      })

      return vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
    end)

    insert(text)

    exec_lua(function()
      vim.lsp.document_color.enable(true, bufnr)
    end)

    screen:expect({ grid = grid_with_colors })
  end)

  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  it('clears document colors when sole client detaches', function()
    exec_lua(function()
      vim.lsp.stop_client(client_id)
    end)

    screen:expect({ grid = grid_without_colors })
  end)

  it('does not clear document colors when one of several clients detaches', function()
    local client_id2 = exec_lua(function()
      _G.server2 = _G._create_server({
        capabilities = {
          colorProvider = true,
        },
        handlers = {
          ['textDocument/documentColor'] = function(_, _, callback)
            callback(nil, {})
          end,
        },
      })
      local client_id2 = vim.lsp.start({ name = 'dummy2', cmd = _G.server2.cmd })
      vim.lsp.document_color.enable(true, bufnr)
      return client_id2
    end)

    exec_lua(function()
      vim.lsp.stop_client(client_id2)
    end)

    screen:expect({ grid = grid_with_colors, unchanged = true })
  end)

  describe('is_enabled()', function()
    it('returns true when document colors is enabled', function()
      eq(
        true,
        exec_lua(function()
          return vim.lsp.document_color.is_enabled(bufnr)
        end)
      )

      exec_lua(function()
        vim.lsp.stop_client(client_id)
      end)

      eq(
        false,
        exec_lua(function()
          return vim.lsp.document_color.is_enabled(bufnr)
        end)
      )
    end)

    it('does not error when called on a new unattached buffer', function()
      eq(
        false,
        exec_lua(function()
          return vim.lsp.document_color.is_enabled(vim.api.nvim_create_buf(false, true))
        end)
      )
    end)
  end)

  describe('enable()', function()
    it('supports foreground styling', function()
      local grid_with_fg_colors = [[
body {                                               |
  color: {4:#FFF};                                       |
  background-color: {5:rgb(0, 255, 255)};                |
}                                                    |
^                                                     |
{1:~                                                    }|*8
                                                     |
      ]]

      exec_lua(function()
        vim.lsp.document_color.enable(true, bufnr, { style = 'foreground' })
      end)

      screen:expect({ grid = grid_with_fg_colors })
    end)

    it('supports custom swatch text', function()
      local grid_with_swatches = [[
body {                                               |
  color: {4: :) }#FFF;                                   |
  background-color: {5: :) }rgb(0, 255, 255);            |
}                                                    |
^                                                     |
{1:~                                                    }|*8
                                                     |
      ]]

      exec_lua(function()
        vim.lsp.document_color.enable(true, bufnr, { style = ' :) ' })
      end)

      screen:expect({ grid = grid_with_swatches })
    end)

    it('will not create highlights with custom style function', function()
      exec_lua(function()
        vim.lsp.document_color.enable(true, bufnr, {
          style = function() end,
        })
      end)

      screen:expect({ grid = grid_without_colors })
    end)
  end)
end)
