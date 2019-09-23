local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local funcs = helpers.funcs

before_each(clear)

local __require_message = function(message_name, argument_string, conf)
  local require_string = string.format(
    [[require('vim.lsp.message').%s:new]],
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
    eq("2.0", jsonrpc)
  end)
end)

local get_request = function(conf)
  return __require_message('RequestMessage', '_A.client, _A.method, _A.params', conf)
end

local mock_client = { server_name = 'test', server_capabilities = {} }

describe('RequestMessage', function()
  it('should return attributes: jsonrpc', function()
    local r = get_request{
      client = mock_client,
      method = 'test',
      params = { param = 1 },
      attribute = 'jsonrpc'
    }

    eq("2.0", r)
  end)
  it('should return attributes: id', function()
    local req_id = get_request{
      client = mock_client,
      method = 'test',
      params = { param = 1 },
      attribute = 'id'
    }
    eq(0, req_id)
  end)
  it('should return attributes: method', function ()
    local method = get_request{
      client = mock_client,
      method = 'test',
      params = { param = 1 },
      attribute = 'method'
    }
    eq('test', method)
  end)
  it('should return attributes: params', function ()
    local params = get_request{
      client = mock_client,
      method = 'test',
      params = { param = 1 },
      attribute = 'params',
    }
    eq({param=1}, params)
  end)
  it('should give valid json', function()
    local data = get_request{
      client = mock_client,
      method = 'test',
      params = { param = 1 },
      property = 'data',
    }
    eq('string', type(data))
  end)

  describe('check_language_server_capabilities', function()
    describe('server_capabilities.referencesProvider eq true', function()
      it('enable to get new RequestMessage', function()
        mock_client.server_capabilities['referencesProvider'] = true
        local json_value = get_request{
          client = mock_client,
          method = 'textDocument/references',
          params = { position = { character = 0, line = 0 } },
          property = 'json',
        }

        local decoded = funcs.json_decode(json_value)
        eq('textDocument/references', decoded.method)
        eq({character = 0, line = 0}, decoded.params.position)
      end)
    end)
  end)
end)
