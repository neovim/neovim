local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command = helpers.command
local insert = helpers.insert

describe('plugin with a server', function()

  before_each(function()
    clear()
    screen = Screen.new(20, 10)
    screen:attach()
    command('set rtp+=runtime')
  end)

  it('basic', function()
    command('call lsp#server#add("text",["nvim", "--headless", '..
            '"--cmd", "source test/functional/fixtures/nvim_fake_lsp.vim"])'
            )
    insert([[
      abc de
      fggli haf
    ]])
    command('echo lsp#request("textDocument/hover")')
    screen:snapshot_util()
  end)

end)
