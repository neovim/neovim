local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')
local Screen = require('test.functional.ui.screen')

local dedent = t.dedent

local api = n.api
local exec_lua = n.exec_lua
local insert = n.insert
local command = n.command

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition

describe('vim.lsp.document_highlight', function()
  local text = dedent([[
    global = _G

    local variable = global

    if variable == global then

    end
  ]])

  local grid_without_highlights = dedent([[
    ^global = _G                                          |
                                                         |
    local variable = global                              |
                                                         |
    if variable == global then                           |
                                                         |
    end                                                  |
                                                         |
    {2:~                                                    }|*5
                                                         |
  ]])

  local grid_with_highlights = dedent([[
    {1:^global} = _G                                          |
                                                         |
    local variable = {1:global}                              |
                                                         |
    if variable == {1:global} then                           |
                                                         |
    end                                                  |
                                                         |
    {2:~                                                    }|*5
                                                         |
  ]])

  --- @type test.functional.ui.screen
  local screen

  --- @type integer
  local client_id

  before_each(function()
    clear_notrace()
    exec_lua(create_server_definition)

    screen = Screen.new()
    screen:set_default_attr_ids({
      [1] = { foreground = Screen.colors.Grey0, background = Screen.colors.LightGrey },
      [2] = { bold = true, foreground = Screen.colors.Blue1 },
    })

    client_id = exec_lua(function()
      _G.server = _G._create_server({
        capabilities = {
          documentHighlightProvider = true,
        },
        handlers = {
          ['textDocument/documentHighlight'] = function(_, _, callback)
            callback(nil, {
              {
                kind = 3,
                range = {
                  ['end'] = {
                    character = 6,
                    line = 0,
                  },
                  start = {
                    character = 0,
                    line = 0,
                  },
                },
              },
              {
                kind = 2,
                range = {
                  ['end'] = {
                    character = 23,
                    line = 2,
                  },
                  start = {
                    character = 17,
                    line = 2,
                  },
                },
              },
              {
                kind = 2,
                range = {
                  ['end'] = {
                    character = 21,
                    line = 4,
                  },
                  start = {
                    character = 15,
                    line = 4,
                  },
                },
              },
            })
          end,
        },
      })

      return vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
    end)

    insert(text)
    command('1')
    exec_lua(function()
      vim.lsp.document_highlight.enable(true)
    end)

    screen:expect({ grid = grid_with_highlights })
  end)

  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  describe('enable()', function()
    it('clears document highlights when sole client detaches', function()
      exec_lua(function()
        vim.lsp.stop_client(client_id)
      end)

      screen:expect({ grid = grid_without_highlights })
    end)
  end)

  describe('jump()', function()
    it('jumpts to the last highlight', function()
      exec_lua(function()
        vim.lsp.document_highlight.jump({ count = 999 })
      end)
      screen:expect([[
        {1:global} = _G                                          |
                                                             |
        local variable = {1:global}                              |
                                                             |
        if variable == {1:^global} then                           |
                                                             |
        end                                                  |
                                                             |
        {2:~                                                    }|*5
                                                             |
      ]])
    end)

    it('jumpts to the first highlight', function()
      exec_lua(function()
        vim.lsp.document_highlight.jump({ count = 999 })
        vim.lsp.document_highlight.jump({ count = -9 })
      end)
      screen:expect([[
        {1:^global} = _G                                          |
                                                             |
        local variable = {1:global}                              |
                                                             |
        if variable == {1:global} then                           |
                                                             |
        end                                                  |
                                                             |
        {2:~                                                    }|*5
                                                             |
      ]])
    end)
  end)
end)
