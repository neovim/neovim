local uv = vim.uv

--- @class vim.SystemOpts
--- @inlinedoc
---
--- Set the current working directory for the sub-process.
--- @field cwd? string
---
--- Set environment variables for the new process. Inherits the current environment with `NVIM` set
--- to |v:servername|.
--- @field env? table<string,string|number>
---
--- `env` defines the job environment exactly, instead of merging current environment. Note: if
--- `env` is `nil`, the current environment is used but without `NVIM` set.
--- @field clear_env? boolean
---
--- If `true`, then a pipe to stdin is opened and can be written to via the `write()` method to
--- SystemObj. If `string` or `string[]` then will be written to stdin and closed.
--- @field stdin? string|string[]|true
---
--- Handle output from stdout.
--- (Default: `true`)
--- @field stdout? fun(err:string?, data: string?)|boolean
---
--- Handle output from stderr.
--- (Default: `true`)
--- @field stderr? fun(err:string?, data: string?)|boolean
---
--- Handle stdout and stderr as text. Normalizes line endings by replacing `\r\n` with `\n`.
--- @field text? boolean
---
--- Run the command with a time limit in ms. Upon timeout the process is sent the TERM signal (15)
--- and the exit code is set to 124.
--- @field timeout? integer
---
--- Spawn the child process in a detached state - this will make it a process group leader, and will
--- effectively enable the child to keep running after the parent exits. Note that the child process
--- will still keep the parent's event loop alive unless the parent process calls [uv.unref()] on
--- the child's process handle.
--- @field detach? boolean

--- @class vim.SystemCompleted
--- @field code integer
--- @field signal integer
--- @field stdout? string `nil` if stdout is disabled or has a custom handler.
--- @field stderr? string `nil` if stderr is disabled or has a custom handler.

--- @class (package) vim.SystemState
--- @field cmd string[]
--- @field handle? uv.uv_process_t
--- @field timer?  uv.uv_timer_t
--- @field pid? integer
--- @field timeout? integer
--- @field done? boolean|'timeout'
--- @field stdin? uv.uv_stream_t
--- @field stdout? uv.uv_stream_t
--- @field stderr? uv.uv_stream_t
--- @field stdout_data? string[]
--- @field stderr_data? string[]
--- @field result? vim.SystemCompleted

--- @enum vim.SystemSig
local SIG = {
  HUP = 1, -- Hangup
  INT = 2, -- Interrupt from keyboard
  KILL = 9, -- Kill signal
  TERM = 15, -- Termination signal
  -- STOP = 17,19,23  -- Stop the process
}

---@param handle uv.uv_handle_t?
local function close_handle(handle)
  if handle and not handle:is_closing() then
    handle:close()
  end
end

--- @class vim.SystemObj
--- @field cmd string[] Command name and args
--- @field pid integer Process ID
--- @field private _state vim.SystemState
local SystemObj = {}

--- @param state vim.SystemState
--- @return vim.SystemObj
local function new_systemobj(state)
  return setmetatable({
    cmd = state.cmd,
    pid = state.pid,
    _state = state,
  }, { __index = SystemObj })
end

--- Sends a signal to the process.
---
--- The signal can be specified as an integer or as a string.
---
--- Example:
--- ```lua
--- local obj = vim.system({'sleep', '10'})
--- obj:kill('TERM') -- sends SIGTERM to the process
--- ```
---
--- @param signal integer|string Signal to send to the process.
function SystemObj:kill(signal)
  self._state.handle:kill(signal)
end

--- @package
--- @param signal? vim.SystemSig
function SystemObj:_timeout(signal)
  self._state.done = 'timeout'
  self:kill(signal or SIG.TERM)
end

--- Waits for the process to complete or until the specified timeout elapses.
---
--- This method blocks execution until the associated process has exited or
--- the optional `timeout` (in milliseconds) has been reached. If the process
--- does not exit before the timeout, it is forcefully terminated with SIGKILL
--- (signal 9), and the exit code is set to 124.
---
--- If no `timeout` is provided, the method will wait indefinitely (or use the
--- timeout specified in the options when the process was started).
---
--- Example:
--- ```lua
--- local obj = vim.system({'echo', 'hello'}, { text = true })
--- local result = obj:wait(1000) -- waits up to 1000ms
--- print(result.code, result.signal, result.stdout, result.stderr)
--- ```
---
--- @param timeout? integer
--- @return vim.SystemCompleted
function SystemObj:wait(timeout)
  local state = self._state

  local done = vim.wait(timeout or state.timeout or vim._maxint, function()
    return state.result ~= nil
  end, nil, true)

  if not done then
    -- Send sigkill since this cannot be caught
    self:_timeout(SIG.KILL)
    vim.wait(timeout or state.timeout or vim._maxint, function()
      return state.result ~= nil
    end, nil, true)
  end

  return state.result
end

--- Writes data to the stdin of the process or closes stdin.
---
--- If `data` is a list of strings, each string is written followed by a
--- newline.
---
--- If `data` is a string, it is written as-is.
---
--- If `data` is `nil`, the write side of the stream is shut down and the pipe
--- is closed.
---
--- Example:
--- ```lua
--- local obj = vim.system({'cat'}, { stdin = true })
--- obj:write({'hello', 'world'}) -- writes 'hello\nworld\n' to stdin
--- obj:write(nil) -- closes stdin
--- ```
---
--- @param data string[]|string|nil
function SystemObj:write(data)
  local stdin = self._state.stdin

  if not stdin then
    error('stdin has not been opened on this object')
  end

  if type(data) == 'table' then
    for _, v in ipairs(data) do
      stdin:write(v)
      stdin:write('\n')
    end
  elseif type(data) == 'string' then
    stdin:write(data)
  elseif data == nil then
    -- Shutdown the write side of the duplex stream and then close the pipe.
    -- Note shutdown will wait for all the pending write requests to complete
    -- TODO(lewis6991): apparently shutdown doesn't behave this way.
    -- (https://github.com/neovim/neovim/pull/17620#discussion_r820775616)
    stdin:write('', function()
      stdin:shutdown(function()
        close_handle(stdin)
      end)
    end)
  end
end

--- Checks if the process handle is closing or already closed.
---
--- This method returns `true` if the underlying process handle is either
--- `nil` or is in the process of closing. It is useful for determining
--- whether it is safe to perform operations on the process handle.
---
--- @return boolean
function SystemObj:is_closing()
  local handle = self._state.handle
  return handle == nil or handle:is_closing() or false
end

--- @param output? fun(err: string?, data: string?)|false
--- @param text? boolean
--- @return uv.uv_stream_t? pipe
--- @return fun(err: string?, data: string?)? handler
--- @return string[]? data
local function setup_output(output, text)
  if output == false then
    return
  end

  local bucket --- @type string[]?
  local handler --- @type fun(err: string?, data: string?)

  if type(output) == 'function' then
    handler = output
  else
    bucket = {}
    handler = function(err, data)
      if err then
        error(err)
      end
      if text and data then
        bucket[#bucket + 1] = data:gsub('\r\n', '\n')
      else
        bucket[#bucket + 1] = data
      end
    end
  end

  local pipe = assert(uv.new_pipe(false))

  --- @param err? string
  --- @param data? string
  local function handler_with_close(err, data)
    handler(err, data)
    if data == nil then
      pipe:read_stop()
      pipe:close()
    end
  end

  return pipe, handler_with_close, bucket
end

--- @param input? string|string[]|boolean
--- @return uv.uv_stream_t?
--- @return string|string[]?
local function setup_input(input)
  if not input then
    return
  end

  local towrite --- @type string|string[]?
  if type(input) == 'string' or type(input) == 'table' then
    towrite = input
  end

  return assert(uv.new_pipe(false)), towrite
end

--- @return table<string,string>
local function base_env()
  local env = vim.fn.environ() --- @type table<string,string>
  env['NVIM'] = vim.v.servername
  env['NVIM_LISTEN_ADDRESS'] = nil
  return env
end

--- uv.spawn will completely overwrite the environment
--- when we just want to modify the existing one, so
--- make sure to prepopulate it with the current env.
--- @param env? table<string,string|number>
--- @param clear_env? boolean
--- @return string[]?
local function setup_env(env, clear_env)
  if not env and clear_env then
    return
  end

  env = env or {}
  if not clear_env then
    --- @type table<string,string|number>
    env = vim.tbl_extend('force', base_env(), env)
  end

  local renv = {} --- @type string[]
  for k, v in pairs(env) do
    renv[#renv + 1] = string.format('%s=%s', k, tostring(v))
  end

  return renv
end

local is_win = vim.fn.has('win32') == 1

--- @param cmd string
--- @param opts uv.spawn.options
--- @param on_exit fun(code: integer, signal: integer)
--- @param on_error fun()
--- @return uv.uv_process_t, integer
local function spawn(cmd, opts, on_exit, on_error)
  if is_win then
    local cmd1 = vim.fn.exepath(cmd)
    if cmd1 ~= '' then
      cmd = cmd1
    end
  end

  local handle, pid_or_err = uv.spawn(cmd, opts, on_exit)
  if not handle then
    on_error()
    if opts.cwd and not uv.fs_stat(opts.cwd) then
      error(("%s (cwd): '%s'"):format(pid_or_err, opts.cwd))
    elseif vim.fn.executable(cmd) == 0 then
      error(("%s (cmd): '%s'"):format(pid_or_err, cmd))
    else
      error(pid_or_err)
    end
  end
  return handle, pid_or_err --[[@as integer]]
end

--- @param timeout integer
--- @param cb fun()
--- @return uv.uv_timer_t
local function timer_oneshot(timeout, cb)
  local timer = assert(uv.new_timer())
  timer:start(timeout, 0, function()
    timer:stop()
    timer:close()
    cb()
  end)
  return timer
end

--- @param state vim.SystemState
--- @param code integer
--- @param signal integer
--- @param on_exit fun(result: vim.SystemCompleted)?
local function _on_exit(state, code, signal, on_exit)
  close_handle(state.handle)
  close_handle(state.stdin)
  close_handle(state.timer)

  -- #30846: Do not close stdout/stderr here, as they may still have data to
  -- read. They will be closed in uv.read_start on EOF.

  local check = uv.new_check()
  check:start(function()
    for _, pipe in pairs({ state.stdin, state.stdout, state.stderr }) do
      if not pipe:is_closing() then
        return
      end
    end
    check:stop()
    check:close()

    if state.done == nil then
      state.done = true
    end

    if (code == 0 or code == 1) and state.done == 'timeout' then
      -- Unix: code == 0
      -- Windows: code == 1
      code = 124
    end

    local stdout_data = state.stdout_data
    local stderr_data = state.stderr_data

    state.result = {
      code = code,
      signal = signal,
      stdout = stdout_data and table.concat(stdout_data) or nil,
      stderr = stderr_data and table.concat(stderr_data) or nil,
    }

    if on_exit then
      on_exit(state.result)
    end
  end)
end

--- @param state vim.SystemState
local function _on_error(state)
  close_handle(state.handle)
  close_handle(state.stdin)
  close_handle(state.stdout)
  close_handle(state.stderr)
  close_handle(state.timer)
end

--- Run a system command
---
--- @param cmd string[]
--- @param opts? vim.SystemOpts
--- @param on_exit? fun(out: vim.SystemCompleted)
--- @return vim.SystemObj
local function run(cmd, opts, on_exit)
  vim.validate('cmd', cmd, 'table')
  vim.validate('opts', opts, 'table', true)
  vim.validate('on_exit', on_exit, 'function', true)

  opts = opts or {}

  local stdout, stdout_handler, stdout_data = setup_output(opts.stdout, opts.text)
  local stderr, stderr_handler, stderr_data = setup_output(opts.stderr, opts.text)
  local stdin, towrite = setup_input(opts.stdin)

  --- @type vim.SystemState
  local state = {
    done = false,
    cmd = cmd,
    timeout = opts.timeout,
    stdin = stdin,
    stdout = stdout,
    stdout_data = stdout_data,
    stderr = stderr,
    stderr_data = stderr_data,
  }

  --- @diagnostic disable-next-line:missing-fields
  state.handle, state.pid = spawn(cmd[1], {
    args = vim.list_slice(cmd, 2),
    stdio = { stdin, stdout, stderr },
    cwd = opts.cwd,
    --- @diagnostic disable-next-line:assign-type-mismatch
    env = setup_env(opts.env, opts.clear_env),
    detached = opts.detach,
    hide = true,
  }, function(code, signal)
    _on_exit(state, code, signal, on_exit)
  end, function()
    _on_error(state)
  end)

  if stdout and stdout_handler then
    stdout:read_start(stdout_handler)
  end

  if stderr and stderr_handler then
    stderr:read_start(stderr_handler)
  end

  local obj = new_systemobj(state)

  if towrite then
    obj:write(towrite)
    obj:write(nil) -- close the stream
  end

  if opts.timeout then
    state.timer = timer_oneshot(opts.timeout, function()
      if state.handle and state.handle:is_active() then
        obj:_timeout()
      end
    end)
  end

  return obj
end

--- Runs a system command or throws an error if {cmd} cannot be run.
---
--- Examples:
---
--- ```lua
--- local on_exit = function(obj)
---   print(obj.code)
---   print(obj.signal)
---   print(obj.stdout)
---   print(obj.stderr)
--- end
---
--- -- Runs asynchronously:
--- vim.system({'echo', 'hello'}, { text = true }, on_exit)
---
--- -- Runs synchronously:
--- local obj = vim.system({'echo', 'hello'}, { text = true }):wait()
--- -- { code = 0, signal = 0, stdout = 'hello\n', stderr = '' }
---
--- ```
---
--- See |uv.spawn()| for more details. Note: unlike |uv.spawn()|, vim.system
--- throws an error if {cmd} cannot be run.
---
--- @param cmd string[] Command to execute
--- @param opts vim.SystemOpts?
--- @param on_exit? fun(out: vim.SystemCompleted) Called when subprocess exits. When provided, the command runs
---   asynchronously. See return of SystemObj:wait().
---
--- @return vim.SystemObj
--- @overload fun(cmd: string, on_exit: fun(out: vim.SystemCompleted)): vim.SystemObj
function vim.system(cmd, opts, on_exit)
  if type(opts) == 'function' then
    on_exit = opts
    opts = nil
  end
  return run(cmd, opts, on_exit)
end
