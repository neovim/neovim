-- Nvim-Lua stdlib: the `vim` module (:help lua-stdlib)
--
-- Lua code lives in one of three places:
--    1. runtime/lua/vim/ (the runtime): For "nice to have" features, e.g. the
--       `inspect` and `lpeg` modules.
--    2. runtime/lua/vim/shared.lua: Code shared between Nvim and tests.
--    3. src/nvim/lua/: Compiled-into Nvim itself.
--
-- Guideline: "If in doubt, put it in the runtime".
--
-- Most functions should live directly in `vim.`, not in submodules.
-- The only "forbidden" names are those claimed by legacy `if_lua`:
--    $ vim
--    :lua for k,v in pairs(vim) do print(k) end
--    buffer
--    open
--    window
--    lastline
--    firstline
--    type
--    line
--    eval
--    dict
--    beep
--    list
--    command
--
-- Reference (#6580):
--    - https://github.com/luafun/luafun
--    - https://github.com/rxi/lume
--    - http://leafo.net/lapis/reference/utilities.html
--    - https://github.com/torch/paths
--    - https://github.com/bakpakin/Fennel (pretty print, repl)
--    - https://github.com/howl-editor/howl/tree/master/lib/howl/util

local vim = vim
assert(vim)

vim.inspect = package.loaded['vim.inspect']
assert(vim.inspect)

vim.log = {
  levels = {
    TRACE = 0;
    DEBUG = 1;
    INFO  = 2;
    WARN  = 3;
    ERROR = 4;
  }
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
  local cmd = { 'ps', '-p', pid, '-o', 'comm=', }
  local err, name = vim._system(cmd)
  if 1 == err and vim.trim(name) == '' then
    return {}  -- Process not found.
  elseif 0 ~= err then
    error('command failed: '..vim.fn.string(cmd))
  end
  local _, ppid = vim._system({ 'ps', '-p', pid, '-o', 'ppid=', })
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
  local cmd = { 'pgrep', '-P', ppid, }
  local err, rv = vim._system(cmd)
  if 1 == err and vim.trim(rv) == '' then
    return {}  -- Process not found.
  elseif 0 ~= err then
    error('command failed: '..vim.fn.string(cmd))
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

local pathtrails = {}
vim._so_trails = {}
for s in  (package.cpath..';'):gmatch('[^;]*;') do
    s = s:sub(1, -2)  -- Strip trailing semicolon
  -- Find out path patterns. pathtrail should contain something like
  -- /?.so, \?.dll. This allows not to bother determining what correct
  -- suffixes are.
  local pathtrail = s:match('[/\\][^/\\]*%?.*$')
  if pathtrail and not pathtrails[pathtrail] then
    pathtrails[pathtrail] = true
    table.insert(vim._so_trails, pathtrail)
  end
end

function vim._load_package(name)
  local basename = name:gsub('%.', '/')
  local paths = {"lua/"..basename..".lua", "lua/"..basename.."/init.lua"}
  for _,path in ipairs(paths) do
    local found = vim.api.nvim_get_runtime_file(path, false)
    if #found > 0 then
      local f, err = loadfile(found[1])
      return f or error(err)
    end
  end

  for _,trail in ipairs(vim._so_trails) do
    local path = "lua"..trail:gsub('?', basename) -- so_trails contains a leading slash
    local found = vim.api.nvim_get_runtime_file(path, false)
    if #found > 0 then
      -- Making function name in Lua 5.1 (see src/loadlib.c:mkfuncname) is
      -- a) strip prefix up to and including the first dash, if any
      -- b) replace all dots by underscores
      -- c) prepend "luaopen_"
      -- So "foo-bar.baz" should result in "luaopen_bar_baz"
      local dash = name:find("-", 1, true)
      local modname = dash and name:sub(dash + 1) or name
      local f, err = package.loadlib(found[1], "luaopen_"..modname:gsub("%.", "_"))
      return f or error(err)
    end
  end
  return nil
end

table.insert(package.loaders, 1, vim._load_package)

-- TODO(ZyX-I): Create compatibility layer.

--- Return a human-readable representation of the given object.
---
--@see https://github.com/kikito/inspect.lua
--@see https://github.com/mpeterv/vinspect
local function inspect(object, options)  -- luacheck: no unused
  error(object, options)  -- Stub for gen_vimdoc.py
end

do
  local tdots, tick, got_line1 = 0, 0, false

  --- Paste handler, invoked by |nvim_paste()| when a conforming UI
  --- (such as the |TUI|) pastes text into the editor.
  ---
  --- Example: To remove ANSI color codes when pasting:
  --- <pre>
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
  --@see |paste|
  ---
  --@param lines  |readfile()|-style list of lines to paste. |channel-lines|
  --@param phase  -1: "non-streaming" paste: the call contains all lines.
  ---              If paste is "streamed", `phase` indicates the stream state:
  ---                - 1: starts the paste (exactly once)
  ---                - 2: continues the paste (zero or more times)
  ---                - 3: ends the paste (exactly once)
  --@returns false if client should cancel the paste.
  function vim.paste(lines, phase)
    local call = vim.api.nvim_call_function
    local now = vim.loop.now()
    local mode = call('mode', {}):sub(1,1)
    if phase < 2 then  -- Reset flags.
      tdots, tick, got_line1 = now, 0, false
    elseif mode ~= 'c' then
      vim.api.nvim_command('undojoin')
    end
    if mode == 'c' and not got_line1 then  -- cmdline-mode: paste only 1 line.
      got_line1 = (#lines > 1)
      vim.api.nvim_set_option('paste', true)  -- For nvim_input().
      local line1 = lines[1]:gsub('<', '<lt>'):gsub('[\r\n\012\027]', ' ')  -- Scrub.
      vim.api.nvim_input(line1)
      vim.api.nvim_set_option('paste', false)
    elseif mode ~= 'c' then
      if phase < 2 and mode:find('^[vV\22sS\19]') then
        vim.api.nvim_command([[exe "normal! \<Del>"]])
        vim.api.nvim_put(lines, 'c', false, true)
      elseif phase < 2 and not mode:find('^[iRt]') then
        vim.api.nvim_put(lines, 'c', true, true)
        -- XXX: Normal-mode: workaround bad cursor-placement after first chunk.
        vim.api.nvim_command('normal! a')
      elseif phase < 2 and mode == 'R' then
        local nchars = 0
        for _, line in ipairs(lines) do
            nchars = nchars + line:len()
        end
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        local bufline = vim.api.nvim_buf_get_lines(0, row-1, row, true)[1]
        local firstline = lines[1]
        firstline = bufline:sub(1, col)..firstline
        lines[1] = firstline
        lines[#lines] = lines[#lines]..bufline:sub(col + nchars + 1, bufline:len())
        vim.api.nvim_buf_set_lines(0, row-1, row, false, lines)
      else
        vim.api.nvim_put(lines, 'c', false, true)
      end
    end
    if phase ~= -1 and (now - tdots >= 100) then
      local dots = ('.'):rep(tick % 4)
      tdots = now
      tick = tick + 1
      -- Use :echo because Lua print('') is a no-op, and we want to clear the
      -- message when there are zero dots.
      vim.api.nvim_command(('echo "%s"'):format(dots))
    end
    if phase == -1 or phase == 3 then
      vim.api.nvim_command('redraw'..(tick > 1 and '|echo ""' or ''))
    end
    return true  -- Paste will not continue if not returning `true`.
  end
end

--- Defers callback `cb` until the Nvim API is safe to call.
---
---@see |lua-loop-callbacks|
---@see |vim.schedule()|
---@see |vim.in_fast_event()|
function vim.schedule_wrap(cb)
  return (function (...)
    local args = {...}
    vim.schedule(function() cb(unpack(args)) end)
  end)
end

--- <Docs described in |vim.empty_dict()| >
--@private
function vim.empty_dict()
  return setmetatable({}, vim._empty_dict_mt)
end

-- vim.fn.{func}(...)
vim.fn = setmetatable({}, {
  __index = function(t, key)
    local _fn
    if vim.api[key] ~= nil then
      _fn = function()
        error(string.format("Tried to call API function with vim.fn: use vim.api.%s instead", key))
      end
    else
      _fn = function(...)
        return vim.call(key, ...)
      end
    end
    t[key] = _fn
    return _fn
  end
})

vim.funcref = function(viml_func_name)
  return vim.fn[viml_func_name]
end

-- These are for loading runtime modules lazily since they aren't available in
-- the nvim binary as specified in executor.c
local function __index(t, key)
  if key == 'treesitter' then
    t.treesitter = require('vim.treesitter')
    return t.treesitter
  elseif require('vim.uri')[key] ~= nil then
    -- Expose all `vim.uri` functions on the `vim` module.
    t[key] = require('vim.uri')[key]
    return t[key]
  elseif key == 'lsp' then
    t.lsp = require('vim.lsp')
    return t.lsp
  elseif key == 'highlight' then
    t.highlight = require('vim.highlight')
    return t.highlight
  elseif key == 'F' then
    t.F = require('vim.F')
    return t.F
  end
end

setmetatable(vim, {
  __index = __index
})

-- An easier alias for commands.
vim.cmd = vim.api.nvim_command

-- These are the vim.env/v/g/o/bo/wo variable magic accessors.
do
  local a = vim.api
  local validate = vim.validate
  local function make_meta_accessor(get, set, del)
    validate {
      get = {get, 'f'};
      set = {set, 'f'};
      del = {del, 'f', true};
    }
    local mt = {}
    if del then
      function mt:__newindex(k, v)
        if v == nil then
          return del(k)
        end
        return set(k, v)
      end
    else
      function mt:__newindex(k, v)
        return set(k, v)
      end
    end
    function mt:__index(k)
      return get(k)
    end
    return setmetatable({}, mt)
  end
  local function pcall_ret(status, ...)
    if status then return ... end
  end
  local function nil_wrap(fn)
    return function(...)
      return pcall_ret(pcall(fn, ...))
    end
  end

  vim.b = make_meta_accessor(
    nil_wrap(function(v) return a.nvim_buf_get_var(0, v) end),
    function(v, k) return a.nvim_buf_set_var(0, v, k) end,
    function(v) return a.nvim_buf_del_var(0, v) end
  )
  vim.w = make_meta_accessor(
    nil_wrap(function(v) return a.nvim_win_get_var(0, v) end),
    function(v, k) return a.nvim_win_set_var(0, v, k) end,
    function(v) return a.nvim_win_del_var(0, v) end
  )
  vim.t = make_meta_accessor(
    nil_wrap(function(v) return a.nvim_tabpage_get_var(0, v) end),
    function(v, k) return a.nvim_tabpage_set_var(0, v, k) end,
    function(v) return a.nvim_tabpage_del_var(0, v) end
  )
  vim.g = make_meta_accessor(nil_wrap(a.nvim_get_var), a.nvim_set_var, a.nvim_del_var)
  vim.v = make_meta_accessor(nil_wrap(a.nvim_get_vvar), a.nvim_set_vvar)
  vim.o = make_meta_accessor(a.nvim_get_option, a.nvim_set_option)

  local function getenv(k)
    local v = vim.fn.getenv(k)
    if v == vim.NIL then
      return nil
    end
    return v
  end
  vim.env = make_meta_accessor(getenv, vim.fn.setenv)
  -- TODO(ashkan) if/when these are available from an API, generate them
  -- instead of hardcoding.
  local window_options = {
              arab = true;       arabic = true;   breakindent = true; breakindentopt = true;
               bri = true;       briopt = true;            cc = true;           cocu = true;
              cole = true;  colorcolumn = true; concealcursor = true;   conceallevel = true;
               crb = true;          cuc = true;           cul = true;     cursorbind = true;
      cursorcolumn = true;   cursorline = true;          diff = true;            fcs = true;
               fdc = true;          fde = true;           fdi = true;            fdl = true;
               fdm = true;          fdn = true;           fdt = true;            fen = true;
         fillchars = true;          fml = true;           fmr = true;     foldcolumn = true;
        foldenable = true;     foldexpr = true;    foldignore = true;      foldlevel = true;
        foldmarker = true;   foldmethod = true;  foldminlines = true;    foldnestmax = true;
          foldtext = true;          lbr = true;           lcs = true;      linebreak = true;
              list = true;    listchars = true;            nu = true;         number = true;
       numberwidth = true;          nuw = true; previewwindow = true;            pvw = true;
    relativenumber = true;    rightleft = true;  rightleftcmd = true;             rl = true;
               rlc = true;          rnu = true;           scb = true;            scl = true;
               scr = true;       scroll = true;    scrollbind = true;     signcolumn = true;
             spell = true;   statusline = true;           stl = true;            wfh = true;
               wfw = true;        winbl = true;      winblend = true;   winfixheight = true;
       winfixwidth = true; winhighlight = true;         winhl = true;           wrap = true;
  }
  local function new_buf_opt_accessor(bufnr)
    local function get(k)
      if window_options[k] then
        return a.nvim_err_writeln(k.." is a window option, not a buffer option")
      end
      if bufnr == nil and type(k) == "number" then
        return new_buf_opt_accessor(k)
      end
      return a.nvim_buf_get_option(bufnr or 0, k)
    end
    local function set(k, v)
      if window_options[k] then
        return a.nvim_err_writeln(k.." is a window option, not a buffer option")
      end
      return a.nvim_buf_set_option(bufnr or 0, k, v)
    end
    return make_meta_accessor(get, set)
  end
  vim.bo = new_buf_opt_accessor(nil)
  local function new_win_opt_accessor(winnr)
    local function get(k)
      if winnr == nil and type(k) == "number" then
        return new_win_opt_accessor(k)
      end
      return a.nvim_win_get_option(winnr or 0, k)
    end
    local function set(k, v) return a.nvim_win_set_option(winnr or 0, k, v) end
    return make_meta_accessor(get, set)
  end
  vim.wo = new_win_opt_accessor(nil)
end

--- Get a table of lines with start, end columns for a region marked by two points
---
--@param bufnr number of buffer
--@param pos1 (line, column) tuple marking beginning of region
--@param pos2 (line, column) tuple marking end of region
--@param regtype type of selection (:help setreg)
--@param inclusive boolean indicating whether the selection is end-inclusive
--@return region lua table of the form {linenr = {startcol,endcol}}
function vim.region(bufnr, pos1, pos2, regtype, inclusive)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end

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
    if regtype:byte() == 22 then  -- block selection: take width from regtype
      c1 = pos1[2]
      c2 = c1 + regtype:sub(2)
      -- and adjust for non-ASCII characters
      bufline = vim.api.nvim_buf_get_lines(bufnr, l, l + 1, true)[1]
      if c1 < #bufline then
        c1 = vim.str_byteindex(bufline, c1)
      end
      if c2 < #bufline then
        c2 = vim.str_byteindex(bufline, c2)
      end
    else
      c1 = (l == pos1[1]) and (pos1[2]) or 0
      c2 = (l == pos2[1]) and (pos2[2] + (inclusive and 1 or 0)) or -1
    end
    table.insert(region, l, {c1, c2})
  end
  return region
end

--- Defers calling `fn` until `timeout` ms passes.
---
--- Use to do a one-shot timer that calls `fn`
--- Note: The {fn} is |schedule_wrap|ped automatically, so API functions are
--- safe to call.
--@param fn Callback to call once `timeout` expires
--@param timeout Number of milliseconds to wait before calling `fn`
--@return timer luv timer object
function vim.defer_fn(fn, timeout)
  vim.validate { fn = { fn, 'c', true}; }
  local timer = vim.loop.new_timer()
  timer:start(timeout, 0, vim.schedule_wrap(function()
    timer:stop()
    timer:close()

    fn()
  end))

  return timer
end


--- Notification provider
--- without a runtime, writes to :Messages
--  see :help nvim_notify
--@param msg Content of the notification to show to the user
--@param log_level Optional log level
--@param opts Dictionary with optional options (timeout, etc)
function vim.notify(msg, log_level, _opts)

  if log_level == vim.log.levels.ERROR then
    vim.api.nvim_err_writeln(msg)
  else
    vim.api.nvim_echo({{msg}}, true, {})
  end
end


local on_keystroke_callbacks = {}

--- Register a lua {fn} with an {id} to be run after every keystroke.
---
--@param fn function: Function to call. It should take one argument, which is a string.
---                   The string will contain the literal keys typed.
---                   See |i_CTRL-V|
---
---                   If {fn} is nil, it removes the callback for the associated {ns_id}
--@param ns_id number? Namespace ID. If not passed or 0, will generate and return a new
---                    namespace ID from |nvim_create_namesapce()|
---
--@return number Namespace ID associated with {fn}
---
--@note {fn} will be automatically removed if an error occurs while calling.
---     This is to prevent the annoying situation of every keystroke erroring
---     while trying to remove a broken callback.
--@note {fn} will not be cleared from |nvim_buf_clear_namespace()|
--@note {fn} will receive the keystrokes after mappings have been evaluated
function vim.register_keystroke_callback(fn, ns_id)
  vim.validate {
    fn = { fn, 'c', true},
    ns_id = { ns_id, 'n', true }
  }

  if ns_id == nil or ns_id == 0 then
    ns_id = vim.api.nvim_create_namespace('')
  end

  on_keystroke_callbacks[ns_id] = fn
  return ns_id
end

--- Function that executes the keystroke callbacks.
--@private
function vim._log_keystroke(char)
  local failed_ns_ids = {}
  local failed_messages = {}
  for k, v in pairs(on_keystroke_callbacks) do
    local ok, err_msg = pcall(v, char)
    if not ok then
      vim.register_keystroke_callback(nil, k)

      table.insert(failed_ns_ids, k)
      table.insert(failed_messages, err_msg)
    end
  end

  if failed_ns_ids[1] then
    error(string.format(
      "Error executing 'on_keystroke' with ns_ids of '%s'\n    With messages: %s",
      table.concat(failed_ns_ids, ", "),
      table.concat(failed_messages, "\n")))
  end
end

--- Generate a list of possible completions for the string.
--- String starts with ^ and then has the pattern.
---
---     1. Can we get it to just return things in the global namespace with that name prefix
---     2. Can we get it to return things from global namespace even with `print(` in front.
function vim._expand_pat(pat, env)
  env = env or _G

  pat = string.sub(pat, 2, #pat)

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
  local last_part = pat:match("[%w.:_%[%]'\"]+$")
  if not last_part then return {}, 0 end

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
    if type(part) == "string" then
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
      if mt and type(mt.__index) == "table" then
        field = rawget(mt.__index, key)
      end
    end
    final_env = field

    if not final_env then
      return {}, 0
    end
  end

  local keys = {}
  local function insert_keys(obj)
    for k,_ in pairs(obj) do
      if type(k) == "string" and string.sub(k,1,string.len(match_part)) == match_part then
        table.insert(keys,k)
      end
    end
  end

  if type(final_env) == "table" then
    insert_keys(final_env)
  end
  local mt = getmetatable(final_env)
  if mt and type(mt.__index) == "table" then
    insert_keys(mt.__index)
  end

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

    if not in_brackets and (s == "." or s == ":") then
      table.insert(parts, accumulator)
      accumulator = ''

      search_index = idx + 1
    elseif s == "[" then
      in_brackets = true

      table.insert(parts, accumulator)
      accumulator = ''

      search_index = idx + 1
    elseif in_brackets then
      if idx == bracket_end then
        in_brackets = false
        search_index = idx + 1

        if string_char == "VAR" then
          table.insert(parts, { accumulator })
          accumulator = ''

          string_char = nil
        end
      elseif not string_char then
        bracket_end = string.find(lua_string, ']', idx, true)

        if s == '"' or s == "'" then
          string_char = s
        elseif s ~= ' ' then
          string_char = "VAR"
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

  parts = vim.tbl_filter(function(val) return #val > 0 end, parts)

  return parts, search_index
end

return module
