require('coxpcall')
local luv = require('luv')
local lfs = require('lfs')
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
local ok = global_helpers.ok
local sleep = global_helpers.sleep
local tbl_contains = global_helpers.tbl_contains
local write_file = global_helpers.write_file

local start_dir = lfs.currentdir()
-- XXX: NVIM_PROG takes precedence, QuickBuild sets it.
local nvim_prog = (
  os.getenv('NVIM_PROG')
  or os.getenv('NVIM_PRG')
  or global_helpers.test_build_dir .. '/bin/nvim'
)
-- Default settings for the test session.
local nvim_set  = 'set shortmess+=IS background=light noswapfile noautoindent'
                  ..' laststatus=1 undodir=. directory=. viewdir=. backupdir=.'
                  ..' belloff= noshowcmd noruler nomore'
local nvim_argv = {nvim_prog, '-u', 'NONE', '-i', 'NONE',
                   '--cmd', nvim_set, '--embed'}
-- Directory containing nvim.
local nvim_dir = nvim_prog:gsub("[/\\][^/\\]+$", "")
if nvim_dir == nvim_prog then
  nvim_dir = "."
end

local mpack = require('mpack')
local tmpname = global_helpers.tmpname
local uname = global_helpers.uname
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
  for i = 1, #nvim_argv do
    new_nvim_argv[i + len] = nvim_argv[i]
  end
  nvim_argv = new_nvim_argv
end

local session, loop_running, last_error, method_error

local function get_session()
  return session
end

local function set_session(s, keep)
  if session and not keep then
    session:close()
  end
  session = s
end

local function request(method, ...)
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

local function next_msg(timeout)
  return session:next_message(timeout and timeout or 10000)
end

local function expect_twostreams(msgs1, msgs2)
  local pos1, pos2 = 1, 1
  while pos1 <= #msgs1 or pos2 <= #msgs2 do
    local msg = next_msg()
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
local function expect_msg_seq(...)
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
  for anum = 1, #seqs do
    local expected_seq = seqs[anum]
    -- Collect enough messages to compare the next expected sequence.
    while #actual_seq < #expected_seq do
      local msg = next_msg(10000)  -- Big timeout for ASAN/valgrind.
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

local function set_method_error(err)
  method_error = err
end

local function run_session(lsession, request_cb, notification_cb, setup_cb, timeout)
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

local function run(request_cb, notification_cb, setup_cb, timeout)
  run_session(session, request_cb, notification_cb, setup_cb, timeout)
end

local function stop()
  session:stop()
end

local function nvim_prog_abs()
  -- system(['build/bin/nvim']) does not work for whatever reason. It must
  -- be executable searched in $PATH or something starting with / or ./.
  if nvim_prog:match('[/\\]') then
    return request('nvim_call_function', 'fnamemodify', {nvim_prog, ':p'})
  else
    return nvim_prog
  end
end

-- Executes an ex-command. VimL errors manifest as client (lua) errors, but
-- v:errmsg will not be updated.
local function nvim_command(cmd)
  request('nvim_command', cmd)
end

-- Evaluates a VimL expression.
-- Fails on VimL error, but does not update v:errmsg.
local function nvim_eval(expr)
  return request('nvim_eval', expr)
end

local os_name = (function()
  local name = nil
  return (function()
    if not name then
      if nvim_eval('has("win32")') == 1 then
        name = 'windows'
      elseif nvim_eval('has("macunix")') == 1 then
        name = 'osx'
      else
        name = 'unix'
      end
    end
    return name
  end)
end)()

local function iswin()
  return package.config:sub(1,1) == '\\'
end

-- Executes a VimL function.
-- Fails on VimL error, but does not update v:errmsg.
local function nvim_call(name, ...)
  return request('nvim_call_function', name, {...})
end

-- Sends user input to Nvim.
-- Does not fail on VimL error, but v:errmsg will be updated.
local function nvim_feed(input)
  while #input > 0 do
    local written = request('nvim_input', input)
    input = input:sub(written + 1)
  end
end

local function feed(...)
  for _, v in ipairs({...}) do
    nvim_feed(dedent(v))
  end
end

local function rawfeed(...)
  for _, v in ipairs({...}) do
    nvim_feed(dedent(v))
  end
end

local function merge_args(...)
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

local function spawn(argv, merge, env)
  local child_stream = ChildProcessStream.spawn(
      merge and merge_args(prepend_argv, argv) or argv,
      env)
  return Session.new(child_stream)
end

-- Creates a new Session connected by domain socket (named pipe) or TCP.
local function connect(file_or_address)
  local addr, port = string.match(file_or_address, "(.*):(%d+)")
  local stream = (addr and port) and TcpStream.open(addr, port) or
    SocketStream.open(file_or_address)
  return Session.new(stream)
end

-- Calls fn() until it succeeds, up to `max` times or until `max_ms`
-- milliseconds have passed.
local function retry(max, max_ms, fn)
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
      error("\nretry() attempts: "..tostring(tries).."\n"..tostring(result))
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
local function clear(...)
  local args = {unpack(nvim_argv)}
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
        'LD_LIBRARY_PATH',
        'PATH',
        'NVIM_LOG_FILE',
        'NVIM_RPLUGIN_MANIFEST',
        'GCOV_ERROR_FILE',
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
  set_session(spawn(args, nil, env))
end

local function insert(...)
  nvim_feed('i')
  for _, v in ipairs({...}) do
    local escaped = v:gsub('<', '<lt>')
    rawfeed(escaped)
  end
  nvim_feed('<ESC>')
end

-- Executes an ex-command by user input. Because nvim_input() is used, VimL
-- errors will not manifest as client (lua) errors. Use command() for that.
local function feed_command(...)
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
local function source(code)
  local fname = tmpname()
  write_file(fname, code)
  nvim_command('source '..fname)
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

local function set_shell_powershell()
  source([[
    set shell=powershell shellquote=( shellpipe=\| shellredir=> shellxquote=
    let &shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command Remove-Item -Force alias:sleep;'
  ]])
end

local function nvim(method, ...)
  return request('nvim_'..method, ...)
end

local function ui(method, ...)
  return request('nvim_ui_'..method, ...)
end

local function nvim_async(method, ...)
  session:notify('nvim_'..method, ...)
end

local function buffer(method, ...)
  return request('nvim_buf_'..method, ...)
end

local function window(method, ...)
  return request('nvim_win_'..method, ...)
end

local function tabpage(method, ...)
  return request('nvim_tabpage_'..method, ...)
end

local function curbuf(method, ...)
  if not method then
    return nvim('get_current_buf')
  end
  return buffer(method, 0, ...)
end

local function wait()
  -- Execute 'nvim_eval' (a deferred function) to block
  -- until all pending input is processed.
  session:request('nvim_eval', '1')
end

local function curbuf_contents()
  wait()  -- Before inspecting the buffer, process all input.
  return table.concat(curbuf('get_lines', 0, -1, true), '\n')
end

local function curwin(method, ...)
  if not method then
    return nvim('get_current_win')
  end
  return window(method, 0, ...)
end

local function curtab(method, ...)
  if not method then
    return nvim('get_current_tabpage')
  end
  return tabpage(method, 0, ...)
end

local function expect(contents)
  return eq(dedent(contents), curbuf_contents())
end

local function expect_any(contents)
  contents = dedent(contents)
  return ok(nil ~= string.find(curbuf_contents(), contents, 1, true))
end

local function do_rmdir(path)
  if lfs.attributes(path, 'mode') ~= 'directory' then
    return  -- Don't complain.
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
            if -1 == nvim_call('delete', abspath) then
              local hint = (os_name() == 'windows'
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

local function rmdir(path)
  local ret, _ = pcall(do_rmdir, path)
  if not ret and os_name() == "windows" then
    -- Maybe "Permission denied"; try again after changing the nvim
    -- process to the top-level directory.
    nvim_command([[exe 'cd '.fnameescape(']]..start_dir.."')")
    ret, _ = pcall(do_rmdir, path)
  end
  -- During teardown, the nvim process may not exit quickly enough, then rmdir()
  -- will fail (on Windows).
  if not ret then  -- Try again.
    sleep(1000)
    do_rmdir(path)
  end
end

local exc_exec = function(cmd)
  nvim_command(([[
    try
      execute "%s"
    catch
      let g:__exception = v:exception
    endtry
  ]]):format(cmd:gsub('\n', '\\n'):gsub('[\\"]', '\\%0')))
  local ret = nvim_eval('get(g:, "__exception", 0)')
  nvim_command('unlet! g:__exception')
  return ret
end

local function create_callindex(func)
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
local function pending_win32(pending_fn)
  if uname() == 'Windows' then
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
local function skip_fragile(pending_fn, cond)
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

local function meth_pcall(...)
  local ret = {pcall(...)}
  if type(ret[2]) == 'string' then
    ret[2] = ret[2]:gsub('^[^:]+:%d+: ', '')
  end
  return ret
end

local funcs = create_callindex(nvim_call)
local meths = create_callindex(nvim)
local uimeths = create_callindex(ui)
local bufmeths = create_callindex(buffer)
local winmeths = create_callindex(window)
local tabmeths = create_callindex(tabpage)
local curbufmeths = create_callindex(curbuf)
local curwinmeths = create_callindex(curwin)
local curtabmeths = create_callindex(curtab)

local function exec_lua(code, ...)
  return meths.execute_lua(code, {...})
end

local function redir_exec(cmd)
  meths.set_var('__redir_exec_cmd', cmd)
  nvim_command([[
    redir => g:__redir_exec_output
      silent! execute g:__redir_exec_cmd
    redir END
  ]])
  local ret = meths.get_var('__redir_exec_output')
  meths.del_var('__redir_exec_output')
  meths.del_var('__redir_exec_cmd')
  return ret
end

local function get_pathsep()
  return iswin() and '\\' or '/'
end

local function pathroot()
  local pathsep = package.config:sub(1,1)
  return iswin() and (nvim_dir:sub(1,2)..pathsep) or '/'
end

-- Returns a valid, platform-independent $NVIM_LISTEN_ADDRESS.
-- Useful for communicating with child instances.
local function new_pipename()
  -- HACK: Start a server temporarily, get the name, then stop it.
  local pipename = nvim_eval('serverstart()')
  funcs.serverstop(pipename)
  return pipename
end

local function missing_provider(provider)
  if provider == 'ruby' or provider == 'node' then
    local prog = funcs['provider#' .. provider .. '#Detect']()
    return prog == '' and (provider .. ' not detected') or false
  elseif provider == 'python' or provider == 'python3' then
    local py_major_version = (provider == 'python3' and 3 or 2)
    local errors = funcs['provider#pythonx#Detect'](py_major_version)[2]
    return errors ~= '' and errors or false
  else
    assert(false, 'Unknown provider: ' .. provider)
  end
end

local function alter_slashes(obj)
  if not iswin() then
    return obj
  end
  if type(obj) == 'string' then
    local ret = obj:gsub('/', '\\')
    return ret
  elseif type(obj) == 'table' then
    local ret = {}
    for k, v in pairs(obj) do
      ret[k] = alter_slashes(v)
    end
    return ret
  else
    assert(false, 'Could only alter slashes for tables of strings and strings')
  end
end


local load_factor = nil
local function load_adjust(num)
  if load_factor == nil then  -- Compute load factor only once.
    clear()
    request('nvim_command', 'source src/nvim/testdir/load.vim')
    load_factor = request('nvim_eval', 'g:test_load_factor')
  end
  return math.ceil(num * load_factor)
end

local module = {
  NIL = mpack.NIL,
  alter_slashes = alter_slashes,
  buffer = buffer,
  bufmeths = bufmeths,
  call = nvim_call,
  create_callindex = create_callindex,
  clear = clear,
  command = nvim_command,
  connect = connect,
  curbuf = curbuf,
  curbuf_contents = curbuf_contents,
  curbufmeths = curbufmeths,
  curtab = curtab,
  curtabmeths = curtabmeths,
  curwin = curwin,
  curwinmeths = curwinmeths,
  eval = nvim_eval,
  exc_exec = exc_exec,
  exec_lua = exec_lua,
  expect = expect,
  expect_any = expect_any,
  expect_msg_seq = expect_msg_seq,
  expect_twostreams = expect_twostreams,
  feed = feed,
  feed_command = feed_command,
  funcs = funcs,
  get_pathsep = get_pathsep,
  get_session = get_session,
  insert = insert,
  iswin = iswin,
  merge_args = merge_args,
  meth_pcall = meth_pcall,
  meths = meths,
  missing_provider = missing_provider,
  mkdir = lfs.mkdir,
  load_adjust = load_adjust,
  new_pipename = new_pipename,
  next_msg = next_msg,
  nvim = nvim,
  nvim_argv = nvim_argv,
  nvim_async = nvim_async,
  nvim_dir = nvim_dir,
  nvim_prog = nvim_prog,
  nvim_prog_abs = nvim_prog_abs,
  nvim_set = nvim_set,
  os_name = os_name,
  pathroot = pathroot,
  pending_win32 = pending_win32,
  prepend_argv = prepend_argv,
  rawfeed = rawfeed,
  redir_exec = redir_exec,
  request = request,
  retry = retry,
  rmdir = rmdir,
  run = run,
  run_session = run_session,
  set_session = set_session,
  set_method_error = set_method_error,
  set_shell_powershell = set_shell_powershell,
  skip_fragile = skip_fragile,
  source = source,
  spawn = spawn,
  stop = stop,
  tabmeths = tabmeths,
  tabpage = tabpage,
  uimeths = uimeths,
  wait = wait,
  window = window,
  winmeths = winmeths,
}
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
