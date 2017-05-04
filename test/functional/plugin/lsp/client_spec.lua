local client = require('runtime.lua.lsp.client')

local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq


describe('LSP client', function()
  before_each(clear)
  it('should parse headers', function()
    local message = [[Content-Length: 108\r\nContent-Type: application/vscode-jsonrpc; charset=utf8\r\n]]

    local parsed = client._parse_header(message)
    eq(108, parsed.content_length)
  end)
end)
