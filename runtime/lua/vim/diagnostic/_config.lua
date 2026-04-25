local store = require('vim.diagnostic._store')

--- @class vim.diagnostic.OptsResolved
--- @field float vim.diagnostic.Opts.Float
--- @field update_in_insert boolean
--- @field underline vim.diagnostic.Opts.Underline
--- @field virtual_text vim.diagnostic.Opts.VirtualText
--- @field virtual_lines vim.diagnostic.Opts.VirtualLines
--- @field signs vim.diagnostic.Opts.Signs
--- @field severity_sort {reverse?:boolean}

--- @class (private) vim.diagnostic._config
local M = {}

--- @type vim.diagnostic.Opts
local global_diagnostic_options = {
  signs = true,
  underline = true,
  virtual_text = false,
  virtual_lines = false,
  float = true,
  update_in_insert = false,
  severity_sort = false,
  jump = {
    -- Wrap around buffer
    wrap = true,
  },
}

--- @param name 'signs'|'underline'|'virtual_text'|'virtual_lines'|'float'
function M.enable_handler(name)
  if global_diagnostic_options[name] == nil then
    global_diagnostic_options[name] = true
  end
end

--- @param option string
--- @param namespace integer?
--- @return table
local function enabled_value(option, namespace)
  local ns = namespace and vim.diagnostic.get_namespace(namespace) or {}
  if ns.opts and type(ns.opts[option]) == 'table' then
    return ns.opts[option]
  end

  local global_opt = global_diagnostic_options[option]
  if type(global_opt) == 'table' then
    return global_opt
  end

  return {}
end

--- @param option string
--- @param value any?
--- @param namespace integer?
--- @param bufnr integer
--- @return any
local function resolve_optional_value(option, value, namespace, bufnr)
  if not value then
    return false
  elseif value == true then
    return enabled_value(option, namespace)
  elseif type(value) == 'function' then
    local val = value(namespace, bufnr) --- @type any
    if val == true then
      return enabled_value(option, namespace)
    else
      return val
    end
  elseif type(value) == 'table' then
    return value
  end
  error('Unexpected option type: ' .. vim.inspect(value))
end

--- @param opts vim.diagnostic.Opts?
--- @param namespace integer?
--- @param bufnr integer
--- @return vim.diagnostic.OptsResolved
function M.get_resolved_options(opts, namespace, bufnr)
  local ns = namespace and vim.diagnostic.get_namespace(namespace) or {}
  -- Do not use tbl_deep_extend so that an empty table can be used to reset to default values
  local resolved = vim.tbl_extend('keep', opts or {}, ns.opts or {}, global_diagnostic_options) --- @type table<string,any>
  for k in pairs(global_diagnostic_options) do
    if resolved[k] ~= nil then
      resolved[k] = resolve_optional_value(k, resolved[k], namespace, bufnr)
    end
  end
  return resolved --[[@as vim.diagnostic.OptsResolved]]
end

--- @param opts vim.diagnostic.Opts? When omitted or `nil`, retrieve the current
---       configuration. Otherwise, a configuration table (see |vim.diagnostic.Opts|).
--- @param namespace integer? Update the options for the given namespace.
---                          When omitted, update the global diagnostic options.
--- @return vim.diagnostic.Opts? : Current diagnostic config if {opts} is omitted.
function M.config(opts, namespace)
  vim.validate('opts', opts, 'table', true)
  vim.validate('namespace', namespace, 'number', true)

  local t --- @type vim.diagnostic.Opts
  if namespace then
    local ns = vim.diagnostic.get_namespace(namespace)
    t = ns.opts
  else
    t = global_diagnostic_options
  end

  if not opts then
    -- Return current config
    return vim.deepcopy(t, true)
  end

  local jump_opts = opts.jump --[[@as vim.diagnostic.JumpOpts1]]
  if jump_opts and jump_opts.float ~= nil then --- @diagnostic disable-line
    vim.deprecate('opts.jump.float', 'opts.jump.on_jump', '0.14')

    local float_opts = jump_opts.float
    if float_opts then
      float_opts = type(float_opts) == 'table' and float_opts or {}

      jump_opts.on_jump = function(_, bufnr)
        vim.diagnostic.open_float(vim.tbl_extend('keep', float_opts, {
          bufnr = bufnr,
          scope = 'cursor',
          focus = false,
        }))
      end
    end

    opts.jump.float = nil --- @diagnostic disable-line
  end

  for k, v in
    pairs(opts --[[@as table<any,any>]])
  do
    t[k] = v
  end

  if namespace then
    for _, bufnr in ipairs(store.get_bufnrs()) do
      local namespaces = store.get_buf_namespaces(bufnr)
      if vim.list_contains(namespaces, namespace) then
        vim.diagnostic.show(namespace, bufnr)
      end
    end
  else
    for _, bufnr in ipairs(store.get_bufnrs()) do
      for _, ns in ipairs(store.get_buf_namespaces(bufnr)) do
        vim.diagnostic.show(ns, bufnr)
      end
    end
  end
end

return M
