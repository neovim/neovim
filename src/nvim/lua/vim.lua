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


-- Internal-only until comments in #8107 are addressed.
-- Returns:
--    {errcode}, {output}
local function _system(cmd)
  local out = vim.api.nvim_call_function('system', { cmd })
  local err = vim.api.nvim_get_vvar('shell_error')
  return err, out
end

-- Gets process info from the `ps` command.
-- Used by nvim_get_proc() as a fallback.
local function _os_proc_info(pid)
  if pid == nil or pid <= 0 or type(pid) ~= 'number' then
    error('invalid pid')
  end
  local cmd = { 'ps', '-p', pid, '-o', 'comm=', }
  local err, name = _system(cmd)
  if 1 == err and string.gsub(name, '%s*', '') == '' then
    return {}  -- Process not found.
  elseif 0 ~= err then
    local args_str = vim.api.nvim_call_function('string', { cmd })
    error('command failed: '..args_str)
  end
  local _, ppid = _system({ 'ps', '-p', pid, '-o', 'ppid=', })
  -- Remove trailing whitespace.
  name = string.gsub(string.gsub(name, '%s+$', ''), '^.*/', '')
  ppid = string.gsub(ppid, '%s+$', '')
  ppid = tonumber(ppid) == nil and -1 or tonumber(ppid)
  return {
    name = name,
    pid = pid,
    ppid = ppid,
  }
end

-- Gets process children from the `pgrep` command.
-- Used by nvim_get_proc_children() as a fallback.
local function _os_proc_children(ppid)
  if ppid == nil or ppid <= 0 or type(ppid) ~= 'number' then
    error('invalid ppid')
  end
  local cmd = { 'pgrep', '-P', ppid, }
  local err, rv = _system(cmd)
  if 1 == err and string.gsub(rv, '%s*', '') == '' then
    return {}  -- Process not found.
  elseif 0 ~= err then
    local args_str = vim.api.nvim_call_function('string', { cmd })
    error('command failed: '..args_str)
  end
  local children = {}
  for s in string.gmatch(rv, '%S+') do
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
local function _update_package_paths()
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

--- Paste handler, invoked by |nvim_paste()| when a conforming UI
--- (such as the |TUI|) pastes text into the editor.
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
local function paste(lines, phase) end  -- luacheck: no unused
paste = (function()
  local tdots, tick, got_line1 = 0, 0, false
  return function(lines, phase)
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
      local line1, _ = string.gsub(lines[1], '[\r\n\012\027]', ' ')  -- Scrub.
      vim.api.nvim_input(line1)
      vim.api.nvim_set_option('paste', false)
    elseif mode ~= 'c' then  -- Else: discard remaining cmdline-mode chunks.
      if phase < 2 and mode ~= 'i' and mode ~= 'R' and mode ~= 't' then
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
end)()

--- Defers callback `cb` until the Nvim API is safe to call.
---
---@see |lua-loop-callbacks|
---@see |vim.schedule()|
---@see |vim.in_fast_event()|
local function schedule_wrap(cb)
  return (function (...)
    local args = {...}
    vim.schedule(function() cb(unpack(args)) end)
  end)
end

local function __index(t, key)
  if key == 'inspect' then
    t.inspect = require('vim.inspect')
    return t.inspect
  elseif require('vim.shared')[key] ~= nil then
    -- Expose all `vim.shared` functions on the `vim` module.
    t[key] = require('vim.shared')[key]
    return t[key]
  end
end

-- Used by nvim_grep().
local function _grep(pattern, path, global)
  local g = global and 'g' or ''
  local vimgrep_cmd = ([[
    try
      silent vimgrep /${pattern}/j${g} ${path}
    catch /E480:/
    endtry
  ]]):gsub('${pattern}', pattern, 1)
     :gsub('${g}', g, 1)
     :gsub('${path}', path, 1)
  vim.api.nvim_command(vimgrep_cmd)
  return vim.api.nvim_eval(
      [[map(getqflist(), 'extend(v:val, {"fname": bufname(v:val.bufnr)})')]])
end

-- Creates a new nvim job (for async calls) and returns its id.
-- Used by acquire_asynccall_channel().
local function _create_nvim_job()
  local progpath = vim.api.nvim_get_vvar('progpath')
  return vim.api.nvim_call_function('jobstart', {
    { progpath, '--embed', '--headless', '-u', 'NONE', '-i', 'NONE', '-n' },
    { rpc = true }
  })
end

-- Adds user function definition to given context dictionary.
-- Used by ctx_dict_add_userfunc() in nvim/eval.c
--
-- @param ctx  context dictionary
-- @param name function name
--
-- @return table containing new context dictionary and new name
local function _add_userfunc(ctx, name)
  if ctx['funcs'] == nil then
    ctx['funcs'] = {}
  end

  -- Function name used to query function definition
  local query_name = name:gsub('^<lambda>([0-9]+)', '{"<lambda>%1"}')

  -- Called function name
  name = name:gsub('^<lambda>', '<SNR>_lambda_')

  -- Function definition
  local body = vim.api.nvim_command_output('func! '..query_name)
  body = body:gsub('^function! <lambda>', 'function! <SNR>_lambda_')
  table.insert(ctx['funcs'], body)

  return { ctx, name }
end

-- Maps job ids of completed async calls to their results.
-- Entries should get removed when collected by call_wait().
local _call_results = {}

-- Puts async call result in "_call_results".
-- Used by put_result().
local function _put_result(job, result)
  _call_results[job] = result
end

-- Appends async call result to a channel in "_call_results".
-- Used for parallel calls by append_result().
local function _append_result(job, result)
  if _call_results[job] == nil then
    _call_results[job] = { result }
  else
    table.insert(_call_results[job], result)
  end
end

-- Removes the async call results of the given job ids from "_call_results"
-- and returns them in an array of maps with "status" and "value" keys.
local function _collect_results(jobs, status)
  local results = {}
  for i, v in ipairs(jobs) do
    table.insert(results, {
      status = status[i],
      value = _call_results[v]
    })
    _call_results[v] = nil
  end
  return results
end

-- Used by async handlers for vimgrep family of commands.
--
-- @param qf use quickfix list if true, otherwise use current
--           window location list
-- @param append append results to existing (quickfix/location) list
local function _async_vimgrep(qf, append, args)
  -- setlist(results, app)
  -- Adds "results" to qf/loc list (append if "app" is true).
  local setlist = (function(setlist_cmd, select_idx)
    return function(results, app)
      vim.api.nvim_call_function(
          setlist_cmd,
          {select(select_idx, 0, results, app and 'a' or ' ')})
    end
  end)(qf and 'setqflist' or 'setloclist', qf and 2 or 1)

  -- Parse arguments
  -- &:vimgrep /{pattern}/[g][j] {file} ...
  local pattern, global, path = args:match('^/(.*)/([jg]*)%s+(.+)%s*$')
  if path == nil or pattern == nil then
    if vim.api.nvim_call_function('match', { args, [[^\i]] }) ~= -1 then
      -- &:vimgrep {pattern} {file} ...
      pattern, path = args:match('^([^%s]+)%s+(.+)%s*$')
    end
  elseif pattern == '' then
    pattern = vim.api.nvim_eval('@/')  -- Last used pattern
  end

  if path == nil or pattern == nil then
    error('Path missing or invalid pattern')
  end

  global = global and global:find('g') and true or false

  local paths = vim.api.nvim_call_function('substitute', {
    path,
    [=[\(\%(`[^`]*`\|\\.\|[^[:space:]]\)\+\)]=],
    [[\=glob(submatch(1))."\n"]],
    'g'
  })
  paths = vim.api.nvim_call_function('trim', { paths })
  paths = vim.api.nvim_call_function('split', { paths, '\n' })

  -- Prepare call_parallel argument lists
  for i, v in ipairs(paths) do
    paths[i] = { pattern, v, global }
  end

  -- Spawn jobs
  local jobcount = vim.api.nvim_get_vvar('cores')  -- Ideal number of jobs
  local jobs = vim.api.nvim_call_function('call_parallel', {
    'nvim_grep', paths, { count = jobcount }
  })

  -- Collect results
  local results = vim.api.nvim_call_function('call_wait', { jobs })
  local bufnr_tbl = {}
  local length = 0
  setlist({ }, append)
  for _, v in ipairs(results) do
    for _, list in ipairs(v.value) do
      length = length + #list
      for _, entry in ipairs(list) do
        local bufnr = bufnr_tbl[entry.fname]
        if bufnr == nil then
          bufnr = vim.api.nvim_call_function('bufnr', {
            entry.fname, true
          })
          bufnr_tbl[entry.fname] = bufnr
        end
        entry.bufnr = bufnr
      end
      setlist(list, true)
    end
  end
  print('Found '..length..' matches')
end

-- Async handlers for commands
local _async_handlers_tbl = {
  ['vimgrep'] = function(args)
    _async_vimgrep(true, false, args)
  end,
  ['vimgrepadd'] = function(args)
    _async_vimgrep(true, true, args)
  end,
  ['lvimgrep'] = function(args)
    _async_vimgrep(false, false, args)
  end,
  ['lvimgrepadd'] = function(args)
    _async_vimgrep(false, true, args)
  end,
}

-- Default command async handler.
local function _async_handler_default(cmd)
  cmd = '"'..cmd:gsub("'", "''"):gsub('\\', '\\\\'):gsub('"', '\\"')..'"'
  local handler_cmd = ([=[
    call call_async(
      'eval',
      ['[nvim_command_output(cmd), nvim_get_context([v:null])]'],
      { 'context': nvim_get_context([v:null]),
        'done': { rv -> nvim_command('echo rv[0]') +
                        nvim_load_context(rv[1]) } })
  ]=]):gsub('\n', ''):gsub('cmd', cmd, 1)
  vim.api.nvim_command(handler_cmd)
end

-- Invokes the async handler of "cmd".
-- Used by ex_async_handler().
local function _async_handler(cmd)
  local handler, args = cmd:match('^([^%s]+)%s*(.*)$')
  local handler_fn = _async_handlers_tbl[handler]
  if handler_fn == nil then
    _async_handler_default(cmd)
  else
    handler_fn(args)
  end
end

local module = {
  _update_package_paths = _update_package_paths,
  _os_proc_children = _os_proc_children,
  _os_proc_info = _os_proc_info,
  _system = _system,
  paste = paste,
  schedule_wrap = schedule_wrap,
  _grep = _grep,
  _create_nvim_job = _create_nvim_job,
  _put_result = _put_result,
  _append_result = _append_result,
  _collect_results = _collect_results,
  _async_handler = _async_handler,
  _add_userfunc = _add_userfunc,
}

setmetatable(module, {
  __index = __index
})

return module
