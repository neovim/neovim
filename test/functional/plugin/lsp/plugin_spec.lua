local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq

local plugin = require('runtime.lua.lsp.plugin')
local callbacks = require('runtime.lua.lsp.callbacks').callbacks

before_each(clear)

describe('LSP plugin', function()
  describe('default callbacks', function()
    it('should return callbacks for things we have defined', function()
      eq(callbacks.textDocument.references, plugin.client.get_callback('textDocument/references'))
    end)

    it('should return the callback passed if given', function()
      local testfunc = function() return 1 end
      eq(testfunc, plugin.client.get_callback('textDocument/references', testfunc))
    end)
  end)
end)
