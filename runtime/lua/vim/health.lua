--- @brief
---<pre>help
--- health.vim is a minimal framework to help users troubleshoot configuration and
--- any other environment conditions that a plugin might care about. Nvim ships
--- with healthchecks for configuration, performance, python support, ruby
--- support, clipboard support, and more.
---
--- To run all healthchecks, use: >vim
---
---         :checkhealth
--- <
--- Plugin authors are encouraged to write new healthchecks. |health-dev|
---
--- Commands                                *health-commands*
---
---                                                              *:che* *:checkhealth*
--- :che[ckhealth]  Run all healthchecks.
---                                         *E5009*
---                 Nvim depends on |$VIMRUNTIME|, 'runtimepath' and 'packpath' to
---                 find the standard "runtime files" for syntax highlighting,
---                 filetype-specific behavior, and standard plugins (including
---                 :checkhealth).  If the runtime files cannot be found then
---                 those features will not work.
---
--- :che[ckhealth] {plugins}
---                 Run healthcheck(s) for one or more plugins. E.g. to run only
---                 the standard Nvim healthcheck: >vim
---                         :checkhealth vim.health
--- <
---                 To run the healthchecks for the "foo" and "bar" plugins
---                 (assuming they are on 'runtimepath' and they have implemented
---                 the Lua `require("foo.health").check()` interface): >vim
---                         :checkhealth foo bar
--- <
---                 To run healthchecks for Lua submodules, use dot notation or
---                 "*" to refer to all submodules. For example Nvim provides
---                 `vim.lsp` and `vim.treesitter`:  >vim
---                         :checkhealth vim.lsp vim.treesitter
---                         :checkhealth vim*
--- <
---
--- Create a healthcheck                                    *health-dev* *vim.health*
---
--- Healthchecks are functions that check the user environment, configuration, or
--- any other prerequisites that a plugin cares about. Nvim ships with
--- healthchecks in:
---         - $VIMRUNTIME/autoload/health/
---         - $VIMRUNTIME/lua/vim/lsp/health.lua
---         - $VIMRUNTIME/lua/vim/treesitter/health.lua
---         - and more...
---
--- To add a new healthcheck for your own plugin, simply create a "health.lua"
--- module on 'runtimepath' that returns a table with a "check()" function. Then
--- |:checkhealth| will automatically find and invoke the function.
---
--- For example if your plugin is named "foo", define your healthcheck module at
--- one of these locations (on 'runtimepath'):
---         - lua/foo/health/init.lua
---         - lua/foo/health.lua
---
--- If your plugin also provides a submodule named "bar" for which you want
--- a separate healthcheck, define the healthcheck at one of these locations:
---         - lua/foo/bar/health/init.lua
---         - lua/foo/bar/health.lua
---
--- All such health modules must return a Lua table containing a `check()`
--- function.
---
--- Copy this sample code into `lua/foo/health.lua`, replacing "foo" in the path
--- with your plugin name: >lua
---
---         local M = {}
---
---         M.check = function()
---           vim.health.start("foo report")
---           -- make sure setup function parameters are ok
---           if check_setup() then
---             vim.health.ok("Setup is correct")
---           else
---             vim.health.error("Setup is incorrect")
---           end
---           -- do some more checking
---           -- ...
---         end
---
---         return M
---</pre>

local M = {}

local s_output = {} ---@type string[]
local checks = {}
local current_name ---@type string

-- From a path return a list [{name}, {func}, {type}] representing a healthcheck
local function filepath_to_healthcheck(path)
  path = vim.fs.normalize(path)
  local name --- @type string
  local func --- @type string
  local filetype --- @type string
  if path:find('vim$') then
    name = vim.fs.basename(path):gsub('%.vim$', '')
    func = 'health#' .. name .. '#check'
    filetype = 'v'
  else
    local subpath = path:gsub('.*lua/', '')
    if vim.fs.basename(subpath) == 'health.lua' then
      -- */health.lua
      name = vim.fs.dirname(subpath)
    else
      -- */health/init.lua
      name = vim.fs.dirname(vim.fs.dirname(subpath))
    end
    name = name:gsub('/', '.')

    func = 'require("' .. name .. '.health").check()'
    filetype = 'l'
  end

  if name ~= 'vim' then
    checks[name] = checks[name] or {}
    checks[name].func = func ---@type string
    checks[name].filetype = filetype ---@type string
  end
end

--- @param plugin_names string
local function get_healthcheck_list(plugin_names)
  local plugin_names_list = vim.split(plugin_names, ' ')
  for _, p in pairs(plugin_names_list) do
    -- support vim/lsp/health{/init/}.lua as :checkhealth vim.lsp

    p = p:gsub('%.', '/')
    p = p:gsub('*', '**')

    local paths = vim.api.nvim_get_runtime_file('autoload/health/' .. p .. '.vim', true)
    vim.list_extend(
      paths,
      vim.api.nvim_get_runtime_file('lua/**/' .. p .. '/health/init.lua', true)
    )
    vim.list_extend(paths, vim.api.nvim_get_runtime_file('lua/**/' .. p .. '/health.lua', true))

    if vim.tbl_count(paths) > 0 then
      local unique_paths = {} --- @type table<string, boolean>
      for _, v in pairs(paths) do
        unique_paths[v] = true
      end
      paths = {}
      for k, _ in pairs(unique_paths) do
        paths[#paths + 1] = k
      end

      for _, v in ipairs(paths) do
        filepath_to_healthcheck(v)
      end
    end
  end
end

--- Changes ':h clipboard' to ':help |clipboard|'.
---
--- @param s string
--- @return string
local function help_to_link(s)
  return vim.fn.substitute(s, [[\v:h%[elp] ([^|][^"\r\n ]+)]], [[:help |\1|]], [[g]])
end

local function collect_output(text, type, advice)
  checks[current_name].output = checks[current_name].output or {}
  table.insert(checks[current_name].output, { text = text, type = type, advice = advice })
end

--- Starts a new report. Most plugins should call this only once, but if
--- you want different sections to appear in your report, call this once
--- per section.
---
--- @param name string
function M.start(name)
  collect_output(name, 'start')
end

--- Reports an informational message.
---
--- @param msg string
function M.info(msg)
  collect_output(msg, 'info')
end

--- Reports a "success" message.
---
--- @param msg string
function M.ok(msg)
  collect_output(msg, 'ok')
end

--- Reports a warning.
---
--- @param msg string
--- @param ... string|string[] Optional advice
function M.warn(msg, ...)
  local varargs = ...
  if varargs then
    if type(varargs) == 'string' then
      varargs = { varargs }
    end
  end
  collect_output(msg, 'warn', varargs)
end

--- Reports an error.
---
--- @param msg string
--- @param ... string|string[] Optional advice
function M.error(msg, ...)
  local varargs = ...
  if varargs then
    if type(varargs) == 'string' then
      varargs = { varargs }
    end
  end
  collect_output(msg, 'error', varargs)
end

local path2name = function(path)
  if path:match('%.lua$') then
    -- Lua: transform "../lua/vim/lsp/health.lua" into "vim.lsp"

    -- Get full path, make sure all slashes are '/'
    path = vim.fs.normalize(path)

    -- Remove everything up to the last /lua/ folder
    path = path:gsub('^.*/lua/', '')

    -- Remove the filename (health.lua)
    path = vim.fs.dirname(path)

    -- Change slashes to dots
    path = path:gsub('/', '.')

    return path
  else
    -- Vim: transform "../autoload/health/provider.vim" into "provider"
    return vim.fn.fnamemodify(path, ':t:r')
  end
end

local PATTERNS = { '/autoload/health/*.vim', '/lua/**/**/health.lua', '/lua/**/**/health/init.lua' }
--- :checkhealth completion function used by cmdexpand.c get_healthcheck_names()
M._complete = function()
  local unique = vim ---@type table<string,boolean>
    ---@param pattern string
    .iter(vim.tbl_map(function(pattern)
      return vim.tbl_map(path2name, vim.api.nvim_get_runtime_file(pattern, true))
    end, PATTERNS))
    :flatten()
    ---@param t table<string,boolean>
    :fold({}, function(t, name)
      t[name] = true -- Remove duplicates
      return t
    end)
  -- vim.health is this file, which is not a healthcheck
  unique['vim'] = nil
  local rv = vim.tbl_keys(unique)
  table.sort(rv)
  return rv
end

local function format_output(output)
  local text_string = output.text
  local text = vim.split(text_string, '\n')

  local type = output.type
  local advice = output.advice
  local formatted_output = {}

  if type == 'start' then
    vim.list_extend(formatted_output, { '', '' })
    text[1] = text[1] .. ' ~'
    vim.list_extend(formatted_output, text)
  elseif type == 'info' then
    vim.list_extend(formatted_output, { '- ' })
    vim.list_extend(formatted_output, text)
  elseif type == 'ok' then
    vim.list_extend(formatted_output, { '- OK ' })
    vim.list_extend(formatted_output, text)
  elseif type == 'warn' then
    vim.list_extend(formatted_output, { '- WARNING ' })
    vim.list_extend(formatted_output, text)
  elseif type == 'error' then
    vim.list_extend(formatted_output, { '- ERROR ' })
    vim.list_extend(formatted_output, text)
  end
  local it = vim.iter(formatted_output)
  local elem1 = it:rev():pop()
  local elem2 = it:pop()
  formatted_output = { elem1 .. elem2 }
  local other_lines = it:rev()
    :map(function(v)
      if type ~= 'start' then
        return '  ' .. v
      else
        return v
      end
    end)
    :totable()

  vim.list_extend(formatted_output, other_lines)

  if advice then
    vim.list_extend(formatted_output, { '  - ADVICE:' })
    it = vim.iter(advice)
    it:map(function(v)
      return '    - ' .. help_to_link(v)
    end)
    vim.list_extend(formatted_output, it:totable())
  end

  return formatted_output
end

--- Runs the specified healthchecks.
--- Runs all discovered healthchecks if plugin_names is empty.
---
--- @param mods string command modifiers that affect splitting a window.
--- @param plugin_names string glob of plugin names, split on whitespace. For example, using
---                            `:checkhealth vim.* nvim` will healthcheck `vim.lsp`, `vim.treesitter`
---                            and `nvim` modules.
function M._check(mods, plugin_names)
  if plugin_names == '' then
    get_healthcheck_list('*')
  else
    get_healthcheck_list(plugin_names)
  end

  local emptybuf = vim.fn.bufnr('$') == 1 and vim.fn.getline(1) == '' and 1 == vim.fn.line('$')

  -- When no command modifiers are used:
  -- - If the current buffer is empty, open healthcheck directly.
  -- - If not specified otherwise open healthcheck in a tab.
  local buf_cmd = #mods > 0 and (mods .. ' sbuffer') or emptybuf and 'buffer' or 'tab sbuffer'

  local bufnr = vim.api.nvim_create_buf(true, true)
  vim.cmd(buf_cmd .. ' ' .. bufnr)

  if vim.fn.bufexists('health://') == 1 then
    vim.cmd.bwipe('health://')
  end
  vim.cmd.file('health://')
  vim.cmd.setfiletype('checkhealth')

  -- This should only happen when doing `:checkhealth vim`
  if next(checks) == nil then
    vim.fn.setline(1, 'ERROR: No healthchecks found.')
    return
  end
  vim.cmd.redraw()
  vim.print('Running healthchecks...')

  for name, value in vim.spairs(checks) do
    current_name = name
    local func = value.func
    local type = value.filetype

    if func == '' then
      M.error('No healthcheck found for "' .. name .. '" plugin.')
    end

    if type == 'v' then
      vim.fn.call(func, {})
    else
      local f = assert(loadstring(func))
      local ok, output = pcall(f) ---@type boolean, string
      if not ok then
        M.error(
          string.format('Failed to run healthcheck for "%s" plugin. Exception:\n%s\n', name, output)
        )
      end
    end

    -- in the event the healthcheck doesn't return anything
    -- (the plugin author should avoid this possibility)
    if checks[name].output == nil then
      M.error('The healthcheck report for "' .. name .. '" plugin is empty.')
    end

    local header = { string.rep('=', 78), name .. ': ' .. func, '' }
    -- remove empty line after header from report_start
    if s_output[1] == '' then
      local tmp = {} ---@type string[]
      for i = 2, #s_output do
        tmp[#tmp + 1] = s_output[i]
      end
      s_output = {}
      for _, v in ipairs(tmp) do
        s_output[#s_output + 1] = v
      end
    end
    s_output[#s_output + 1] = ''
    s_output = vim.list_extend(s_output, header)

    for _, v in ipairs(checks[name].output) do
      local formatted_output = format_output(v)
      vim.list_extend(s_output, formatted_output)
    end
  end
  vim.fn.append(vim.fn.line('$'), s_output)

  -- Clear the 'Running healthchecks...' message.
  vim.cmd.redraw()
  vim.print('')
end

return M
