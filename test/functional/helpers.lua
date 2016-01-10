require('coxpcall')
local ffi = require('ffi')
local lfs = require('lfs')
local assert = require('luassert')
local Loop = require('nvim.loop')
local MsgpackStream = require('nvim.msgpack_stream')
local AsyncSession = require('nvim.async_session')
local Session = require('nvim.session')

local nvim_prog = os.getenv('NVIM_PROG') or 'build/bin/nvim'
local nvim_argv = {nvim_prog, '-u', 'NONE', '-i', 'NONE', '-N',
                   '--cmd', 'set shortmess+=I background=light noswapfile noautoindent laststatus=1 undodir=. directory=. viewdir=. backupdir=.',
                   '--embed'}

-- Formulate a path to the directory containing nvim.  We use this to
-- help run test executables.  It helps to keep the tests working, even
-- when the build is not in the default location.
local nvim_dir = nvim_prog:gsub("[/\\][^/\\]+$", "")
if nvim_dir == nvim_prog then
    nvim_dir = "."
end

-- Nvim "Unit Under Test" http://en.wikipedia.org/wiki/Device_under_test
local NvimUUT = {}
NvimUUT.__index = NvimUUT

local prepend_argv

if os.getenv('VALGRIND') then
  local log_file = os.getenv('VALGRIND_LOG') or 'valgrind-%p.log'
  prepend_argv = {'valgrind', '-q', '--tool=memcheck',
                  '--leak-check=yes', '--track-origins=yes',
                  '--show-possibly-lost=no',
                  '--suppressions=.valgrind.supp',
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

local session, loop_running, last_error

local function set_session(s)
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

local function next_message()
  return session:next_message()
end

local function call_and_stop_on_error(...)
  local status, result = copcall(...)  -- luacheck: ignore
  if not status then
    session:stop()
    last_error = result
    return ''
  end
  return result
end

local function run(request_cb, notification_cb, setup_cb, timeout)
  local on_request, on_notification, on_setup

  if request_cb then
    function on_request(method, args)
      return call_and_stop_on_error(request_cb, method, args)
    end
  end

  if notification_cb then
    function on_notification(method, args)
      call_and_stop_on_error(notification_cb, method, args)
    end
  end

  if setup_cb then
    function on_setup()
      call_and_stop_on_error(setup_cb)
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

local function stop()
  session:stop()
end

local function nvim_command(cmd)
  request('vim_command', cmd)
end

local function nvim_eval(expr)
  return request('vim_eval', expr)
end

local function nvim_call(name, ...)
  return request('vim_call_function', name, {...})
end

local function nvim_feed(input)
  while #input > 0 do
    local written = request('vim_input', input)
    input = input:sub(written + 1)
  end
end

local function dedent(str)
  -- find minimum common indent across lines
  local indent = nil
  for line in str:gmatch('[^\n]+') do
    local line_indent = line:match('^%s+') or ''
    if indent == nil or #line_indent < #indent then
      indent = line_indent
    end
  end
  if #indent == 0 then
    -- no minimum common indent
    return str
  end
  -- create a pattern for the indent
  indent = indent:gsub('%s', '%%s')
  -- strip it from the first line
  str = str:gsub('^'..indent, '')
  -- strip it from the remaining lines
  str = str:gsub('[\n]'..indent, '\n')
  return str
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

local function spawn(argv, merge)
  local loop = Loop.new()
  local msgpack_stream = MsgpackStream.new(loop)
  local async_session = AsyncSession.new(msgpack_stream)
  local sess = Session.new(async_session)
  loop:spawn(merge and merge_args(prepend_argv, argv) or argv)
  return sess
end

local function clear(extra_cmd)
  if session then
    session:exit(0)
  end
  local args = {unpack(nvim_argv)}
  if extra_cmd ~= nil then
    table.insert(args, '--cmd')
    table.insert(args, extra_cmd)
  end
  session = spawn(args)
end

local function insert(...)
  nvim_feed('i')
  for _, v in ipairs({...}) do
    local escaped = v:gsub('<', '<lt>')
    rawfeed(escaped)
  end
  nvim_feed('<ESC>')
end

local function execute(...)
  for _, v in ipairs({...}) do
    if v:sub(1, 1) ~= '/' then
      -- not a search command, prefix with colon
      nvim_feed(':')
    end
    nvim_feed(v:gsub('<', '<lt>'))
    nvim_feed('<CR>')
  end
end

-- Dedent the given text and write it to the file name.
local function write_file(name, text, dont_dedent)
  local file = io.open(name, 'w')
  if not dont_dedent then
    text = dedent(text)
  end
  file:write(text)
  file:flush()
  file:close()
end

local function source(code)
  local tmpname = os.tmpname()
  if ffi.os == 'OSX' and string.match(tmpname, '^/tmp') then
   tmpname = '/private'..tmpname
  end
  write_file(tmpname, code)
  nvim_command('source '..tmpname)
  os.remove(tmpname)
  return tmpname
end

local function eq(expected, actual)
  return assert.are.same(expected, actual)
end

local function neq(expected, actual)
  return assert.are_not.same(expected, actual)
end

local function ok(expr)
  assert.is_true(expr)
end

local function nvim(method, ...)
  return request('vim_'..method, ...)
end

local function nvim_async(method, ...)
  session:notify('vim_'..method, ...)
end

local function buffer(method, ...)
  return request('buffer_'..method, ...)
end

local function window(method, ...)
  return request('window_'..method, ...)
end

local function tabpage(method, ...)
  return request('tabpage_'..method, ...)
end

local function curbuf(method, ...)
  local buf = nvim('get_current_buffer')
  if not method then
    return buf
  end
  return buffer(method, buf, ...)
end

local function wait()
  session:request('vim_eval', '1')
end

local function curbuf_contents()
  -- Before inspecting the buffer, execute 'vim_eval' to wait until all
  -- previously sent keys are processed(vim_eval is a deferred function, and
  -- only processed after all input)
  wait()
  return table.concat(curbuf('get_line_slice', 0, -1, true, true), '\n')
end

local function curwin(method, ...)
  local win = nvim('get_current_window')
  if not method then
    return win
  end
  return window(method, win, ...)
end

local function curtab(method, ...)
  local tab = nvim('get_current_tabpage')
  if not method then
    return tab
  end
  return tabpage(method, tab, ...)
end

local function expect(contents)
  return eq(dedent(contents), curbuf_contents())
end

local function os_is_windows()
  return nvim_eval('has("win32")') == 1
end

local function rmdir(path)
  if lfs.attributes(path, 'mode') ~= 'directory' then
    return nil
  end
  for file in lfs.dir(path) do
    if file == '.' or file == '..' then
      goto continue
    end
    local ret, err = os.remove(path..'/'..file)
    if not ret then
      error('os.remove: '..err)
      return nil
    end
    ::continue::
  end
  local ret, err = os.remove(path)
  if not ret then
    error('os.remove: '..err)
  end
  return ret
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

local function redir_exec(cmd)
  nvim_command(([[
    redir => g:__output
      silent! execute "%s"
    redir END
  ]]):format(cmd:gsub('\n', '\\n'):gsub('[\\"]', '\\%0')))
  local ret = nvim_eval('get(g:, "__output", 0)')
  nvim_command('unlet! g:__output')
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

local funcs = create_callindex(nvim_call)
local meths = create_callindex(nvim)
local bufmeths = create_callindex(buffer)
local winmeths = create_callindex(window)
local tabmeths = create_callindex(tabpage)
local curbufmeths = create_callindex(curbuf)
local curwinmeths = create_callindex(curwin)
local curtabmeths = create_callindex(curtab)

return {
  prepend_argv = prepend_argv,
  clear = clear,
  spawn = spawn,
  dedent = dedent,
  source = source,
  rawfeed = rawfeed,
  insert = insert,
  feed = feed,
  execute = execute,
  eval = nvim_eval,
  call = nvim_call,
  command = nvim_command,
  request = request,
  next_message = next_message,
  run = run,
  stop = stop,
  eq = eq,
  neq = neq,
  expect = expect,
  ok = ok,
  nvim = nvim,
  nvim_async = nvim_async,
  nvim_prog = nvim_prog,
  nvim_dir = nvim_dir,
  buffer = buffer,
  window = window,
  tabpage = tabpage,
  curbuf = curbuf,
  curwin = curwin,
  curtab = curtab,
  curbuf_contents = curbuf_contents,
  wait = wait,
  set_session = set_session,
  write_file = write_file,
  os_is_windows = os_is_windows,
  rmdir = rmdir,
  mkdir = lfs.mkdir,
  exc_exec = exc_exec,
  redir_exec = redir_exec,
  merge_args = merge_args,
  funcs = funcs,
  meths = meths,
  bufmeths = bufmeths,
  winmeths = winmeths,
  tabmeths = tabmeths,
  curbufmeths = curbufmeths,
  curwinmeths = curwinmeths,
  curtabmeths = curtabmeths,
}
