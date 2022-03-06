local uv = vim.loop

---@private
local function handle_input(pipe, input)
  if type(input) == 'table' then
    for _, v in ipairs(input) do
      pipe:write(v)
      pipe:write('\n')
    end
  elseif type(input) == 'string' then
    pipe:write(input)
  end

  -- Shutdown the write side of the duplex stream and then close the pipe.
  -- Note shutdown will wait for all the pending write requests to complete
  -- TODO(lewis6991): apparently shutdown doesn't behave this way.
  -- (https://github.com/neovim/neovim/pull/17620#discussion_r820775616)
  pipe:write('', function()
    pipe:shutdown(function()
      if pipe then
        pipe:close()
      end
    end)
  end)
end

---@private
local function parse_spec(spec)
  if type(spec) == 'string' then
    spec = vim.split(spec, '%s')
  end

  return {
    command = spec[1],
    args = {select(2, unpack(spec))}
  }
end

---@private
local function handle_output(pipe, output)
  pipe:read_start(function(err, data)
    if err then error(err) end
    output[#output+1] = data
  end)
end

---@private
local function close_pipe(pipe)
  if pipe then
    pipe:read_stop()
    if not pipe:is_closing() then
      pipe:close()
    end
  end
end

--- Run a subprocess
---
--- Convenience wrapper for vim.loop.spawn with automatic IO handling.
---
--- Examples:
--- <pre>
---
---   local on_exit = function(code, signal, stdout, stderr)
---     print(code)
---     print(signal)
---     print(stdout)
---     print(stderr)
---   end
---
---   vim.subprocess('echo hello', on_exit)
---   vim.subprocess({'echo', 'hello'}, on_exit)
---   vim.subprocess({command = 'echo', args = {'hello'}}, on_exit)
---
--- </pre>
---
--- @param spec table   When passed as a string or a string array, the argument is interpreted
---                     as a command.
---
---                     When passed as a keyed table, accepts all options as vim.loop.spawn in
---                     addition to:
---                     - command: (string) command to execute
---                     - input: (string|string array) cannot be used with stdin
---                     - stdin: (uv_pipe_t) cannot be used with input
---                     - stdout: (uv_pipe_t)
---                     - stderr: (uv_pipe_t)
---
--- @param on_exit function  Called when subprocess exits. Has the following arguments:
---                          - code: (integer)
---                          - signal: (integer)
---                          - stdout: (string), nil if stdout argument is passed
---                          - stderr: (string), nil if stderr argument is passed
---
---  @returns process handle (uv_process_t userdata), PID (integer)
local function subprocess(spec, on_exit)
  vim.validate {
    spec = { spec, { 'table', 'string' }},
    on_exit = { on_exit, 'function' },
  }

  if spec.stdin and spec.input then
    error('stdin cannot be used with input')
  end

  if not spec.command then
    -- Assume spec is raw command as string or array
    spec = parse_spec(spec)
  end

  local stdout = spec.stdout or uv.new_pipe(false)
  local stderr = spec.stderr or uv.new_pipe(false)
  local stdin

  if not spec.stdin and spec.input then
    stdin = uv.new_pipe(false)
  end

  -- Define data buckets as tables and concatenate the elements at the end as one operation.
  local stdout_data, stderr_data

  local spec0 = vim.deepcopy(spec)

  -- Remove non luv.spawn arguments
  for _, s in ipairs{'input', 'command', 'stdout', 'stderr', 'stdin'} do
    spec0[s] = nil
  end

  spec0.stdio = { stdin, stdout, stderr }

  local handle, pid = uv.spawn(spec.command, spec0,
    function(code, signal)
      close_pipe(stdin)
      close_pipe(stdout)
      close_pipe(stderr)

      on_exit(
        code, signal,
        stdout_data and stdout_data[1] and table.concat(stdout_data) or nil,
        stderr_data and stderr_data[1] and table.concat(stderr_data) or nil
      )
    end
  )

  if not handle then
    close_pipe(stdin)
    close_pipe(stdout)
    close_pipe(stderr)
  end

  if not spec.stdout then
    stdout_data = {}
    handle_output(stdout, stdout_data)
  end

  if not spec.stderr then
    stderr_data = {}
    handle_output(stderr, stderr_data)
  end

  if not spec.stdin and spec.input then
    handle_input(stdin, spec.input)
  end

  return handle, pid
end

return subprocess
