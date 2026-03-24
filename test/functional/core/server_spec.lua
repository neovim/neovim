local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq, neq, eval = t.eq, t.neq, n.eval
local clear, command, fn, api, exec_lua = n.clear, n.command, n.fn, n.api, n.exec_lua
local matches = t.matches
local pcall_err = t.pcall_err
local retry = t.retry
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

local function make_tmpdir()
  local tmp_dir = assert(vim.uv.fs_mkdtemp(vim.fs.dirname(t.tmpname(false)) .. '/XXXXXX'))
  finally(function()
    fn.delete(tmp_dir, 'rf')
  end)
  return tmp_dir
end

local function clear_with_runtime_dir(tmp_dir)
  local run_dir = tmp_dir .. '/run'
  assert(vim.uv.fs_mkdir(run_dir, 448))
  clear({ env = { XDG_RUNTIME_DIR = run_dir } })
end

local function start_peer(tmp_dir)
  local peer_run_dir = tmp_dir .. '/peer_run'
  assert(vim.uv.fs_mkdir(peer_run_dir, 448))
  local peer_addr = ('%s/%s'):format(tmp_dir, n.new_pipename():match('[^/]*$'))
  local peer = n.new_session(true, {
    args = { '--clean', '--listen', peer_addr, '--embed' },
    env = { XDG_RUNTIME_DIR = peer_run_dir },
    merge = false,
  })
  retry(nil, nil, function()
    eq(true, vim.list_contains(fn.serverlist({ peer = true }), peer_addr))
  end)
  return peer_addr, peer
end

local function connect_with_async_error(mods)
  return exec_lua(
    [[
      local mods = ...
      local written
      local schedule, select, nvim_cmd, nvim_echo, serverlist =
        vim.schedule, vim.ui.select, vim.api.nvim_cmd, vim.api.nvim_echo, vim.fn.serverlist

      vim.fn.serverlist = function(opts)
        if opts and opts.peer then
          return { '/tmp/nvim.peer' }
        end
        return {}
      end
      vim.schedule = function(cb) cb() end
      vim.ui.select = function(_, _, on_choice) on_choice('/tmp/nvim.peer', 1) end
      vim.api.nvim_cmd = function() error('boom\n') end
      vim.api.nvim_echo = function(chunks) written = chunks[1][1] end

      local ok = require('vim._core.server').connect(false, mods)

      vim.fn.serverlist, vim.schedule, vim.ui.select, vim.api.nvim_cmd, vim.api.nvim_echo =
        serverlist, schedule, select, nvim_cmd, nvim_echo

      return { ok, written }
    ]],
    mods
  )
end

local function exec_connect(bang, choice, mods)
  local choice_expr = choice and ('%q'):format(choice) or 'nil'
  local mods_expr = mods and vim.inspect(mods) or 'nil'
  return exec_lua(([[
    local selected, invoked
    local schedule, select, nvim_cmd = vim.schedule, vim.ui.select, vim.api.nvim_cmd
    vim.schedule = function(cb) cb() end
    vim.ui.select = function(items, _, on_choice)
      selected = items
      on_choice(%s, 1)
    end
    vim.api.nvim_cmd = function(cmd, _) invoked = cmd end
    local ok = require('vim._core.server').connect(%s, %s)
    vim.schedule, vim.ui.select, vim.api.nvim_cmd = schedule, select, nvim_cmd
    return { ok, selected, invoked }
  ]]):format(choice_expr, tostring(bang), mods_expr))
end

local function with_peer(cb)
  t.skip(is_os('win'), 'N/A on Windows')
  local tmp_dir = make_tmpdir()
  clear_with_runtime_dir(tmp_dir)
  local peer_addr, peer = start_peer(tmp_dir)
  finally(function()
    peer:close()
  end)
  return cb(peer_addr)
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
    matches([[[/\\]xtest1%.2%.3%.4[^/\\]*]], fn.serverstart('xtest1.2.3.4'))
    clear_serverlist()

    eq('Vim:Failed to start server: invalid argument', pcall_err(fn.serverstart, '127.0.0.1:65536')) -- invalid port
    eq({}, fn.serverlist())
  end)

  it('serverlist() returns the list of servers', function()
    -- Set XDG_RUNTIME_DIR to a temp dir in this session to properly test serverlist({peer = true}). See #35492
    local tmp_dir = assert(vim.uv.fs_mkdtemp(vim.fs.dirname(t.tmpname(false)) .. '/XXXXXX'))
    local current_server = clear({ env = { XDG_RUNTIME_DIR = tmp_dir } })
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

    -- serverlist({peer=true}) returns servers from other Nvim sessions.
    if t.is_os('win') then
      return
    end

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

    new_servs = fn.serverlist({ peer = true })
    local servers_without_peer = fn.serverlist()
    eq(true, vim.list_contains(new_servs, peer_addr))
    eq(true, #servers_without_peer < #new_servs)
    eq(true, old_servs_num < #new_servs)
    client:close()
  end)

  it('connect() ignores local aliases', function()
    t.skip(is_os('win'), 'N/A on Windows')

    local tmp_dir = make_tmpdir()
    clear_with_runtime_dir(tmp_dir)

    local alias = tmp_dir .. '/nvim.alias'
    eq(alias, fn.serverstart(alias))

    local peer_addr, peer = start_peer(tmp_dir)
    retry(nil, nil, function()
      local peers = fn.serverlist({ peer = true })
      eq(true, vim.list_contains(peers, alias))
      eq(true, vim.list_contains(peers, peer_addr))
    end)

    local rv = exec_connect(false, nil)
    eq({ 0, { peer_addr } }, rv)

    eq(1, fn.serverstop(alias))
    peer:close()
  end)

  it('connect() returns 1 when no peer servers are found', function()
    clear_with_runtime_dir(make_tmpdir())

    local rv = exec_lua([[return require('vim._core.server').connect(false)]])
    eq(1, rv)
  end)

  it('connect() fails fast without a UI', function()
    clear()
    matches(
      'Vim%(connect%):E5769: :connect without an address requires a UI',
      pcall_err(command, 'connect')
    )
  end)

  it('connect() suppresses async follow-up errors when emsg_silent is set', function()
    clear()
    eq({ 0, nil }, connect_with_async_error({ emsg_silent = true }))
  end)

  it('connect() reports async follow-up errors when only silent is set', function()
    clear()
    local rv = connect_with_async_error({ silent = true })
    eq(0, rv[1])
    matches('boom$', rv[2])
  end)

  it('connect() can be cancelled', function()
    with_peer(function(peer_addr)
      local rv = exec_connect(true, nil)
      eq({ 0, { peer_addr } }, rv)
    end)
  end)

  it('connect() forwards bang and mods', function()
    with_peer(function(peer_addr)
      local mods = {
        confirm = true,
        keepalt = true,
        silent = true,
        split = 'botright',
        tab = 2,
        vertical = true,
      }
      eq(
        { 0, { peer_addr }, { cmd = 'connect', bang = false, args = { peer_addr }, mods = mods } },
        exec_connect(false, peer_addr, mods)
      )
      eq(
        { 0, { peer_addr }, { cmd = 'connect', bang = true, args = { peer_addr }, mods = {} } },
        exec_connect(true, peer_addr)
      )
    end)
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
    matches(expected, r:output():gsub('\\n', ' '))

    if is_os('win') then
      return -- On Windows, output without --headless is garbage.
    end
    table.remove(cmd, 3) -- Remove '--headless'.
    assert(not vim.tbl_contains(cmd, '--headless'))
    r = run(cmd)
    eq(1, r.status)
    matches(expected, r:output():gsub('\\n', ' '))
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
    matches([[[/\\]test%-name[^/\\]*]], api.nvim_get_vvar('servername'))
  end)
end)
