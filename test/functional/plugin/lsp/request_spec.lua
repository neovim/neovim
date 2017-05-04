-- luacheck: globals describe
-- luacheck: globals it
-- luacheck: globals before_each
-- luacheck: globals after_each

local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq

local request = require('runtime.lua.lsp.request')

before_each(clear)

describe('get_request_function', function()
  it('should return valid functions for valid names', function()
    local f = request.get_request_function('textDocument/references')
    eq(request.requests.textDocument.references, f)
  end)

  it('should return valid function for textDocument/hover', function()
    local f = request.get_request_function('textDocument/hover')
    eq(request.requests.textDocument.hover, f)
  end)

  it('should return nil for non supported items', function()
    local f = request.get_request_function('notSupported/nope')
    eq(nil, f)
  end)

  it('should also work if you pass in an already split string', function()
    local f = request.get_request_function({'textDocument', 'references'})
    eq(request.requests.textDocument.references, f)
  end)
end)
