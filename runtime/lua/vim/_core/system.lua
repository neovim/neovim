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
---
--- Spawn a terminal
--- @field term? boolean
---
--- @field width? integer
--- @field height? integer

--- @class vim.SystemCompleted
--- @field code integer
--- @field signal integer
--- @field stdout? string `nil` if stdout is disabled or has a custom handler.
--- @field stderr? string `nil` if stderr is disabled or has a custom handler.

--- @enum vim.SystemSig
local SIG = {
  HUP = 1, -- Hangup
  INT = 2, -- Interrupt from keyboard
  KILL = 9, -- Kill signal
  TERM = 15, -- Termination signal
  -- STOP = 17,19,23  -- Stop the process
}

--- @class (package) vim.SystemState
--- @field cmd string[]
--- @field timer?  uv.uv_timer_t
--- @field pid? integer
--- @field job_id integer
--- @field timeout? integer
--- @field done? boolean|'timeout'
--- @field stdout_data? string[]
--- @field stderr_data? string[]
--- @field result? vim.SystemCompleted

---@param handle uv.uv_handle_t?
local function close_handle(handle)
  if handle and not handle:is_closing() then
    handle:close()
  end
end

--- @class vim.SystemObj
--- @field cmd string[] Command name and args
--- @field pid integer Process ID
--- @field job_id integer Job ID
--- @field private _state vim.SystemState
local SystemObj = {}

--- @param state vim.SystemState
--- @return vim.SystemObj
local function new_systemobj(state)
  return setmetatable({
    cmd = state.cmd,
    job_id = state.job_id,
    pid = state.pid,
    _state = state,
  }, { __index = SystemObj })
end

--- kills the job.
---
--- Example:
--- ```lua
--- local obj = vim.system({'sleep', '10'})
--- obj:kill()
--- ```
---
function SystemObj:kill()
  local job_id = self._state.job_id --- @type integer

  if self._state.done ~= true then
    vim.fn.jobstop(job_id)
  end
end

--- @package
function SystemObj:_timeout()
  self._state.done = 'timeout'
  self:kill()
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
  local is_timeout = (
    vim.fn.jobwait({ state.job_id }, timeout or state.timeout or vim._maxint)[1] == -1
  ) --- @type boolean

  if is_timeout then
    self:_timeout()
    vim.fn.jobwait({ state.job_id }, timeout or state.timeout or vim._maxint)
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
  local state = self._state
  local job_id = state.job_id
  local stdin = state.stdin

  if stdin == false or stdin == nil then
    error('stdin has not been opened on this object')
  end

  if type(data) == 'table' then
    for _, v in ipairs(data) do
      vim.fn.chansend(job_id, v .. '\n')
    end
  elseif type(data) == 'string' then
    vim.fn.chansend(job_id, data)
  elseif data == nil then
    vim.fn.chanclose(job_id, 'stdin')
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
  return handle == nil or (vim.fn.jobwait({ self._state.job_id }, 0)[1] ~= -1) or false
end

local is_win = vim.fn.has('win32') == 1

--- @param timeout integer
--- @param cb fun()
--- @return uv.uv_timer_t
local function timer_oneshot(timeout, cb)
  local timer = assert(uv.new_timer())
  timer:start(timeout, 0, function()
    timer:stop()
    timer:close()
    vim.schedule(cb)
  end)

  return timer
end

--- @param data string[] Raw line array from jobstart
--- @param text boolean Whether to normalize line endings
--- @return string
local function sanitize_data(data, text)
  local sanitized = ''
  local eof = (data == { '' })

  if eof then
    return ''
  end

  for i, line in ipairs(data) do
    if text then
      --- @type string
      line = line:gsub('\r$', '')
    end

    if not (i == #data and line == '') then
      sanitized = sanitized .. line .. '\n'
    end

    if i == #data and line ~= '' then
      sanitized = string.sub(sanitized, 1, -2)
    end
  end

  return sanitized
end

--- @param cmd string[]
--- @param opts vim.SystemOpts
--- @param on_exit fun(job_id:integer, signal:integer, event_type:string)
--- @param on_error fun(chan_id: integer, data: string[], name: string)
--- @param on_output fun(chan_id: integer, data: string[], name: string)
--- @return  integer
local function spawn(cmd, opts, on_exit, on_error, on_output)
  if is_win then
    local cmd1 = vim.fn.exepath(cmd[1])
    if cmd1 ~= '' then
      cmd[1] = cmd1
    end
  end

  local stdin = 'pipe'

  if not opts.stdin then -- means its not false | nil
    stdin = 'pipe'
  end

  local job_opts = {
    cwd = opts.cwd,
    env = opts.env,
    clear_env = opts.clear_env,
    stdin = stdin,
    detach = opts.detach,
    term = opts.term,
    width = opts.width,
    height = opts.height,

    stdout_buffered = (type(opts.stdout) ~= 'function'),
    stderr_buffered = (type(opts.stderr) ~= 'function'),

    on_stdout = on_output,

    on_stderr = on_error,
    on_exit = on_exit,
  }

  if opts.clear_env and job_opts.env == nil then
    job_opts.clear_env = false
  end

  if job_opts.env and vim.tbl_isempty(job_opts.env) then
    job_opts.env = nil
  end

  if opts.cwd and not uv.fs_stat(opts.cwd) then
    error(("ENOENT: no such file or directory (cwd): '%s'"):format(opts.cwd))
  end
  if vim.fn.executable(cmd[1]) == 0 then
    error(("ENOENT: no such file or directory (cmd): '%s'"):format(cmd[1]))
  end

  local job_id = vim.fn.jobstart(cmd, job_opts)
  if job_id <= 0 then
    error('job failed to start')
  end

  return job_id
end

--- @param state vim.SystemState
--- @param exit_code integer
local function _on_exit(state, exit_code)
  close_handle(state.timer)

  local signal = 0 --- @type integer

  if exit_code > 128 and exit_code <= 255 then
    signal = (exit_code - 128)
    exit_code = 0
  end

  if state.done == 'timeout' then
    exit_code = 124
    signal = 15 -- SIGTERM
  end

  state.result = {
    code = exit_code,
    signal = signal,
    stdout = state.stdout_data and table.concat(state.stdout_data) or nil,
    stderr = state.stderr_data and table.concat(state.stderr_data) or nil,
  }
  state.done = true
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

  local stdout_data = opts.stdout ~= false and {} or nil
  local stderr_data = opts.stdout ~= false and {} or nil

  local state = {
    done = false,
    cmd = cmd,
    stdin = opts.stdin,
    timeout = opts.timeout,
    stdout_data = stdout_data,
    stderr_data = stderr_data,
  }

  state.job_id = spawn(cmd, opts, function(_, exit_code, _)
    _on_exit(state, exit_code)
    if on_exit ~= nil then
      on_exit(state.result)
    end
  end, function(_, data)
    if stderr_data and data then
      local processed_lines = sanitize_data(data, opts.text)

      if processed_lines ~= '' then
        if type(opts.stderr) == 'function' then
          opts.stderr(nil, processed_lines)
        else
          table.insert(stderr_data, processed_lines)
        end
      end
    end
  end, function(_, data)
    if stdout_data and data then
      local processed_lines = sanitize_data(data, opts.text)

      if processed_lines ~= '' then
        if type(opts.stdout) == 'function' then
          opts.stdout(nil, processed_lines)
        else
          table.insert(stdout_data, processed_lines)
        end
      end
    end
  end)
  state.pid = vim.fn.jobpid(state.job_id)

  local obj = new_systemobj(state)

  if opts.stdin ~= nil and type(opts.stdin) ~= 'boolean' then
    local data = opts.stdin
    ---@cast data string|string[]
    obj:write(data)
    obj:write(nil)
  end

  if opts.timeout ~= 0 and opts.timeout ~= nil then
    state.timer = timer_oneshot(opts.timeout, function()
      if not state.done then
        obj:_timeout()
      end
    end)
  end

  return obj
end

--- Runs a system command or throws an error if {cmd} cannot be run.
---
--- The command runs directly (not in 'shell') so shell builtins such as "echo" in cmd.exe, cmdlets
--- in powershell, or "help" in bash, will not work unless you actually invoke a shell:
--- `vim.system({'bash', '-c', 'help'})`.
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
--- @overload fun(cmd: string[], on_exit: fun(out: vim.SystemCompleted)): vim.SystemObj
function vim.system(cmd, opts, on_exit)
  if type(opts) == 'function' then
    on_exit = opts
    opts = nil
  end

  return run(cmd, opts, on_exit)
end
