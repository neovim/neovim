
local helpers = require('test.functional.helpers')
local nvim, eq, neq, ok, eval
  = helpers.nvim, helpers.eq, helpers.neq, helpers.ok, helpers.eval
local clear = helpers.clear

describe('server*() functions', function()
  before_each(clear)

  it('set $NVIM_LISTEN_ADDRESS on first serverstart()', function()
    -- Ensure the listen address is unset.
    nvim('command', 'let $NVIM_LISTEN_ADDRESS = ""')
    nvim('command', 'let s = serverstart()')
    eq(1, eval('$NVIM_LISTEN_ADDRESS == s'))
    nvim('command', 'call serverstop(s)')
    eq(0, eval('$NVIM_LISTEN_ADDRESS == s'))
  end)

  it('let the user retrieve the list of servers', function()
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
