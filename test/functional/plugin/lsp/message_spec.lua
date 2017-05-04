-- luacheck: globals describe
-- luacheck: globals it
-- luacheck: globals before_each
-- luacheck: globals after_each

local message = require('runtime.lua.lsp.message')
local json = require('runtime.lua.json')

local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local funcs = helpers.funcs
local neq = helpers.neq
-- local dedent = helpers.dedent
-- local source = helpers.source

before_each(clear)

describe('Message', function()
  local m = message.Message:new()

  it('should return attributes', function ()
    eq(m.jsonrpc, "2.0")
  end)
end)

describe('RequestMessage', function()
  local req_string = "require('lsp.message').RequestMessage"
  local r = message.RequestMessage:new('request_server', 'test', {param=1})

  it('should return attributes', function()
    eq(r.jsonrpc, "2.0")
    eq(r.id, 0)
    eq(r.method, 'test')
    eq(r.params, {param=1})
    -- TODO: More specific test
    neq(r:json(), '')
  end)

  it('should give valid json', function()
    eq('string', type(r:data()))
  end)

  it('should handle auto populating values', function()
    local json_value = funcs.luaeval(req_string .. ":new('request_server', 'textDocument/references'):json()")
    local decoded = json.decode(json_value)
    eq('textDocument/references', decoded.method)
    eq(true, decoded.params.context.includeDeclaration)
    eq({character = 0, line = 0}, decoded.params.position)
  end)

end)

describe('ResponseMessage', function()
  local r_result = message.ResponseMessage:new('resp_server', true)
  local r_error = message.ResponseMessage:new('resp_server', nil, message.ResponseError:new())

  it('should return attributes', function()
    eq("2.0", r_result.jsonrpc)
    eq(0, r_result.id)
    eq(true, r_result.result)

    eq("2.0", r_error.jsonrpc)
    eq(1, r_error.id)
    eq(nil, r_error.result)

    -- TODO: Check the error
    -- eq(r_error.err
  end)
end)

