local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local source = helpers.source
local dedent = helpers.dedent
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('Language Client API ', function()
  before_each(function()
    clear()
    source(dedent([[
      lua << EOF
        lsp = require('vim.lsp')
        lsp.server_config.add(
          'txt',
          {
            execute_path = 'nvim',
            args = { '--headless', '--cmd', 'source test/functional/fixtures/nvim_fake_lsp.vim' }
          }
        )
      EOF
    ]]))
  end)

  describe('start_client and stop_client', function()
    it('should return true', function()
      exec_lua("client = lsp.start_client('txt')")
      helpers.sleep(100)
      eq(false, exec_lua("return client._stopped"))

      exec_lua("lsp.stop_client('txt')")
      helpers.sleep(100)
      eq(true, exec_lua("return client._stopped"))

    end)
  end)
end)
