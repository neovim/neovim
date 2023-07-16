-- Nvim-Lua stdlib: the `vim` module (:help lua-stdlib)
--
-- Lua code lives in one of three places:
--    1. runtime/lua/vim/ (the runtime): For "nice to have" features, e.g. the
--       `inspect` and `lpeg` modules.
--    2. runtime/lua/vim/shared.lua: pure lua functions which always
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
  F = true,
  lsp = true,
  highlight = true,
  diagnostic = true,
  keymap = true,
  ui = true,
  health = true,
  secure = true,
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

-- Internal-only until comments in #8107 are addressed.
-- Returns:
--    {errcode}, {output}
function vim._system(cmd)
  local out = vim.fn.system(cmd)
  local err = vim.v.shell_error
  return err, out
end

-- Gets process info from the `ps` command.
-- Used by nvim_get_proc() as a fallback.
function vim._os_proc_info(pid)
  if pid == nil or pid <= 0 or type(pid) ~= 'number' then
    error('invalid pid')
  end
  local cmd = { 'ps', '-p', pid, '-o', 'comm=' }
  local err, name = vim._system(cmd)
  if 1 == err and vim.trim(name) == '' then
    return {} -- Process not found.
  elseif 0 ~= err then
    error('command failed: ' .. vim.fn.string(cmd))
  end
  local _, ppid = vim._system({ 'ps', '-p', pid, '-o', 'ppid=' })
  -- Remove trailing whitespace.
  name = vim.trim(name):gsub('^.*/', '')
  ppid = tonumber(ppid) or -1
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
  local err, rv = vim._system(cmd)
  if 1 == err and vim.trim(rv) == '' then
    return {} -- Process not found.
  elseif 0 ~= err then
    error('command failed: ' .. vim.fn.string(cmd))
  end
  local children = {}
  for s in rv:gmatch('%S+') do
    local i = tonumber(s)
    if i ~= nil then
      table.insert(children, i)
    end
  end
  return children
end

--- Gets a human-readable representation of the given object.
---
---@see https://github.com/kikito/inspect.lua
---@see https://github.com/mpeterv/vinspect
local function inspect(object, options) -- luacheck: no unused
  error(object, options) -- Stub for gen_vimdoc.py
end

do
  local tdots, tick, got_line1, undo_started, trailing_nl = 0, 0, false, false, false

  --- Paste handler, invoked by |nvim_paste()| when a conforming UI
  --- (such as the |TUI|) pastes text into the editor.
  ---
  --- Example: To remove ANSI color codes when pasting:
  --- <pre>lua
  --- vim.paste = (function(overridden)
  ---   return function(lines, phase)
  ---     for i,line in ipairs(lines) do
  ---       -- Scrub ANSI color codes from paste input.
  ---       lines[i] = line:gsub('\27%[[0-9;mK]+', '')
  ---     end
  ---     overridden(lines, phase)
  ---   end
  --- end)(vim.paste)
  --- </pre>
  ---
  ---@see |paste|
  ---@alias paste_phase -1 | 1 | 2 | 3
  ---
  ---@param lines  string[] # |readfile()|-style list of lines to paste. |channel-lines|
  ---@param phase paste_phase  -1: "non-streaming" paste: the call contains all lines.
  ---              If paste is "streamed", `phase` indicates the stream state:
  ---                - 1: starts the paste (exactly once)
  ---                - 2: continues the paste (zero or more times)
  ---                - 3: ends the paste (exactly once)
  ---@returns boolean # false if client should cancel the paste.
  function vim.paste(lines, phase)
    local now = vim.loop.now()
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

--- Defers callback `cb` until the Nvim API is safe to call.
---
---@see |lua-loop-callbacks|
---@see |vim.schedule()|
---@see |vim.in_fast_event()|
---@param cb function
---@return function
function vim.schedule_wrap(cb)
  return function(...)
    local args = vim.F.pack_len(...)
    vim.schedule(function()
      cb(vim.F.unpack_len(args))
    end)
  end
end

-- vim.fn.{func}(...)
vim.fn = setmetatable({}, {
  __index = function(t, key)
    local _fn
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

vim.funcref = function(viml_func_name)
  return vim.fn[viml_func_name]
end

--- Execute Vim script commands.
---
--- Note that `vim.cmd` can be indexed with a command name to return a callable function to the
--- command.
---
--- Example:
--- <pre>lua
---   vim.cmd('echo 42')
---   vim.cmd([[
---     augroup My_group
---       autocmd!
---       autocmd FileType c setlocal cindent
---     augroup END
---   ]])
---
---   -- Ex command :echo "foo"
---   -- Note string literals need to be double quoted.
---   vim.cmd('echo "foo"')
---   vim.cmd { cmd = 'echo', args = { '"foo"' } }
---   vim.cmd.echo({ args = { '"foo"' } })
---   vim.cmd.echo('"foo"')
---
---   -- Ex command :write! myfile.txt
---   vim.cmd('write! myfile.txt')
---   vim.cmd { cmd = 'write', args = { "myfile.txt" }, bang = true }
---   vim.cmd.write { args = { "myfile.txt" }, bang = true }
---   vim.cmd.write { "myfile.txt", bang = true }
---
---   -- Ex command :colorscheme blue
---   vim.cmd('colorscheme blue')
---   vim.cmd.colorscheme('blue')
--- </pre>
---
---@param command string|table Command(s) to execute.
---                            If a string, executes multiple lines of Vim script at once. In this
---                            case, it is an alias to |nvim_exec2()|, where `opts.output` is set
---                            to false. Thus it works identical to |:source|.
---                            If a table, executes a single command. In this case, it is an alias
---                            to |nvim_cmd()| where `opts` is empty.
---@see |ex-cmd-index|
function vim.cmd(command) -- luacheck: no unused
  error(command) -- Stub for gen_vimdoc.py
end

local VIM_CMD_ARG_MAX = 20

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

-- These are the vim.env/v/g/o/bo/wo variable magic accessors.
do
  local validate = vim.validate

  --@private
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
  vim.v = make_dict_accessor('v', false)
  vim.b = make_dict_accessor('b')
  vim.w = make_dict_accessor('w')
  vim.t = make_dict_accessor('t')
end

--- Get a table of lines with start, end columns for a region marked by two points.
--- Input and output positions are (0,0)-indexed and indicate byte positions.
---
---@param bufnr integer number of buffer
---@param pos1 integer[] (line, column) tuple marking beginning of region
---@param pos2 integer[] (line, column) tuple marking end of region
---@param regtype string type of selection, see |setreg()|
---@param inclusive boolean indicating whether column of pos2 is inclusive
---@return table region Table of the form `{linenr = {startcol,endcol}}`.
---        `endcol` is exclusive, and whole lines are marked with
---        `{startcol,endcol} = {0,-1}`.
function vim.region(bufnr, pos1, pos2, regtype, inclusive)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end

  -- check that region falls within current buffer
  local buf_line_count = vim.api.nvim_buf_line_count(bufnr)
  pos1[1] = math.min(pos1[1], buf_line_count - 1)
  pos2[1] = math.min(pos2[1], buf_line_count - 1)

  -- in case of block selection, columns need to be adjusted for non-ASCII characters
  -- TODO: handle double-width characters
  local bufline
  if regtype:byte() == 22 then
    bufline = vim.api.nvim_buf_get_lines(bufnr, pos1[1], pos1[1] + 1, true)[1]
    pos1[2] = vim.str_utfindex(bufline, pos1[2])
  end

  local region = {}
  for l = pos1[1], pos2[1] do
    local c1, c2
    if regtype:byte() == 22 then -- block selection: take width from regtype
      c1 = pos1[2]
      c2 = c1 + regtype:sub(2)
      -- and adjust for non-ASCII characters
      bufline = vim.api.nvim_buf_get_lines(bufnr, l, l + 1, true)[1]
      local utflen = vim.str_utfindex(bufline, #bufline)
      if c1 <= utflen then
        c1 = vim.str_byteindex(bufline, c1)
      else
        c1 = #bufline + 1
      end
      if c2 <= utflen then
        c2 = vim.str_byteindex(bufline, c2)
      else
        c2 = #bufline + 1
      end
    else
      c1 = (l == pos1[1]) and pos1[2] or 0
      c2 = (l == pos2[1]) and (pos2[2] + (inclusive and 1 or 0)) or -1
    end
    table.insert(region, l, { c1, c2 })
  end
  return region
end

--- Defers calling `fn` until `timeout` ms passes.
---
--- Use to do a one-shot timer that calls `fn`
--- Note: The {fn} is |vim.schedule_wrap()|ped automatically, so API functions are
--- safe to call.
---@param fn function Callback to call once `timeout` expires
---@param timeout integer Number of milliseconds to wait before calling `fn`
---@return table timer luv timer object
function vim.defer_fn(fn, timeout)
  vim.validate({ fn = { fn, 'c', true } })
  local timer = vim.loop.new_timer()
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

--- Display a notification to the user.
---
--- This function can be overridden by plugins to display notifications using a
--- custom provider (such as the system notification provider). By default,
--- writes to |:messages|.
---
---@param msg string Content of the notification to show to the user.
---@param level integer|nil One of the values from |vim.log.levels|.
---@param opts table|nil Optional parameters. Unused by default.
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
  local notified = {}

  --- Display a notification only one time.
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

local on_key_cbs = {}

--- Adds Lua function {fn} with namespace id {ns_id} as a listener to every,
--- yes every, input key.
---
--- The Nvim command-line option |-w| is related but does not support callbacks
--- and cannot be toggled dynamically.
---
---@param fn function: Callback function. It should take one string argument.
---                   On each key press, Nvim passes the key char to fn(). |i_CTRL-V|
---                   If {fn} is nil, it removes the callback for the associated {ns_id}
---@param ns_id integer? Namespace ID. If nil or 0, generates and returns a new
---                    |nvim_create_namespace()| id.
---
---@return integer Namespace id associated with {fn}. Or count of all callbacks
---if on_key() is called without arguments.
---
---@note {fn} will be removed if an error occurs while calling.
---@note {fn} will not be cleared by |nvim_buf_clear_namespace()|
---@note {fn} will receive the keys after mappings have been evaluated
function vim.on_key(fn, ns_id)
  if fn == nil and ns_id == nil then
    return #on_key_cbs
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

--- Generate a list of possible completions for the string.
--- String has the pattern.
---
---     1. Can we get it to just return things in the global namespace with that name prefix
---     2. Can we get it to return things from global namespace even with `print(` in front.
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
    local key

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

  local keys = {}
  ---@private
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

vim._expand_pat_get_parts = function(lua_string)
  local parts = {}

  local accumulator, search_index = '', 1
  local in_brackets, bracket_end = false, -1
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

  parts = vim.tbl_filter(function(val)
    return #val > 0
  end, parts)

  return parts, search_index
end

do
  -- Ideally we should just call complete() inside omnifunc, though there are
  -- some bugs, so fake the two-step dance for now.
  local matches

  --- Omnifunc for completing lua values from from the runtime lua interpreter,
  --- similar to the builtin completion for the `:lua` command.
  ---
  --- Activate using `set omnifunc=v:lua.vim.lua_omnifunc` in a lua buffer.
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

---@private
function vim.pretty_print(...)
  vim.deprecate('vim.pretty_print', 'vim.print', '0.10')
  return vim.print(...)
end

--- "Pretty prints" the given arguments and returns them unmodified.
---
--- Example:
--- <pre>lua
---   local hl_normal = vim.print(vim.api.nvim_get_hl_by_name('Normal', true))
--- </pre>
---
--- @see |vim.inspect()|
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

function vim._cs_remote(rcid, server_addr, connect_error, args)
  local function connection_failure_errmsg(consequence)
    local explanation
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
    return { errmsg = 'Unknown option argument: ' .. args[1] }
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
---@returns Deprecated message, or nil if no message was shown.
function vim.deprecate(name, alternative, version, plugin, backtrace)
  local msg = ('%s is deprecated'):format(name)
  plugin = plugin or 'Nvim'
  msg = alternative and ('%s, use %s instead.'):format(msg, alternative) or msg
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
  if displayed then
    return msg
  end
end

--- Create builtin mappings (incl. menus).
--- Called once on startup.
function vim._init_default_mappings()
  -- mappings

  --@private
  local function map(mode, lhs, rhs)
    vim.api.nvim_set_keymap(mode, lhs, rhs, { noremap = true, desc = 'Nvim builtin' })
  end

  map('n', 'Y', 'y$')
  -- Use normal! <C-L> to prevent inserting raw <C-L> when using i_<C-O>. #17473
  map('n', '<C-L>', '<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>')
  map('i', '<C-U>', '<C-G>u<C-U>')
  map('i', '<C-W>', '<C-G>u<C-W>')
  map('x', '*', 'y/\\V<C-R>"<CR>')
  map('x', '#', 'y?\\V<C-R>"<CR>')
  -- Use : instead of <Cmd> so that ranges are supported. #19365
  map('n', '&', ':&&<CR>')

  -- menus

  -- TODO VimScript, no l10n
  vim.cmd([[
    aunmenu *
    vnoremenu PopUp.Cut                     "+x
    vnoremenu PopUp.Copy                    "+y
    anoremenu PopUp.Paste                   "+gP
    vnoremenu PopUp.Paste                   "+P
    vnoremenu PopUp.Delete                  "_x
    nnoremenu PopUp.Select\ All             ggVG
    vnoremenu PopUp.Select\ All             gg0oG$
    inoremenu PopUp.Select\ All             <C-Home><C-O>VG
    anoremenu PopUp.-1-                     <Nop>
    anoremenu PopUp.How-to\ disable\ mouse  <Cmd>help disable-mouse<CR>
  ]])
end

function vim._init_default_autocmds()
  local nvim_terminal_augroup = vim.api.nvim_create_augroup('nvim_terminal', {})
  vim.api.nvim_create_autocmd({ 'bufreadcmd' }, {
    pattern = 'term://*',
    group = nvim_terminal_augroup,
    nested = true,
    command = "if !exists('b:term_title')|call termopen(matchstr(expand(\"<amatch>\"), '\\c\\mterm://\\%(.\\{-}//\\%(\\d\\+:\\)\\?\\)\\?\\zs.*'), {'cwd': expand(get(matchlist(expand(\"<amatch>\"), '\\c\\mterm://\\(.\\{-}\\)//'), 1, ''))})",
  })
  vim.api.nvim_create_autocmd({ 'cmdwinenter' }, {
    pattern = '[:>]',
    group = vim.api.nvim_create_augroup('nvim_cmdwin', {}),
    command = 'syntax sync minlines=1 maxlines=1',
  })
end

function vim._init_defaults()
  vim._init_default_mappings()
  vim._init_default_autocmds()
end

require('vim._options')

return vim
