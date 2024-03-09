-- Nvim-Lua stdlib: the `vim` module (:help lua-stdlib)
--
-- Lua code lives in one of three places:
--    1. runtime/lua/vim/ (the runtime): For "nice to have" features, e.g. the
--       `inspect` and `lpeg` modules.
--    2. runtime/lua/vim/shared.lua: pure Lua functions which always
--       are available. Used in the test runner, as well as worker threads
--       and processes launched from Nvim.
--    3. runtime/lua/vim/_editor.lua: Code which directly interacts with
--       the Nvim editor state. Only available in the main thread.
--
-- Guideline: "If in doubt, put it in the runtime".
--
-- Most functions should live directly in `vim.`, not in submodules.
--
-- Compatibility with Vim's `if_lua` is explicitly a non-goal.
--
-- Reference (#6580):
--    - https://github.com/luafun/luafun
--    - https://github.com/rxi/lume
--    - http://leafo.net/lapis/reference/utilities.html
--    - https://github.com/torch/paths
--    - https://github.com/bakpakin/Fennel (pretty print, repl)
--    - https://github.com/howl-editor/howl/tree/master/lib/howl/util

-- These are for loading runtime modules lazily since they aren't available in
-- the nvim binary as specified in executor.c
for k, v in pairs({
  treesitter = true,
  filetype = true,
  loader = true,
  func = true,
  F = true,
  lsp = true,
  highlight = true,
  diagnostic = true,
  keymap = true,
  ui = true,
  health = true,
  secure = true,
  snippet = true,
  _watch = true,
}) do
  vim._submodules[k] = v
end

-- There are things which have special rules in vim._init_packages
-- for legacy reasons (uri) or for performance (_inspector).
-- most new things should go into a submodule namespace ( vim.foobar.do_thing() )
vim._extra = {
  uri_from_fname = true,
  uri_from_bufnr = true,
  uri_to_fname = true,
  uri_to_bufnr = true,
  show_pos = true,
  inspect_pos = true,
}

--- @private
vim.log = {
  levels = {
    TRACE = 0,
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    OFF = 5,
  },
}

-- TODO(lewis6991): document that the signature is system({cmd}, [{opts},] {on_exit})
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
--- -- { code = 0, signal = 0, stdout = 'hello', stderr = '' }
---
--- ```
---
--- See |uv.spawn()| for more details. Note: unlike |uv.spawn()|, vim.system
--- throws an error if {cmd} cannot be run.
---
--- @param cmd (string[]) Command to execute
--- @param opts vim.SystemOpts? Options:
---   - cwd: (string) Set the current working directory for the sub-process.
---   - env: table<string,string> Set environment variables for the new process. Inherits the
---     current environment with `NVIM` set to |v:servername|.
---   - clear_env: (boolean) `env` defines the job environment exactly, instead of merging current
---     environment.
---   - stdin: (string|string[]|boolean) If `true`, then a pipe to stdin is opened and can be written
---     to via the `write()` method to SystemObj. If string or string[] then will be written to stdin
---     and closed. Defaults to `false`.
---   - stdout: (boolean|function)
---     Handle output from stdout. When passed as a function must have the signature `fun(err: string, data: string)`.
---     Defaults to `true`
---   - stderr: (boolean|function)
---     Handle output from stderr. When passed as a function must have the signature `fun(err: string, data: string)`.
---     Defaults to `true`.
---   - text: (boolean) Handle stdout and stderr as text. Replaces `\r\n` with `\n`.
---   - timeout: (integer) Run the command with a time limit. Upon timeout the process is sent the
---     TERM signal (15) and the exit code is set to 124.
---   - detach: (boolean) If true, spawn the child process in a detached state - this will make it
---     a process group leader, and will effectively enable the child to keep running after the
---     parent exits. Note that the child process will still keep the parent's event loop alive
---     unless the parent process calls |uv.unref()| on the child's process handle.
---
--- @param on_exit? fun(out: vim.SystemCompleted) Called when subprocess exits. When provided, the command runs
---   asynchronously. Receives SystemCompleted object, see return of SystemObj:wait().
---
--- @return vim.SystemObj Object with the fields:
---   - pid (integer) Process ID
---   - wait (fun(timeout: integer|nil): SystemCompleted) Wait for the process to complete. Upon
---     timeout the process is sent the KILL signal (9) and the exit code is set to 124. Cannot
---     be called in |api-fast|.
---     - SystemCompleted is an object with the fields:
---       - code: (integer)
---       - signal: (integer)
---       - stdout: (string), nil if stdout argument is passed
---       - stderr: (string), nil if stderr argument is passed
---   - kill (fun(signal: integer|string))
---   - write (fun(data: string|nil)) Requires `stdin=true`. Pass `nil` to close the stream.
---   - is_closing (fun(): boolean)
function vim.system(cmd, opts, on_exit)
  if type(opts) == 'function' then
    on_exit = opts
    opts = nil
  end
  return require('vim._system').run(cmd, opts, on_exit)
end

-- Gets process info from the `ps` command.
-- Used by nvim_get_proc() as a fallback.
function vim._os_proc_info(pid)
  if pid == nil or pid <= 0 or type(pid) ~= 'number' then
    error('invalid pid')
  end
  local cmd = { 'ps', '-p', pid, '-o', 'comm=' }
  local r = vim.system(cmd):wait()
  local name = assert(r.stdout)
  if r.code == 1 and vim.trim(name) == '' then
    return {} -- Process not found.
  elseif r.code ~= 0 then
    error('command failed: ' .. vim.fn.string(cmd))
  end
  local ppid_string = assert(vim.system({ 'ps', '-p', pid, '-o', 'ppid=' }):wait().stdout)
  -- Remove trailing whitespace.
  name = vim.trim(name):gsub('^.*/', '')
  local ppid = tonumber(ppid_string) or -1
  return {
    name = name,
    pid = pid,
    ppid = ppid,
  }
end

-- Gets process children from the `pgrep` command.
-- Used by nvim_get_proc_children() as a fallback.
function vim._os_proc_children(ppid)
  if ppid == nil or ppid <= 0 or type(ppid) ~= 'number' then
    error('invalid ppid')
  end
  local cmd = { 'pgrep', '-P', ppid }
  local r = vim.system(cmd):wait()
  if r.code == 1 and vim.trim(r.stdout) == '' then
    return {} -- Process not found.
  elseif r.code ~= 0 then
    error('command failed: ' .. vim.fn.string(cmd))
  end
  local children = {}
  for s in r.stdout:gmatch('%S+') do
    local i = tonumber(s)
    if i ~= nil then
      table.insert(children, i)
    end
  end
  return children
end

--- @nodoc
--- @class vim.inspect.Opts
--- @field depth? integer
--- @field newline? string
--- @field process? fun(item:any, path: string[]): any

--- Gets a human-readable representation of the given object.
---
---@see |vim.print()|
---@see https://github.com/kikito/inspect.lua
---@see https://github.com/mpeterv/vinspect
---@return string
---@overload fun(x: any, opts?: vim.inspect.Opts): string
vim.inspect = vim.inspect

do
  local tdots, tick, got_line1, undo_started, trailing_nl = 0, 0, false, false, false

  --- Paste handler, invoked by |nvim_paste()| when a conforming UI
  --- (such as the |TUI|) pastes text into the editor.
  ---
  --- Example: To remove ANSI color codes when pasting:
  ---
  --- ```lua
  --- vim.paste = (function(overridden)
  ---   return function(lines, phase)
  ---     for i,line in ipairs(lines) do
  ---       -- Scrub ANSI color codes from paste input.
  ---       lines[i] = line:gsub('\27%[[0-9;mK]+', '')
  ---     end
  ---     overridden(lines, phase)
  ---   end
  --- end)(vim.paste)
  --- ```
  ---
  ---@see |paste|
  ---
  ---@param lines  string[] # |readfile()|-style list of lines to paste. |channel-lines|
  ---@param phase (-1|1|2|3)  -1: "non-streaming" paste: the call contains all lines.
  ---              If paste is "streamed", `phase` indicates the stream state:
  ---                - 1: starts the paste (exactly once)
  ---                - 2: continues the paste (zero or more times)
  ---                - 3: ends the paste (exactly once)
  ---@return boolean result false if client should cancel the paste.
  function vim.paste(lines, phase)
    local now = vim.uv.now()
    local is_first_chunk = phase < 2
    local is_last_chunk = phase == -1 or phase == 3
    if is_first_chunk then -- Reset flags.
      tdots, tick, got_line1, undo_started, trailing_nl = now, 0, false, false, false
    end
    if #lines == 0 then
      lines = { '' }
    end
    if #lines == 1 and lines[1] == '' and not is_last_chunk then
      -- An empty chunk can cause some edge cases in streamed pasting,
      -- so don't do anything unless it is the last chunk.
      return true
    end
    -- Note: mode doesn't always start with "c" in cmdline mode, so use getcmdtype() instead.
    if vim.fn.getcmdtype() ~= '' then -- cmdline-mode: paste only 1 line.
      if not got_line1 then
        got_line1 = (#lines > 1)
        -- Escape control characters
        local line1 = lines[1]:gsub('(%c)', '\022%1')
        -- nvim_input() is affected by mappings,
        -- so use nvim_feedkeys() with "n" flag to ignore mappings.
        -- "t" flag is also needed so the pasted text is saved in cmdline history.
        vim.api.nvim_feedkeys(line1, 'nt', true)
      end
      return true
    end
    local mode = vim.api.nvim_get_mode().mode
    if undo_started then
      vim.api.nvim_command('undojoin')
    end
    if mode:find('^i') or mode:find('^n?t') then -- Insert mode or Terminal buffer
      vim.api.nvim_put(lines, 'c', false, true)
    elseif phase < 2 and mode:find('^R') and not mode:find('^Rv') then -- Replace mode
      -- TODO: implement Replace mode streamed pasting
      -- TODO: support Virtual Replace mode
      local nchars = 0
      for _, line in ipairs(lines) do
        nchars = nchars + line:len()
      end
      --- @type integer, integer
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local bufline = vim.api.nvim_buf_get_lines(0, row - 1, row, true)[1]
      local firstline = lines[1]
      firstline = bufline:sub(1, col) .. firstline
      lines[1] = firstline
      lines[#lines] = lines[#lines] .. bufline:sub(col + nchars + 1, bufline:len())
      vim.api.nvim_buf_set_lines(0, row - 1, row, false, lines)
    elseif mode:find('^[nvV\22sS\19]') then -- Normal or Visual or Select mode
      if mode:find('^n') then -- Normal mode
        -- When there was a trailing new line in the previous chunk,
        -- the cursor is on the first character of the next line,
        -- so paste before the cursor instead of after it.
        vim.api.nvim_put(lines, 'c', not trailing_nl, false)
      else -- Visual or Select mode
        vim.api.nvim_command([[exe "silent normal! \<Del>"]])
        local del_start = vim.fn.getpos("'[")
        local cursor_pos = vim.fn.getpos('.')
        if mode:find('^[VS]') then -- linewise
          if cursor_pos[2] < del_start[2] then -- replacing lines at eof
            -- create a new line
            vim.api.nvim_put({ '' }, 'l', true, true)
          end
          vim.api.nvim_put(lines, 'c', false, false)
        else
          -- paste after cursor when replacing text at eol, otherwise paste before cursor
          vim.api.nvim_put(lines, 'c', cursor_pos[3] < del_start[3], false)
        end
      end
      -- put cursor at the end of the text instead of one character after it
      vim.fn.setpos('.', vim.fn.getpos("']"))
      trailing_nl = lines[#lines] == ''
    else -- Don't know what to do in other modes
      return false
    end
    undo_started = true
    if phase ~= -1 and (now - tdots >= 100) then
      local dots = ('.'):rep(tick % 4)
      tdots = now
      tick = tick + 1
      -- Use :echo because Lua print('') is a no-op, and we want to clear the
      -- message when there are zero dots.
      vim.api.nvim_command(('echo "%s"'):format(dots))
    end
    if is_last_chunk then
      vim.api.nvim_command('redraw' .. (tick > 1 and '|echo ""' or ''))
    end
    return true -- Paste will not continue if not returning `true`.
  end
end

--- Returns a function which calls {fn} via |vim.schedule()|.
---
--- The returned function passes all arguments to {fn}.
---
--- Example:
---
--- ```lua
--- function notify_readable(_err, readable)
---   vim.notify("readable? " .. tostring(readable))
--- end
--- vim.uv.fs_access(vim.fn.stdpath("config"), "R", vim.schedule_wrap(notify_readable))
--- ```
---
---@see |lua-loop-callbacks|
---@see |vim.schedule()|
---@see |vim.in_fast_event()|
---@param fn function
---@return function
function vim.schedule_wrap(fn)
  return function(...)
    local args = vim.F.pack_len(...)
    vim.schedule(function()
      fn(vim.F.unpack_len(args))
    end)
  end
end

-- vim.fn.{func}(...)
---@nodoc
vim.fn = setmetatable({}, {
  --- @param t table<string,function>
  --- @param key string
  --- @return function
  __index = function(t, key)
    local _fn --- @type function
    if vim.api[key] ~= nil then
      _fn = function()
        error(string.format('Tried to call API function with vim.fn: use vim.api.%s instead', key))
      end
    else
      _fn = function(...)
        return vim.call(key, ...)
      end
    end
    t[key] = _fn
    return _fn
  end,
})

--- @private
vim.funcref = function(viml_func_name)
  return vim.fn[viml_func_name]
end

local VIM_CMD_ARG_MAX = 20

--- Executes Vim script commands.
---
--- Note that `vim.cmd` can be indexed with a command name to return a callable function to the
--- command.
---
--- Example:
---
--- ```lua
--- vim.cmd('echo 42')
--- vim.cmd([[
---   augroup My_group
---     autocmd!
---     autocmd FileType c setlocal cindent
---   augroup END
--- ]])
---
--- -- Ex command :echo "foo"
--- -- Note string literals need to be double quoted.
--- vim.cmd('echo "foo"')
--- vim.cmd { cmd = 'echo', args = { '"foo"' } }
--- vim.cmd.echo({ args = { '"foo"' } })
--- vim.cmd.echo('"foo"')
---
--- -- Ex command :write! myfile.txt
--- vim.cmd('write! myfile.txt')
--- vim.cmd { cmd = 'write', args = { "myfile.txt" }, bang = true }
--- vim.cmd.write { args = { "myfile.txt" }, bang = true }
--- vim.cmd.write { "myfile.txt", bang = true }
---
--- -- Ex command :colorscheme blue
--- vim.cmd('colorscheme blue')
--- vim.cmd.colorscheme('blue')
--- ```
---
---@param command string|table Command(s) to execute.
---                            If a string, executes multiple lines of Vim script at once. In this
---                            case, it is an alias to |nvim_exec2()|, where `opts.output` is set
---                            to false. Thus it works identical to |:source|.
---                            If a table, executes a single command. In this case, it is an alias
---                            to |nvim_cmd()| where `opts` is empty.
---@see |ex-cmd-index|
vim.cmd = setmetatable({}, {
  __call = function(_, command)
    if type(command) == 'table' then
      return vim.api.nvim_cmd(command, {})
    else
      vim.api.nvim_exec2(command, {})
      return ''
    end
  end,
  __index = function(t, command)
    t[command] = function(...)
      local opts
      if select('#', ...) == 1 and type(select(1, ...)) == 'table' then
        opts = select(1, ...)

        -- Move indexed positions in opts to opt.args
        if opts[1] and not opts.args then
          opts.args = {}
          for i = 1, VIM_CMD_ARG_MAX do
            if not opts[i] then
              break
            end
            opts.args[i] = opts[i]
            opts[i] = nil
          end
        end
      else
        opts = { args = { ... } }
      end
      opts.cmd = command
      return vim.api.nvim_cmd(opts, {})
    end
    return t[command]
  end,
})

--- @class (private) vim.var_accessor
--- @field [string] any
--- @field [integer] vim.var_accessor

-- These are the vim.env/v/g/o/bo/wo variable magic accessors.
do
  local validate = vim.validate

  --- @param scope string
  --- @param handle? false|integer
  --- @return vim.var_accessor
  local function make_dict_accessor(scope, handle)
    validate({
      scope = { scope, 's' },
    })
    local mt = {}
    function mt:__newindex(k, v)
      return vim._setvar(scope, handle or 0, k, v)
    end
    function mt:__index(k)
      if handle == nil and type(k) == 'number' then
        return make_dict_accessor(scope, k)
      end
      return vim._getvar(scope, handle or 0, k)
    end
    return setmetatable({}, mt)
  end

  vim.g = make_dict_accessor('g', false)
  vim.v = make_dict_accessor('v', false) --[[@as vim.v]]
  vim.b = make_dict_accessor('b')
  vim.w = make_dict_accessor('w')
  vim.t = make_dict_accessor('t')
end

--- Gets a dict of line segment ("chunk") positions for the region from `pos1` to `pos2`.
---
--- Input and output positions are byte positions, (0,0)-indexed. "End of line" column
--- position (for example, |linewise| visual selection) is returned as |v:maxcol| (big number).
---
---@param bufnr integer Buffer number, or 0 for current buffer
---@param pos1 integer[]|string Start of region as a (line, column) tuple or |getpos()|-compatible string
---@param pos2 integer[]|string End of region as a (line, column) tuple or |getpos()|-compatible string
---@param regtype string [setreg()]-style selection type
---@param inclusive boolean Controls whether the ending column is inclusive (see also 'selection').
---@return table region Dict of the form `{linenr = {startcol,endcol}}`. `endcol` is exclusive, and
---whole lines are returned as `{startcol,endcol} = {0,-1}`.
function vim.region(bufnr, pos1, pos2, regtype, inclusive)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end

  if type(pos1) == 'string' then
    local pos = vim.fn.getpos(pos1)
    pos1 = { pos[2] - 1, pos[3] - 1 }
  end
  if type(pos2) == 'string' then
    local pos = vim.fn.getpos(pos2)
    pos2 = { pos[2] - 1, pos[3] - 1 }
  end

  if pos1[1] > pos2[1] or (pos1[1] == pos2[1] and pos1[2] > pos2[2]) then
    pos1, pos2 = pos2, pos1
  end

  -- getpos() may return {0,0,0,0}
  if pos1[1] < 0 or pos1[2] < 0 then
    return {}
  end

  -- check that region falls within current buffer
  local buf_line_count = vim.api.nvim_buf_line_count(bufnr)
  pos1[1] = math.min(pos1[1], buf_line_count - 1)
  pos2[1] = math.min(pos2[1], buf_line_count - 1)

  -- in case of block selection, columns need to be adjusted for non-ASCII characters
  -- TODO: handle double-width characters
  if regtype:byte() == 22 then
    local bufline = vim.api.nvim_buf_get_lines(bufnr, pos1[1], pos1[1] + 1, true)[1]
    pos1[2] = vim.str_utfindex(bufline, pos1[2])
  end

  local region = {}
  for l = pos1[1], pos2[1] do
    local c1 --- @type number
    local c2 --- @type number
    if regtype:byte() == 22 then -- block selection: take width from regtype
      c1 = pos1[2]
      c2 = c1 + tonumber(regtype:sub(2))
      -- and adjust for non-ASCII characters
      local bufline = vim.api.nvim_buf_get_lines(bufnr, l, l + 1, true)[1]
      local utflen = vim.str_utfindex(bufline, #bufline)
      if c1 <= utflen then
        c1 = assert(tonumber(vim.str_byteindex(bufline, c1)))
      else
        c1 = #bufline + 1
      end
      if c2 <= utflen then
        c2 = assert(tonumber(vim.str_byteindex(bufline, c2)))
      else
        c2 = #bufline + 1
      end
    elseif regtype == 'V' then -- linewise selection, always return whole line
      c1 = 0
      c2 = -1
    else
      c1 = (l == pos1[1]) and pos1[2] or 0
      if inclusive and l == pos2[1] then
        local bufline = vim.api.nvim_buf_get_lines(bufnr, pos2[1], pos2[1] + 1, true)[1]
        pos2[2] = vim.fn.byteidx(bufline, vim.fn.charidx(bufline, pos2[2]) + 1)
      end
      c2 = (l == pos2[1]) and pos2[2] or -1
    end
    table.insert(region, l, { c1, c2 })
  end
  return region
end

--- Defers calling {fn} until {timeout} ms passes.
---
--- Use to do a one-shot timer that calls {fn}
--- Note: The {fn} is |vim.schedule_wrap()|ped automatically, so API functions are
--- safe to call.
---@param fn function Callback to call once `timeout` expires
---@param timeout integer Number of milliseconds to wait before calling `fn`
---@return table timer luv timer object
function vim.defer_fn(fn, timeout)
  vim.validate({ fn = { fn, 'c', true } })
  local timer = assert(vim.uv.new_timer())
  timer:start(
    timeout,
    0,
    vim.schedule_wrap(function()
      if not timer:is_closing() then
        timer:close()
      end

      fn()
    end)
  )

  return timer
end

--- Displays a notification to the user.
---
--- This function can be overridden by plugins to display notifications using a
--- custom provider (such as the system notification provider). By default,
--- writes to |:messages|.
---
---@param msg string Content of the notification to show to the user.
---@param level integer|nil One of the values from |vim.log.levels|.
---@param opts table|nil Optional parameters. Unused by default.
---@diagnostic disable-next-line: unused-local
function vim.notify(msg, level, opts) -- luacheck: no unused args
  if level == vim.log.levels.ERROR then
    vim.api.nvim_err_writeln(msg)
  elseif level == vim.log.levels.WARN then
    vim.api.nvim_echo({ { msg, 'WarningMsg' } }, true, {})
  else
    vim.api.nvim_echo({ { msg } }, true, {})
  end
end

do
  local notified = {} --- @type table<string,true>

  --- Displays a notification only one time.
  ---
  --- Like |vim.notify()|, but subsequent calls with the same message will not
  --- display a notification.
  ---
  ---@param msg string Content of the notification to show to the user.
  ---@param level integer|nil One of the values from |vim.log.levels|.
  ---@param opts table|nil Optional parameters. Unused by default.
  ---@return boolean true if message was displayed, else false
  function vim.notify_once(msg, level, opts)
    if not notified[msg] then
      vim.notify(msg, level, opts)
      notified[msg] = true
      return true
    end
    return false
  end
end

local on_key_cbs = {} --- @type table<integer,function>

--- Adds Lua function {fn} with namespace id {ns_id} as a listener to every,
--- yes every, input key.
---
--- The Nvim command-line option |-w| is related but does not support callbacks
--- and cannot be toggled dynamically.
---
---@note {fn} will be removed on error.
---@note {fn} will not be cleared by |nvim_buf_clear_namespace()|
---@note {fn} will receive the keys after mappings have been evaluated
---
---@param fn fun(key: string)? Function invoked on every key press. |i_CTRL-V|
---                   Passing in nil when {ns_id} is specified removes the
---                   callback associated with namespace {ns_id}.
---@param ns_id integer? Namespace ID. If nil or 0, generates and returns a
---                     new |nvim_create_namespace()| id.
---
---@return integer Namespace id associated with {fn}. Or count of all callbacks
---if on_key() is called without arguments.
function vim.on_key(fn, ns_id)
  if fn == nil and ns_id == nil then
    return vim.tbl_count(on_key_cbs)
  end

  vim.validate({
    fn = { fn, 'c', true },
    ns_id = { ns_id, 'n', true },
  })

  if ns_id == nil or ns_id == 0 then
    ns_id = vim.api.nvim_create_namespace('')
  end

  on_key_cbs[ns_id] = fn
  return ns_id
end

--- Executes the on_key callbacks.
---@private
function vim._on_key(char)
  local failed_ns_ids = {}
  local failed_messages = {}
  for k, v in pairs(on_key_cbs) do
    local ok, err_msg = pcall(v, char)
    if not ok then
      vim.on_key(nil, k)
      table.insert(failed_ns_ids, k)
      table.insert(failed_messages, err_msg)
    end
  end

  if failed_ns_ids[1] then
    error(
      string.format(
        "Error executing 'on_key' with ns_ids '%s'\n    Messages: %s",
        table.concat(failed_ns_ids, ', '),
        table.concat(failed_messages, '\n')
      )
    )
  end
end

--- Generates a list of possible completions for the string.
--- String has the pattern.
---
--- 1. Can we get it to just return things in the global namespace with that name prefix
--- 2. Can we get it to return things from global namespace even with `print(` in front.
---
--- @param pat string
--- @return any[], integer
function vim._expand_pat(pat, env)
  env = env or _G

  if pat == '' then
    local result = vim.tbl_keys(env)
    table.sort(result)
    return result, 0
  end

  -- TODO: We can handle spaces in [] ONLY.
  --    We should probably do that at some point, just for cooler completion.
  -- TODO: We can suggest the variable names to go in []
  --    This would be difficult as well.
  --    Probably just need to do a smarter match than just `:match`

  -- Get the last part of the pattern
  local last_part = pat:match('[%w.:_%[%]\'"]+$')
  if not last_part then
    return {}, 0
  end

  local parts, search_index = vim._expand_pat_get_parts(last_part)

  local match_part = string.sub(last_part, search_index, #last_part)
  local prefix_match_pat = string.sub(pat, 1, #pat - #match_part) or ''

  local final_env = env

  for _, part in ipairs(parts) do
    if type(final_env) ~= 'table' then
      return {}, 0
    end
    local key --- @type any

    -- Normally, we just have a string
    -- Just attempt to get the string directly from the environment
    if type(part) == 'string' then
      key = part
    else
      -- However, sometimes you want to use a variable, and complete on it
      --    With this, you have the power.

      -- MY_VAR = "api"
      -- vim[MY_VAR]
      -- -> _G[MY_VAR] -> "api"
      local result_key = part[1]
      if not result_key then
        return {}, 0
      end

      local result = rawget(env, result_key)

      if result == nil then
        return {}, 0
      end

      key = result
    end
    local field = rawget(final_env, key)
    if field == nil then
      local mt = getmetatable(final_env)
      if mt and type(mt.__index) == 'table' then
        field = rawget(mt.__index, key)
      elseif final_env == vim and (vim._submodules[key] or vim._extra[key]) then
        field = vim[key]
      end
    end
    final_env = field

    if not final_env then
      return {}, 0
    end
  end

  local keys = {} --- @type table<string,true>
  --- @param obj table<any,any>
  local function insert_keys(obj)
    for k, _ in pairs(obj) do
      if type(k) == 'string' and string.sub(k, 1, string.len(match_part)) == match_part then
        keys[k] = true
      end
    end
  end

  if type(final_env) == 'table' then
    insert_keys(final_env)
  end
  local mt = getmetatable(final_env)
  if mt and type(mt.__index) == 'table' then
    insert_keys(mt.__index)
  end
  if final_env == vim then
    insert_keys(vim._submodules)
    insert_keys(vim._extra)
  end

  keys = vim.tbl_keys(keys)
  table.sort(keys)

  return keys, #prefix_match_pat
end

--- @param lua_string string
--- @return (string|string[])[], integer
vim._expand_pat_get_parts = function(lua_string)
  local parts = {}

  local accumulator, search_index = '', 1
  local in_brackets = false
  local bracket_end = -1 --- @type integer?
  local string_char = nil
  for idx = 1, #lua_string do
    local s = lua_string:sub(idx, idx)

    if not in_brackets and (s == '.' or s == ':') then
      table.insert(parts, accumulator)
      accumulator = ''

      search_index = idx + 1
    elseif s == '[' then
      in_brackets = true

      table.insert(parts, accumulator)
      accumulator = ''

      search_index = idx + 1
    elseif in_brackets then
      if idx == bracket_end then
        in_brackets = false
        search_index = idx + 1

        if string_char == 'VAR' then
          table.insert(parts, { accumulator })
          accumulator = ''

          string_char = nil
        end
      elseif not string_char then
        bracket_end = string.find(lua_string, ']', idx, true)

        if s == '"' or s == "'" then
          string_char = s
        elseif s ~= ' ' then
          string_char = 'VAR'
          accumulator = s
        end
      elseif string_char then
        if string_char ~= s then
          accumulator = accumulator .. s
        else
          table.insert(parts, accumulator)
          accumulator = ''

          string_char = nil
        end
      end
    else
      accumulator = accumulator .. s
    end
  end

  --- @param val any[]
  parts = vim.tbl_filter(function(val)
    return #val > 0
  end, parts)

  return parts, search_index
end

do
  -- Ideally we should just call complete() inside omnifunc, though there are
  -- some bugs, so fake the two-step dance for now.
  local matches --- @type any[]

  --- Omnifunc for completing Lua values from the runtime Lua interpreter,
  --- similar to the builtin completion for the `:lua` command.
  ---
  --- Activate using `set omnifunc=v:lua.vim.lua_omnifunc` in a Lua buffer.
  --- @param find_start 1|0
  function vim.lua_omnifunc(find_start, _)
    if find_start == 1 then
      local line = vim.api.nvim_get_current_line()
      local prefix = string.sub(line, 1, vim.api.nvim_win_get_cursor(0)[2])
      local pos
      matches, pos = vim._expand_pat(prefix)
      return (#matches > 0 and pos) or -1
    else
      return matches
    end
  end
end

--- "Pretty prints" the given arguments and returns them unmodified.
---
--- Example:
---
--- ```lua
--- local hl_normal = vim.print(vim.api.nvim_get_hl(0, { name = 'Normal' }))
--- ```
---
--- @see |vim.inspect()|
--- @see |:=|
--- @param ... any
--- @return any # given arguments.
function vim.print(...)
  if vim.in_fast_event() then
    print(...)
    return ...
  end

  for i = 1, select('#', ...) do
    local o = select(i, ...)
    if type(o) == 'string' then
      vim.api.nvim_out_write(o)
    else
      vim.api.nvim_out_write(vim.inspect(o, { newline = '\n', indent = '  ' }))
    end
    vim.api.nvim_out_write('\n')
  end

  return ...
end

--- Translates keycodes.
---
--- Example:
---
--- ```lua
--- local k = vim.keycode
--- vim.g.mapleader = k'<bs>'
--- ```
---
--- @param str string String to be converted.
--- @return string
--- @see |nvim_replace_termcodes()|
function vim.keycode(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

--- @param server_addr string
--- @param connect_error string
function vim._cs_remote(rcid, server_addr, connect_error, args)
  --- @return string
  local function connection_failure_errmsg(consequence)
    local explanation --- @type string
    if server_addr == '' then
      explanation = 'No server specified with --server'
    else
      explanation = "Failed to connect to '" .. server_addr .. "'"
      if connect_error ~= '' then
        explanation = explanation .. ': ' .. connect_error
      end
    end
    return 'E247: ' .. explanation .. '. ' .. consequence
  end

  local f_silent = false
  local f_tab = false

  local subcmd = string.sub(args[1], 10)
  if subcmd == 'tab' then
    f_tab = true
  elseif subcmd == 'silent' then
    f_silent = true
  elseif
    subcmd == 'wait'
    or subcmd == 'wait-silent'
    or subcmd == 'tab-wait'
    or subcmd == 'tab-wait-silent'
  then
    return { errmsg = 'E5600: Wait commands not yet implemented in Nvim' }
  elseif subcmd == 'tab-silent' then
    f_tab = true
    f_silent = true
  elseif subcmd == 'send' then
    if rcid == 0 then
      return { errmsg = connection_failure_errmsg('Send failed.') }
    end
    vim.rpcrequest(rcid, 'nvim_input', args[2])
    return { should_exit = true, tabbed = false }
  elseif subcmd == 'expr' then
    if rcid == 0 then
      return { errmsg = connection_failure_errmsg('Send expression failed.') }
    end
    local res = tostring(vim.rpcrequest(rcid, 'nvim_eval', args[2]))
    return { result = res, should_exit = true, tabbed = false }
  elseif subcmd ~= '' then
    return { errmsg = 'Unknown option argument: ' .. tostring(args[1]) }
  end

  if rcid == 0 then
    if not f_silent then
      vim.notify(connection_failure_errmsg('Editing locally'), vim.log.levels.WARN)
    end
  else
    local command = {}
    if f_tab then
      table.insert(command, 'tab')
    end
    table.insert(command, 'drop')
    for i = 2, #args do
      table.insert(command, vim.fn.fnameescape(args[i]))
    end
    vim.fn.rpcrequest(rcid, 'nvim_command', table.concat(command, ' '))
  end

  return {
    should_exit = rcid ~= 0,
    tabbed = f_tab,
  }
end

--- Shows a deprecation message to the user.
---
---@param name        string     Deprecated feature (function, API, etc.).
---@param alternative string|nil Suggested alternative feature.
---@param version     string     Version when the deprecated function will be removed.
---@param plugin      string|nil Name of the plugin that owns the deprecated feature.
---                              Defaults to "Nvim".
---@param backtrace   boolean|nil Prints backtrace. Defaults to true.
---
---@return string|nil # Deprecated message, or nil if no message was shown.
function vim.deprecate(name, alternative, version, plugin, backtrace)
  vim.validate {
    name = { name, 'string' },
    alternative = { alternative, 'string', true },
    version = { version, 'string', true },
    plugin = { plugin, 'string', true },
  }
  plugin = plugin or 'Nvim'

  -- Only issue warning if feature is hard-deprecated as specified by MAINTAIN.md.
  -- e.g., when planned to be removed in version = '0.12' (soft-deprecated since 0.10-dev),
  -- show warnings since 0.11, including 0.11-dev (hard_deprecated_since = 0.11-dev).
  if plugin == 'Nvim' then
    local current_version = vim.version() ---@type vim.Version
    local removal_version = assert(vim.version.parse(version))
    local is_hard_deprecated ---@type boolean

    if removal_version.minor > 0 then
      local hard_deprecated_since = assert(vim.version._version({
        major = removal_version.major,
        minor = removal_version.minor - 1,
        patch = 0,
        prerelease = 'dev', -- Show deprecation warnings in devel (nightly) version as well
      }))
      is_hard_deprecated = (current_version >= hard_deprecated_since)
    else
      -- Assume there will be no next minor version before bumping up the major version;
      -- therefore we can always show a warning.
      assert(removal_version.minor == 0, vim.inspect(removal_version))
      is_hard_deprecated = true
    end

    if not is_hard_deprecated then
      return
    end
  end

  local msg = ('%s is deprecated'):format(name)
  msg = alternative and ('%s, use %s instead.'):format(msg, alternative) or (msg .. '.')
  msg = ('%s%s\nThis feature will be removed in %s version %s'):format(
    msg,
    (plugin == 'Nvim' and ' :help deprecated' or ''),
    plugin,
    version
  )
  local displayed = vim.notify_once(msg, vim.log.levels.WARN)
  if displayed and backtrace ~= false then
    vim.notify(debug.traceback('', 2):sub(2), vim.log.levels.WARN)
  end
  return displayed and msg or nil
end

require('vim._options')

-- Remove at Nvim 1.0
---@deprecated
vim.loop = vim.uv

return vim
