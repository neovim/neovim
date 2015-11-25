
local helpers = require('test.functional.helpers')
local nvim, eq, neq, eval = helpers.nvim, helpers.eq, helpers.neq, helpers.eval
local clear = helpers.clear

describe('serverstart(), serverstop()', function()
  before_each(clear)

  it('sets $NVIM_LISTEN_ADDRESS on first invocation', function()
    -- Unset $NVIM_LISTEN_ADDRESS
    nvim('command', 'let $NVIM_LISTEN_ADDRESS = ""')

    local s = eval('serverstart()')
    assert(s ~= nil and s:len() > 0, "serverstart() returned empty")
    eq(s, eval('$NVIM_LISTEN_ADDRESS'))
    nvim('command', "call serverstop('"..s.."')")
    eq('', eval('$NVIM_LISTEN_ADDRESS'))
  end)

  it([[sets v:servername _only_ on nvim startup
      (unless all servers are stopped)]], function()
    local initial_server = eval('v:servername')
    assert(initial_server ~= nil and initial_server:len() > 0,
      "v:servername was not initialized")

    -- v:servername is readonly so we cannot unset it--but we can test that it
    -- does not get set again thereafter.
    local s = eval('serverstart()')
    assert(s ~= nil and s:len() > 0, "serverstart() returned empty")
    neq(initial_server, s)

    -- serverstop() does _not_ modify v:servername...
    nvim('command', "call serverstop('"..s.."')")
    eq(initial_server, eval('v:servername'))

    -- ...unless we stop _all_ servers.
    nvim('command', "call serverstop(serverlist()[0])")
    eq('', eval('v:servername'))

    -- v:servername will take the next available server.
    nvim('command', "call serverstart('test_server_socket')")
    eq('test_server_socket', eval('v:servername'))
  end)

  it('serverstop() ignores invalid input', function()
    nvim('command', "call serverstop('')")
    nvim('command', "call serverstop('bogus-socket-name')")
  end)

end)

describe('serverlist()', function()
  before_each(clear)

  it('returns the list of servers', function()
    -- There should already be at least one server.
    local n = eval('len(serverlist())')

    -- Add a few
    local servs = {'should-not-exist', 'another-one-that-shouldnt'}
    for _, s in ipairs(servs) do
      eq(s, eval('serverstart("'..s..'")'))
    end

    local new_servs = eval('serverlist()')

    -- Exactly #servs servers should be added.
    eq(n + #servs, #new_servs)
    -- The new servers should be at the end of the list.
    for i = 1, #servs do
      eq(servs[i], new_servs[i + n])
      nvim('command', 'call serverstop("'..servs[i]..'")')
    end
    -- After calling serverstop() on the new servers, they should no longer be
    -- in the list.
    eq(n, eval('len(serverlist())'))
  end)
end)
