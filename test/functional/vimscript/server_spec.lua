local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq, neq, eval = t.eq, t.neq, n.eval
local clear, fn, api = n.clear, n.fn, n.api
local matches = t.matches
local pcall_err = t.pcall_err
local check_close = n.check_close
local mkdir = t.mkdir
local rmdir = n.rmdir
local is_os = t.is_os

local testlog = 'Xtest-server-log'

local function clear_serverlist()
  for _, server in pairs(fn.serverlist()) do
    fn.serverstop(server)
  end
end

after_each(function()
  check_close()
  os.remove(testlog)
end)

before_each(function()
  os.remove(testlog)
end)

describe('server', function()
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

  it('broken $XDG_RUNTIME_DIR is not fatal #30282', function()
    clear {
      args_rm = { '--listen' },
      env = { NVIM_LOG_FILE = testlog, XDG_RUNTIME_DIR = '/non-existent-dir/subdir//' },
    }

    if is_os('win') then
      -- Windows pipes have a special namespace and thus aren't decided by $XDG_RUNTIME_DIR.
      matches('nvim', api.nvim_get_vvar('servername'))
    else
      eq('', api.nvim_get_vvar('servername'))
      t.assert_log('Failed to start server%: no such file or directory', testlog, 100)
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
    clear {
      args_rm = { '--listen' },
      env = {
        NVIM_LOG_FILE = testlog,
        NVIM_LISTEN_ADDRESS = '',
      },
    }
    eq(0, eval("serverstop('')"))
    eq(0, eval("serverstop('bogus-socket-name')"))
    t.assert_log('Not listening on bogus%-socket%-name', testlog, 10)
  end)

  it('parses endpoints', function()
    clear {
      args_rm = { '--listen' },
      env = {
        NVIM_LOG_FILE = testlog,
        NVIM_LISTEN_ADDRESS = '',
      },
    }
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
      t.assert_log('Failed to start server: address already in use: 127%.0%.0%.1', testlog, 10)
    end

    local v6 = '::1:12345'
    status, _ = pcall(fn.serverstart, v6)
    if status then
      table.insert(expected, v6)
      pcall(fn.serverstart, v6) -- exists already; ignore
      t.assert_log('Failed to start server: address already in use: ::1', testlog, 10)
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
    local _n = eval('len(serverlist())')

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
    eq(_n + #servs, #new_servs)
    -- The new servers should be at the end of the list.
    for i = 1, #servs do
      eq(servs[i], new_servs[i + _n])
      eq(1, eval("serverstop('" .. servs[i] .. "')"))
    end
    -- After serverstop() the servers should NOT be in the list.
    eq(_n, eval('len(serverlist())'))
  end)
end)

describe('startup --listen', function()
  -- Tests Nvim output when failing to start, with and without "--headless".
  -- TODO(justinmk): clear() should have a way to get stdout if Nvim fails to start.
  local function _test(args, env, expected)
    local function run(cmd)
      return n.exec_lua(function(cmd_, env_)
        return vim
          .system(cmd_, {
            text = true,
            env = vim.tbl_extend(
              'force',
              -- Avoid noise in the logs; we expect failures for these tests.
              { NVIM_LOG_FILE = testlog },
              env_ or {}
            ),
          })
          :wait()
      end, cmd, env) --[[@as vim.SystemCompleted]]
    end

    local cmd = vim.list_extend({ n.nvim_prog, '+qall!', '--headless' }, args)
    local r = run(cmd)
    eq(1, r.code)
    matches(expected, (r.stderr .. r.stdout):gsub('\\n', ' '))

    if is_os('win') then
      return -- On Windows, output without --headless is garbage.
    end
    table.remove(cmd, 3) -- Remove '--headless'.
    assert(not vim.tbl_contains(cmd, '--headless'))
    r = run(cmd)
    eq(1, r.code)
    matches(expected, (r.stderr .. r.stdout):gsub('\\n', ' '))
  end

  it('validates', function()
    clear { env = { NVIM_LOG_FILE = testlog } }
    local in_use = n.eval('v:servername') ---@type string Address already used by another server.

    t.assert_nolog('Failed to start server', testlog, 100)
    t.assert_nolog('Host lookup failed', testlog, 100)

    _test({ '--listen' }, nil, 'nvim.*: Argument missing after: "%-%-listen"')
    _test({ '--listen2' }, nil, 'nvim.*: Garbage after option argument: "%-%-listen2"')
    _test(
      { '--listen', in_use },
      nil,
      ('nvim.*: Failed to %%-%%-listen: [^:]+ already [^:]+: "%s"'):format(vim.pesc(in_use))
    )
    _test({ '--listen', '/' }, nil, 'nvim.*: Failed to %-%-listen: [^:]+: "/"')
    _test(
      { '--listen', 'https://example.com' },
      nil,
      ('nvim.*: Failed to %%-%%-listen: %s: "https://example.com"'):format(
        is_os('mac') and 'unknown node or service' or 'service not available for socket type'
      )
    )

    t.assert_log('Failed to start server', testlog, 100)
    t.assert_log('Host lookup failed', testlog, 100)

    _test(
      {},
      { NVIM_LISTEN_ADDRESS = in_use },
      ('nvim.*: Failed $NVIM_LISTEN_ADDRESS: [^:]+ already [^:]+: "%s"'):format(vim.pesc(in_use))
    )
    _test({}, { NVIM_LISTEN_ADDRESS = '/' }, 'nvim.*: Failed $NVIM_LISTEN_ADDRESS: [^:]+: "/"')
    _test(
      {},
      { NVIM_LISTEN_ADDRESS = 'https://example.com' },
      ('nvim.*: Failed $NVIM_LISTEN_ADDRESS: %s: "https://example.com"'):format(
        is_os('mac') and 'unknown node or service' or 'service not available for socket type'
      )
    )
  end)

  it('sets v:servername, overrides $NVIM_LISTEN_ADDRESS', function()
    local addr = (is_os('win') and [[\\.\pipe\Xtest-listen-pipe]] or './Xtest-listen-pipe')
    clear({ env = { NVIM_LISTEN_ADDRESS = './Xtest-env-pipe' }, args = { '--listen', addr } })
    eq('', eval('$NVIM_LISTEN_ADDRESS')) -- Cleared on startup.
    eq(addr, api.nvim_get_vvar('servername'))

    -- Address without slashes is a "name" which is appended to a generated path. #8519
    clear({ args = { '--listen', 'test-name' } })
    matches([[.*[/\\]test%-name[^/\\]*]], api.nvim_get_vvar('servername'))
  end)
end)
