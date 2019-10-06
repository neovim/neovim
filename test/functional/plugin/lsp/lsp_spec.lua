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
        lsp.server_config.add({
          filetype = 'txt',
          cmd = { './build/bin/nvim', '--headless' }
        })
      EOF
    ]]))
  end)

  after_each(function()
    exec_lua("lsp.stop_client('txt')")
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
