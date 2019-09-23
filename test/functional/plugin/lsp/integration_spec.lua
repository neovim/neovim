local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local source = helpers.source
local dedent = helpers.dedent
-- local eq = helpers.eq
local command = helpers.command
-- local exec_lua = helpers.exec_lua
local insert = helpers.insert
local feed = helpers.feed

local function set_responses(responses)
  command("lua require('vim.lsp').request_async('meta/setResponse', "..responses..")")
end

describe('plugin with a server', function()
  local screen

  before_each(function()
    clear()
    command('set rtp+=./runtime')
    screen = Screen.new(20, 10)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Red},
    })
    source(dedent([[
      lua << EOF
        lsp = require('vim.lsp')
        lsp.server_config.add({
          filetype = 'txt',
          cmd = {
            execute_path = './build/bin/nvim',
            args = { '--headless', '--cmd', 'source test/functional/fixtures/nvim_fake_lsp.vim' }
          }
        })
      EOF
    ]]))
  end)

  after_each(function()
    command("lua require('vim.lsp').stop_client('txt')")
  end)

  it('textDocument/hover', function()
    command('set ft=txt')
    command("lua require('vim.lsp').config.set_all_builtin_callbacks()")
    insert([[
      abc de
      fggli haf]])
    set_responses([[
      {
        result = {
          contents = { { value = "hover_content", language = "txt" } },
          range = { start = { line = 0, character = 0 },
                    ["end"] = { line = 0, character = 2 },
          }
        }
      }
    ]])
    helpers.sleep(100)
    feed("gg")
    feed("<ESC>:lua vim.lsp.request_async('textDocument/hover', vim.lsp.protocol.TextDocumentPositionParams())<CR>")
    helpers.sleep(100)

    screen:expect({grid=[[
      {2:ab}c de              |
      fggli haf           |
      hover_conten^t       |
      {1:~                   }|
      {1:~                   }|
      {1:~                   }|
      {1:~                   }|
      {1:~                   }|
      {1:~                   }|
                          |
    ]]})
  end)
end)
