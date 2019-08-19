local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local source = helpers.source
local dedent = helpers.dedent

before_each(clear)

describe('Language Client API ', function()
  describe('default callbacks', function()
    it('should return callbacks for things we have defined', function()
      source(dedent([[
        lua << EOF
          local lsp = require('vim.lsp')
          assert(lsp.is_supported_request('textDocument/references'))
        EOF
      ]]))
    end)
  end)
end)
