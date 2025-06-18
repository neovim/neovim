local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')
local Screen = require('test.functional.ui.screen')

local dedent = t.dedent
local exec_lua = n.exec_lua
local insert = n.insert

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition

describe('vim.lsp.selection_range', function()
  local text = dedent([[
  hello
  hello
  hello
  hello
  hello]])

  --- @type test.functional.ui.screen
  local screen

  before_each(function()
    clear_notrace()
    screen = Screen.new(50, 9)

    exec_lua(create_server_definition)
    exec_lua(function()
      _G.server = _G._create_server({
        capabilities = {
          selectionRangeProvider = true,
        },
        handlers = {
          ['textDocument/selectionRange'] = function(_, _, callback)
            callback(nil, {
              {
                range = {
                  start = { line = 2, character = 0 },
                  ['end'] = { line = 2, character = 5 },
                },
                parent = {
                  range = {
                    start = { line = 1, character = 0 },
                    ['end'] = { line = 3, character = 5 },
                  },
                  parent = {
                    range = {
                      start = { line = 0, character = 0 },
                      ['end'] = { line = 5, character = 5 },
                    },
                    parent = nil,
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
  end)

  it('selects ranges', function()
    -- Initial range
    exec_lua(function()
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_cursor(win, { 3, 0 })
      vim.lsp.buf.selection_range(1)
    end)

    screen:expect([[
      hello                                             |*2
      {17:hell}^o                                             |
      hello                                             |*2
      {1:~                                                 }|*3
      {5:-- VISUAL --}                                      |
    ]])

    -- Outermost range
    exec_lua(function()
      vim.lsp.buf.selection_range(99)
    end)

    screen:expect([[
      {17:hello}                                             |*4
      {17:hell}^o                                             |
      {1:~                                                 }|*3
      {5:-- VISUAL --}                                      |
    ]])

    -- Back to innermost
    exec_lua(function()
      vim.lsp.buf.selection_range(-99)
    end)

    screen:expect([[
      hello                                             |*2
      {17:hell}^o                                             |
      hello                                             |*2
      {1:~                                                 }|*3
      {5:-- VISUAL --}                                      |
    ]])

    -- Middle range
    exec_lua(function()
      vim.lsp.buf.selection_range(1)
    end)

    screen:expect([[
      hello                                             |
      {17:hello}                                             |*2
      {17:hell}^o                                             |
      hello                                             |
      {1:~                                                 }|*3
      {5:-- VISUAL --}                                      |
    ]])
  end)
end)
