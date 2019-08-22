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
-- Most functions should live directly on `vim.`, not sub-modules. The only
-- "forbidden" names are those claimed by legacy `if_lua`:
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
local function inspect(object, options)  -- luacheck: no unused
  error(object, options)  -- Stub for gen_vimdoc.py
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

--- Defers the wrapped callback until when the nvim API is safe to call.
---
--- See |vim-loop-callbacks|
local function schedule_wrap(cb)
  return (function (...)
    local args = {...}
    vim.schedule(function() cb(unpack(args)) end)
  end)
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
-- Used by asynccall_channel_acquire().
local function _create_nvim_job()
  local progpath = vim.api.nvim_get_vvar('progpath')
  return vim.api.nvim_call_function('jobstart', {
    { progpath, '--embed', '--headless', '-u', 'NONE', '-i', 'NONE', '-n' },
    { rpc = true }
  })
end

local _async_invoke_called = false

-- Load the given context dictionary and call the given function within
-- a function-call context.
-- Used by nvim__async_invoke() in "nvim/api/vim.c".
--
-- @param ctx Context dictionary
-- @param fn Name of function to call
-- @param args Table of function call arguments
--
-- @returns Result of function call
local function _async_invoke(ctx, fn, args)
  if not _async_invoke_called then
    vim.api.nvim_command(
      [[function <SNR>ASYNC_INIT(ctx, fn)
          call nvim_load_context(a:ctx)
          function <SNR>_lambda_CALL(args) closure
            return call(function(a:fn), args)
          endfunction
        endfunction
      ]])
    vim.api.nvim_call_function('<SNR>ASYNC_INIT', {ctx, fn})
    vim.api.nvim_command('delfunction <SNR>ASYNC_INIT')
    _async_invoke_called = true
  end
  return vim.api.nvim_call_function('<SNR>_lambda_CALL', {args})
end

-- Returns function name for use in context dictionary.
-- Used by ctx_dict_add_userfunc() in "nvim/eval.c".
--
-- @param name Function name
--
-- @returns Function name as used in context
local function _ctx_get_func_name(name)
  name = name:gsub('^<lambda>', '<SNR>_lambda_')
  return name
end

-- Returns function definiton for use in context dictionary.
-- Used by ctx_pack_func() in "nvim/context.c".
--
-- @param name Function name
--
-- @returns Function definition string
local function _ctx_get_func_def(name)
  name = name:gsub('^<lambda>([0-9]+)', '{"<lambda>%1"}')
  local def = vim.api.nvim_command_output('func '..name)
    :gsub('^%s*function <lambda>', 'function <SNR>_lambda_')
    :gsub('^%s*function', 'function!')
    :gsub('\n[0-9]+', '\n')
  return def
end

-- Adds function entry to context dictionary.
-- Used by ctx_dict_add_userfunc() in "nvim/eval.c".
--
-- @param ctx Context dictionary to add to
-- @param func Function entry to add
--
-- @returns Context dictionary after adding function entry
local function _ctx_add_func(ctx, func)
  if ctx['funcs'] == nil then
    ctx['funcs'] = {}
  end
  table.insert(ctx['funcs'], func)
  return ctx
end

-- Maps job ids of completed async calls to their results.
-- Entries should get removed when collected by call_wait().
local _call_results = {}

-- Puts async call result in "_call_results".
-- Used by asynccall_put_result().
local function _put_result(job, result)
  _call_results[job] = result
end

-- Appends async call result to a channel in "_call_results".
-- Used for parallel calls by asynccall_append_result().
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
    if pattern == '' then
      error('E35: No previous regular expression')
    end
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

  -- Prepare call_parallel arguments
  for i, v in ipairs(paths) do
    paths[i] = { pattern, v, global }
  end

  vim.api.nvim_command([[call ctxpush(['gvars', 'funcs'])]])
  vim.api.nvim_set_var('_count', 0)

  if qf then
    vim.api.nvim_command([[
    function! _itemdone(results)
      let g:_count += len(a:results)
      call setqflist(map(a:results, { _, r -> ]]..
    [[  extend(r, { 'bufnr': bufnr(r.fname, 1) }) }), 'a')
    endfunction
    ]])
  else
    vim.api.nvim_command([[
    function! _itemdone(results)
      let g:_count += len(a:results)
      call setloclist(0, map(a:results, { _, r -> ]]..
    [[  extend(r, { 'bufnr': bufnr(r.fname, 1) }) }), 'a')
    endfunction
    ]])
  end

  vim.api.nvim_command([[
  function! _done(...)
    echom 'Found '.g:_count.' matches'
    call call_wait(g:_jobs)
    call timer_start(0, { -> ctxpop() })
  endfunction
  ]])

  -- Clear list (if append is false) and spawn jobs
  if not append then
    if qf then
      vim.api.nvim_call_function('setqflist', {{}})
    else
      vim.api.nvim_call_function('setloclist', {0, {}})
    end
  end

  local jobs = vim.api.nvim_call_function('call_parallel', {
    'nvim_grep', paths, { itemdone = '_itemdone', done = '_done' }
  })
  vim.api.nvim_set_var('_jobs', jobs)
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
  schedule_wrap = schedule_wrap,
  _grep = _grep,
  _create_nvim_job = _create_nvim_job,
  _async_invoke = _async_invoke,
  _ctx_get_func_name = _ctx_get_func_name,
  _ctx_get_func_def = _ctx_get_func_def,
  _ctx_add_func = _ctx_add_func,
  _put_result = _put_result,
  _append_result = _append_result,
  _collect_results = _collect_results,
  _async_handler = _async_handler,
}

setmetatable(module, {
  __index = __index
})

return module
