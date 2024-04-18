local t = require('test.functional.testutil')()
local assert_log = t.assert_log
local eq, neq, eval = t.eq, t.neq, t.eval
local clear, fn, api = t.clear, t.fn, t.api
local ok = t.ok
local matches = t.matches
local pcall_err = t.pcall_err
local check_close = t.check_close
local mkdir = t.mkdir
local rmdir = t.rmdir
local is_os = t.is_os

local testlog = 'Xtest-server-log'

local function clear_serverlist()
  for _, server in pairs(fn.serverlist()) do
    fn.serverstop(server)
  end
end

describe('server', function()
  after_each(function()
    check_close()
    os.remove(testlog)
  end)

  it('serverstart() stores sockets in $XDG_RUNTIME_DIR', function()
    local dir = 'Xtest_xdg_run'
    mkdir(dir)
    finally(function()
      rmdir(dir)
    end)
    clear({ env = { XDG_RUNTIME_DIR = dir } })
    matches(dir, fn.stdpath('run'))
    if not is_os('win') then
      matches(dir, fn.serverstart())
    end
  end)

  it('serverstart(), serverstop() does not set $NVIM', function()
    clear()
    local s = eval('serverstart()')
    assert(s ~= nil and s:len() > 0, 'serverstart() returned empty')
    eq('', eval('$NVIM'))
    eq('', eval('$NVIM_LISTEN_ADDRESS'))
    eq(1, eval("serverstop('" .. s .. "')"))
    eq('', eval('$NVIM_LISTEN_ADDRESS'))
  end)

  it('sets new v:servername if $NVIM_LISTEN_ADDRESS is invalid', function()
    clear({ env = { NVIM_LISTEN_ADDRESS = '.' } })
    -- Cleared on startup.
    eq('', eval('$NVIM_LISTEN_ADDRESS'))
    local servers = fn.serverlist()
    eq(1, #servers)
    ok(string.len(servers[1]) > 4) -- "~/.local/state/nvim…/…" or "\\.\pipe\…"
  end)

  it('sets v:servername at startup or if all servers were stopped', function()
    clear()
    local initial_server = api.nvim_get_vvar('servername')
    assert(initial_server ~= nil and initial_server:len() > 0, 'v:servername was not initialized')

    -- v:servername is readonly so we cannot unset it--but we can test that it
    -- does not get set again thereafter.
    local s = fn.serverstart()
    assert(s ~= nil and s:len() > 0, 'serverstart() returned empty')
    neq(initial_server, s)

    -- serverstop() does _not_ modify v:servername...
    eq(1, fn.serverstop(s))
    eq(initial_server, api.nvim_get_vvar('servername'))

    -- ...unless we stop _all_ servers.
    eq(1, fn.serverstop(fn.serverlist()[1]))
    eq('', api.nvim_get_vvar('servername'))

    -- v:servername and $NVIM take the next available server.
    local servername = (
      is_os('win') and [[\\.\pipe\Xtest-functional-server-pipe]]
      or './Xtest-functional-server-socket'
    )
    fn.serverstart(servername)
    eq(servername, api.nvim_get_vvar('servername'))
    -- Not set in the current process, only in children.
    eq('', eval('$NVIM'))
  end)

  it('serverstop() returns false for invalid input', function()
    clear { env = {
      NVIM_LOG_FILE = testlog,
      NVIM_LISTEN_ADDRESS = '.',
    } }
    eq(0, eval("serverstop('')"))
    eq(0, eval("serverstop('bogus-socket-name')"))
    assert_log('Not listening on bogus%-socket%-name', testlog, 10)
  end)

  it('parses endpoints', function()
    clear { env = {
      NVIM_LOG_FILE = testlog,
      NVIM_LISTEN_ADDRESS = '.',
    } }
    clear_serverlist()
    eq({}, fn.serverlist())

    local s = fn.serverstart('127.0.0.1:0') -- assign random port
    if #s > 0 then
      matches('127.0.0.1:%d+', s)
      eq(s, fn.serverlist()[1])
      clear_serverlist()
    end

    s = fn.serverstart('127.0.0.1:') -- assign random port
    if #s > 0 then
      matches('127.0.0.1:%d+', s)
      eq(s, fn.serverlist()[1])
      clear_serverlist()
    end

    local expected = {}
    local v4 = '127.0.0.1:12345'
    local status, _ = pcall(fn.serverstart, v4)
    if status then
      table.insert(expected, v4)
      pcall(fn.serverstart, v4) -- exists already; ignore
      assert_log('Failed to start server: address already in use: 127%.0%.0%.1', testlog, 10)
    end

    local v6 = '::1:12345'
    status, _ = pcall(fn.serverstart, v6)
    if status then
      table.insert(expected, v6)
      pcall(fn.serverstart, v6) -- exists already; ignore
      assert_log('Failed to start server: address already in use: ::1', testlog, 10)
    end
    eq(expected, fn.serverlist())
    clear_serverlist()

    -- Address without slashes is a "name" which is appended to a generated path. #8519
    matches([[.*[/\\]xtest1%.2%.3%.4[^/\\]*]], fn.serverstart('xtest1.2.3.4'))
    clear_serverlist()

    eq('Vim:Failed to start server: invalid argument', pcall_err(fn.serverstart, '127.0.0.1:65536')) -- invalid port
    eq({}, fn.serverlist())
  end)

  it('serverlist() returns the list of servers', function()
    clear()
    -- There should already be at least one server.
    local n = eval('len(serverlist())')

    -- Add some servers.
    local servs = (
      is_os('win') and { [[\\.\pipe\Xtest-pipe0934]], [[\\.\pipe\Xtest-pipe4324]] }
      or { [[./Xtest-pipe0934]], [[./Xtest-pipe4324]] }
    )
    for _, s in ipairs(servs) do
      eq(s, eval("serverstart('" .. s .. "')"))
    end

    local new_servs = eval('serverlist()')

    -- Exactly #servs servers should be added.
    eq(n + #servs, #new_servs)
    -- The new servers should be at the end of the list.
    for i = 1, #servs do
      eq(servs[i], new_servs[i + n])
      eq(1, eval("serverstop('" .. servs[i] .. "')"))
    end
    -- After serverstop() the servers should NOT be in the list.
    eq(n, eval('len(serverlist())'))
  end)
end)

describe('startup --listen', function()
  it('validates', function()
    clear()
    local cmd = { unpack(t.nvim_argv) }
    table.insert(cmd, '--listen')
    matches('nvim.*: Argument missing after: "%-%-listen"', fn.system(cmd))

    cmd = { unpack(t.nvim_argv) }
    table.insert(cmd, '--listen2')
    matches('nvim.*: Garbage after option argument: "%-%-listen2"', fn.system(cmd))
  end)

  it('sets v:servername, overrides $NVIM_LISTEN_ADDRESS', function()
    local addr = (is_os('win') and [[\\.\pipe\Xtest-listen-pipe]] or './Xtest-listen-pipe')
    clear({ env = { NVIM_LISTEN_ADDRESS = './Xtest-env-pipe' }, args = { '--listen', addr } })
    eq(addr, api.nvim_get_vvar('servername'))

    -- Address without slashes is a "name" which is appended to a generated path. #8519
    clear({ args = { '--listen', 'test-name' } })
    matches([[.*[/\\]test%-name[^/\\]*]], api.nvim_get_vvar('servername'))
  end)
end)
