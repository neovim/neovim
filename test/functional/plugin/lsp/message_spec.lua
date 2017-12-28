local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local funcs = helpers.funcs
-- local dedent = helpers.dedent
-- local source = helpers.source

before_each(clear)

local __require_message = function(message_name, argument_string, conf)
  local require_string = string.format(
    [[require('lsp.message').%s:new]],
    message_name
  )

  if conf.attribute then
    return funcs.luaeval(
      string.format(
        [[%s(%s).%s]],
        require_string,
        argument_string,
        conf.attribute),
      conf
    )
  end

  if conf.property then
    return funcs.luaeval(
      string.format(
        [[%s(%s):%s()]],
        require_string,
        argument_string,
        conf.property
        ),
      conf
    )
  end

  return funcs.luaeval(
    string.format([[%s(%s)]], require_string, argument_string),
    conf
  )
end

local get_message = function(conf)
  return __require_message('Message', '', conf)
end
describe('Message', function()
  it('should return attributes', function ()
    local jsonrpc = get_message{
      attribute = 'jsonrpc'
    }
    eq(jsonrpc, "2.0")
  end)
end)

local get_request = function(conf)
  return __require_message('RequestMessage', '_A.name, _A.method, _A.params', conf)
end
describe('RequestMessage', function()
  it('should return attributes: jsonrpc', function()
    local r = get_request{
      name = 'request_server',
      method = 'test',
      params = { param = 1 },
      attribute = 'jsonrpc'
    }

    eq(r, "2.0")
  end)
  it('should return attributes: id', function()
    local req_id = get_request{
      name = 'request_server',
      method = 'test',
      params = { param = 1 },
      attribute = 'id'
    }
    eq(req_id, 0)
  end)
  it('should return attributes: method', function ()
    local method = get_request{
      name = 'request_server',
      method = 'test',
      params = { param = 1 },
      attribute = 'method'
    }
    eq(method, 'test')
  end)
  it('should return attributes: params', function ()
    local params = get_request{
      name = 'request_server',
      method = 'test',
      params = { param = 1 },
      attribute = 'params',
    }
    eq(params, {param=1})
  end)
  it('should give valid json', function()
    local data = get_request{
      name = 'request_server',
      method = 'test',
      params = { param = 1 },
      property = 'data',
    }
    eq('string', type(data))
  end)
  it('should handle auto populating values', function()
    local json_value = get_request{
      name = 'request_server',
      method = 'textDocument/references',
      property = 'json',
    }

    local decoded = funcs.json_decode(json_value)
    eq('textDocument/references', decoded.method)
    eq(true, decoded.params.context.includeDeclaration)
    eq({character = 0, line = 0}, decoded.params.position)
  end)
end)

-- local get_response = function(conf)
--   return __require_message('ResponseMessage', '_A.name', )
-- end
-- describe('ResponseMessage', function()
--   local r_result = message.ResponseMessage:new('resp_server', true)
--   local r_error = message.ResponseMessage:new('resp_server', nil, message.ResponseError:new())

--   it('should return attributes', function()
--     eq("2.0", r_result.jsonrpc)
--     eq(0, r_result.id)
--     eq(true, r_result.result)

--     eq("2.0", r_error.jsonrpc)
--     eq(1, r_error.id)
--     eq(nil, r_error.result)

--     -- TODO: Check the error
--     -- eq(r_error.err
--   end)
-- end)

