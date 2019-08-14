local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local insert = helpers.insert
local nvim = helpers.nvim

local function set_responses(responses)
  nvim('call_function', 'lsp#request', { "meta/setResponses", responses })
end

describe('plugin with a server', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(20, 10)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Red},
    })
    command('set rtp+=./runtime')
    command('hi Error guifg=red')
  end)

  it('textDocument/hover', function()
    command('call lsp#server_config#add("text",["nvim", "--headless", '..
            '"--cmd", "source test/functional/fixtures/nvim_fake_lsp.vim"])'
            )
    insert([[
      abc de
      fggli haf]])
    command('set ft=text')
    helpers.sleep(100)
    set_responses{
      {
        result = {
          contents = { { value = "hover_content", language = "txt" } },
          range = { start = { line = 0, character = 0 },
                    ["end"] = { line = 0, character = 2 },
          }
        }
      }
    }
    helpers.feed("o")
    helpers.feed('<C-r>=lsp#request("textDocument/hover")<Enter><Esc>')
    helpers.sleep(100)
    screen:expect([[
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
    ]])
  end)

  it('can deal with garbage responses', function()
    command('call lsp#server_config#add("text",["nvim", "--headless", '..
            '"--cmd", "source test/functional/fixtures/nvim_fake_lsp.vim"])'
            )
    insert([[
      abc de
      fggli haf]])
    command('set ft=text')
    helpers.sleep(100)

    set_responses{
      -- missing value in contents element
      {
        result = {
          contents = { { language = "txt" } },
          range = { start = { line = 0, character = 0 },
                    ["end"] = { line = 0, character = 2 },
          }
        }
      },
      -- element in contents that's not a table
      {
        result = {
          contents = { "xyz" },
          range = { start = { line = 0, character = 0 },
                    ["end"] = { line = 0, character = 2 },
          }
        }
      },
      -- contents missing
      {
        result = {
          range = { start = { line = 0, character = 0 },
                    ["end"] = { line = 0, character = 2 },
          }
        }
      },
      -- result empty
      {
        result = { }
      },
      -- response empty
      {
      },
      -- response not a table
      "xyz",
      -- response not a table
      5,
      -- response a non-ascii string
      "A\\u20dd\\u20dd",
    }

    helpers.command('echo lsp#request("textDocument/hover")')
  end)

end)
