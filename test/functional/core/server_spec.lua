local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each, after_each, finally =
  t.describe, t.it, t.before_each, t.after_each, t.finally
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
      is_os('win') and [[//./pipe/Xtest-functional-server-pipe]]
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
    matches([[[/\\]xtest1%.2%.3%.4[^/\\]*]], fn.serverstart('xtest1.2.3.4'))
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
      is_os('win') and { [[//./pipe/Xtest-pipe0934]], [[//./pipe/Xtest-pipe4324]] }
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

  it('serverlist({peer=true}) gets peer sessions (concurrently)', function()
    t.skip(is_os('win'), 'peer discovery is not supported on Windows')
    -- Set XDG_RUNTIME_DIR to a temp dir to properly test serverlist({peer=true}). #35492
    local tmp_dir = assert(vim.uv.fs_mkdtemp(vim.fs.dirname(t.tmpname(false)) .. '/XXXXXX'))
    local current_server = clear({ env = { XDG_RUNTIME_DIR = tmp_dir } })

    local old_servs_num = #fn.serverlist({ peer = true })
    local peer_temp = n.new_pipename()
    local peer_name = peer_temp:match('[^/]*$')

    local tmp_dir2 = assert(vim.uv.fs_mkdtemp(vim.fs.dirname(t.tmpname(false)) .. '/XXXXXX'))
    local peer_addr = ('%s/%s'):format(tmp_dir2, peer_name)
    -- Set XDG_RUNTIME_DIR to a temp dir in this session to properly test serverlist({peer = true}). See #35492
    local client = n.new_session(true, {
      args = { '--clean', '--listen', peer_addr, '--embed' },
      env = { XDG_RUNTIME_DIR = tmp_dir2 },
      merge = false,
    })
    n.set_session(client)
    eq(peer_addr, fn.serverlist()[1])

    n.set_session(current_server)

    local new_servs = fn.serverlist({ peer = true })
    local servers_without_peer = fn.serverlist()
    eq(true, vim.list_contains(new_servs, peer_addr))
    eq(true, #servers_without_peer < #new_servs)
    eq(true, old_servs_num < #new_servs)

    -- serverlist({info=true}) returns rich info dicts (implies peer=true)
    local info_servs = fn.serverlist({ info = true })
    eq(#new_servs, #info_servs)

    local own_addr = fn.serverlist()[1]
    local self_pid = fn.getpid()
    ---@type table<string, table>
    local by_addr = {}
    for _, entry in ipairs(info_servs) do
      eq('string', type(entry.addr))
      eq('boolean', type(entry.own))
      by_addr[entry.addr] = entry
    end

    -- own server: own=true, pid matches, active present
    local own_entry = by_addr[own_addr]
    eq(true, own_entry ~= nil)
    eq(true, own_entry.own)
    eq(self_pid, own_entry.pid)
    eq('number', type(own_entry.active))
    eq(eval('v:useractive'), own_entry.active)

    -- peer server: own=false, pid + active from peer process
    local peer_entry = by_addr[peer_addr]
    eq(true, peer_entry ~= nil)
    eq(false, peer_entry.own)
    eq('number', type(peer_entry.pid))
    eq('number', type(peer_entry.active))
    n.set_session(client)
    local peer_pid = fn.getpid()
    local peer_active = eval('v:useractive')
    n.set_session(current_server)
    eq(peer_pid, peer_entry.pid)
    eq(peer_active, peer_entry.active)

    -- Queries peers concurrently, omits unresponsive ones (connection accepted, but no answer).
    local hung_dir = assert(vim.uv.fs_mkdtemp(vim.fs.dirname(t.tmpname(false)) .. '/XXXXXX'))
    local hung = {} ---@type uv.uv_pipe_t[]
    finally(function()
      for _, pipe in ipairs(hung) do
        pipe:close()
      end
      n.rmdir(hung_dir)
    end)
    for i = 1, 4 do
      local pipe = assert(vim.uv.new_pipe())
      assert(pipe:bind(('%s/nvim.hung.%d'):format(hung_dir, i)))
      assert(pipe:listen(8, function() end))
      table.insert(hung, pipe)
    end
    local ms, servers = unpack(n.exec_lua(function()
      local start = vim.uv.hrtime()
      local servers = vim.fn.serverlist({ peer = true })
      return { (vim.uv.hrtime() - start) / 1e6, servers }
    end))
    -- One timeout (1s) for all, not one per server.
    t.ok(ms < 3000, '< 3000 ms', ms)
    t.not_matches('nvim%.hung', table.concat(servers, ' '))
    eq(true, vim.list_contains(servers, peer_addr))

    client:close()
  end)

  it(':connect (no args) shows peers + ssh hosts', function()
    t.skip(is_os('win'), 'peer discovery is not supported on Windows')
    local base = vim.fs.dirname(t.tmpname(false))
    local run_dir = assert(vim.uv.fs_mkdtemp(base .. '/XXXXXX'))
    local peer_dir = assert(vim.uv.fs_mkdtemp(base .. '/XXXXXX'))
    local home = assert(vim.uv.fs_mkdtemp(base .. '/XXXXXX'))
    finally(function()
      n.rmdir(peer_dir)
      n.rmdir(run_dir)
      n.rmdir(home)
    end)
    t.mkdir(home .. '/.ssh')
    t.write_file(home .. '/.ssh/config', 'Host *\n  User me\nHost host1 host2\n  Port 22\n')
    local current_server = clear({ env = { XDG_RUNTIME_DIR = run_dir, HOME = home } })
    local own_name = vim.fs.basename(fn.serverlist()[1])
    local peer_name = vim.fs.basename(n.new_pipename())
    local client = n.new_session(true, {
      args = { '--clean', '--listen', ('%s/%s'):format(peer_dir, peer_name), '--embed' },
      env = { XDG_RUNTIME_DIR = peer_dir },
      merge = false,
    })
    client:request('nvim_get_vvar', 'servername') -- Waits until it listens.
    Screen.new() -- `:connect` needs a UI.
    n.exec_lua(function()
      vim.ui.select = function(addrs, opts)
        _G.menu = vim.tbl_map(opts.format_item, addrs)
      end
    end)
    local function menu()
      n.command('connect')
      return table.concat(n.exec_lua('return _G.menu'), '\n')
    end

    -- Peer with unknown user activity ("?").
    matches(('%s +%%?\n'):format(vim.pesc(peer_name)), menu())

    n.set_session(client)
    n.feed('<Esc>') -- Sets v:useractive.
    n.set_session(current_server)
    local items = menu()
    matches(('%s +just now\n'):format(vim.pesc(peer_name)), items)
    matches('ssh://host1\nssh://host2$', items)
    t.not_matches(vim.pesc(own_name), items)

    eq('Vim(connect):E477: No ! allowed', pcall_err(n.command, 'connect!'))

    client:close()
  end)

  it(':connect triggers ConnectPre, ConnectPost', function()
    clear()
    Screen.new() -- Keeps the server running after the other UI connects.
    n.exec_lua(function()
      _G.events = {}
      vim.api.nvim_create_autocmd({ 'ConnectPre', 'ConnectPost' }, {
        callback = function(ev)
          table.insert(_G.events, { ev.event, ev.match })
        end,
      })
    end)
    local addr = eval('v:servername')
    local ui = n.connect(addr)
    finally(function()
      ui:close()
    end)
    local screen = Screen.new(40, 4, nil, ui)
    screen._handle_connect = function() end
    screen._handle_error_exit = function() end

    -- Not triggered if the server is unreachable.
    ui:request('nvim_command', 'connect ' .. n.new_pipename())
    eq({}, n.exec_lua('return _G.events'))

    ui:request('nvim_command', 'connect ' .. addr)
    eq(
      { { 'ConnectPre', t.fix_slashes(addr) }, { 'ConnectPost', t.fix_slashes(addr) } },
      n.exec_lua('return _G.events')
    )
  end)

  it('v:useractive advances on UI input', function()
    clear()
    local before = eval('v:useractive')
    eq('number', type(before))
    n.feed('ix<Esc>')
    local after = eval('v:useractive')
    eq(true, after > before)
  end)

  it('v:useractive is read-only', function()
    clear()
    matches('E46:', pcall_err(n.command, 'let v:useractive = 0'))
  end)

  it('removes stale socket files automatically #36581', function()
    -- Windows named pipes are ephemeral kernel objects that are automatically
    -- cleaned up when the process terminates. Unix domain sockets persist as
    -- files on the filesystem and can become stale after crashes.
    t.skip(is_os('win'), 'N/A on Windows')

    clear()
    clear_serverlist()
    local socket_path = './Xtest-stale-socket'

    -- Create stale socket file (simulate crash)
    vim.uv.fs_close(vim.uv.fs_open(socket_path, 'w', 438))

    -- serverstart() should detect and remove stale socket
    eq(socket_path, fn.serverstart(socket_path))
    fn.serverstop(socket_path)

    -- Same test with --listen flag
    vim.uv.fs_close(vim.uv.fs_open(socket_path, 'w', 438))
    clear({ args = { '--listen', socket_path } })
    eq(socket_path, api.nvim_get_vvar('servername'))
    fn.serverstop(socket_path)
  end)

  it('does not remove live sockets #36581', function()
    t.skip(is_os('win'), 'N/A on Windows')

    clear()
    local socket_path = './Xtest-live-socket'
    eq(socket_path, fn.serverstart(socket_path))

    -- Second instance should fail without removing live socket
    local result = n.exec_lua(function(sock)
      return vim
        .system(
          { vim.v.progpath, '--headless', '--listen', sock },
          { text = true, env = { NVIM_LOG_FILE = testlog } }
        )
        :wait()
    end, socket_path)
    t.assert_log('Socket already in use by another Nvim instance: ', testlog, 100)
    t.assert_log('Failed to start server: address already in use: ', testlog, 100)

    neq(0, result.code)
    matches('Failed.*listen', result.stderr)
    fn.serverstop(socket_path)
  end)

  it('normalizes sep in named pipe paths #39382', function()
    t.skip(not is_os('win'), 'N/A: Named pipe is Windows feature')

    local name, named_pipe = 'Xtest-server', [[\\.\pipe\Xtest-server]]
    -- default address
    clear { args_rm = { '--listen' } }
    matches('//./pipe/', fn.eval('v:servername'), true)

    clear({ args_rm = { '--listen' }, env = { NVIM_LISTEN_ADDRESS = named_pipe } })
    eq(vim.fs.normalize(named_pipe), fn.eval('v:servername'))

    clear({ args_rm = { '--listen' }, args = { '--listen', name } })
    matches(vim.fs.normalize(named_pipe), fn.eval('v:servername'), true)

    clear({ args_rm = { '--listen' }, args = { '--listen', named_pipe } })
    eq(vim.fs.normalize(named_pipe), fn.eval('v:servername'))

    local server = n.get_session()
    local client = n.new_session(true)
    n.set_session(client)
    local res = fn.system({
      n.nvim_prog,
      '--clean',
      '-es',
      '--server',
      named_pipe,
      '--remote-expr',
      'v:servername',
    })
    eq(vim.fs.normalize(named_pipe), res)
    client:close()
    n.set_session(server)
  end)
end)

describe('startup --listen', function()
  -- Tests Nvim output when failing to start, with and without "--headless".
  local function _test(args, env, expected)
    local function run(cmd)
      return n.spawn_wait {
        merge = false,
        args = cmd,
        env = vim.tbl_extend(
          'force',
          -- Avoid noise in the logs; we expect failures for these tests.
          { NVIM_LOG_FILE = testlog },
          env or {}
        ),
      }
    end

    local cmd = vim.list_extend({ '--clean', '+qall!', '--headless' }, args)
    local r = run(cmd)
    eq(1, r.status)
    matches(expected, (r:output():gsub('\\n', ' ')))

    if is_os('win') then
      return -- On Windows, output without --headless is garbage.
    end
    table.remove(cmd, 3) -- Remove '--headless'.
    assert(not vim.tbl_contains(cmd, '--headless'))
    r = run(cmd)
    eq(1, r.status)
    matches(expected, (r:output():gsub('\\n', ' ')))
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
    if not is_os('win') then
      -- Too-long path is rejected, not silently truncated. #38623
      local too_long = './Xtest-listen-' .. ('x'):rep(256)
      _test(
        { '--listen', too_long },
        nil,
        ('nvim.*: Failed to %%-%%-listen: invalid argument: "%s"'):format(vim.pesc(too_long))
      )
    end
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
    local addr = (is_os('win') and [[//./pipe/Xtest-listen-pipe]] or './Xtest-listen-pipe')
    clear({ env = { NVIM_LISTEN_ADDRESS = './Xtest-env-pipe' }, args = { '--listen', addr } })
    eq('', eval('$NVIM_LISTEN_ADDRESS')) -- Cleared on startup.
    eq(addr, api.nvim_get_vvar('servername'))

    -- Address without slashes is a "name" which is appended to a generated path. #8519
    clear({ args = { '--listen', 'test-name' } })
    matches([[[/\\]test%-name[^/\\]*]], api.nvim_get_vvar('servername'))
  end)
end)

it(':restart! works in headless server (no UI)', function()
  t.skip(is_os('win'), 'FIXME: --listen not preserved by :restart! on Windows')

  local nvim0 = clear()
  local server_pipe = n.new_pipename()
  local dir = vim.fs.normalize(t.tmpname(false))
  local subdir = dir .. '/subdir'
  mkdir(dir)
  mkdir(subdir)

  finally(function()
    n.expect_exit(n.command, 'qall!')
    nvim0:close()
    n.set_session(nil)
    rmdir(dir)
  end)

  fn.jobstart({
    n.nvim_prog,
    '--clean',
    '--headless',
    '--listen',
    server_pipe,
    '--cmd',
    'let g:early_startreason = v:startreason',
  })
  t.retry(nil, nil, function()
    neq(nil, vim.uv.fs_stat(server_pipe))
  end)
  n.set_session(n.connect(server_pipe))

  api.nvim_set_current_dir(dir)
  n.command('bcd ' .. fn.fnameescape(subdir))
  eq(subdir, fn.getcwd())
  eq(dir, fn.getcwd(-1, -1, -1))

  n.expect_exit(n.command, 'restart!')
  n.set_session(n.connect(server_pipe))
  eq(1, api.nvim_get_vvar('vim_did_enter'))
  eq('restart!', api.nvim_get_vvar('startreason'))
  eq('restart!', n.eval('g:early_startreason'))
  eq(dir, fn.getcwd())

  -- TODO: [command] is currently not executed without UI
  -- n.expect_exit(n.command, 'restart! lua _G.new_server = 1')
  -- n.set_session(n.connect(server_pipe))
  -- eq(1, n.exec_lua('return _G.new_server'))
end)
