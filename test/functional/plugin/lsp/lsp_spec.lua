local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local source = helpers.source
local dedent = helpers.dedent
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('Language Client API ', function()
  describe('server_name is specified', function()
    before_each(function()
      clear()
      source(dedent([[
        lua << EOF
          lsp = require('vim.lsp')
          lsp.server_config.add({
            filetype = 'txt',
            server_name = 'nvim-server',
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
        eq(false, exec_lua("return lsp.client_has_started('txt')"))
        eq(false, exec_lua("return lsp.client_has_started('txt', 'nvim-server')"))

        exec_lua("client = lsp.start_client('txt', 'nvim-server')")
        helpers.sleep(10)

        eq(false, exec_lua("return client:is_stopped()"))
        eq(true, exec_lua("return lsp.client_has_started('txt')"))
        eq(true, exec_lua("return lsp.client_has_started('txt', 'nvim-server')"))

        exec_lua("lsp.stop_client('txt', 'nvim-server')")
        helpers.sleep(10)

        eq(true, exec_lua("return client:is_stopped()"))
        eq(false, exec_lua("return lsp.client_has_started('txt')"))
        eq(false, exec_lua("return lsp.client_has_started('txt', 'nvim-server')"))
      end)
    end)
  end)

  describe('server_name is not specified', function()
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
        eq(false, exec_lua("return lsp.client_has_started('txt')"))
        eq(false, exec_lua("return lsp.client_has_started('txt', 'txt')"))

        exec_lua("client = lsp.start_client('txt')")
        helpers.sleep(10)

        eq(false, exec_lua("return client:is_stopped()"))
        eq(true, exec_lua("return lsp.client_has_started('txt')"))
        eq(true, exec_lua("return lsp.client_has_started('txt', 'txt')"))

        exec_lua("lsp.stop_client('txt', 'txt')")
        helpers.sleep(10)

        eq(true, exec_lua("return client:is_stopped()"))
        eq(false, exec_lua("return lsp.client_has_started('txt')"))
        eq(false, exec_lua("return lsp.client_has_started('txt', 'txt')"))
      end)
    end)
  end)

  describe('running two language server for one filetype', function()
    before_each(function()
      clear()
      source(dedent([[
        lua << EOF
          lsp = require('vim.lsp')
          lsp.server_config.add({
            filetype = 'txt',
            server_name = 'server1',
            cmd = { './build/bin/nvim', '--headless' }
          })
          lsp.server_config.add({
            filetype = 'txt',
            server_name = 'server2',
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
        eq(false, exec_lua("return lsp.client_has_started('txt')"))
        eq(false, exec_lua("return lsp.client_has_started('txt', 'server1')"))
        eq(false, exec_lua("return lsp.client_has_started('txt', 'server2')"))

        exec_lua("client = lsp.start_client('txt', 'server1')")
        helpers.sleep(10)

        eq(false, exec_lua("return client:is_stopped()"))
        eq(true, exec_lua("return lsp.client_has_started('txt')"))
        eq(true, exec_lua("return lsp.client_has_started('txt', 'server1')"))
        eq(false, exec_lua("return lsp.client_has_started('txt', 'server2')"))

        exec_lua("lsp.stop_client('txt', 'server1')")
        helpers.sleep(10)

        eq(true, exec_lua("return client:is_stopped()"))
        eq(false, exec_lua("return lsp.client_has_started('txt')"))
        eq(false, exec_lua("return lsp.client_has_started('txt', 'server1')"))
        eq(false, exec_lua("return lsp.client_has_started('txt', 'server2')"))

        exec_lua("client = lsp.start_client('txt', 'server2')")
        helpers.sleep(10)

        eq(false, exec_lua("return client:is_stopped()"))
        eq(true, exec_lua("return lsp.client_has_started('txt')"))
        eq(false, exec_lua("return lsp.client_has_started('txt', 'server1')"))
        eq(true, exec_lua("return lsp.client_has_started('txt', 'server2')"))

        exec_lua("lsp.stop_client('txt', 'server2')")
        helpers.sleep(10)

        eq(true, exec_lua("return client:is_stopped()"))
        eq(false, exec_lua("return lsp.client_has_started('txt')"))
        eq(false, exec_lua("return lsp.client_has_started('txt', 'server1')"))
        eq(false, exec_lua("return lsp.client_has_started('txt', 'server2')"))
      end)
    end)
  end)
end)
