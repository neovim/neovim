
local helpers = require('test.functional.helpers')(after_each)
local eq, neq, eval = helpers.eq, helpers.neq, helpers.eval
local command = helpers.command
local clear, funcs, meths = helpers.clear, helpers.funcs, helpers.meths
local os_name = helpers.os_name

local function clear_serverlist()
    for _, server in pairs(funcs.serverlist()) do
      funcs.serverstop(server)
    end
end

describe('serverstart(), serverstop()', function()
  before_each(clear)

  it('sets $NVIM_LISTEN_ADDRESS on first invocation', function()
    -- Unset $NVIM_LISTEN_ADDRESS
    command('let $NVIM_LISTEN_ADDRESS = ""')

    local s = eval('serverstart()')
    assert(s ~= nil and s:len() > 0, "serverstart() returned empty")
    eq(s, eval('$NVIM_LISTEN_ADDRESS'))
    command("call serverstop('"..s.."')")
    eq('', eval('$NVIM_LISTEN_ADDRESS'))
  end)

  it('sets v:servername _only_ on nvim startup unless all servers are stopped',
  function()
    local initial_server = meths.get_vvar('servername')
    assert(initial_server ~= nil and initial_server:len() > 0,
           'v:servername was not initialized')

    -- v:servername is readonly so we cannot unset it--but we can test that it
    -- does not get set again thereafter.
    local s = funcs.serverstart()
    assert(s ~= nil and s:len() > 0, "serverstart() returned empty")
    neq(initial_server, s)

    -- serverstop() does _not_ modify v:servername...
    funcs.serverstop(s)
    eq(initial_server, meths.get_vvar('servername'))

    -- ...unless we stop _all_ servers.
    funcs.serverstop(funcs.serverlist()[1])
    eq('', meths.get_vvar('servername'))

    -- v:servername will take the next available server.
    local servername = (os_name() == 'windows'
                        and [[\\.\pipe\Xtest-functional-server-pipe]]
                        or 'Xtest-functional-server-socket')
    funcs.serverstart(servername)
    eq(servername, meths.get_vvar('servername'))
  end)

  it('serverstop() ignores invalid input', function()
    command("call serverstop('')")
    command("call serverstop('bogus-socket-name')")
  end)

  it('parses endpoints correctly', function()
    clear_serverlist()
    eq({}, funcs.serverlist())

    local s = funcs.serverstart('127.0.0.1:0')  -- assign random port
    if #s > 0 then
      assert(string.match(s, '127.0.0.1:%d+'))
      eq(s, funcs.serverlist()[1])
      clear_serverlist()
    end

    s = funcs.serverstart('127.0.0.1:')  -- assign random port
    if #s > 0 then
      assert(string.match(s, '127.0.0.1:%d+'))
      eq(s, funcs.serverlist()[1])
      clear_serverlist()
    end

    local expected = {}
    local v4 = '127.0.0.1:12345'
    s = funcs.serverstart(v4)
    if #s > 0 then
      table.insert(expected, v4)
      funcs.serverstart(v4)  -- exists already; ignore
    end

    local v6 = '::1:12345'
    s = funcs.serverstart(v6)
    if #s > 0 then
      table.insert(expected, v6)
      funcs.serverstart(v6)  -- exists already; ignore
    end
    eq(expected, funcs.serverlist())
    clear_serverlist()

    funcs.serverstart('127.0.0.1:65536')  -- invalid port
    eq({}, funcs.serverlist())
  end)
end)

describe('serverlist()', function()
  before_each(clear)

  it('returns the list of servers', function()
    -- There should already be at least one server.
    local n = eval('len(serverlist())')

    -- Add a few
    local servs = (os_name() == 'windows'
      and { [[\\.\pipe\Xtest-pipe0934]], [[\\.\pipe\Xtest-pipe4324]] }
      or  { [[Xtest-pipe0934]], [[Xtest-pipe4324]] })
    for _, s in ipairs(servs) do
      eq(s, eval("serverstart('"..s.."')"))
    end

    local new_servs = eval('serverlist()')

    -- Exactly #servs servers should be added.
    eq(n + #servs, #new_servs)
    -- The new servers should be at the end of the list.
    for i = 1, #servs do
      eq(servs[i], new_servs[i + n])
      command("call serverstop('"..servs[i].."')")
    end
    -- After serverstop() the servers should NOT be in the list.
    eq(n, eval('len(serverlist())'))
  end)
end)
