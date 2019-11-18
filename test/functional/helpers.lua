require('coxpcall')
local busted = require('busted')
local luv = require('luv')
local lfs = require('lfs')
local mpack = require('mpack')
local global_helpers = require('test.helpers')

-- nvim client: Found in .deps/usr/share/lua/<version>/nvim/ if "bundled".
local Session = require('nvim.session')
local TcpStream = require('nvim.tcp_stream')
local SocketStream = require('nvim.socket_stream')
local ChildProcessStream = require('nvim.child_process_stream')

local check_cores = global_helpers.check_cores
local check_logs = global_helpers.check_logs
local dedent = global_helpers.dedent
local eq = global_helpers.eq
local filter = global_helpers.filter
local is_os = global_helpers.is_os
local map = global_helpers.map
local ok = global_helpers.ok
local sleep = global_helpers.sleep
local tbl_contains = global_helpers.tbl_contains
local write_file = global_helpers.write_file

local module = {
  NIL = mpack.NIL,
  mkdir = lfs.mkdir,
}

local start_dir = lfs.currentdir()
module.nvim_prog = (
  os.getenv('NVIM_PRG')
  or global_helpers.test_build_dir .. '/bin/nvim'
)
-- Default settings for the test session.
module.nvim_set = (
  'set shortmess+=IS background=light noswapfile noautoindent'
  ..' laststatus=1 undodir=. directory=. viewdir=. backupdir=.'
  ..' belloff= wildoptions-=pum noshowcmd noruler nomore redrawdebug=invalid')
module.nvim_argv = {
  module.nvim_prog, '-u', 'NONE', '-i', 'NONE',
  '--cmd', module.nvim_set, '--embed'}
-- Directory containing nvim.
module.nvim_dir = module.nvim_prog:gsub("[/\\][^/\\]+$", "")
if module.nvim_dir == module.nvim_prog then
  module.nvim_dir = "."
end

local tmpname = global_helpers.tmpname
local iswin = global_helpers.iswin
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

function module.set_session(s, keep)
  if session and not keep then
    session:close()
  end
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
    final_error = cat_err(final_error, result)
  end
  error(final_error)
end

local function call_and_stop_on_error(lsession, ...)
  local status, result = copcall(...)  -- luacheck: ignore
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
  session:run(on_request, on_notification, on_setup, timeout)
  loop_running = false
  if last_error then
    local err = last_error
    last_error = nil
    error(err)
  end
end

function module.run(request_cb, notification_cb, setup_cb, timeout)
  module.run_session(session, request_cb, notification_cb, setup_cb, timeout)
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

-- Executes an ex-command. VimL errors manifest as client (lua) errors, but
-- v:errmsg will not be updated.
function module.command(cmd)
  module.request('nvim_command', cmd)
end

-- Evaluates a VimL expression.
-- Fails on VimL error, but does not update v:errmsg.
function module.eval(expr)
  return module.request('nvim_eval', expr)
end

-- Executes a VimL function.
-- Fails on VimL error, but does not update v:errmsg.
function module.call(name, ...)
  return module.request('nvim_call_function', name, {...})
end

-- Sends user input to Nvim.
-- Does not fail on VimL error, but v:errmsg will be updated.
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
--  "-u", "-i", "--cmd" are treated specially: their "values" are also removed.
--  Example:
--      args={'--headless', '-u', 'NONE'}
--      args_rm={'--cmd', '-u'}
--  Result:
--      {'--headless'}
--
--  All cases are removed.
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
    else
      table.insert(new_args, arg)
    end
  end
  return new_args
end

function module.spawn(argv, merge, env)
  local child_stream = ChildProcessStream.spawn(
      merge and module.merge_args(prepend_argv, argv) or argv,
      env)
  return Session.new(child_stream)
end

-- Creates a new Session connected by domain socket (named pipe) or TCP.
function module.connect(file_or_address)
  local addr, port = string.match(file_or_address, "(.*):(%d+)")
  local stream = (addr and port) and TcpStream.open(addr, port) or
    SocketStream.open(file_or_address)
  return Session.new(stream)
end

-- Calls fn() until it succeeds, up to `max` times or until `max_ms`
-- milliseconds have passed.
function module.retry(max, max_ms, fn)
  assert(max == nil or max > 0)
  assert(max_ms == nil or max_ms > 0)
  local tries = 1
  local timeout = (max_ms and max_ms or 10000)
  local start_time = luv.now()
  while true do
    local status, result = pcall(fn)
    if status then
      return result
    end
    luv.update_time()  -- Update cached value of luv.now() (libuv: uv_now()).
    if (max and tries >= max) or (luv.now() - start_time > timeout) then
      busted.fail(string.format("retry() attempts: %d\n%s", tries, tostring(result)), 2)
    end
    tries = tries + 1
    luv.sleep(20)  -- Avoid hot loop...
  end
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
  local argv, env = module.new_argv(...)
  module.set_session(module.spawn(argv, nil, env))
end

-- Builds an argument list for use in clear().
--
--@see clear() for parameters.
function module.new_argv(...)
  local args = {unpack(module.nvim_argv)}
  table.insert(args, '--headless')
  local new_args
  local env = nil
  local opts = select(1, ...)
  if type(opts) == 'table' then
    args = remove_args(args, opts.args_rm)
    if opts.env then
      local env_tbl = {}
      for k, v in pairs(opts.env) do
        assert(type(k) == 'string')
        assert(type(v) == 'string')
        env_tbl[k] = v
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
        'TMPDIR',
      }) do
        if not env_tbl[k] then
          env_tbl[k] = os.getenv(k)
        end
      end
      env = {}
      for k, v in pairs(env_tbl) do
        env[#env + 1] = k .. '=' .. v
      end
    end
    new_args = opts.args or {}
  else
    new_args = {...}
  end
  for _, arg in ipairs(new_args) do
    table.insert(args, arg)
  end
  return args, env
end

function module.insert(...)
  nvim_feed('i')
  for _, v in ipairs({...}) do
    local escaped = v:gsub('<', '<lt>')
    module.rawfeed(escaped)
  end
  nvim_feed('<ESC>')
end

-- Executes an ex-command by user input. Because nvim_input() is used, VimL
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

local sourced_fnames = {}
function module.source(code)
  local fname = tmpname()
  write_file(fname, code)
  module.command('source '..fname)
  -- DO NOT REMOVE FILE HERE.
  -- do_source() has a habit of checking whether files are “same” by using inode
  -- and device IDs. If you run two source() calls in quick succession there is
  -- a good chance that underlying filesystem will reuse the inode, making files
  -- appear as “symlinks” to do_source when it checks FileIDs. With current
  -- setup linux machines (both QB, travis and mine(ZyX-I) with XFS) do reuse
  -- inodes, Mac OS machines (again, both QB and travis) do not.
  --
  -- Files appearing as “symlinks” mean that both the first and the second
  -- source() calls will use same SID, which may fail some tests which check for
  -- exact numbers after `<SNR>` in e.g. function names.
  sourced_fnames[#sourced_fnames + 1] = fname
  return fname
end

function module.set_shell_powershell()
  local shell = iswin() and 'powershell' or 'pwsh'
  assert(module.eval('executable("'..shell..'")'))
  local cmd = 'Remove-Item -Force '..table.concat(iswin()
    and {'alias:cat', 'alias:echo', 'alias:sleep'}
    or  {'alias:echo'}, ',')..';'
  module.source([[
    let &shell = ']]..shell..[['
    set shellquote= shellpipe=\| shellxquote=
    let &shellredir = '| Out-File -Encoding UTF8'
    let &shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command ]]..cmd..[['
  ]])
end

function module.nvim(method, ...)
  return module.request('nvim_'..method, ...)
end

local function ui(method, ...)
  return module.request('nvim_ui_'..method, ...)
end

function module.nvim_async(method, ...)
  session:notify('nvim_'..method, ...)
end

function module.buffer(method, ...)
  return module.request('nvim_buf_'..method, ...)
end

function module.window(method, ...)
  return module.request('nvim_win_'..method, ...)
end

function module.tabpage(method, ...)
  return module.request('nvim_tabpage_'..method, ...)
end

function module.curbuf(method, ...)
  if not method then
    return module.nvim('get_current_buf')
  end
  return module.buffer(method, 0, ...)
end

function module.wait()
  -- Execute 'nvim_eval' (a deferred function) to block
  -- until all pending input is processed.
  session:request('nvim_eval', '1')
end

function module.curbuf_contents()
  module.wait()  -- Before inspecting the buffer, process all input.
  return table.concat(module.curbuf('get_lines', 0, -1, true), '\n')
end

function module.curwin(method, ...)
  if not method then
    return module.nvim('get_current_win')
  end
  return module.window(method, 0, ...)
end

function module.curtab(method, ...)
  if not method then
    return module.nvim('get_current_tabpage')
  end
  return module.tabpage(method, 0, ...)
end

function module.expect(contents)
  return eq(dedent(contents), module.curbuf_contents())
end

function module.expect_any(contents)
  contents = dedent(contents)
  return ok(nil ~= string.find(module.curbuf_contents(), contents, 1, true))
end

-- Checks that the Nvim session did not terminate.
function module.assert_alive()
  assert(2 == module.eval('1+1'), 'crash? request failed')
end

local function do_rmdir(path)
  local mode, errmsg, errcode = lfs.attributes(path, 'mode')
  if mode == nil then
    if errcode == 2 then
      -- "No such file or directory", don't complain.
      return
    end
    error(string.format('rmdir: %s (%d)', errmsg, errcode))
  end
  if mode ~= 'directory' then
    error(string.format('rmdir: not a directory: %s', path))
  end
  for file in lfs.dir(path) do
    if file ~= '.' and file ~= '..' then
      local abspath = path..'/'..file
      if lfs.attributes(abspath, 'mode') == 'directory' then
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
  local ret, err = lfs.rmdir(path)
  if not ret then
    error('lfs.rmdir('..path..'): '..err)
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

-- Helper to skip tests. Returns true in Windows systems.
-- pending_fn is pending() from busted
function module.pending_win32(pending_fn)
  if iswin() then
    if pending_fn ~= nil then
      pending_fn('FIXME: Windows', function() end)
    end
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

module.funcs = module.create_callindex(module.call)
module.meths = module.create_callindex(module.nvim)
module.async_meths = module.create_callindex(module.nvim_async)
module.uimeths = module.create_callindex(ui)
module.bufmeths = module.create_callindex(module.buffer)
module.winmeths = module.create_callindex(module.window)
module.tabmeths = module.create_callindex(module.tabpage)
module.curbufmeths = module.create_callindex(module.curbuf)
module.curwinmeths = module.create_callindex(module.curwin)
module.curtabmeths = module.create_callindex(module.curtab)

function module.exec_lua(code, ...)
  return module.meths.execute_lua(code, {...})
end

function module.redir_exec(cmd)
  module.meths.set_var('__redir_exec_cmd', cmd)
  module.command([[
    redir => g:__redir_exec_output
      silent! execute g:__redir_exec_cmd
    redir END
  ]])
  local ret = module.meths.get_var('__redir_exec_output')
  module.meths.del_var('__redir_exec_output')
  module.meths.del_var('__redir_exec_cmd')
  return ret
end

function module.get_pathsep()
  return iswin() and '\\' or '/'
end

function module.pathroot()
  local pathsep = package.config:sub(1,1)
  return iswin() and (module.nvim_dir:sub(1,2)..pathsep) or '/'
end

-- Returns a valid, platform-independent $NVIM_LISTEN_ADDRESS.
-- Useful for communicating with child instances.
function module.new_pipename()
  -- HACK: Start a server temporarily, get the name, then stop it.
  local pipename = module.eval('serverstart()')
  module.funcs.serverstop(pipename)
  return pipename
end

function module.missing_provider(provider)
  if provider == 'ruby' or provider == 'node' then
    local prog = module.funcs['provider#' .. provider .. '#Detect']()
    return prog == '' and (provider .. ' not detected') or false
  elseif provider == 'python' or provider == 'python3' then
    local py_major_version = (provider == 'python3' and 3 or 2)
    local errors = module.funcs['provider#pythonx#Detect'](py_major_version)[2]
    return errors ~= '' and errors or false
  else
    assert(false, 'Unknown provider: ' .. provider)
  end
end

function module.alter_slashes(obj)
  if not iswin() then
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
    assert(false, 'Could only alter slashes for tables of strings and strings')
  end
end

local load_factor = 1
if global_helpers.isCI() then
  -- Compute load factor only once (but outside of any tests).
  module.clear()
  module.request('nvim_command', 'source src/nvim/testdir/load.vim')
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
  return os.execute((iswin()
    and 'taskkill /f /t /pid '..pid..' > nul'
    or  'kill -9 '..pid..' > /dev/null'))
end

module = global_helpers.tbl_extend('error', module, global_helpers)

return function(after_each)
  if after_each then
    after_each(function()
      for _, fname in ipairs(sourced_fnames) do
        os.remove(fname)
      end
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
