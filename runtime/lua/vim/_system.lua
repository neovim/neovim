local uv = vim.uv

--- @class SystemOpts
--- @field cmd string[]
--- @field stdin string|string[]|true
--- @field stdout fun(err:string, data: string)|false
--- @field stderr fun(err:string, data: string)|false
--- @field cwd? string
--- @field env? table<string,string|number>
--- @field clear_env? boolean
--- @field text boolean?
--- @field timeout? integer Timeout in ms
--- @field detach? boolean

--- @class SystemCompleted
--- @field code integer
--- @field signal integer
--- @field stdout? string
--- @field stderr? string

--- @class SystemState
--- @field handle uv_process_t
--- @field timer uv_timer_t
--- @field pid integer
--- @field timeout? integer
--- @field done boolean
--- @field stdin uv_stream_t?
--- @field stdout uv_stream_t?
--- @field stderr uv_stream_t?
--- @field cmd string[]
--- @field result? SystemCompleted

---@private
---@param state SystemState
local function close_handles(state)
  for _, handle in pairs({ state.handle, state.stdin, state.stdout, state.stderr }) do
    if not handle:is_closing() then
      handle:close()
    end
  end
end

--- @param cmd string[]
--- @return SystemCompleted
local function timeout_result(cmd)
  local cmd_str = table.concat(cmd, ' ')
  local err = string.format("Command timed out: '%s'", cmd_str)
  return { code = 0, signal = 2, stdout = '', stderr = err }
end

--- @class SystemObj
--- @field pid integer
--- @field private _state SystemState
--- @field wait fun(self: SystemObj, timeout?: integer): SystemCompleted
--- @field kill fun(self: SystemObj, signal: integer)
--- @field write fun(self: SystemObj, data?: string|string[])
--- @field is_closing fun(self: SystemObj): boolean?
local SystemObj = {}

--- @param state SystemState
--- @return SystemObj
local function new_systemobj(state)
  return setmetatable({
    pid = state.pid,
    _state = state,
  }, { __index = SystemObj })
end

--- @param signal integer
function SystemObj:kill(signal)
  local state = self._state
  state.handle:kill(signal)
  close_handles(state)
end

local MAX_TIMEOUT = 2 ^ 31

--- @param timeout? integer
--- @return SystemCompleted
function SystemObj:wait(timeout)
  local state = self._state

  vim.wait(timeout or state.timeout or MAX_TIMEOUT, function()
    return state.done
  end)

  if not state.done then
    self:kill(6) -- 'sigint'
    state.result = timeout_result(state.cmd)
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
  return handle == nil or handle:is_closing()
end

---@private
---@param output function|'false'
---@return uv_stream_t?
---@return function? Handler
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

---@private
---@param input string|string[]|true|nil
---@return uv_stream_t?
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
  local env = vim.fn.environ()
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

--- @param stream uv_stream_t
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

local M = {}

--- @param cmd string
--- @param opts uv.aliases.spawn_options
--- @param on_exit fun(code: integer, signal: integer)
--- @param on_error fun()
--- @return uv_process_t, integer
local function spawn(cmd, opts, on_exit, on_error)
  local handle, pid_or_err = uv.spawn(cmd, opts, on_exit)
  if not handle then
    on_error()
    error(pid_or_err)
  end
  return handle, pid_or_err --[[@as integer]]
end

--- Run a system command
---
--- @param cmd string[]
--- @param opts? SystemOpts
--- @param on_exit? fun(out: SystemCompleted)
--- @return SystemObj
function M.run(cmd, opts, on_exit)
  vim.validate({
    cmd = { cmd, 'table' },
    opts = { opts, 'table', true },
    on_exit = { on_exit, 'function', true },
  })

  opts = opts or {}

  local stdout, stdout_handler = setup_output(opts.stdout)
  local stderr, stderr_handler = setup_output(opts.stderr)
  local stdin, towrite = setup_input(opts.stdin)

  --- @type SystemState
  local state = {
    done = false,
    cmd = cmd,
    timeout = opts.timeout,
    stdin = stdin,
    stdout = stdout,
    stderr = stderr,
  }

  -- Define data buckets as tables and concatenate the elements at the end as
  -- one operation.
  --- @type string[], string[]
  local stdout_data, stderr_data

  state.handle, state.pid = spawn(cmd[1], {
    args = vim.list_slice(cmd, 2),
    stdio = { stdin, stdout, stderr },
    cwd = opts.cwd,
    env = setup_env(opts.env, opts.clear_env),
    detached = opts.detach,
    hide = true,
  }, function(code, signal)
    close_handles(state)
    if state.timer then
      state.timer:stop()
      state.timer:close()
    end

    local check = assert(uv.new_check())

    check:start(function()
      for _, pipe in pairs({ state.stdin, state.stdout, state.stderr }) do
        if not pipe:is_closing() then
          return
        end
      end
      check:stop()

      state.done = true
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
  end, function()
    close_handles(state)
  end)

  if stdout then
    stdout_data = {}
    stdout:read_start(stdout_handler or default_handler(stdout, opts.text, stdout_data))
  end

  if stderr then
    stderr_data = {}
    stderr:read_start(stderr_handler or default_handler(stderr, opts.text, stderr_data))
  end

  local obj = new_systemobj(state)

  if towrite then
    obj:write(towrite)
    obj:write(nil) -- close the stream
  end

  if opts.timeout then
    state.timer = assert(uv.new_timer())
    state.timer:start(opts.timeout, 0, function()
      state.timer:stop()
      state.timer:close()
      if state.handle and state.handle:is_active() then
        obj:kill(6) --- 'sigint'
        state.result = timeout_result(state.cmd)
        if on_exit then
          on_exit(state.result)
        end
      end
    end)
  end

  return obj
end

return M
