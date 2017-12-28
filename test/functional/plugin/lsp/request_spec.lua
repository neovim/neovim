-- luacheck: globals describe
-- luacheck: globals it
-- luacheck: globals before_each
-- luacheck: globals after_each

local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local source = helpers.source
local dedent = helpers.dedent

before_each(clear)
describe('get_request_function', function()
  it('should return valid functions for valid names', function()
    source(dedent([[
      lua << EOF
        local request = require('lsp.request')
        local f = request.get_request_function('textDocument/references')
        assert(request.requests.textDocument.references == f)
      EOF
    ]]))
  end)

  it('should return valid function for textDocument/hover', function()
    source(dedent([[
      lua << EOF
        local request = require('lsp.request')
        local f = request.get_request_function('textDocument/hover')
        assert(request.requests.textDocument.hover == f)
      EOF
    ]]))
  end)

  it('should return nil for non supported items', function()
    source(dedent([[
      lua << EOF
        local request = require('lsp.request')
        local f = request.get_request_function('notSupported/nope')
        assert(nil == f)
      EOF
    ]]))
  end)

  it('should also work if you pass in an already split string', function()
    source(dedent([[
      lua << EOF
        local request = require('lsp.request')
        local f = request.get_request_function({'textDocument', 'references'})
        assert(request.requests.textDocument.references == f)
      EOF
    ]]))
  end)
end)
