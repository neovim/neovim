local api = vim.api

local diagnostic_modules = vim._defer_require('vim.diagnostic', {
  _config = ..., --- @module 'vim.diagnostic._config'
  _severity = ..., --- @module 'vim.diagnostic._severity'
  _shared = ..., --- @module 'vim.diagnostic._shared'
  _store = ..., --- @module 'vim.diagnostic._store'
})

--- @class (private) vim.diagnostic._display
local M = {}

-- Metatable that automatically creates an empty table when assigning to a missing key
local bufnr_and_namespace_cacher_mt = {
  --- @param t table<integer,table>
  --- @param bufnr integer
  --- @return table
  __index = function(t, bufnr)
    assert(bufnr > 0, 'Invalid buffer number')
    t[bufnr] = {}
    return t[bufnr]
  end,
}

--- @type table<integer,table<integer,table>>
local bufs_waiting_to_update = setmetatable({}, bufnr_and_namespace_cacher_mt)

--- @type table<string,true>
local registered_autocmds = {}

--- Table of autocmd events to fire the update for displaying new diagnostic information
local insert_leave_auto_cmds = { 'InsertLeave', 'CursorHoldI' }

--- @param namespace integer
--- @param bufnr integer
--- @return string
local function make_augroup_key(namespace, bufnr)
  local ns = vim.diagnostic.get_namespace(namespace)
  return string.format('nvim.diagnostic.insertleave.%s.%s', bufnr, ns.name)
end

--- @param namespace integer
--- @param bufnr integer
local function execute_scheduled_display(namespace, bufnr)
  local args = bufs_waiting_to_update[bufnr][namespace]
  if not args then
    return
  end

  -- Clear the args so we don't display unnecessarily.
  bufs_waiting_to_update[bufnr][namespace] = nil

  M.show(namespace, bufnr, nil, args)
end

--- @param namespace integer
--- @param bufnr integer
--- @param args vim.diagnostic.OptsResolved
local function schedule_display(namespace, bufnr, args)
  bufs_waiting_to_update[bufnr][namespace] = args

  local key = make_augroup_key(namespace, bufnr)
  if not registered_autocmds[key] then
    local group = api.nvim_create_augroup(key, { clear = true })
    api.nvim_create_autocmd(insert_leave_auto_cmds, {
      group = group,
      buf = bufnr,
      callback = function()
        execute_scheduled_display(namespace, bufnr)
      end,
      desc = 'vim.diagnostic: display diagnostics',
    })
    registered_autocmds[key] = true
  end
end

--- @param namespace integer
--- @param bufnr integer
local function clear_scheduled_display(namespace, bufnr)
  local key = make_augroup_key(namespace, bufnr)

  if registered_autocmds[key] then
    api.nvim_del_augroup_by_name(key)
    registered_autocmds[key] = nil
  end
end

--- @param namespace integer? Diagnostic namespace. When omitted, hide
---                          diagnostics from all namespaces.
--- @param bufnr integer? Buffer number, or 0 for current buffer. When
---                      omitted, hide diagnostics in all buffers.
function M.hide(namespace, bufnr)
  vim.validate('namespace', namespace, 'number', true)
  vim.validate('bufnr', bufnr, 'number', true)

  local buffers = bufnr and { vim._resolve_bufnr(bufnr) } or diagnostic_modules._store.get_bufnrs()
  for _, iter_bufnr in ipairs(buffers) do
    local namespaces = namespace and { namespace }
      or diagnostic_modules._store.get_buf_namespaces(iter_bufnr)
    for _, iter_namespace in ipairs(namespaces) do
      for _, handler in pairs(vim.diagnostic.handlers) do
        if handler.hide then
          handler.hide(iter_namespace, iter_bufnr)
        end
      end
    end
  end
end

--- @param namespace integer? Diagnostic namespace. When omitted, show
---                          diagnostics from all namespaces.
--- @param bufnr integer? Buffer number, or 0 for current buffer. When omitted, show
---                      diagnostics in all buffers.
--- @param diagnostics vim.Diagnostic[]? The diagnostics to display. When omitted, use the
---                             saved diagnostics for the given namespace and
---                             buffer. This can be used to display a list of diagnostics
---                             without saving them or to display only a subset of
---                             diagnostics. May not be used when {namespace}
---                             or {bufnr} is nil.
--- @param opts? vim.diagnostic.Opts Display options.
function M.show(namespace, bufnr, diagnostics, opts)
  vim.validate('namespace', namespace, 'number', true)
  vim.validate('bufnr', bufnr, 'number', true)
  vim.validate('diagnostics', diagnostics, vim.islist, true, 'a list of diagnostics')
  vim.validate('opts', opts, 'table', true)

  if not bufnr or not namespace then
    assert(not diagnostics, 'Cannot show diagnostics without a buffer and namespace')
    if not bufnr then
      for _, iter_bufnr in ipairs(diagnostic_modules._store.get_bufnrs()) do
        M.show(namespace, iter_bufnr, nil, opts)
      end
    else
      -- namespace is nil
      bufnr = vim._resolve_bufnr(bufnr)
      for _, iter_namespace in ipairs(diagnostic_modules._store.get_buf_namespaces(bufnr)) do
        M.show(iter_namespace, bufnr, nil, opts)
      end
    end
    return
  end

  if not vim.diagnostic.is_enabled({ bufnr = bufnr or 0, ns_id = namespace }) then
    return
  end

  M.hide(namespace, bufnr)

  diagnostics = diagnostics
    or diagnostic_modules._store.get_diagnostics(bufnr, {
      namespace = namespace,
    }, true)

  if vim.tbl_isempty(diagnostics) then
    return
  end

  local opts_res = diagnostic_modules._config.get_resolved_options(opts, namespace, bufnr)

  if opts_res.update_in_insert then
    clear_scheduled_display(namespace, bufnr)
  else
    local mode = api.nvim_get_mode()
    if mode.mode:sub(1, 1) == 'i' then
      schedule_display(namespace, bufnr, opts_res)
      return
    end
  end

  if opts_res.severity_sort then
    if type(opts_res.severity_sort) == 'table' and opts_res.severity_sort.reverse then
      table.sort(diagnostics, function(a, b)
        return diagnostic_modules._shared.diagnostic_cmp(a, b, 'severity', false)
      end)
    else
      table.sort(diagnostics, function(a, b)
        return diagnostic_modules._shared.diagnostic_cmp(a, b, 'severity', true)
      end)
    end
  end

  for handler_name, handler in pairs(vim.diagnostic.handlers) do
    if handler.show and opts_res[handler_name] then
      local filtered = diagnostic_modules._severity.filter_by_severity(
        opts_res[handler_name].severity,
        diagnostics
      )
      handler.show(namespace, bufnr, filtered, opts_res)
    end
  end
end

return M
