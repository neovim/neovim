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

-- TODO(ZyX-I): Create compatibility layer.
--{{{1 package.path updater function
-- Last inserted paths. Used to clear out items from package.[c]path when they
-- are no longer in &runtimepath.
local last_nvim_paths = {}
function vim._update_package_paths()
  local cur_nvim_paths = {}
  local rtps = vim.api.nvim_list_runtime_paths()
  local sep = package.config:sub(1, 1)
  for _, key in ipairs({'path', 'cpath'}) do
    local orig_str = package[key] .. ';'
    local pathtrails_ordered = {}
    local orig = {}
    -- Note: ignores trailing item without trailing `;`. Not using something
    -- simpler in order to preserve empty items (stand for default path).
    for s in orig_str:gmatch('[^;]*;') do
      s = s:sub(1, -2)  -- Strip trailing semicolon
      orig[#orig + 1] = s
    end
    if key == 'path' then
      -- /?.lua and /?/init.lua
      pathtrails_ordered = {sep .. '?.lua', sep .. '?' .. sep .. 'init.lua'}
    else
      local pathtrails = {}
      for _, s in ipairs(orig) do
        -- Find out path patterns. pathtrail should contain something like
        -- /?.so, \?.dll. This allows not to bother determining what correct
        -- suffixes are.
        local pathtrail = s:match('[/\\][^/\\]*%?.*$')
        if pathtrail and not pathtrails[pathtrail] then
          pathtrails[pathtrail] = true
          pathtrails_ordered[#pathtrails_ordered + 1] = pathtrail
        end
      end
    end
    local new = {}
    for _, rtp in ipairs(rtps) do
      if not rtp:match(';') then
        for _, pathtrail in pairs(pathtrails_ordered) do
          local new_path = rtp .. sep .. 'lua' .. pathtrail
          -- Always keep paths from &runtimepath at the start:
          -- append them here disregarding orig possibly containing one of them.
          new[#new + 1] = new_path
          cur_nvim_paths[new_path] = true
        end
      end
    end
    for _, orig_path in ipairs(orig) do
      -- Handle removing obsolete paths originating from &runtimepath: such
      -- paths either belong to cur_nvim_paths and were already added above or
      -- to last_nvim_paths and should not be added at all if corresponding
      -- entry was removed from &runtimepath list.
      if not (cur_nvim_paths[orig_path] or last_nvim_paths[orig_path]) then
        new[#new + 1] = orig_path
      end
    end
    package[key] = table.concat(new, ';')
  end
  last_nvim_paths = cur_nvim_paths
end

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

-- vim.fn.{func}(...)
vim.fn = setmetatable({}, {
  __index = function(t, key)
    local function _fn(...)
      return vim.call(key, ...)
    end
    t[key] = _fn
    return _fn
  end
})

-- These are for loading runtime modules lazily since they aren't available in
-- the nvim binary as specified in executor.c
local function __index(t, key)
  if key == 'inspect' then
    t.inspect = require('vim.inspect')
    return t.inspect
  elseif key == 'treesitter' then
    t.treesitter = require('vim.treesitter')
    return t.treesitter
  elseif require('vim.uri')[key] ~= nil then
    -- Expose all `vim.uri` functions on the `vim` module.
    t[key] = require('vim.uri')[key]
    return t[key]
  elseif key == 'lsp' then
    t.lsp = require('vim.lsp')
    return t.lsp
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
      return a.nvim_win_get_option(winnr or nil, k)
    end
    local function set(k, v) return a.nvim_win_set_option(winnr or nil, k, v) end
    return make_meta_accessor(get, set)
  end
  vim.wo = new_win_opt_accessor(nil)
end

return module
