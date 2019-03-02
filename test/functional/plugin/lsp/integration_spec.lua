local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local insert = helpers.insert

describe('plugin with a server', function()

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

  it('basic', function()
    command('call lsp#server#add("text",["nvim", "--headless", '..
            '"--cmd", "source test/functional/fixtures/nvim_fake_lsp.vim"])'
            )
    insert([[
      abc de
      fggli haf
      ]])
    command('set ft=text')
    helpers.sleep(100)
    helpers.feed("o")
    helpers.feed('<C-r>=lsp#request("textDocument/hover")<Enter><Esc>')
    helpers.sleep(100)
    screen:expect([[
      {2:ab}c de              |
      fggli haf           |
                          |
      hover_content       |
      ^                    |
      {1:~                   }|
      {1:~                   }|
      {1:~                   }|
      {1:~                   }|
                          |
    ]])
  end)

end)
