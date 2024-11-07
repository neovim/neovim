local uv = vim.uv

--- @class vim.SystemOpts
--- @field stdin? string|string[]|true
--- @field stdout? fun(err:string?, data: string?)|false
--- @field stderr? fun(err:string?, data: string?)|false
--- @field cwd? string
--- @field env? table<string,string|number>
--- @field clear_env? boolean
--- @field text? boolean
--- @field timeout? integer Timeout in ms
--- @field detach? boolean

--- @class vim.SystemCompleted
--- @field code integer
--- @field signal integer
--- @field stdout? string
--- @field stderr? string

--- @class vim.SystemState
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

---@param state vim.SystemState
local function close_handles(state)
  close_handle(state.handle)
  close_handle(state.stdin)
  close_handle(state.stdout)
  close_handle(state.stderr)
  close_handle(state.timer)
end

--- @class vim.SystemObj
--- @field cmd string[]
--- @field pid integer
--- @field private _state vim.SystemState
--- @field wait fun(self: vim.SystemObj, timeout?: integer): vim.SystemCompleted
--- @field kill fun(self: vim.SystemObj, signal: integer|string)
--- @field write fun(self: vim.SystemObj, data?: string|string[])
--- @field is_closing fun(self: vim.SystemObj): boolean
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

--- @param signal integer|string
function SystemObj:kill(signal)
  self._state.handle:kill(signal)
end

--- @package
--- @param signal? vim.SystemSig
function SystemObj:_timeout(signal)
  self._state.done = 'timeout'
  self:kill(signal or SIG.TERM)
end

local MAX_TIMEOUT = 2 ^ 31

--- @param timeout? integer
--- @return vim.SystemCompleted
function SystemObj:wait(timeout)
  local state = self._state

  local done = vim.wait(timeout or state.timeout or MAX_TIMEOUT, function()
    return state.result ~= nil
  end, nil, true)

  if not done then
    -- Send sigkill since this cannot be caught
    self:_timeout(SIG.KILL)
    vim.wait(timeout or state.timeout or MAX_TIMEOUT, function()
      return state.result ~= nil
    end, nil, true)
  end

  return state.result
end

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
        if stdin then
          stdin:close()
        end
      end)
    end)
  end
end

--- @return boolean
function SystemObj:is_closing()
  local handle = self._state.handle
  return handle == nil or handle:is_closing() or false
end

---@param output fun(err:string?, data: string?)|false
---@return uv.uv_stream_t?
---@return fun(err:string?, data: string?)? Handler
local function setup_output(output)
  if output == nil then
    return assert(uv.new_pipe(false)), nil
  end

  if type(output) == 'function' then
    return assert(uv.new_pipe(false)), output
  end

  assert(output == false)
  return nil, nil
end

---@param input string|string[]|true|nil
---@return uv.uv_stream_t?
---@return string|string[]?
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
  if clear_env then
    return env
  end

  --- @type table<string,string|number>
  env = vim.tbl_extend('force', base_env(), env or {})

  local renv = {} --- @type string[]
  for k, v in pairs(env) do
    renv[#renv + 1] = string.format('%s=%s', k, tostring(v))
  end

  return renv
end

--- @param stream uv.uv_stream_t
--- @param text? boolean
--- @param bucket string[]
--- @return fun(err: string?, data: string?)
local function default_handler(stream, text, bucket)
  return function(err, data)
    if err then
      error(err)
    end
    if data ~= nil then
      if text then
        bucket[#bucket + 1] = data:gsub('\r\n', '\n')
      else
        bucket[#bucket + 1] = data
      end
    else
      stream:read_stop()
      stream:close()
    end
  end
end

local is_win = vim.fn.has('win32') == 1

local M = {}

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
    error(pid_or_err)
  end
  return handle, pid_or_err --[[@as integer]]
end

---@param timeout integer
---@param cb fun()
---@return uv.uv_timer_t
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
  close_handles(state)

  local check = assert(uv.new_check())
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

--- Run a system command
---
--- @param cmd string[]
--- @param opts? vim.SystemOpts
--- @param on_exit? fun(out: vim.SystemCompleted)
--- @return vim.SystemObj
function M.run(cmd, opts, on_exit)
  vim.validate('cmd', cmd, 'table')
  vim.validate('opts', opts, 'table', true)
  vim.validate('on_exit', on_exit, 'function', true)

  opts = opts or {}

  local stdout, stdout_handler = setup_output(opts.stdout)
  local stderr, stderr_handler = setup_output(opts.stderr)
  local stdin, towrite = setup_input(opts.stdin)

  --- @type vim.SystemState
  local state = {
    done = false,
    cmd = cmd,
    timeout = opts.timeout,
    stdin = stdin,
    stdout = stdout,
    stderr = stderr,
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
    close_handles(state)
  end)

  if stdout then
    state.stdout_data = {}
    stdout:read_start(stdout_handler or default_handler(stdout, opts.text, state.stdout_data))
  end

  if stderr then
    state.stderr_data = {}
    stderr:read_start(stderr_handler or default_handler(stderr, opts.text, state.stderr_data))
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

return M
