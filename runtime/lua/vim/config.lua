-------------------------------------------------------------------------------
-- Module to host plugins configurations.
--
-------------------------------------------------------------------------------
-- WHAT DOES THE USER
-------------------------------------------------------------------------------
-- The user is supposed to configure plugins by calling:
--
--    vim.config[plugin_name] {
--      <options>
--    }
--
-- Plugin configuration can be later updated in the same manner. Doing so, will
-- not replace the configuration, will only update it with the new values.
-- To completely replace previous configuration, add `true` argument:
--
--    vim.config[plugin_name]({
--      <options>
--    }, true)
--
-- If a setup function has been set in the meanwhile, it will be called.
--
-- If the user wants to reset the plugin's default options:
--
--    vim.config().reset(plugin_name)
--
-- This must be handled by the plugin `reset` function (see below).
--
-- If the user wants to know some/all current options (default or not):
--
--    vim.config().query(plugin_name, {options})
--
-- This must be handled by the plugin `query` function (see below).
--
-- NOTE: the plugin is not obliged to expose any function (setup, reset, query).
--       They are all optional. If absent, user is notified when calling them.
--
-------------------------------------------------------------------------------
-- WHAT DOES THE PLUGIN AUTHOR
-------------------------------------------------------------------------------
-- Plugin authors are supposed to fetch a copy of the plugin configuration with:
--
--    vim.config().get(plugin_name)
--
-- They can set a function to be called every time the plugin configuration
-- is updated by the user. This `setup` function is set like this:
--
--    vim.config().setup_func(plugin_name, plugin_setup_func)
--
-- This function should accept no arguments: it will get user options on its
-- own.
--
-- They can set a function that resets all plugin options to their default values:
--
--    vim.config().reset_func(plugin_name, plugin_reset_func)
--
-- This function should accept no arguments.
--
-- They can set a function that returns plugin options (set by the user or not):
--
--    vim.config().query_func(plugin_name, plugin_query_func)
--
-- This function should accept one argument (an array with options names).
-- If no argument is given, it should return all options.
--
-- NOTE: it's not mandatory for a plugin to provide these functionalities, but
-- if they intend to, they should conform to this interface, so that there is
-- a standard way to do the same things for all plugins, and so that it's
-- possible to gather plugin informations to display with:
--
--    vim.config().info()
--
-- At least setting a `setup` function is very recommended.
--
-------------------------------------------------------------------------------
-- LOADED/ENABLED/DISABLED PLUGINS
-------------------------------------------------------------------------------
-- When a plugin is loaded, it should call:
--
--    vim.config().loaded(plugin_name, true)
--
-- To check if a plugin has been loaded:
--
--    loaded = vim.config().loaded(plugin_name)
--
--  NOTE: this could be simplified by having a dedicated `vim.loaded` table.
--
-- Plugins could set functions to allow users (or other plugins) to
-- disable/enable them temporarily (or not).
--
--    vim.config().enable_func(plugin_name, plugin_enable_func)
--
-- Users (or other plugins) can then disable/enable them by calling:
--
--    vim.config().enable(plugin_name, false (to disable) or true (to enable))
--
-- For example, a plugin could remove all its mappings when disabled, and apply
-- them back when enabled. It goes by itself that if a plugin wants to handle
-- the case of being temporarily disabled, it should also handle the opposite
-- action (to be re-enabled), and do so only if it's currently disabled.
--
-- To check if a plugin is enabled:
--
--    loaded = vim.config().enabled(plugin_name)
--
--  NOTE: this could be simplified by having a dedicated `vim.enabled` table.
-------------------------------------------------------------------------------
local a, fn = vim.api, vim.fn
local winopt, bufopt = a.nvim_win_set_option, a.nvim_buf_set_option
local insert, fmt = table.insert, string.format

-- Table with all plugins configurations, as set by users
local configs = {}

-- Table with all plugins `setup` functions, as set by plugins
local setup_fn = {}

-- Table with all plugins `reset` functions, as set by plugins
local reset_fn = {}

-- Table with all plugins `query` functions, as set by plugins
local query_fn = {}

-- Table with all plugins `enable` functions, as set by plugins
local enable_fn = {}

-- Table with paths of scripts that updated configurations
local traces = {}

-- Table with loaded plugins
local loaded = {}

-- Table with enabled plugins
local enabled = {}

----------------------------------------------------------------------------------------------------
-- Setting/updating options
----------------------------------------------------------------------------------------------------

---@private
local function record_update(name, opts, replace, reset)
  -- if vim.o.verbose > 0 then
  if true then
    -- register when, where and how the function was called
    traces[name] = traces[name] or {}
    table.insert(traces[name], {
      fn.strftime('%H:%M:%S'),
      debug.getinfo(3).source:sub(2),
      replace and 'replace' or reset and 'DEFAULT' or 'keep   ',
      vim.inspect(opts),
    })
  end
end

-------------------------------------------------------------------------------
--- Calling vim.config[name] sets plugin `name` options through this function.
---@private
---@param name string: name of plugin
local function plugin_cfg_func(_, name)
  assert(type(name) == 'string', 'Argument #1 must be a string (name of plugin)')
  ---@param opts table: plugin options
  ---@param replace bool: replace options, or merge with current (default)
  return function(opts, replace)
    assert(type(opts) == 'table', 'Argument #1 must be a table (plugin options)')
    record_update(name, opts, replace)
    if replace or not configs[name] then
      -- replace the whole configuration
      configs[name] = opts
    else
      -- update the configuration in a conservative way
      for opt, v in pairs(opts) do
        configs[name][opt] = v
      end
    end
    -- a `setup` function for this plugin has been set, call it
    if setup_fn[name] then
      setup_fn[name](configs[name])
    end
  end
end

----------------------------------------------------------------------------------------------------
-- Plugin state functions
----------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--- Set a plugin's `loaded` state. Should be done by the plugin when it's
--- loaded. Return `loaded` state.
---@private
---@param name string
---@param set_loaded bool
---@return bool
local function plugin_loaded(name, set_loaded)
  if set_loaded then
    loaded[name] = true
    enabled[name] = true
  end
  return loaded[name]
end

-------------------------------------------------------------------------------
--- Check if a plugin is currently enabled.
---@private
---@param name string
---@return bool
local function plugin_enabled(name)
  return enabled[name]
end

-------------------------------------------------------------------------------
--- Return a copy of the plugin configuration, or nil if there is none.
---@private
---@param name string
---@return table|nil
local function get_copy_of_plugin_cfg(name)
  if configs[name] then
    return vim.deepcopy(configs[name])
  end
end

-------------------------------------------------------------------------------
--- Call the function that resets plugin options, if defined.
--- Clear user configuration and record the action.
---@private
---@param name string
local function reset_config(name)
  assert(reset_fn[name] ~= nil, "vim.config: no reset function for " .. name)
  reset_fn[name]()
  record_update(name, {}, false, true)
  configs[name] = {}
end

-------------------------------------------------------------------------------
--- Call the function that queries plugin options, if defined.
---@private
---@param name string
---@param options table
---@return table
local function query_config(name, options)
  assert(query_fn[name] ~= nil, "vim.config: no query function for " .. name)
  return query_fn[name](options)
end

-------------------------------------------------------------------------------
--- Call the function that disables/enables plugin, update the disabled/enabled
--- tables. The function should handle both disabling and (re-)enabling, it is
--- called with a boolean argument (`true` when enabling, `false` when
--- disabling).
---@private
---@param name string
---@param state bool
---@return bool
local function enable_plugin(name, state)
  assert(enable_fn[name] ~= nil, "vim.config: no enable function for " .. name)
  assert(type(state) ~= "boolean", "vim.config: argument #2 for 'enable' must be a boolean")
  local enable = enable_fn[name](state)
  enabled[name] = enable
  return enable
end

-------------------------------------------------------------------------------
--- Set the function to be called when the plugin configuration is updated.
---@private
---@param name string: plugin name
---@param func function: plugin setup function
local function set_plugin_setup_func(name, func)
  assert(type(name) == 'string', 'vim.config: argument #1 for setup_func must be a string')
  assert(type(func) == 'function', 'vim.config: argument #2 for setup_func must be a function')
  setup_fn[name] = func
end

-------------------------------------------------------------------------------
--- Set the function to be called when options must be reset to default.
---@private
---@param name string: plugin name
---@param func function: plugin reset function
local function set_plugin_reset_func(name, func)
  assert(type(name) == 'string', 'vim.config: argument #1 for reset_func must be a string')
  assert(type(func) == 'function', 'vim.config: argument #2 for reset_func must be a function')
  reset_fn[name] = func
end

-------------------------------------------------------------------------------
--- Set the function to be called when querying plugin options.
---@private
---@param name string: plugin name
---@param func function: plugin query function
local function set_plugin_query_func(name, func)
  assert(type(name) == 'string', 'vim.config: argument #1 for query_func must be a string')
  assert(type(func) == 'function', 'vim.config: argument #2 for query_func must be a function')
  query_fn[name] = func
end


-------------------------------------------------------------------------------
--- Set the function to be called when disabling/enabling plugin.
---@private
---@param name string: plugin name
---@param func function: plugin enable function
local function set_plugin_enable_func(name, func)
  assert(type(name) == 'string', 'vim.config: argument #1 for enable_func must be a string')
  assert(type(func) == 'function', 'vim.config: argument #2 for enable_func must be a function')
  enable_fn[name] = func
end


----------------------------------------------------------------------------------------------------
-- Display configurations in popup
----------------------------------------------------------------------------------------------------

---@private
local function foldtext()
  local l = fn.getline(vim.v.foldstart)
  if l:find('^%w.*update%(s%)') then
    return string.format('%s [%d update(s)]', l:match('^%S+'), l:match('%s+(%d+)'))
  else
    return l:match('^%S+')
  end
end

---@private
local function foldexpr()
  local l = fn.getline(vim.v.lnum)
  if l:find('^%w') then
    return 1
  else
    return '='
  end
end

-------------------------------------------------------------------------------
--- Print configuration for a specific plugin in a popup window.
--- If `name` isn't given, print all configurations.
---@param name string
---@private
local function display_configs(name)
  if name and not configs[name] then
    print(fmt("vim.config: no configuration for '%s'", name))
    return
  elseif next(configs) == nil then
    print('vim.config: no configured plugins')
    return
  end
  local buf = a.nvim_create_buf(false, true)
  local text = {}
  for pname, cfg in pairs(name and { configs[name] } or configs) do
    local t = traces[pname]
    if type(t) == "table" then
      local u = fmt('updated %s time(s)', #t)
      insert(text, fmt('%s%10s%70s', pname, enabled[pname] and "" or "DISABLED", u))
      insert(text, '')
      -- add informations about sourcing scripts, options set
      for _, v in ipairs(t) do
        insert(
          text,
          fmt(
            '  %s %s => %s %s',
            v[1], -- time
            v[2], -- script path
            v[3], -- mode (keep/replace/DEFAULT)
            v[4]:gsub('\n', ' '):gsub('%s+', ' ')
          )
        )
      end
    else
      insert(text, pname)
    end
    insert(text, '')
    insert(text, '  has setup function?   ' .. (setup_fn[pname] and "🗸" or "✘"))
    insert(text, '  has reset function?   ' .. (reset_fn[pname] and "🗸" or "✘"))
    insert(text, '  has query function?   ' .. (query_fn[pname] and "🗸" or "✘"))
    insert(text, '  has enable function?  ' .. (enable_fn[pname] and "🗸" or "✘"))
    insert(text, '')
    for _, line in ipairs(vim.split(vim.inspect(cfg), '\n')) do
      insert(text, line)
    end
  end
  a.nvim_buf_set_lines(buf, 0, 1, true, text)
  local win = a.nvim_open_win(buf, true, {
    relative = 'editor',
    width = 120,
    height = #text,
    row = vim.o.lines / 2 - #text / 2,
    col = vim.o.columns / 2 - 60,
    style = 'minimal',
    border = 'single',
  })
  bufopt(buf, 'tabstop', 2)
  bufopt(buf, 'shiftwidth', 2)
  bufopt(buf, 'softtabstop', 2)
  bufopt(buf, 'expandtab', true)
  winopt(win, 'foldexpr', 'v:lua.vim.config().foldexpr()')
  winopt(win, 'foldmethod', 'expr')
  winopt(win, 'foldenable', true)
  winopt(win, 'foldtext', 'v:lua.vim.config().foldtext()')
  winopt(win, 'fillchars', 'fold: ,eob: ')
  winopt(win, 'winhighlight', 'NormalFloat:Pmenu,Folded:PmenuSel')
  a.nvim_win_call(win, function()
    vim.cmd[[
    syn keyword ConfigPluginDisabled DISABLED
    syn match ConfigPluginName "^\k\+"
    syn match ConfigPluginTrace "^  \d\d:.*" contains=ConfigPluginTime
    syn match ConfigPluginTime "\d\d:\d\d:\d\d" nextgroup=ConfigPluginFile contained
    syn match ConfigPluginFile ".*\ze=>" nextgroup=ConfigPluginArrow contained
    syn match ConfigPluginArrow "\s*=>." nextgroup=ConfigPluginMode contained
    syn match ConfigPluginMode "\w\+" nextgroup=ConfigPluginOptsSet contained
    syn match ConfigPluginOptsSet ".*" contained
    syn match ConfigPluginHasFn "^  has \w\+ function?\s*" nextgroup=ConfigPluginYes,ConfigPluginNo
    syn match ConfigPluginYes "🗸" contained
    syn match ConfigPluginNo "✘" contained
    syn region ConfigPluginOptions start="^{" end="^}"
    hi default link ConfigPluginName Identifier
    hi default link ConfigPluginDisabled Error
    hi default link ConfigPluginTime Comment
    hi default link ConfigPluginOptions String
    hi default link ConfigPluginFile String
    hi default link ConfigPluginMode Constant
    hi default ConfigPluginHasFn gui=italic cterm=italic
    hi default ConfigPluginYes guifg=#00af00 ctermfg=34
    hi default ConfigPluginNo guifg=#ff0000 ctermfg=9
    ]]
  end)
end

-------------------------------------------------------------------------------
--- Return module
return setmetatable({}, {
  __metatable = false,
  __index = plugin_cfg_func,
  __newindex = function()
    error('vim.config: access to this table is restricted')
  end,
  __call = function()
    return {
      loaded = plugin_loaded,
      enabled = plugin_enabled,
      get = get_copy_of_plugin_cfg,
      reset = reset_config,
      query = query_config,
      enable = enable_plugin,
      setup_func = set_plugin_setup_func,
      reset_func = set_plugin_reset_func,
      query_func = set_plugin_query_func,
      enable_func = set_plugin_enable_func,
      info = display_configs,
      foldtext = foldtext,
      foldexpr = foldexpr,
    }
  end,
})
