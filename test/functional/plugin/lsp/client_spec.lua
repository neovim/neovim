local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local funcs = helpers.funcs


local require_client = [[require('lsp.client').]]
local lsp_client_call = function(method, ...)
  return funcs.luaeval(require_client .. method .. '(_A)', ...)
end

describe('LSP client', function()
  before_each(clear)

  it('should parse headers', function()
    local message =
      [[Content-Length: 108\r\nContent-Type: application/vscode-jsonrpc; charset=utf8\r\n]]

    local parsed = lsp_client_call([[_parse_header]], message)
    eq(108, parsed.content_length)
  end)
end)
