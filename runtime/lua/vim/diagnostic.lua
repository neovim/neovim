local if_nil = vim.F.if_nil

local M = {}

M.severity = {
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  HINT = 4,
}

vim.tbl_add_reverse_lookup(M.severity)

-- Mappings from qflist/loclist error types to severities
M.severity.E = M.severity.ERROR
M.severity.W = M.severity.WARN
M.severity.I = M.severity.INFO
M.severity.N = M.severity.HINT

local global_diagnostic_options = {
  signs = true,
  underline = true,
  virtual_text = true,
  float = true,
  update_in_insert = false,
  severity_sort = false,
}

M.handlers = setmetatable({}, {
  __newindex = function(t, name, handler)
    vim.validate({ handler = { handler, 't' } })
    rawset(t, name, handler)
    if global_diagnostic_options[name] == nil then
      global_diagnostic_options[name] = true
    end
  end,
})

-- Metatable that automatically creates an empty table when assigning to a missing key
local bufnr_and_namespace_cacher_mt = {
  __index = function(t, bufnr)
    assert(bufnr > 0, 'Invalid buffer number')
    t[bufnr] = {}
    return t[bufnr]
  end,
}

local diagnostic_cache = setmetatable({}, {
  __index = function(t, bufnr)
    assert(bufnr > 0, 'Invalid buffer number')
    vim.api.nvim_buf_attach(bufnr, false, {
      on_detach = function()
        rawset(t, bufnr, nil) -- clear cache
      end,
    })
    t[bufnr] = {}
    return t[bufnr]
  end,
})

local diagnostic_cache_extmarks = setmetatable({}, bufnr_and_namespace_cacher_mt)
local diagnostic_attached_buffers = {}
local diagnostic_disabled = {}
local bufs_waiting_to_update = setmetatable({}, bufnr_and_namespace_cacher_mt)

local all_namespaces = {}

---@private
local function to_severity(severity)
  if type(severity) == 'string' then
    return assert(
      M.severity[string.upper(severity)],
      string.format('Invalid severity: %s', severity)
    )
  end
  return severity
end

---@private
local function filter_by_severity(severity, diagnostics)
  if not severity then
    return diagnostics
  end

  if type(severity) ~= 'table' then
    severity = to_severity(severity)
    return vim.tbl_filter(function(t)
      return t.severity == severity
    end, diagnostics)
  end

  local min_severity = to_severity(severity.min) or M.severity.HINT
  local max_severity = to_severity(severity.max) or M.severity.ERROR

  return vim.tbl_filter(function(t)
    return t.severity <= min_severity and t.severity >= max_severity
  end, diagnostics)
end

---@private
local function count_sources(bufnr)
  local seen = {}
  local count = 0
  for _, namespace_diagnostics in pairs(diagnostic_cache[bufnr]) do
    for _, diagnostic in ipairs(namespace_diagnostics) do
      if diagnostic.source and not seen[diagnostic.source] then
        seen[diagnostic.source] = true
        count = count + 1
      end
    end
  end
  return count
end

---@private
local function prefix_source(diagnostics)
  return vim.tbl_map(function(d)
    if not d.source then
      return d
    end

    local t = vim.deepcopy(d)
    t.message = string.format('%s: %s', d.source, d.message)
    return t
  end, diagnostics)
end

---@private
local function reformat_diagnostics(format, diagnostics)
  vim.validate({
    format = { format, 'f' },
    diagnostics = { diagnostics, 't' },
  })

  local formatted = vim.deepcopy(diagnostics)
  for _, diagnostic in ipairs(formatted) do
    diagnostic.message = format(diagnostic)
  end
  return formatted
end

---@private
local function enabled_value(option, namespace)
  local ns = namespace and M.get_namespace(namespace) or {}
  if ns.opts and type(ns.opts[option]) == 'table' then
    return ns.opts[option]
  end

  if type(global_diagnostic_options[option]) == 'table' then
    return global_diagnostic_options[option]
  end

  return {}
end

---@private
local function resolve_optional_value(option, value, namespace, bufnr)
  if not value then
    return false
  elseif value == true then
    return enabled_value(option, namespace)
  elseif type(value) == 'function' then
    local val = value(namespace, bufnr)
    if val == true then
      return enabled_value(option, namespace)
    else
      return val
    end
  elseif type(value) == 'table' then
    return value
  else
    error('Unexpected option type: ' .. vim.inspect(value))
  end
end

---@private
local function get_resolved_options(opts, namespace, bufnr)
  local ns = namespace and M.get_namespace(namespace) or {}
  -- Do not use tbl_deep_extend so that an empty table can be used to reset to default values
  local resolved = vim.tbl_extend('keep', opts or {}, ns.opts or {}, global_diagnostic_options)
  for k in pairs(global_diagnostic_options) do
    if resolved[k] ~= nil then
      resolved[k] = resolve_optional_value(k, resolved[k], namespace, bufnr)
    end
  end
  return resolved
end

-- Default diagnostic highlights
local diagnostic_severities = {
  [M.severity.ERROR] = { ctermfg = 1, guifg = 'Red' },
  [M.severity.WARN] = { ctermfg = 3, guifg = 'Orange' },
  [M.severity.INFO] = { ctermfg = 4, guifg = 'LightBlue' },
  [M.severity.HINT] = { ctermfg = 7, guifg = 'LightGrey' },
}

-- Make a map from DiagnosticSeverity -> Highlight Name
---@private
local function make_highlight_map(base_name)
  local result = {}
  for k in pairs(diagnostic_severities) do
    local name = M.severity[k]
    name = name:sub(1, 1) .. name:sub(2):lower()
    result[k] = 'Diagnostic' .. base_name .. name
  end

  return result
end

local virtual_text_highlight_map = make_highlight_map('VirtualText')
local underline_highlight_map = make_highlight_map('Underline')
local floating_highlight_map = make_highlight_map('Floating')
local sign_highlight_map = make_highlight_map('Sign')

---@private
local define_default_signs = (function()
  local signs_defined = false
  return function()
    if signs_defined then
      return
    end

    for severity, sign_hl_name in pairs(sign_highlight_map) do
      if vim.tbl_isempty(vim.fn.sign_getdefined(sign_hl_name)) then
        local severity_name = M.severity[severity]
        vim.fn.sign_define(sign_hl_name, {
          text = (severity_name or 'U'):sub(1, 1),
          texthl = sign_hl_name,
          linehl = '',
          numhl = '',
        })
      end
    end

    signs_defined = true
  end
end)()

---@private
local function get_bufnr(bufnr)
  if not bufnr or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

---@private
local function is_disabled(namespace, bufnr)
  local ns = M.get_namespace(namespace)
  if ns.disabled then
    return true
  end

  if type(diagnostic_disabled[bufnr]) == 'table' then
    return diagnostic_disabled[bufnr][namespace]
  end
  return diagnostic_disabled[bufnr]
end

---@private
local function diagnostic_lines(diagnostics)
  if not diagnostics then
    return {}
  end

  local diagnostics_by_line = {}
  for _, diagnostic in ipairs(diagnostics) do
    local line_diagnostics = diagnostics_by_line[diagnostic.lnum]
    if not line_diagnostics then
      line_diagnostics = {}
      diagnostics_by_line[diagnostic.lnum] = line_diagnostics
    end
    table.insert(line_diagnostics, diagnostic)
  end
  return diagnostics_by_line
end

---@private
local function set_diagnostic_cache(namespace, bufnr, diagnostics)
  for _, diagnostic in ipairs(diagnostics) do
    assert(diagnostic.lnum, 'Diagnostic line number is required')
    assert(diagnostic.col, 'Diagnostic column is required')
    diagnostic.severity = diagnostic.severity and to_severity(diagnostic.severity)
      or M.severity.ERROR
    diagnostic.end_lnum = diagnostic.end_lnum or diagnostic.lnum
    diagnostic.end_col = diagnostic.end_col or diagnostic.col
    diagnostic.namespace = namespace
    diagnostic.bufnr = bufnr
  end
  diagnostic_cache[bufnr][namespace] = diagnostics
end

---@private
local function restore_extmarks(bufnr, last)
  for ns, extmarks in pairs(diagnostic_cache_extmarks[bufnr]) do
    local extmarks_current = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
    local found = {}
    for _, extmark in ipairs(extmarks_current) do
      -- nvim_buf_set_lines will move any extmark to the line after the last
      -- nvim_buf_set_text will move any extmark to the last line
      if extmark[2] ~= last + 1 then
        found[extmark[1]] = true
      end
    end
    for _, extmark in ipairs(extmarks) do
      if not found[extmark[1]] then
        local opts = extmark[4]
        opts.id = extmark[1]
        pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, extmark[2], extmark[3], opts)
      end
    end
  end
end

---@private
local function save_extmarks(namespace, bufnr)
  bufnr = get_bufnr(bufnr)
  if not diagnostic_attached_buffers[bufnr] then
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = function(_, _, _, _, _, last)
        restore_extmarks(bufnr, last - 1)
      end,
      on_detach = function()
        diagnostic_cache_extmarks[bufnr] = nil
      end,
    })
    diagnostic_attached_buffers[bufnr] = true
  end
  diagnostic_cache_extmarks[bufnr][namespace] =
    vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
end

local registered_autocmds = {}

---@private
local function make_augroup_key(namespace, bufnr)
  local ns = M.get_namespace(namespace)
  return string.format('DiagnosticInsertLeave:%s:%s', bufnr, ns.name)
end

---@private
local function execute_scheduled_display(namespace, bufnr)
  local args = bufs_waiting_to_update[bufnr][namespace]
  if not args then
    return
  end

  -- Clear the args so we don't display unnecessarily.
  bufs_waiting_to_update[bufnr][namespace] = nil

  M.show(namespace, bufnr, nil, args)
end

--- @deprecated
--- Callback scheduled when leaving Insert mode.
---
--- called from the Vimscript autocommand.
---
--- See @ref schedule_display()
---
---@private
function M._execute_scheduled_display(namespace, bufnr)
  vim.deprecate('vim.diagnostic._execute_scheduled_display', nil, '0.9')
  execute_scheduled_display(namespace, bufnr)
end

--- Table of autocmd events to fire the update for displaying new diagnostic information
local insert_leave_auto_cmds = { 'InsertLeave', 'CursorHoldI' }

---@private
local function schedule_display(namespace, bufnr, args)
  bufs_waiting_to_update[bufnr][namespace] = args

  local key = make_augroup_key(namespace, bufnr)
  if not registered_autocmds[key] then
    local group = vim.api.nvim_create_augroup(key, { clear = true })
    vim.api.nvim_create_autocmd(insert_leave_auto_cmds, {
      group = group,
      buffer = bufnr,
      callback = function()
        execute_scheduled_display(namespace, bufnr)
      end,
      desc = 'vim.diagnostic: display diagnostics',
    })
    registered_autocmds[key] = true
  end
end

---@private
local function clear_scheduled_display(namespace, bufnr)
  local key = make_augroup_key(namespace, bufnr)

  if registered_autocmds[key] then
    vim.api.nvim_del_augroup_by_name(key)
    registered_autocmds[key] = nil
  end
end

---@private
local function get_diagnostics(bufnr, opts, clamp)
  opts = opts or {}

  local namespace = opts.namespace
  local diagnostics = {}

  -- Memoized results of buf_line_count per bufnr
  local buf_line_count = setmetatable({}, {
    __index = function(t, k)
      t[k] = vim.api.nvim_buf_line_count(k)
      return rawget(t, k)
    end,
  })

  ---@private
  local function add(b, d)
    if not opts.lnum or d.lnum == opts.lnum then
      if clamp and vim.api.nvim_buf_is_loaded(b) then
        local line_count = buf_line_count[b] - 1
        if
          d.lnum > line_count
          or d.end_lnum > line_count
          or d.lnum < 0
          or d.end_lnum < 0
          or d.col < 0
          or d.end_col < 0
        then
          d = vim.deepcopy(d)
          d.lnum = math.max(math.min(d.lnum, line_count), 0)
          d.end_lnum = math.max(math.min(d.end_lnum, line_count), 0)
          d.col = math.max(d.col, 0)
          d.end_col = math.max(d.end_col, 0)
        end
      end
      table.insert(diagnostics, d)
    end
  end

  if namespace == nil and bufnr == nil then
    for b, t in pairs(diagnostic_cache) do
      for _, v in pairs(t) do
        for _, diagnostic in pairs(v) do
          add(b, diagnostic)
        end
      end
    end
  elseif namespace == nil then
    bufnr = get_bufnr(bufnr)
    for iter_namespace in pairs(diagnostic_cache[bufnr]) do
      for _, diagnostic in pairs(diagnostic_cache[bufnr][iter_namespace]) do
        add(bufnr, diagnostic)
      end
    end
  elseif bufnr == nil then
    for b, t in pairs(diagnostic_cache) do
      for _, diagnostic in pairs(t[namespace] or {}) do
        add(b, diagnostic)
      end
    end
  else
    bufnr = get_bufnr(bufnr)
    for _, diagnostic in pairs(diagnostic_cache[bufnr][namespace] or {}) do
      add(bufnr, diagnostic)
    end
  end

  if opts.severity then
    diagnostics = filter_by_severity(opts.severity, diagnostics)
  end

  return diagnostics
end

---@private
local function set_list(loclist, opts)
  opts = opts or {}
  local open = vim.F.if_nil(opts.open, true)
  local title = opts.title or 'Diagnostics'
  local winnr = opts.winnr or 0
  local bufnr
  if loclist then
    bufnr = vim.api.nvim_win_get_buf(winnr)
  end
  -- Don't clamp line numbers since the quickfix list can already handle line
  -- numbers beyond the end of the buffer
  local diagnostics = get_diagnostics(bufnr, opts, false)
  local items = M.toqflist(diagnostics)
  if loclist then
    vim.fn.setloclist(winnr, {}, ' ', { title = title, items = items })
  else
    vim.fn.setqflist({}, ' ', { title = title, items = items })
  end
  if open then
    vim.api.nvim_command(loclist and 'lopen' or 'botright copen')
  end
end

---@private
local function next_diagnostic(position, search_forward, bufnr, opts, namespace)
  position[1] = position[1] - 1
  bufnr = get_bufnr(bufnr)
  local wrap = vim.F.if_nil(opts.wrap, true)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local diagnostics =
    get_diagnostics(bufnr, vim.tbl_extend('keep', opts, { namespace = namespace }), true)
  local line_diagnostics = diagnostic_lines(diagnostics)
  for i = 0, line_count do
    local offset = i * (search_forward and 1 or -1)
    local lnum = position[1] + offset
    if lnum < 0 or lnum >= line_count then
      if not wrap then
        return
      end
      lnum = (lnum + line_count) % line_count
    end
    if line_diagnostics[lnum] and not vim.tbl_isempty(line_diagnostics[lnum]) then
      local line_length = #vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, true)[1]
      local sort_diagnostics, is_next
      if search_forward then
        sort_diagnostics = function(a, b)
          return a.col < b.col
        end
        is_next = function(d)
          return math.min(d.col, line_length - 1) > position[2]
        end
      else
        sort_diagnostics = function(a, b)
          return a.col > b.col
        end
        is_next = function(d)
          return math.min(d.col, line_length - 1) < position[2]
        end
      end
      table.sort(line_diagnostics[lnum], sort_diagnostics)
      if i == 0 then
        for _, v in pairs(line_diagnostics[lnum]) do
          if is_next(v) then
            return v
          end
        end
      else
        return line_diagnostics[lnum][1]
      end
    end
  end
end

---@private
local function diagnostic_move_pos(opts, pos)
  opts = opts or {}

  local float = vim.F.if_nil(opts.float, true)
  local win_id = opts.win_id or vim.api.nvim_get_current_win()

  if not pos then
    vim.api.nvim_echo({ { 'No more valid diagnostics to move to', 'WarningMsg' } }, true, {})
    return
  end

  vim.api.nvim_win_call(win_id, function()
    -- Save position in the window's jumplist
    vim.cmd("normal! m'")
    vim.api.nvim_win_set_cursor(win_id, { pos[1] + 1, pos[2] })
    -- Open folds under the cursor
    vim.cmd('normal! zv')
  end)

  if float then
    local float_opts = type(float) == 'table' and float or {}
    vim.schedule(function()
      M.open_float(vim.tbl_extend('keep', float_opts, {
        bufnr = vim.api.nvim_win_get_buf(win_id),
        scope = 'cursor',
        focus = false,
      }))
    end)
  end
end

--- Configure diagnostic options globally or for a specific diagnostic
--- namespace.
---
--- Configuration can be specified globally, per-namespace, or ephemerally
--- (i.e. only for a single call to |vim.diagnostic.set()| or
--- |vim.diagnostic.show()|). Ephemeral configuration has highest priority,
--- followed by namespace configuration, and finally global configuration.
---
--- For example, if a user enables virtual text globally with
--- <pre>
---   vim.diagnostic.config({ virtual_text = true })
--- </pre>
---
--- and a diagnostic producer sets diagnostics with
--- <pre>
---   vim.diagnostic.set(ns, 0, diagnostics, { virtual_text = false })
--- </pre>
---
--- then virtual text will not be enabled for those diagnostics.
---
---@note Each of the configuration options below accepts one of the following:
---         - `false`: Disable this feature
---         - `true`: Enable this feature, use default settings.
---         - `table`: Enable this feature with overrides. Use an empty table to use default values.
---         - `function`: Function with signature (namespace, bufnr) that returns any of the above.
---
---@param opts table|nil When omitted or "nil", retrieve the current configuration. Otherwise, a
---                      configuration table with the following keys:
---       - underline: (default true) Use underline for diagnostics. Options:
---                    * severity: Only underline diagnostics matching the given severity
---                    |diagnostic-severity|
---       - virtual_text: (default true) Use virtual text for diagnostics. If multiple diagnostics
---                       are set for a namespace, one prefix per diagnostic + the last diagnostic
---                       message are shown.
---                       Options:
---                       * severity: Only show virtual text for diagnostics matching the given
---                       severity |diagnostic-severity|
---                       * source: (boolean or string) Include the diagnostic source in virtual
---                                 text. Use "if_many" to only show sources if there is more than
---                                 one diagnostic source in the buffer. Otherwise, any truthy value
---                                 means to always show the diagnostic source.
---                       * spacing: (number) Amount of empty spaces inserted at the beginning
---                                  of the virtual text.
---                       * prefix: (string) Prepend diagnostic message with prefix.
---                       * format: (function) A function that takes a diagnostic as input and
---                                 returns a string. The return value is the text used to display
---                                 the diagnostic. Example:
---                       <pre>
---                       function(diagnostic)
---                         if diagnostic.severity == vim.diagnostic.severity.ERROR then
---                           return string.format("E: %s", diagnostic.message)
---                         end
---                         return diagnostic.message
---                       end
---                       </pre>
---       - signs: (default true) Use signs for diagnostics. Options:
---                * severity: Only show signs for diagnostics matching the given severity
---                |diagnostic-severity|
---                * priority: (number, default 10) Base priority to use for signs. When
---                {severity_sort} is used, the priority of a sign is adjusted based on
---                its severity. Otherwise, all signs use the same priority.
---       - float: Options for floating windows. See |vim.diagnostic.open_float()|.
---       - update_in_insert: (default false) Update diagnostics in Insert mode (if false,
---                           diagnostics are updated on InsertLeave)
---       - severity_sort: (default false) Sort diagnostics by severity. This affects the order in
---                         which signs and virtual text are displayed. When true, higher severities
---                         are displayed before lower severities (e.g. ERROR is displayed before WARN).
---                         Options:
---                         * reverse: (boolean) Reverse sort order
---
---@param namespace number|nil Update the options for the given namespace. When omitted, update the
---                            global diagnostic options.
function M.config(opts, namespace)
  vim.validate({
    opts = { opts, 't', true },
    namespace = { namespace, 'n', true },
  })

  local t
  if namespace then
    local ns = M.get_namespace(namespace)
    t = ns.opts
  else
    t = global_diagnostic_options
  end

  if not opts then
    -- Return current config
    return vim.deepcopy(t)
  end

  for k, v in pairs(opts) do
    t[k] = v
  end

  if namespace then
    for bufnr, v in pairs(diagnostic_cache) do
      if vim.api.nvim_buf_is_loaded(bufnr) and v[namespace] then
        M.show(namespace, bufnr)
      end
    end
  else
    for bufnr, v in pairs(diagnostic_cache) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        for ns in pairs(v) do
          M.show(ns, bufnr)
        end
      end
    end
  end
end

--- Set diagnostics for the given namespace and buffer.
---
---@param namespace number The diagnostic namespace
---@param bufnr number Buffer number
---@param diagnostics table A list of diagnostic items |diagnostic-structure|
---@param opts table|nil Display options to pass to |vim.diagnostic.show()|
function M.set(namespace, bufnr, diagnostics, opts)
  vim.validate({
    namespace = { namespace, 'n' },
    bufnr = { bufnr, 'n' },
    diagnostics = {
      diagnostics,
      vim.tbl_islist,
      'a list of diagnostics',
    },
    opts = { opts, 't', true },
  })

  bufnr = get_bufnr(bufnr)

  if vim.tbl_isempty(diagnostics) then
    diagnostic_cache[bufnr][namespace] = nil
  else
    set_diagnostic_cache(namespace, bufnr, diagnostics)
  end

  if vim.api.nvim_buf_is_loaded(bufnr) then
    M.show(namespace, bufnr, nil, opts)
  end

  vim.api.nvim_exec_autocmds('DiagnosticChanged', {
    modeline = false,
    buffer = bufnr,
  })
end

--- Get namespace metadata.
---
---@param namespace number Diagnostic namespace
---@return table Namespace metadata
function M.get_namespace(namespace)
  vim.validate({ namespace = { namespace, 'n' } })
  if not all_namespaces[namespace] then
    local name
    for k, v in pairs(vim.api.nvim_get_namespaces()) do
      if namespace == v then
        name = k
        break
      end
    end

    assert(name, 'namespace does not exist or is anonymous')

    all_namespaces[namespace] = {
      name = name,
      opts = {},
      user_data = {},
    }
  end
  return all_namespaces[namespace]
end

--- Get current diagnostic namespaces.
---
---@return table A list of active diagnostic namespaces |vim.diagnostic|.
function M.get_namespaces()
  return vim.deepcopy(all_namespaces)
end

--- Get current diagnostics.
---
---@param bufnr number|nil Buffer number to get diagnostics from. Use 0 for
---                        current buffer or nil for all buffers.
---@param opts table|nil A table with the following keys:
---                        - namespace: (number) Limit diagnostics to the given namespace.
---                        - lnum: (number) Limit diagnostics to the given line number.
---                        - severity: See |diagnostic-severity|.
---@return table A list of diagnostic items |diagnostic-structure|.
function M.get(bufnr, opts)
  vim.validate({
    bufnr = { bufnr, 'n', true },
    opts = { opts, 't', true },
  })

  return get_diagnostics(bufnr, opts, false)
end

--- Get the previous diagnostic closest to the cursor position.
---
---@param opts table See |vim.diagnostic.goto_next()|
---@return table Previous diagnostic
function M.get_prev(opts)
  opts = opts or {}

  local win_id = opts.win_id or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  local cursor_position = opts.cursor_position or vim.api.nvim_win_get_cursor(win_id)

  return next_diagnostic(cursor_position, false, bufnr, opts, opts.namespace)
end

--- Return the position of the previous diagnostic in the current buffer.
---
---@param opts table See |vim.diagnostic.goto_next()|
---@return table Previous diagnostic position as a (row, col) tuple.
function M.get_prev_pos(opts)
  local prev = M.get_prev(opts)
  if not prev then
    return false
  end

  return { prev.lnum, prev.col }
end

--- Move to the previous diagnostic in the current buffer.
---@param opts table See |vim.diagnostic.goto_next()|
function M.goto_prev(opts)
  return diagnostic_move_pos(opts, M.get_prev_pos(opts))
end

--- Get the next diagnostic closest to the cursor position.
---
---@param opts table See |vim.diagnostic.goto_next()|
---@return table Next diagnostic
function M.get_next(opts)
  opts = opts or {}

  local win_id = opts.win_id or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  local cursor_position = opts.cursor_position or vim.api.nvim_win_get_cursor(win_id)

  return next_diagnostic(cursor_position, true, bufnr, opts, opts.namespace)
end

--- Return the position of the next diagnostic in the current buffer.
---
---@param opts table See |vim.diagnostic.goto_next()|
---@return table Next diagnostic position as a (row, col) tuple.
function M.get_next_pos(opts)
  local next = M.get_next(opts)
  if not next then
    return false
  end

  return { next.lnum, next.col }
end

--- Move to the next diagnostic.
---
---@param opts table|nil Configuration table with the following keys:
---         - namespace: (number) Only consider diagnostics from the given namespace.
---         - cursor_position: (cursor position) Cursor position as a (row, col) tuple. See
---                          |nvim_win_get_cursor()|. Defaults to the current cursor position.
---         - wrap: (boolean, default true) Whether to loop around file or not. Similar to 'wrapscan'.
---         - severity: See |diagnostic-severity|.
---         - float: (boolean or table, default true) If "true", call |vim.diagnostic.open_float()|
---                    after moving. If a table, pass the table as the {opts} parameter to
---                    |vim.diagnostic.open_float()|. Unless overridden, the float will show
---                    diagnostics at the new cursor position (as if "cursor" were passed to
---                    the "scope" option).
---         - win_id: (number, default 0) Window ID
function M.goto_next(opts)
  return diagnostic_move_pos(opts, M.get_next_pos(opts))
end

M.handlers.signs = {
  show = function(namespace, bufnr, diagnostics, opts)
    vim.validate({
      namespace = { namespace, 'n' },
      bufnr = { bufnr, 'n' },
      diagnostics = {
        diagnostics,
        vim.tbl_islist,
        'a list of diagnostics',
      },
      opts = { opts, 't', true },
    })

    bufnr = get_bufnr(bufnr)
    opts = opts or {}

    if opts.signs and opts.signs.severity then
      diagnostics = filter_by_severity(opts.signs.severity, diagnostics)
    end

    define_default_signs()

    -- 10 is the default sign priority when none is explicitly specified
    local priority = opts.signs and opts.signs.priority or 10
    local get_priority
    if opts.severity_sort then
      if type(opts.severity_sort) == 'table' and opts.severity_sort.reverse then
        get_priority = function(severity)
          return priority + (severity - vim.diagnostic.severity.ERROR)
        end
      else
        get_priority = function(severity)
          return priority + (vim.diagnostic.severity.HINT - severity)
        end
      end
    else
      get_priority = function()
        return priority
      end
    end

    local ns = M.get_namespace(namespace)
    if not ns.user_data.sign_group then
      ns.user_data.sign_group = string.format('vim.diagnostic.%s', ns.name)
    end

    local sign_group = ns.user_data.sign_group
    for _, diagnostic in ipairs(diagnostics) do
      vim.fn.sign_place(0, sign_group, sign_highlight_map[diagnostic.severity], bufnr, {
        priority = get_priority(diagnostic.severity),
        lnum = diagnostic.lnum + 1,
      })
    end
  end,
  hide = function(namespace, bufnr)
    local ns = M.get_namespace(namespace)
    if ns.user_data.sign_group then
      vim.fn.sign_unplace(ns.user_data.sign_group, { buffer = bufnr })
    end
  end,
}

M.handlers.underline = {
  show = function(namespace, bufnr, diagnostics, opts)
    vim.validate({
      namespace = { namespace, 'n' },
      bufnr = { bufnr, 'n' },
      diagnostics = {
        diagnostics,
        vim.tbl_islist,
        'a list of diagnostics',
      },
      opts = { opts, 't', true },
    })

    bufnr = get_bufnr(bufnr)
    opts = opts or {}

    if opts.underline and opts.underline.severity then
      diagnostics = filter_by_severity(opts.underline.severity, diagnostics)
    end

    local ns = M.get_namespace(namespace)
    if not ns.user_data.underline_ns then
      ns.user_data.underline_ns = vim.api.nvim_create_namespace('')
    end

    local underline_ns = ns.user_data.underline_ns
    for _, diagnostic in ipairs(diagnostics) do
      local higroup = underline_highlight_map[diagnostic.severity]

      if higroup == nil then
        -- Default to error if we don't have a highlight associated
        higroup = underline_highlight_map.Error
      end

      vim.highlight.range(
        bufnr,
        underline_ns,
        higroup,
        { diagnostic.lnum, diagnostic.col },
        { diagnostic.end_lnum, diagnostic.end_col },
        { priority = vim.highlight.priorities.diagnostics }
      )
    end
    save_extmarks(underline_ns, bufnr)
  end,
  hide = function(namespace, bufnr)
    local ns = M.get_namespace(namespace)
    if ns.user_data.underline_ns then
      diagnostic_cache_extmarks[bufnr][ns.user_data.underline_ns] = {}
      vim.api.nvim_buf_clear_namespace(bufnr, ns.user_data.underline_ns, 0, -1)
    end
  end,
}

M.handlers.virtual_text = {
  show = function(namespace, bufnr, diagnostics, opts)
    vim.validate({
      namespace = { namespace, 'n' },
      bufnr = { bufnr, 'n' },
      diagnostics = {
        diagnostics,
        vim.tbl_islist,
        'a list of diagnostics',
      },
      opts = { opts, 't', true },
    })

    bufnr = get_bufnr(bufnr)
    opts = opts or {}

    local severity
    if opts.virtual_text then
      if opts.virtual_text.format then
        diagnostics = reformat_diagnostics(opts.virtual_text.format, diagnostics)
      end
      if
        opts.virtual_text.source
        and (opts.virtual_text.source ~= 'if_many' or count_sources(bufnr) > 1)
      then
        diagnostics = prefix_source(diagnostics)
      end
      if opts.virtual_text.severity then
        severity = opts.virtual_text.severity
      end
    end

    local ns = M.get_namespace(namespace)
    if not ns.user_data.virt_text_ns then
      ns.user_data.virt_text_ns = vim.api.nvim_create_namespace('')
    end

    local virt_text_ns = ns.user_data.virt_text_ns
    local buffer_line_diagnostics = diagnostic_lines(diagnostics)
    for line, line_diagnostics in pairs(buffer_line_diagnostics) do
      if severity then
        line_diagnostics = filter_by_severity(severity, line_diagnostics)
      end
      local virt_texts = M._get_virt_text_chunks(line_diagnostics, opts.virtual_text)

      if virt_texts then
        vim.api.nvim_buf_set_extmark(bufnr, virt_text_ns, line, 0, {
          hl_mode = 'combine',
          virt_text = virt_texts,
        })
      end
    end
    save_extmarks(virt_text_ns, bufnr)
  end,
  hide = function(namespace, bufnr)
    local ns = M.get_namespace(namespace)
    if ns.user_data.virt_text_ns then
      diagnostic_cache_extmarks[bufnr][ns.user_data.virt_text_ns] = {}
      vim.api.nvim_buf_clear_namespace(bufnr, ns.user_data.virt_text_ns, 0, -1)
    end
  end,
}

--- Get virtual text chunks to display using |nvim_buf_set_extmark()|.
---
--- Exported for backward compatibility with
--- vim.lsp.diagnostic.get_virtual_text_chunks_for_line(). When that function is eventually removed,
--- this can be made local.
---@private
function M._get_virt_text_chunks(line_diags, opts)
  if #line_diags == 0 then
    return nil
  end

  opts = opts or {}
  local prefix = opts.prefix or '■'
  local spacing = opts.spacing or 4

  -- Create a little more space between virtual text and contents
  local virt_texts = { { string.rep(' ', spacing) } }

  for i = 1, #line_diags - 1 do
    table.insert(virt_texts, { prefix, virtual_text_highlight_map[line_diags[i].severity] })
  end
  local last = line_diags[#line_diags]

  -- TODO(tjdevries): Allow different servers to be shown first somehow?
  -- TODO(tjdevries): Display server name associated with these?
  if last.message then
    table.insert(virt_texts, {
      string.format('%s %s', prefix, last.message:gsub('\r', ''):gsub('\n', '  ')),
      virtual_text_highlight_map[last.severity],
    })

    return virt_texts
  end
end

--- Hide currently displayed diagnostics.
---
--- This only clears the decorations displayed in the buffer. Diagnostics can
--- be redisplayed with |vim.diagnostic.show()|. To completely remove
--- diagnostics, use |vim.diagnostic.reset()|.
---
--- To hide diagnostics and prevent them from re-displaying, use
--- |vim.diagnostic.disable()|.
---
---@param namespace number|nil Diagnostic namespace. When omitted, hide
---                            diagnostics from all namespaces.
---@param bufnr number|nil Buffer number, or 0 for current buffer. When
---                        omitted, hide diagnostics in all buffers.
function M.hide(namespace, bufnr)
  vim.validate({
    namespace = { namespace, 'n', true },
    bufnr = { bufnr, 'n', true },
  })

  local buffers = bufnr and { get_bufnr(bufnr) } or vim.tbl_keys(diagnostic_cache)
  for _, iter_bufnr in ipairs(buffers) do
    local namespaces = namespace and { namespace } or vim.tbl_keys(diagnostic_cache[iter_bufnr])
    for _, iter_namespace in ipairs(namespaces) do
      for _, handler in pairs(M.handlers) do
        if handler.hide then
          handler.hide(iter_namespace, iter_bufnr)
        end
      end
    end
  end
end

--- Display diagnostics for the given namespace and buffer.
---
---@param namespace number|nil Diagnostic namespace. When omitted, show
---                            diagnostics from all namespaces.
---@param bufnr number|nil Buffer number, or 0 for current buffer. When omitted, show
---                        diagnostics in all buffers.
---@param diagnostics table|nil The diagnostics to display. When omitted, use the
---                             saved diagnostics for the given namespace and
---                             buffer. This can be used to display a list of diagnostics
---                             without saving them or to display only a subset of
---                             diagnostics. May not be used when {namespace}
---                             or {bufnr} is nil.
---@param opts table|nil Display options. See |vim.diagnostic.config()|.
function M.show(namespace, bufnr, diagnostics, opts)
  vim.validate({
    namespace = { namespace, 'n', true },
    bufnr = { bufnr, 'n', true },
    diagnostics = {
      diagnostics,
      function(v)
        return v == nil or vim.tbl_islist(v)
      end,
      'a list of diagnostics',
    },
    opts = { opts, 't', true },
  })

  if not bufnr or not namespace then
    assert(not diagnostics, 'Cannot show diagnostics without a buffer and namespace')
    if not bufnr then
      for iter_bufnr in pairs(diagnostic_cache) do
        M.show(namespace, iter_bufnr, nil, opts)
      end
    else
      -- namespace is nil
      bufnr = get_bufnr(bufnr)
      for iter_namespace in pairs(diagnostic_cache[bufnr]) do
        M.show(iter_namespace, bufnr, nil, opts)
      end
    end
    return
  end

  if is_disabled(namespace, bufnr) then
    return
  end

  M.hide(namespace, bufnr)

  diagnostics = diagnostics or get_diagnostics(bufnr, { namespace = namespace }, true)

  if not diagnostics or vim.tbl_isempty(diagnostics) then
    return
  end

  opts = get_resolved_options(opts, namespace, bufnr)

  if opts.update_in_insert then
    clear_scheduled_display(namespace, bufnr)
  else
    local mode = vim.api.nvim_get_mode()
    if string.sub(mode.mode, 1, 1) == 'i' then
      schedule_display(namespace, bufnr, opts)
      return
    end
  end

  if vim.F.if_nil(opts.severity_sort, false) then
    if type(opts.severity_sort) == 'table' and opts.severity_sort.reverse then
      table.sort(diagnostics, function(a, b)
        return a.severity < b.severity
      end)
    else
      table.sort(diagnostics, function(a, b)
        return a.severity > b.severity
      end)
    end
  end

  for handler_name, handler in pairs(M.handlers) do
    if handler.show and opts[handler_name] then
      handler.show(namespace, bufnr, diagnostics, opts)
    end
  end
end

--- Show diagnostics in a floating window.
---
---@param opts table|nil Configuration table with the same keys as
---            |vim.lsp.util.open_floating_preview()| in addition to the following:
---            - bufnr: (number) Buffer number to show diagnostics from.
---                     Defaults to the current buffer.
---            - namespace: (number) Limit diagnostics to the given namespace
---            - scope: (string, default "line") Show diagnostics from the whole buffer ("buffer"),
---                     the current cursor line ("line"), or the current cursor position ("cursor").
---                     Shorthand versions are also accepted ("c" for "cursor", "l" for "line", "b"
---                     for "buffer").
---            - pos: (number or table) If {scope} is "line" or "cursor", use this position rather
---                   than the cursor position. If a number, interpreted as a line number;
---                   otherwise, a (row, col) tuple.
---            - severity_sort: (default false) Sort diagnostics by severity. Overrides the setting
---                             from |vim.diagnostic.config()|.
---            - severity: See |diagnostic-severity|. Overrides the setting from
---                        |vim.diagnostic.config()|.
---            - header: (string or table) String to use as the header for the floating window. If a
---                      table, it is interpreted as a [text, hl_group] tuple. Overrides the setting
---                      from |vim.diagnostic.config()|.
---            - source: (boolean or string) Include the diagnostic source in the message.
---                      Use "if_many" to only show sources if there is more than one source of
---                      diagnostics in the buffer. Otherwise, any truthy value means to always show
---                      the diagnostic source. Overrides the setting from
---                      |vim.diagnostic.config()|.
---            - format: (function) A function that takes a diagnostic as input and returns a
---                      string. The return value is the text used to display the diagnostic.
---                      Overrides the setting from |vim.diagnostic.config()|.
---            - prefix: (function, string, or table) Prefix each diagnostic in the floating
---                      window. If a function, it must have the signature (diagnostic, i,
---                      total) -> (string, string), where {i} is the index of the diagnostic
---                      being evaluated and {total} is the total number of diagnostics
---                      displayed in the window. The function should return a string which
---                      is prepended to each diagnostic in the window as well as an
---                      (optional) highlight group which will be used to highlight the
---                      prefix. If {prefix} is a table, it is interpreted as a [text,
---                      hl_group] tuple as in |nvim_echo()|; otherwise, if {prefix} is a
---                      string, it is prepended to each diagnostic in the window with no
---                      highlight.
---                      Overrides the setting from |vim.diagnostic.config()|.
---@return tuple ({float_bufnr}, {win_id})
function M.open_float(opts, ...)
  -- Support old (bufnr, opts) signature
  local bufnr
  if opts == nil or type(opts) == 'number' then
    bufnr = opts
    opts = ...
  else
    vim.validate({
      opts = { opts, 't', true },
    })
  end

  opts = opts or {}
  bufnr = get_bufnr(bufnr or opts.bufnr)

  do
    -- Resolve options with user settings from vim.diagnostic.config
    -- Unlike the other decoration functions (e.g. set_virtual_text, set_signs, etc.) `open_float`
    -- does not have a dedicated table for configuration options; instead, the options are mixed in
    -- with its `opts` table which also includes "keyword" parameters. So we create a dedicated
    -- options table that inherits missing keys from the global configuration before resolving.
    local t = global_diagnostic_options.float
    local float_opts = vim.tbl_extend('keep', opts, type(t) == 'table' and t or {})
    opts = get_resolved_options({ float = float_opts }, nil, bufnr).float
  end

  local scope = ({ l = 'line', c = 'cursor', b = 'buffer' })[opts.scope] or opts.scope or 'line'
  local lnum, col
  if scope == 'line' or scope == 'cursor' then
    if not opts.pos then
      local pos = vim.api.nvim_win_get_cursor(0)
      lnum = pos[1] - 1
      col = pos[2]
    elseif type(opts.pos) == 'number' then
      lnum = opts.pos
    elseif type(opts.pos) == 'table' then
      lnum, col = unpack(opts.pos)
    else
      error("Invalid value for option 'pos'")
    end
  elseif scope ~= 'buffer' then
    error("Invalid value for option 'scope'")
  end

  local diagnostics = get_diagnostics(bufnr, opts, true)

  if scope == 'line' then
    diagnostics = vim.tbl_filter(function(d)
      return d.lnum == lnum
    end, diagnostics)
  elseif scope == 'cursor' then
    -- LSP servers can send diagnostics with `end_col` past the length of the line
    local line_length = #vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, true)[1]
    diagnostics = vim.tbl_filter(function(d)
      return d.lnum == lnum
        and math.min(d.col, line_length - 1) <= col
        and (d.end_col >= col or d.end_lnum > lnum)
    end, diagnostics)
  end

  if vim.tbl_isempty(diagnostics) then
    return
  end

  local severity_sort = vim.F.if_nil(opts.severity_sort, global_diagnostic_options.severity_sort)
  if severity_sort then
    if type(severity_sort) == 'table' and severity_sort.reverse then
      table.sort(diagnostics, function(a, b)
        return a.severity > b.severity
      end)
    else
      table.sort(diagnostics, function(a, b)
        return a.severity < b.severity
      end)
    end
  end

  local lines = {}
  local highlights = {}
  local header = if_nil(opts.header, 'Diagnostics:')
  if header then
    vim.validate({
      header = {
        header,
        function(v)
          return type(v) == 'string' or type(v) == 'table'
        end,
        "'string' or 'table'",
      },
    })
    if type(header) == 'table' then
      -- Don't insert any lines for an empty string
      if string.len(if_nil(header[1], '')) > 0 then
        table.insert(lines, header[1])
        table.insert(highlights, { 0, header[2] or 'Bold' })
      end
    elseif #header > 0 then
      table.insert(lines, header)
      table.insert(highlights, { 0, 'Bold' })
    end
  end

  if opts.format then
    diagnostics = reformat_diagnostics(opts.format, diagnostics)
  end

  if opts.source and (opts.source ~= 'if_many' or count_sources(bufnr) > 1) then
    diagnostics = prefix_source(diagnostics)
  end

  local prefix_opt =
    if_nil(opts.prefix, (scope == 'cursor' and #diagnostics <= 1) and '' or function(_, i)
      return string.format('%d. ', i)
    end)

  local prefix, prefix_hl_group
  if prefix_opt then
    vim.validate({
      prefix = {
        prefix_opt,
        function(v)
          return type(v) == 'string' or type(v) == 'table' or type(v) == 'function'
        end,
        "'string' or 'table' or 'function'",
      },
    })
    if type(prefix_opt) == 'string' then
      prefix, prefix_hl_group = prefix_opt, 'NormalFloat'
    elseif type(prefix_opt) == 'table' then
      prefix, prefix_hl_group = prefix_opt[1] or '', prefix_opt[2] or 'NormalFloat'
    end
  end

  for i, diagnostic in ipairs(diagnostics) do
    if prefix_opt and type(prefix_opt) == 'function' then
      prefix, prefix_hl_group = prefix_opt(diagnostic, i, #diagnostics)
      prefix, prefix_hl_group = prefix or '', prefix_hl_group or 'NormalFloat'
    end
    local hiname = floating_highlight_map[diagnostic.severity]
    local message_lines = vim.split(diagnostic.message, '\n')
    table.insert(lines, prefix .. message_lines[1])
    table.insert(highlights, { #prefix, hiname, prefix_hl_group })
    for j = 2, #message_lines do
      table.insert(lines, string.rep(' ', #prefix) .. message_lines[j])
      table.insert(highlights, { 0, hiname })
    end
  end

  -- Used by open_floating_preview to allow the float to be focused
  if not opts.focus_id then
    opts.focus_id = scope
  end
  local float_bufnr, winnr = require('vim.lsp.util').open_floating_preview(lines, 'plaintext', opts)
  for i, hi in ipairs(highlights) do
    local prefixlen, hiname, prefix_hiname = unpack(hi)
    if prefix_hiname then
      vim.api.nvim_buf_add_highlight(float_bufnr, -1, prefix_hiname, i - 1, 0, prefixlen)
    end
    vim.api.nvim_buf_add_highlight(float_bufnr, -1, hiname, i - 1, prefixlen, -1)
  end

  return float_bufnr, winnr
end

--- Remove all diagnostics from the given namespace.
---
--- Unlike |vim.diagnostic.hide()|, this function removes all saved
--- diagnostics. They cannot be redisplayed using |vim.diagnostic.show()|. To
--- simply remove diagnostic decorations in a way that they can be
--- re-displayed, use |vim.diagnostic.hide()|.
---
---@param namespace number|nil Diagnostic namespace. When omitted, remove
---                            diagnostics from all namespaces.
---@param bufnr number|nil Remove diagnostics for the given buffer. When omitted,
---             diagnostics are removed for all buffers.
function M.reset(namespace, bufnr)
  vim.validate({
    namespace = { namespace, 'n', true },
    bufnr = { bufnr, 'n', true },
  })

  local buffers = bufnr and { get_bufnr(bufnr) } or vim.tbl_keys(diagnostic_cache)
  for _, iter_bufnr in ipairs(buffers) do
    local namespaces = namespace and { namespace } or vim.tbl_keys(diagnostic_cache[iter_bufnr])
    for _, iter_namespace in ipairs(namespaces) do
      diagnostic_cache[iter_bufnr][iter_namespace] = nil
      M.hide(iter_namespace, iter_bufnr)
    end

    vim.api.nvim_exec_autocmds('DiagnosticChanged', {
      modeline = false,
      buffer = iter_bufnr,
    })
  end
end

--- Add all diagnostics to the quickfix list.
---
---@param opts table|nil Configuration table with the following keys:
---         - namespace: (number) Only add diagnostics from the given namespace.
---         - open: (boolean, default true) Open quickfix list after setting.
---         - title: (string) Title of quickfix list. Defaults to "Diagnostics".
---         - severity: See |diagnostic-severity|.
function M.setqflist(opts)
  set_list(false, opts)
end

--- Add buffer diagnostics to the location list.
---
---@param opts table|nil Configuration table with the following keys:
---         - namespace: (number) Only add diagnostics from the given namespace.
---         - winnr: (number, default 0) Window number to set location list for.
---         - open: (boolean, default true) Open the location list after setting.
---         - title: (string) Title of the location list. Defaults to "Diagnostics".
---         - severity: See |diagnostic-severity|.
function M.setloclist(opts)
  set_list(true, opts)
end

--- Disable diagnostics in the given buffer.
---
---@param bufnr number|nil Buffer number, or 0 for current buffer. When
---                        omitted, disable diagnostics in all buffers.
---@param namespace number|nil Only disable diagnostics for the given namespace.
function M.disable(bufnr, namespace)
  vim.validate({ bufnr = { bufnr, 'n', true }, namespace = { namespace, 'n', true } })
  if bufnr == nil then
    if namespace == nil then
      -- Disable everything (including as yet non-existing buffers and
      -- namespaces) by setting diagnostic_disabled to an empty table and set
      -- its metatable to always return true. This metatable is removed
      -- in enable()
      diagnostic_disabled = setmetatable({}, {
        __index = function()
          return true
        end,
      })
    else
      local ns = M.get_namespace(namespace)
      ns.disabled = true
    end
  else
    bufnr = get_bufnr(bufnr)
    if namespace == nil then
      diagnostic_disabled[bufnr] = true
    else
      if type(diagnostic_disabled[bufnr]) ~= 'table' then
        diagnostic_disabled[bufnr] = {}
      end
      diagnostic_disabled[bufnr][namespace] = true
    end
  end

  M.hide(namespace, bufnr)
end

--- Enable diagnostics in the given buffer.
---
---@param bufnr number|nil Buffer number, or 0 for current buffer. When
---                        omitted, enable diagnostics in all buffers.
---@param namespace number|nil Only enable diagnostics for the given namespace.
function M.enable(bufnr, namespace)
  vim.validate({ bufnr = { bufnr, 'n', true }, namespace = { namespace, 'n', true } })
  if bufnr == nil then
    if namespace == nil then
      -- Enable everything by setting diagnostic_disabled to an empty table
      diagnostic_disabled = {}
    else
      local ns = M.get_namespace(namespace)
      ns.disabled = false
    end
  else
    bufnr = get_bufnr(bufnr)
    if namespace == nil then
      diagnostic_disabled[bufnr] = nil
    else
      if type(diagnostic_disabled[bufnr]) ~= 'table' then
        return
      end
      diagnostic_disabled[bufnr][namespace] = nil
    end
  end

  M.show(namespace, bufnr)
end

--- Parse a diagnostic from a string.
---
--- For example, consider a line of output from a linter:
--- <pre>
--- WARNING filename:27:3: Variable 'foo' does not exist
--- </pre>
---
--- This can be parsed into a diagnostic |diagnostic-structure|
--- with:
--- <pre>
--- local s = "WARNING filename:27:3: Variable 'foo' does not exist"
--- local pattern = "^(%w+) %w+:(%d+):(%d+): (.+)$"
--- local groups = { "severity", "lnum", "col", "message" }
--- vim.diagnostic.match(s, pattern, groups, { WARNING = vim.diagnostic.WARN })
--- </pre>
---
---@param str string String to parse diagnostics from.
---@param pat string Lua pattern with capture groups.
---@param groups table List of fields in a |diagnostic-structure| to
---                    associate with captures from {pat}.
---@param severity_map table A table mapping the severity field from {groups}
---                          with an item from |vim.diagnostic.severity|.
---@param defaults table|nil Table of default values for any fields not listed in {groups}.
---                          When omitted, numeric values default to 0 and "severity" defaults to
---                          ERROR.
---@return diagnostic |diagnostic-structure| or `nil` if {pat} fails to match {str}.
function M.match(str, pat, groups, severity_map, defaults)
  vim.validate({
    str = { str, 's' },
    pat = { pat, 's' },
    groups = { groups, 't' },
    severity_map = { severity_map, 't', true },
    defaults = { defaults, 't', true },
  })

  severity_map = severity_map or M.severity

  local diagnostic = {}
  local matches = { string.match(str, pat) }
  if vim.tbl_isempty(matches) then
    return
  end

  for i, match in ipairs(matches) do
    local field = groups[i]
    if field == 'severity' then
      match = severity_map[match]
    elseif field == 'lnum' or field == 'end_lnum' or field == 'col' or field == 'end_col' then
      match = assert(tonumber(match)) - 1
    end
    diagnostic[field] = match
  end

  diagnostic = vim.tbl_extend('keep', diagnostic, defaults or {})
  diagnostic.severity = diagnostic.severity or M.severity.ERROR
  diagnostic.col = diagnostic.col or 0
  diagnostic.end_lnum = diagnostic.end_lnum or diagnostic.lnum
  diagnostic.end_col = diagnostic.end_col or diagnostic.col
  return diagnostic
end

local errlist_type_map = {
  [M.severity.ERROR] = 'E',
  [M.severity.WARN] = 'W',
  [M.severity.INFO] = 'I',
  [M.severity.HINT] = 'N',
}

--- Convert a list of diagnostics to a list of quickfix items that can be
--- passed to |setqflist()| or |setloclist()|.
---
---@param diagnostics table List of diagnostics |diagnostic-structure|.
---@return array of quickfix list items |setqflist-what|
function M.toqflist(diagnostics)
  vim.validate({
    diagnostics = {
      diagnostics,
      vim.tbl_islist,
      'a list of diagnostics',
    },
  })

  local list = {}
  for _, v in ipairs(diagnostics) do
    local item = {
      bufnr = v.bufnr,
      lnum = v.lnum + 1,
      col = v.col and (v.col + 1) or nil,
      end_lnum = v.end_lnum and (v.end_lnum + 1) or nil,
      end_col = v.end_col and (v.end_col + 1) or nil,
      text = v.message,
      type = errlist_type_map[v.severity] or 'E',
    }
    table.insert(list, item)
  end
  table.sort(list, function(a, b)
    if a.bufnr == b.bufnr then
      return a.lnum < b.lnum
    else
      return a.bufnr < b.bufnr
    end
  end)
  return list
end

--- Convert a list of quickfix items to a list of diagnostics.
---
---@param list table A list of quickfix items from |getqflist()| or
---            |getloclist()|.
---@return array of diagnostics |diagnostic-structure|
function M.fromqflist(list)
  vim.validate({
    list = {
      list,
      vim.tbl_islist,
      'a list of quickfix items',
    },
  })

  local diagnostics = {}
  for _, item in ipairs(list) do
    if item.valid == 1 then
      local lnum = math.max(0, item.lnum - 1)
      local col = math.max(0, item.col - 1)
      local end_lnum = item.end_lnum > 0 and (item.end_lnum - 1) or lnum
      local end_col = item.end_col > 0 and (item.end_col - 1) or col
      local severity = item.type ~= '' and M.severity[item.type] or M.severity.ERROR
      table.insert(diagnostics, {
        bufnr = item.bufnr,
        lnum = lnum,
        col = col,
        end_lnum = end_lnum,
        end_col = end_col,
        severity = severity,
        message = item.text,
      })
    end
  end
  return diagnostics
end

return M
