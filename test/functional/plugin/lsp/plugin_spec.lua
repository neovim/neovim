local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local source = helpers.source
local dedent = helpers.dedent

before_each(clear)

describe('LSP plugin', function()
  describe('default callbacks', function()
    it('should return callbacks for things we have defined', function()
      source(dedent([[
        lua << EOF
          local plugin = require('lsp.plugin')
          local callbacks = require('lsp.callbacks').callbacks
          assert(
            callbacks.textDocument.references == plugin.client.get_callback('textDocument/references')
            )
        EOF
      ]]))
    end)

    it('should return the callback passed if given', function()
      source(dedent([[
        lua << EOF
          local plugin = require('lsp.plugin')
          local callbacks = require('lsp.callbacks').callbacks
          local testfunc = function() return 1 end
          assert(
            testfunc == plugin.client.get_callback('textDocument/references', testfunc)
          )
        EOF
      ]]))
    end)
  end)
end)
