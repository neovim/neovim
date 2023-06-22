local luv = require('luv')
local global_helpers = require('test.helpers')

local Session = require('test.client.session')
local uv_stream = require('test.client.uv_stream')
local SocketStream = uv_stream.SocketStream
local ChildProcessStream = uv_stream.ChildProcessStream

local check_cores = global_helpers.check_cores
local check_logs = global_helpers.check_logs
local dedent = global_helpers.dedent
local eq = global_helpers.eq
local filter = global_helpers.tbl_filter
local is_os = global_helpers.is_os
local map = global_helpers.tbl_map
local ok = global_helpers.ok
local sleep = global_helpers.sleep
local tbl_contains = global_helpers.tbl_contains
local fail = global_helpers.fail

local module = {
}

local start_dir = luv.cwd()
local runtime_set = 'set runtimepath^=./build/lib/nvim/'
module.nvim_prog = (
  os.getenv('NVIM_PRG')
  or global_helpers.test_build_dir .. '/bin/nvim'
)
-- Default settings for the test session.
module.nvim_set = (
  'set shortmess+=IS background=light noswapfile noautoindent startofline'
  ..' laststatus=1 undodir=. directory=. viewdir=. backupdir=.'
  ..' belloff= wildoptions-=pum joinspaces noshowcmd noruler nomore redrawdebug=invalid')
module.nvim_argv = {
  module.nvim_prog, '-u', 'NONE', '-i', 'NONE',
  -- XXX: find treesitter parsers.
  '--cmd', runtime_set,
  '--cmd', module.nvim_set,
  '--cmd', 'mapclear',
  '--cmd', 'mapclear!',
  '--embed'}

-- Directory containing nvim.
module.nvim_dir = module.nvim_prog:gsub("[/\\][^/\\]+$", "")
if module.nvim_dir == module.nvim_prog then
  module.nvim_dir = "."
end

local prepend_argv

if os.getenv('VALGRIND') then
  local log_file = os.getenv('VALGRIND_LOG') or 'valgrind-%p.log'
  prepend_argv = {'valgrind', '-q', '--tool=memcheck',
                  '--leak-check=yes', '--track-origins=yes',
                  '--show-possibly-lost=no',
                  '--suppressions=src/.valgrind.supp',
                  '--log-file='..log_file}
  if os.getenv('GDB') then
    table.insert(prepend_argv, '--vgdb=yes')
    table.insert(prepend_argv, '--vgdb-error=0')
  end
elseif os.getenv('GDB') then
  local gdbserver_port = '7777'
  if os.getenv('GDBSERVER_PORT') then
    gdbserver_port = os.getenv('GDBSERVER_PORT')
  end
  prepend_argv = {'gdbserver', 'localhost:'..gdbserver_port}
end

if prepend_argv then
  local new_nvim_argv = {}
  local len = #prepend_argv
  for i = 1, len do
    new_nvim_argv[i] = prepend_argv[i]
  end
  for i = 1, #module.nvim_argv do
    new_nvim_argv[i + len] = module.nvim_argv[i]
  end
  module.nvim_argv = new_nvim_argv
  module.prepend_argv = prepend_argv
end

local session, loop_running, last_error, method_error

function module.get_session()
  return session
end

function module.set_session(s)
  session = s
end

function module.request(method, ...)
  local status, rv = session:request(method, ...)
  if not status then
    if loop_running then
      last_error = rv[2]
      session:stop()
    else
      error(rv[2])
    end
  end
  return rv
end

function module.request_lua(method, ...)
  return module.exec_lua([[return vim.api[...](select(2, ...))]], method, ...)
end

function module.next_msg(timeout)
  return session:next_message(timeout and timeout or 10000)
end

function module.expect_twostreams(msgs1, msgs2)
  local pos1, pos2 = 1, 1
  while pos1 <= #msgs1 or pos2 <= #msgs2 do
    local msg = module.next_msg()
    if pos1 <= #msgs1 and pcall(eq, msgs1[pos1], msg) then
      pos1 = pos1 + 1
    elseif pos2 <= #msgs2 then
      eq(msgs2[pos2], msg)
      pos2 = pos2 + 1
    else
      -- already failed, but show the right error message
      eq(msgs1[pos1], msg)
    end
  end
end

-- Expects a sequence of next_msg() results. If multiple sequences are
-- passed they are tried until one succeeds, in order of shortest to longest.
--
-- Can be called with positional args (list of sequences only):
--    expect_msg_seq(seq1, seq2, ...)
-- or keyword args:
--    expect_msg_seq{ignore={...}, seqs={seq1, seq2, ...}}
--
-- ignore:      List of ignored event names.
-- seqs:        List of one or more potential event sequences.
function module.expect_msg_seq(...)
  if select('#', ...) < 1 then
    error('need at least 1 argument')
  end
  local arg1 = select(1, ...)
  if (arg1['seqs'] and select('#', ...) > 1) or type(arg1) ~= 'table'  then
    error('invalid args')
  end
  local ignore = arg1['ignore'] and arg1['ignore'] or {}
  local seqs = arg1['seqs'] and arg1['seqs'] or {...}
  if type(ignore) ~= 'table' then
    error("'ignore' arg must be a list of strings")
  end
  table.sort(seqs, function(a, b)  -- Sort ascending, by (shallow) length.
    return #a < #b
  end)

  local actual_seq = {}
  local nr_ignored = 0
  local final_error = ''
  local function cat_err(err1, err2)
    if err1 == nil then
      return err2
    end
    return string.format('%s\n%s\n%s', err1, string.rep('=', 78), err2)
  end
  local msg_timeout = module.load_adjust(10000)  -- Big timeout for ASAN/valgrind.
  for anum = 1, #seqs do
    local expected_seq = seqs[anum]
    -- Collect enough messages to compare the next expected sequence.
    while #actual_seq < #expected_seq do
      local msg = module.next_msg(msg_timeout)
      local msg_type = msg and msg[2] or nil
      if msg == nil then
        error(cat_err(final_error,
                      string.format('got %d messages (ignored %d), expected %d',
                                    #actual_seq, nr_ignored, #expected_seq)))
      elseif tbl_contains(ignore, msg_type) then
        nr_ignored = nr_ignored + 1
      else
        table.insert(actual_seq, msg)
      end
    end
    local status, result = pcall(eq, expected_seq, actual_seq)
    if status then
      return result
    end
    local message = result
    if type(result) == "table" then
      -- 'eq' returns several things
      message = result.message
    end
    final_error = cat_err(final_error, message)
  end
  error(final_error)
end

local function call_and_stop_on_error(lsession, ...)
  local status, result = Session.safe_pcall(...)  -- luacheck: ignore
  if not status then
    lsession:stop()
    last_error = result
    return ''
  end
  return result
end

function module.set_method_error(err)
  method_error = err
end

function module.run_session(lsession, request_cb, notification_cb, setup_cb, timeout)
  local on_request, on_notification, on_setup

  if request_cb then
    function on_request(method, args)
      method_error = nil
      local result = call_and_stop_on_error(lsession, request_cb, method, args)
      if method_error ~= nil then
        return method_error, true
      end
      return result
    end
  end

  if notification_cb then
    function on_notification(method, args)
      call_and_stop_on_error(lsession, notification_cb, method, args)
    end
  end

  if setup_cb then
    function on_setup()
      call_and_stop_on_error(lsession, setup_cb)
    end
  end

  loop_running = true
  lsession:run(on_request, on_notification, on_setup, timeout)
  loop_running = false
  if last_error then
    local err = last_error
    last_error = nil
    error(err)
  end

  return lsession.eof_err
end

function module.run(request_cb, notification_cb, setup_cb, timeout)
  return module.run_session(session, request_cb, notification_cb, setup_cb, timeout)
end

function module.stop()
  session:stop()
end

function module.nvim_prog_abs()
  -- system(['build/bin/nvim']) does not work for whatever reason. It must
  -- be executable searched in $PATH or something starting with / or ./.
  if module.nvim_prog:match('[/\\]') then
    return module.request('nvim_call_function', 'fnamemodify', {module.nvim_prog, ':p'})
  else
    return module.nvim_prog
  end
end

-- Executes an ex-command. Vimscript errors manifest as client (lua) errors, but
-- v:errmsg will not be updated.
function module.command(cmd)
  module.request('nvim_command', cmd)
end

-- Use for commands which expect nvim to quit.
-- The first argument can also be a timeout.
function module.expect_exit(fn_or_timeout, ...)
  local eof_err_msg = 'EOF was received from Nvim. Likely the Nvim process crashed.'
  if type(fn_or_timeout) == 'function' then
    eq(eof_err_msg, module.pcall_err(fn_or_timeout, ...))
  else
    eq(eof_err_msg, module.pcall_err(function(timeout, fn, ...)
      fn(...)
      while session:next_message(timeout) do
      end
      if session.eof_err then
        error(session.eof_err[2])
      end
    end, fn_or_timeout, ...))
  end
end

-- Evaluates a Vimscript expression.
-- Fails on Vimscript error, but does not update v:errmsg.
function module.eval(expr)
  return module.request('nvim_eval', expr)
end

-- Executes a Vimscript function via RPC.
-- Fails on Vimscript error, but does not update v:errmsg.
function module.call(name, ...)
  return module.request('nvim_call_function', name, {...})
end

-- Executes a Vimscript function via Lua.
-- Fails on Vimscript error, but does not update v:errmsg.
function module.call_lua(name, ...)
  return module.exec_lua([[return vim.call(...)]], name, ...)
end

-- Sends user input to Nvim.
-- Does not fail on Vimscript error, but v:errmsg will be updated.
local function nvim_feed(input)
  while #input > 0 do
    local written = module.request('nvim_input', input)
    if written == nil then
      module.assert_alive()
      error('crash? (nvim_input returned nil)')
    end
    input = input:sub(written + 1)
  end
end

function module.feed(...)
  for _, v in ipairs({...}) do
    nvim_feed(dedent(v))
  end
end

function module.rawfeed(...)
  for _, v in ipairs({...}) do
    nvim_feed(dedent(v))
  end
end

function module.merge_args(...)
  local i = 1
  local argv = {}
  for anum = 1,select('#', ...) do
    local args = select(anum, ...)
    if args then
      for _, arg in ipairs(args) do
        argv[i] = arg
        i = i + 1
      end
    end
  end
  return argv
end

--  Removes Nvim startup args from `args` matching items in `args_rm`.
--
--  - Special case: "-u", "-i", "--cmd" are treated specially: their "values" are also removed.
--  - Special case: "runtimepath" will remove only { '--cmd', 'set runtimepath^=…', }
--
--  Example:
--      args={'--headless', '-u', 'NONE'}
--      args_rm={'--cmd', '-u'}
--  Result:
--      {'--headless'}
--
--  All matching cases are removed.
--
--  Example:
--      args={'--cmd', 'foo', '-N', '--cmd', 'bar'}
--      args_rm={'--cmd', '-u'}
--  Result:
--      {'-N'}
local function remove_args(args, args_rm)
  local new_args = {}
  local skip_following = {'-u', '-i', '-c', '--cmd', '-s', '--listen'}
  if not args_rm or #args_rm == 0 then
    return {unpack(args)}
  end
  for _, v in ipairs(args_rm) do
    assert(type(v) == 'string')
  end
  local last = ''
  for _, arg in ipairs(args) do
    if tbl_contains(skip_following, last) then
      last = ''
    elseif tbl_contains(args_rm, arg) then
      last = arg
    elseif arg == runtime_set and tbl_contains(args_rm, 'runtimepath') then
      table.remove(new_args)  -- Remove the preceding "--cmd".
      last = ''
    else
      table.insert(new_args, arg)
    end
  end
  return new_args
end

function module.check_close()
  if not session then
    return
  end
  local start_time = luv.now()
  session:close()
  luv.update_time()  -- Update cached value of luv.now() (libuv: uv_now()).
  local end_time = luv.now()
  local delta = end_time - start_time
  if delta > 500 then
    print("nvim took " .. delta .. " milliseconds to exit after last test\n"..
          "This indicates a likely problem with the test even if it passed!\n")
    io.stdout:flush()
  end
  session = nil
end

--- @param io_extra used for stdin_fd, see :help ui-option
function module.spawn(argv, merge, env, keep, io_extra)
  if not keep then
    module.check_close()
  end

  local child_stream = ChildProcessStream.spawn(
      merge and module.merge_args(prepend_argv, argv) or argv,
      env, io_extra)
  return Session.new(child_stream)
end

-- Creates a new Session connected by domain socket (named pipe) or TCP.
function module.connect(file_or_address)
  local addr, port = string.match(file_or_address, "(.*):(%d+)")
  local stream = (addr and port) and SocketStream.connect(addr, port) or
    SocketStream.open(file_or_address)
  return Session.new(stream)
end

-- Starts a new global Nvim session.
--
-- Parameters are interpreted as startup args, OR a map with these keys:
--    args:       List: Args appended to the default `nvim_argv` set.
--    args_rm:    List: Args removed from the default set. All cases are
--                removed, e.g. args_rm={'--cmd'} removes all cases of "--cmd"
--                (and its value) from the default set.
--    env:        Map: Defines the environment of the new session.
--
-- Example:
--    clear('-e')
--    clear{args={'-e'}, args_rm={'-i'}, env={TERM=term}}
function module.clear(...)
  module.set_session(module.spawn_argv(false, ...))
end

-- same params as clear, but does returns the session instead
-- of replacing the default session
function module.spawn_argv(keep, ...)
  local argv, env, io_extra = module.new_argv(...)
  return module.spawn(argv, nil, env, keep, io_extra)
end

-- Builds an argument list for use in clear().
--
---@see clear() for parameters.
function module.new_argv(...)
  local args = {unpack(module.nvim_argv)}
  table.insert(args, '--headless')
  if _G._nvim_test_id then
    -- Set the server name to the test-id for logging. #8519
    table.insert(args, '--listen')
    table.insert(args, _G._nvim_test_id)
  end
  local new_args
  local io_extra
  local env = nil
  local opts = select(1, ...)
  if type(opts) ~= 'table' then
    new_args = {...}
  else
    args = remove_args(args, opts.args_rm)
    if opts.env then
      local env_opt = {}
      for k, v in pairs(opts.env) do
        assert(type(k) == 'string')
        assert(type(v) == 'string')
        env_opt[k] = v
      end
      for _, k in ipairs({
        'HOME',
        'ASAN_OPTIONS',
        'TSAN_OPTIONS',
        'MSAN_OPTIONS',
        'LD_LIBRARY_PATH',
        'PATH',
        'NVIM_LOG_FILE',
        'NVIM_RPLUGIN_MANIFEST',
        'GCOV_ERROR_FILE',
        'XDG_DATA_DIRS',
        'TMPDIR',
        'VIMRUNTIME',
      }) do
        -- Set these from the environment unless the caller defined them.
        if not env_opt[k] then
          env_opt[k] = os.getenv(k)
        end
      end
      env = {}
      for k, v in pairs(env_opt) do
        env[#env + 1] = k .. '=' .. v
      end
    end
    new_args = opts.args or {}
    io_extra = opts.io_extra
  end
  for _, arg in ipairs(new_args) do
    table.insert(args, arg)
  end
  return args, env, io_extra
end

function module.insert(...)
  nvim_feed('i')
  for _, v in ipairs({...}) do
    local escaped = v:gsub('<', '<lt>')
    module.rawfeed(escaped)
  end
  nvim_feed('<ESC>')
end

-- Executes an ex-command by user input. Because nvim_input() is used, Vimscript
-- errors will not manifest as client (lua) errors. Use command() for that.
function module.feed_command(...)
  for _, v in ipairs({...}) do
    if v:sub(1, 1) ~= '/' then
      -- not a search command, prefix with colon
      nvim_feed(':')
    end
    nvim_feed(v:gsub('<', '<lt>'))
    nvim_feed('<CR>')
  end
end

-- @deprecated use nvim_exec2()
function module.source(code)
  module.exec(dedent(code))
end

function module.has_powershell()
  return module.eval('executable("'..(is_os('win') and 'powershell' or 'pwsh')..'")') == 1
end

--- Sets Nvim shell to powershell.
---
--- @param fake (boolean) If true, a fake will be used if powershell is not
---             found on the system.
--- @returns true if powershell was found on the system, else false.
function module.set_shell_powershell(fake)
  local found = module.has_powershell()
  if not fake then
    assert(found)
  end
  local shell = found and (is_os('win') and 'powershell' or 'pwsh') or module.testprg('pwsh-test')
  local cmd = 'Remove-Item -Force '..table.concat(is_os('win')
    and {'alias:cat', 'alias:echo', 'alias:sleep', 'alias:sort', 'alias:tee'}
    or  {'alias:echo'}, ',')..';'
  module.exec([[
    let &shell = ']]..shell..[['
    set shellquote= shellxquote=
    let &shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command '
    let &shellcmdflag .= '[Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();'
    let &shellcmdflag .= '$PSDefaultParameterValues[''Out-File:Encoding'']=''utf8'';'
    let &shellcmdflag .= ']]..cmd..[['
    let &shellredir = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'
    let &shellpipe  = '2>&1 | %%{ "$_" } | tee %s; exit $LastExitCode'
  ]])
  return found
end

function module.create_callindex(func)
  local table = {}
  setmetatable(table, {
    __index = function(tbl, arg1)
      local ret = function(...) return func(arg1, ...) end
      tbl[arg1] = ret
      return ret
    end,
  })
  return table
end

local function ui(method, ...)
  return module.request('nvim_ui_'..method, ...)
end

function module.nvim_async(method, ...)
  session:notify('nvim_'..method, ...)
end

module.async_meths = module.create_callindex(module.nvim_async)
module.uimeths = module.create_callindex(ui)

local function create_api(request, call)
  local m = {}
  function m.nvim(method, ...)
    return request('nvim_'..method, ...)
  end

  function m.buffer(method, ...)
    return request('nvim_buf_'..method, ...)
  end

  function m.window(method, ...)
    return request('nvim_win_'..method, ...)
  end

  function m.tabpage(method, ...)
    return request('nvim_tabpage_'..method, ...)
  end

  function m.curbuf(method, ...)
    if not method then
      return m.nvim('get_current_buf')
    end
    return m.buffer(method, 0, ...)
  end

  function m.curwin(method, ...)
    if not method then
      return m.nvim('get_current_win')
    end
    return m.window(method, 0, ...)
  end

  function m.curtab(method, ...)
    if not method then
      return m.nvim('get_current_tabpage')
    end
    return m.tabpage(method, 0, ...)
  end

  m.funcs = module.create_callindex(call)
  m.meths = module.create_callindex(m.nvim)
  m.bufmeths = module.create_callindex(m.buffer)
  m.winmeths = module.create_callindex(m.window)
  m.tabmeths = module.create_callindex(m.tabpage)
  m.curbufmeths = module.create_callindex(m.curbuf)
  m.curwinmeths = module.create_callindex(m.curwin)
  m.curtabmeths = module.create_callindex(m.curtab)

  return m
end

module.rpc = {
  api = create_api(module.request, module.call),
}

module.lua = {
  api = create_api(module.request_lua, module.call_lua),
}

module.describe_lua_and_rpc = function(describe)
  return function(what, tests)
    local function d(flavour)
      describe(string.format('%s (%s)', what, flavour), function(...)
        return tests(module[flavour].api, ...)
      end)
    end

    d('rpc')
    d('lua')
  end
end

for name, fn in pairs(module.rpc.api) do
  module[name] = fn
end

function module.poke_eventloop()
  -- Execute 'nvim_eval' (a deferred function) to
  -- force at least one main_loop iteration
  session:request('nvim_eval', '1')
end

function module.buf_lines(bufnr)
  return module.exec_lua("return vim.api.nvim_buf_get_lines((...), 0, -1, false)", bufnr)
end

---@see buf_lines()
function module.curbuf_contents()
  module.poke_eventloop()  -- Before inspecting the buffer, do whatever.
  return table.concat(module.curbuf('get_lines', 0, -1, true), '\n')
end

function module.expect(contents)
  return eq(dedent(contents), module.curbuf_contents())
end

function module.expect_any(contents)
  contents = dedent(contents)
  return ok(nil ~= string.find(module.curbuf_contents(), contents, 1, true))
end

function module.expect_events(expected, received, kind)
  local inspect = require'vim.inspect'
  if not pcall(eq, expected, received) then
    local msg = 'unexpected '..kind..' received.\n\n'

    msg = msg .. 'received events:\n'
    for _, e in ipairs(received) do
      msg = msg .. '  ' .. inspect(e) .. ';\n'
    end
    msg = msg .. '\nexpected events:\n'
    for _, e in ipairs(expected) do
      msg = msg .. '  ' .. inspect(e) .. ';\n'
    end
    fail(msg)
  end
  return received
end

-- Checks that the Nvim session did not terminate.
function module.assert_alive()
  assert(2 == module.eval('1+1'), 'crash? request failed')
end

-- Asserts that buffer is loaded and visible in the current tabpage.
function module.assert_visible(bufnr, visible)
  assert(type(visible) == 'boolean')
  eq(visible, module.bufmeths.is_loaded(bufnr))
  if visible then
    assert(-1 ~= module.funcs.bufwinnr(bufnr),
      'expected buffer to be visible in current tabpage: '..tostring(bufnr))
  else
    assert(-1 == module.funcs.bufwinnr(bufnr),
      'expected buffer NOT visible in current tabpage: '..tostring(bufnr))
  end
end

local function do_rmdir(path)
  local stat = luv.fs_stat(path)
  if stat == nil then
    return
  end
  if stat.type ~= 'directory' then
    error(string.format('rmdir: not a directory: %s', path))
  end
  for file in vim.fs.dir(path) do
    if file ~= '.' and file ~= '..' then
      local abspath = path..'/'..file
      if global_helpers.isdir(abspath) then
        do_rmdir(abspath)  -- recurse
      else
        local ret, err = os.remove(abspath)
        if not ret then
          if not session then
            error('os.remove: '..err)
          else
            -- Try Nvim delete(): it handles `readonly` attribute on Windows,
            -- and avoids Lua cross-version/platform incompatibilities.
            if -1 == module.call('delete', abspath) then
              local hint = (is_os('win')
                and ' (hint: try :%bwipeout! before rmdir())' or '')
              error('delete() failed'..hint..': '..abspath)
            end
          end
        end
      end
    end
  end
  local ret, err = luv.fs_rmdir(path)
  if not ret then
    error('luv.fs_rmdir('..path..'): '..err)
  end
end

function module.rmdir(path)
  local ret, _ = pcall(do_rmdir, path)
  if not ret and is_os('win') then
    -- Maybe "Permission denied"; try again after changing the nvim
    -- process to the top-level directory.
    module.command([[exe 'cd '.fnameescape(']]..start_dir.."')")
    ret, _ = pcall(do_rmdir, path)
  end
  -- During teardown, the nvim process may not exit quickly enough, then rmdir()
  -- will fail (on Windows).
  if not ret then  -- Try again.
    sleep(1000)
    do_rmdir(path)
  end
end

function module.exc_exec(cmd)
  module.command(([[
    try
      execute "%s"
    catch
      let g:__exception = v:exception
    endtry
  ]]):format(cmd:gsub('\n', '\\n'):gsub('[\\"]', '\\%0')))
  local ret = module.eval('get(g:, "__exception", 0)')
  module.command('unlet! g:__exception')
  return ret
end

function module.skip(cond, reason)
  if cond then
    local pending = getfenv(2).pending
    pending(reason or 'FIXME')
    return true
  else
    return false
  end
end

-- Calls pending() and returns `true` if the system is too slow to
-- run fragile or expensive tests. Else returns `false`.
function module.skip_fragile(pending_fn, cond)
  if pending_fn == nil or type(pending_fn) ~= type(function()end) then
    error("invalid pending_fn")
  end
  if cond then
    pending_fn("skipped (test is fragile on this system)", function() end)
    return true
  elseif os.getenv("TEST_SKIP_FRAGILE") then
    pending_fn("skipped (TEST_SKIP_FRAGILE)", function() end)
    return true
  end
  return false
end

function module.exec(code)
  module.meths.exec2(code, {})
end

function module.exec_capture(code)
  return module.meths.exec2(code, { output = true }).output
end

function module.exec_lua(code, ...)
  return module.meths.exec_lua(code, {...})
end

function module.get_pathsep()
  return is_os('win') and '\\' or '/'
end

--- Gets the filesystem root dir, namely "/" or "C:/".
function module.pathroot()
  local pathsep = package.config:sub(1,1)
  return is_os('win') and (module.nvim_dir:sub(1,2)..pathsep) or '/'
end

--- Gets the full `…/build/bin/{name}` path of a test program produced by
--- `test/functional/fixtures/CMakeLists.txt`.
---
--- @param name (string) Name of the test program.
function module.testprg(name)
  local ext = module.is_os('win') and '.exe' or ''
  return ('%s/%s%s'):format(module.nvim_dir, name, ext)
end

-- Returns a valid, platform-independent Nvim listen address.
-- Useful for communicating with child instances.
function module.new_pipename()
  -- HACK: Start a server temporarily, get the name, then stop it.
  local pipename = module.eval('serverstart()')
  module.funcs.serverstop(pipename)
  return pipename
end

function module.missing_provider(provider)
  if provider == 'ruby' or provider == 'node' or provider == 'perl' then
    local e = module.funcs['provider#'..provider..'#Detect']()[2]
    return e ~= '' and e or false
  elseif provider == 'python' or provider == 'python3' then
    local py_major_version = (provider == 'python3' and 3 or 2)
    local e = module.funcs['provider#pythonx#Detect'](py_major_version)[2]
    return e ~= '' and e or false
  else
    assert(false, 'Unknown provider: '..provider)
  end
end

function module.alter_slashes(obj)
  if not is_os('win') then
    return obj
  end
  if type(obj) == 'string' then
    local ret = obj:gsub('/', '\\')
    return ret
  elseif type(obj) == 'table' then
    local ret = {}
    for k, v in pairs(obj) do
      ret[k] = module.alter_slashes(v)
    end
    return ret
  else
    assert(false, 'expected string or table of strings, got '..type(obj))
  end
end

local load_factor = 1
if global_helpers.is_ci() then
  -- Compute load factor only once (but outside of any tests).
  module.clear()
  module.request('nvim_command', 'source test/old/testdir/load.vim')
  load_factor = module.request('nvim_eval', 'g:test_load_factor')
end
function module.load_adjust(num)
  return math.ceil(num * load_factor)
end

function module.parse_context(ctx)
  local parsed = {}
  for _, item in ipairs({'regs', 'jumps', 'bufs', 'gvars'}) do
    parsed[item] = filter(function(v)
      return type(v) == 'table'
    end, module.call('msgpackparse', ctx[item]))
  end
  parsed['bufs'] = parsed['bufs'][1]
  return map(function(v)
    if #v == 0 then
      return nil
    end
    return v
  end, parsed)
end

function module.add_builddir_to_rtp()
  -- Add runtime from build dir for doc/tags (used with :help).
  module.command(string.format([[set rtp+=%s/runtime]], module.test_build_dir))
end

-- Kill process with given pid
function module.os_kill(pid)
  return os.execute((is_os('win')
    and 'taskkill /f /t /pid '..pid..' > nul'
    or  'kill -9 '..pid..' > /dev/null'))
end

-- Create folder with non existing parents
function module.mkdir_p(path)
  return os.execute((is_os('win')
    and 'mkdir '..path
    or 'mkdir -p '..path))
end

module = global_helpers.tbl_extend('error', module, global_helpers)

return function(after_each)
  if after_each then
    after_each(function()
      check_logs()
      check_cores('build/bin/nvim')
      if session then
        local msg = session:next_message(0)
        if msg then
          if msg[1] == "notification" and msg[2] == "nvim_error_event" then
            error(msg[3][2])
          end
        end
      end
    end)
  end
  return module
end
