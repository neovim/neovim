local api, if_nil = vim.api, vim.F.if_nil

local M = {}

--- [diagnostic-structure]()
---
--- Diagnostics use the same indexing as the rest of the Nvim API (i.e. 0-based
--- rows and columns). |api-indexing|
--- @class vim.Diagnostic
---
--- Buffer number
--- @field bufnr? integer
---
--- The starting line of the diagnostic (0-indexed)
--- @field lnum integer
---
--- The final line of the diagnostic (0-indexed)
--- @field end_lnum? integer
---
--- The starting column of the diagnostic (0-indexed)
--- @field col integer
---
--- The final column of the diagnostic (0-indexed)
--- @field end_col? integer
---
--- The severity of the diagnostic |vim.diagnostic.severity|
--- @field severity? vim.diagnostic.Severity
---
--- The diagnostic text
--- @field message string
---
--- The source of the diagnostic
--- @field source? string
---
--- The diagnostic code
--- @field code? string|integer
---
--- @field _tags? { deprecated: boolean, unnecessary: boolean}
---
--- Arbitrary data plugins or users can add
--- @field user_data? any arbitrary data plugins can add
---
--- @field namespace? integer

--- Many of the configuration options below accept one of the following:
--- - `false`: Disable this feature
--- - `true`: Enable this feature, use default settings.
--- - `table`: Enable this feature with overrides. Use an empty table to use default values.
--- - `function`: Function with signature (namespace, bufnr) that returns any of the above.
--- @class vim.diagnostic.Opts
---
--- Use underline for diagnostics.
--- (default: `true`)
--- @field underline? boolean|vim.diagnostic.Opts.Underline|fun(namespace: integer, bufnr:integer): vim.diagnostic.Opts.Underline
---
--- Use virtual text for diagnostics. If multiple diagnostics are set for a
--- namespace, one prefix per diagnostic + the last diagnostic message are
--- shown.
--- (default: `true`)
--- @field virtual_text? boolean|vim.diagnostic.Opts.VirtualText|fun(namespace: integer, bufnr:integer): vim.diagnostic.Opts.VirtualText
---
--- Use signs for diagnostics |diagnostic-signs|.
--- (default: `true`)
--- @field signs? boolean|vim.diagnostic.Opts.Signs|fun(namespace: integer, bufnr:integer): vim.diagnostic.Opts.Signs
---
--- Options for floating windows. See |vim.diagnostic.Opts.Float|.
--- @field float? boolean|vim.diagnostic.Opts.Float|fun(namespace: integer, bufnr:integer): vim.diagnostic.Opts.Float
---
--- Update diagnostics in Insert mode
--- (if `false`, diagnostics are updated on |InsertLeave|)
--- (default: `false`)
--- @field update_in_insert? boolean
---
--- Sort diagnostics by severity. This affects the order in which signs and
--- virtual text are displayed. When true, higher severities are displayed
--- before lower severities (e.g. ERROR is displayed before WARN).
--- Options:
---   - {reverse}? (boolean) Reverse sort order
--- (default: `false`)
--- @field severity_sort? boolean|{reverse?:boolean}
---
--- Default values for |vim.diagnostic.jump()|. See |vim.diagnostic.Opts.Jump|.
--- @field jump? vim.diagnostic.Opts.Jump

--- @class (private) vim.diagnostic.OptsResolved
--- @field float vim.diagnostic.Opts.Float
--- @field update_in_insert boolean
--- @field underline vim.diagnostic.Opts.Underline
--- @field virtual_text vim.diagnostic.Opts.VirtualText
--- @field signs vim.diagnostic.Opts.Signs
--- @field severity_sort {reverse?:boolean}

--- @class vim.diagnostic.Opts.Float
---
--- Buffer number to show diagnostics from.
--- (default: current buffer)
--- @field bufnr? integer
---
--- Limit diagnostics to the given namespace
--- @field namespace? integer
---
--- Show diagnostics from the whole buffer (`buffer"`, the current cursor line
--- (`line`), or the current cursor position (`cursor`). Shorthand versions
--- are also accepted (`c` for `cursor`, `l` for `line`, `b` for `buffer`).
--- (default: `line`)
--- @field scope? 'line'|'buffer'|'cursor'|'c'|'l'|'b'
---
--- If {scope} is "line" or "cursor", use this position rather than the cursor
--- position. If a number, interpreted as a line number; otherwise, a
--- (row, col) tuple.
--- @field pos? integer|[integer,integer]
---
--- Sort diagnostics by severity.
--- Overrides the setting from |vim.diagnostic.config()|.
--- (default: `false`)
--- @field severity_sort? boolean|{reverse?:boolean}
---
--- See |diagnostic-severity|.
--- Overrides the setting from |vim.diagnostic.config()|.
--- @field severity? vim.diagnostic.SeverityFilter
---
--- String to use as the header for the floating window. If a table, it is
--- interpreted as a `[text, hl_group]` tuple.
--- Overrides the setting from |vim.diagnostic.config()|.
--- @field header? string|[string,any]
---
--- Include the diagnostic source in the message.
--- Use "if_many" to only show sources if there is more than one source of
--- diagnostics in the buffer. Otherwise, any truthy value means to always show
--- the diagnostic source.
--- Overrides the setting from |vim.diagnostic.config()|.
--- @field source? boolean|'if_many'
---
--- A function that takes a diagnostic as input and returns a string.
--- The return value is the text used to display the diagnostic.
--- Overrides the setting from |vim.diagnostic.config()|.
--- @field format? fun(diagnostic:vim.Diagnostic): string
---
--- Prefix each diagnostic in the floating window:
--- - If a `function`, {i} is the index of the diagnostic being evaluated and
---   {total} is the total number of diagnostics displayed in the window. The
---   function should return a `string` which is prepended to each diagnostic
---   in the window as well as an (optional) highlight group which will be
---   used to highlight the prefix.
--- - If a `table`, it is interpreted as a `[text, hl_group]` tuple as
---   in |nvim_echo()|
--- - If a `string`, it is prepended to each diagnostic in the window with no
---   highlight.
--- Overrides the setting from |vim.diagnostic.config()|.
--- @field prefix? string|table|(fun(diagnostic:vim.Diagnostic,i:integer,total:integer): string, string)
---
--- Same as {prefix}, but appends the text to the diagnostic instead of
--- prepending it.
--- Overrides the setting from |vim.diagnostic.config()|.
--- @field suffix? string|table|(fun(diagnostic:vim.Diagnostic,i:integer,total:integer): string, string)
---
--- @field focus_id? string
---
--- @field border? string see |nvim_open_win()|.

--- @class vim.diagnostic.Opts.Underline
---
--- Only underline diagnostics matching the given
--- severity |diagnostic-severity|.
--- @field severity? vim.diagnostic.SeverityFilter

--- @class vim.diagnostic.Opts.VirtualText
---
--- Only show virtual text for diagnostics matching the given
--- severity |diagnostic-severity|
--- @field severity? vim.diagnostic.SeverityFilter
---
--- Include the diagnostic source in virtual text. Use `'if_many'` to only
--- show sources if there is more than one diagnostic source in the buffer.
--- Otherwise, any truthy value means to always show the diagnostic source.
--- @field source? boolean|"if_many"
---
--- Amount of empty spaces inserted at the beginning of the virtual text.
--- @field spacing? integer
---
--- Prepend diagnostic message with prefix. If a `function`, {i} is the index
--- of the diagnostic being evaluated, and {total} is the total number of
--- diagnostics for the line. This can be used to render diagnostic symbols
--- or error codes.
--- @field prefix? string|(fun(diagnostic:vim.Diagnostic,i:integer,total:integer): string)
---
--- Append diagnostic message with suffix.
--- This can be used to render an LSP diagnostic error code.
--- @field suffix? string|(fun(diagnostic:vim.Diagnostic): string)
---
--- The return value is the text used to display the diagnostic. Example:
--- ```lua
--- function(diagnostic)
---   if diagnostic.severity == vim.diagnostic.severity.ERROR then
---     return string.format("E: %s", diagnostic.message)
---   end
---   return diagnostic.message
--- end
--- ```
--- @field format? fun(diagnostic:vim.Diagnostic): string
---
--- See |nvim_buf_set_extmark()|.
--- @field hl_mode? 'replace'|'combine'|'blend'
---
--- See |nvim_buf_set_extmark()|.
--- @field virt_text? [string,any][]
---
--- See |nvim_buf_set_extmark()|.
--- @field virt_text_pos? 'eol'|'overlay'|'right_align'|'inline'
---
--- See |nvim_buf_set_extmark()|.
--- @field virt_text_win_col? integer
---
--- See |nvim_buf_set_extmark()|.
--- @field virt_text_hide? boolean

--- @class vim.diagnostic.Opts.Signs
---
--- Only show virtual text for diagnostics matching the given
--- severity |diagnostic-severity|
--- @field severity? vim.diagnostic.SeverityFilter
---
--- Base priority to use for signs. When {severity_sort} is used, the priority
--- of a sign is adjusted based on its severity.
--- Otherwise, all signs use the same priority.
--- (default: `10`)
--- @field priority? integer
---
--- A table mapping |diagnostic-severity| to the sign text to display in the
--- sign column. The default is to use `"E"`, `"W"`, `"I"`, and `"H"` for errors,
--- warnings, information, and hints, respectively. Example:
--- ```lua
--- vim.diagnostic.config({
---   signs = { text = { [vim.diagnostic.severity.ERROR] = 'E', ... } }
--- })
--- ```
--- @field text? table<vim.diagnostic.Severity,string>
---
--- A table mapping |diagnostic-severity| to the highlight group used for the
--- line number where the sign is placed.
--- @field numhl? table<vim.diagnostic.Severity,string>
---
--- A table mapping |diagnostic-severity| to the highlight group used for the
--- whole line the sign is placed in.
--- @field linehl? table<vim.diagnostic.Severity,string>

--- @class vim.diagnostic.Opts.Jump
---
--- Default value of the {float} parameter of |vim.diagnostic.jump()|.
--- (default: false)
--- @field float? boolean|vim.diagnostic.Opts.Float
---
--- Default value of the {wrap} parameter of |vim.diagnostic.jump()|.
--- (default: true)
--- @field wrap? boolean
---
--- Default value of the {severity} parameter of |vim.diagnostic.jump()|.
--- @field severity? vim.diagnostic.SeverityFilter
---
--- Default value of the {_highest} parameter of |vim.diagnostic.jump()|.
--- @field package _highest? boolean

-- TODO: inherit from `vim.diagnostic.Opts`, implement its fields.
--- Optional filters |kwargs|, or `nil` for all.
--- @class vim.diagnostic.Filter
--- @inlinedoc
---
--- Diagnostic namespace, or `nil` for all.
--- @field ns_id? integer
---
--- Buffer number, or 0 for current buffer, or `nil` for all buffers.
--- @field bufnr? integer

--- @nodoc
--- @enum vim.diagnostic.Severity
M.severity = {
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  HINT = 4,
  [1] = 'ERROR',
  [2] = 'WARN',
  [3] = 'INFO',
  [4] = 'HINT',
}

--- @alias vim.diagnostic.SeverityInt 1|2|3|4

--- See |diagnostic-severity| and |vim.diagnostic.get()|
--- @alias vim.diagnostic.SeverityFilter vim.diagnostic.Severity|vim.diagnostic.Severity[]|{min:vim.diagnostic.Severity,max:vim.diagnostic.Severity}

-- Mappings from qflist/loclist error types to severities
M.severity.E = M.severity.ERROR
M.severity.W = M.severity.WARN
M.severity.I = M.severity.INFO
M.severity.N = M.severity.HINT

--- @type vim.diagnostic.Opts
local global_diagnostic_options = {
  signs = true,
  underline = true,
  virtual_text = true,
  float = true,
  update_in_insert = false,
  severity_sort = false,
  jump = {
    -- Do not show floating window
    float = false,

    -- Wrap around buffer
    wrap = true,
  },
}

--- @class (private) vim.diagnostic.Handler
--- @field show? fun(namespace: integer, bufnr: integer, diagnostics: vim.Diagnostic[], opts?: vim.diagnostic.OptsResolved)
--- @field hide? fun(namespace:integer, bufnr:integer)

--- @nodoc
--- @type table<string,vim.diagnostic.Handler>
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
  --- @param t table<integer,table>
  --- @param bufnr integer
  --- @return table
  __index = function(t, bufnr)
    assert(bufnr > 0, 'Invalid buffer number')
    t[bufnr] = {}
    return t[bufnr]
  end,
}

-- bufnr -> ns -> Diagnostic[]
local diagnostic_cache = {} --- @type table<integer,table<integer,vim.Diagnostic[]>>
do
  local group = api.nvim_create_augroup('DiagnosticBufWipeout', {})
  setmetatable(diagnostic_cache, {
    --- @param t table<integer,vim.Diagnostic[]>
    --- @param bufnr integer
    __index = function(t, bufnr)
      assert(bufnr > 0, 'Invalid buffer number')
      api.nvim_create_autocmd('BufWipeout', {
        group = group,
        buffer = bufnr,
        callback = function()
          rawset(t, bufnr, nil)
        end,
      })
      t[bufnr] = {}
      return t[bufnr]
    end,
  })
end

--- @class (private) vim.diagnostic._extmark
--- @field [1] integer id
--- @field [2] integer start
--- @field [3] integer end
--- @field [4] table details

--- @type table<integer,table<integer,vim.diagnostic._extmark[]>>
local diagnostic_cache_extmarks = setmetatable({}, bufnr_and_namespace_cacher_mt)

--- @type table<integer,true>
local diagnostic_attached_buffers = {}

--- @type table<integer,true|table<integer,true>>
local diagnostic_disabled = {}

--- @type table<integer,table<integer,table>>
local bufs_waiting_to_update = setmetatable({}, bufnr_and_namespace_cacher_mt)

--- @class vim.diagnostic.NS
--- @field name string
--- @field opts vim.diagnostic.Opts
--- @field user_data table
--- @field disabled? boolean

--- @type table<integer,vim.diagnostic.NS>
local all_namespaces = {}

---@param severity string|vim.diagnostic.Severity
---@return vim.diagnostic.Severity?
local function to_severity(severity)
  if type(severity) == 'string' then
    assert(M.severity[string.upper(severity)], string.format('Invalid severity: %s', severity))
    return M.severity[string.upper(severity)]
  end
  return severity
end

--- @param severity vim.diagnostic.SeverityFilter
--- @return fun(vim.Diagnostic):boolean
local function severity_predicate(severity)
  if type(severity) ~= 'table' then
    severity = assert(to_severity(severity))
    ---@param d vim.Diagnostic
    return function(d)
      return d.severity == severity
    end
  end
  if severity.min or severity.max then
    --- @cast severity {min:vim.diagnostic.Severity,max:vim.diagnostic.Severity}
    local min_severity = to_severity(severity.min) or M.severity.HINT
    local max_severity = to_severity(severity.max) or M.severity.ERROR

    --- @param d vim.Diagnostic
    return function(d)
      return d.severity <= min_severity and d.severity >= max_severity
    end
  end

  --- @cast severity vim.diagnostic.Severity[]
  local severities = {} --- @type table<vim.diagnostic.Severity,true>
  for _, s in ipairs(severity) do
    severities[assert(to_severity(s))] = true
  end

  --- @param d vim.Diagnostic
  return function(d)
    return severities[d.severity]
  end
end

--- @param severity vim.diagnostic.SeverityFilter
--- @param diagnostics vim.Diagnostic[]
--- @return vim.Diagnostic[]
local function filter_by_severity(severity, diagnostics)
  if not severity then
    return diagnostics
  end
  return vim.tbl_filter(severity_predicate(severity), diagnostics)
end

--- @param bufnr integer
--- @return integer
local function count_sources(bufnr)
  local seen = {} --- @type table<string,true>
  local count = 0
  for _, namespace_diagnostics in pairs(diagnostic_cache[bufnr]) do
    for _, diagnostic in ipairs(namespace_diagnostics) do
      local source = diagnostic.source
      if source and not seen[source] then
        seen[source] = true
        count = count + 1
      end
    end
  end
  return count
end

--- @param diagnostics vim.Diagnostic[]
--- @return vim.Diagnostic[]
local function prefix_source(diagnostics)
  --- @param d vim.Diagnostic
  return vim.tbl_map(function(d)
    if not d.source then
      return d
    end

    local t = vim.deepcopy(d, true)
    t.message = string.format('%s: %s', d.source, d.message)
    return t
  end, diagnostics)
end

--- @param diagnostics vim.Diagnostic[]
--- @return vim.Diagnostic[]
local function reformat_diagnostics(format, diagnostics)
  vim.validate({
    format = { format, 'f' },
    diagnostics = { diagnostics, 't' },
  })

  local formatted = vim.deepcopy(diagnostics, true)
  for _, diagnostic in ipairs(formatted) do
    diagnostic.message = format(diagnostic)
  end
  return formatted
end

--- @param option string
--- @param namespace integer?
--- @return table
local function enabled_value(option, namespace)
  local ns = namespace and M.get_namespace(namespace) or {}
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
local function get_resolved_options(opts, namespace, bufnr)
  local ns = namespace and M.get_namespace(namespace) or {}
  -- Do not use tbl_deep_extend so that an empty table can be used to reset to default values
  local resolved = vim.tbl_extend('keep', opts or {}, ns.opts or {}, global_diagnostic_options) --- @type table<string,any>
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

--- Make a map from vim.diagnostic.Severity -> Highlight Name
--- @param base_name string
--- @return table<vim.diagnostic.SeverityInt,string>
local function make_highlight_map(base_name)
  local result = {} --- @type table<vim.diagnostic.SeverityInt,string>
  for k in pairs(diagnostic_severities) do
    local name = M.severity[k]
    name = name:sub(1, 1) .. name:sub(2):lower()
    result[k] = 'Diagnostic' .. base_name .. name
  end

  return result
end

-- TODO(lewis6991): these highlight maps can only be indexed with an integer, however there usage
-- implies they can be indexed with any vim.diagnostic.Severity
local virtual_text_highlight_map = make_highlight_map('VirtualText')
local underline_highlight_map = make_highlight_map('Underline')
local floating_highlight_map = make_highlight_map('Floating')
local sign_highlight_map = make_highlight_map('Sign')

local function get_bufnr(bufnr)
  if not bufnr or bufnr == 0 then
    return api.nvim_get_current_buf()
  end
  return bufnr
end

--- @param diagnostics vim.Diagnostic[]
--- @return table<integer,vim.Diagnostic[]>
local function diagnostic_lines(diagnostics)
  if not diagnostics then
    return {}
  end

  local diagnostics_by_line = {} --- @type table<integer,vim.Diagnostic[]>
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

--- @param namespace integer
--- @param bufnr integer
--- @param diagnostics vim.Diagnostic[]
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

--- @param bufnr integer
--- @param last integer
local function restore_extmarks(bufnr, last)
  for ns, extmarks in pairs(diagnostic_cache_extmarks[bufnr]) do
    local extmarks_current = api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
    local found = {} --- @type table<integer,true>
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
        pcall(api.nvim_buf_set_extmark, bufnr, ns, extmark[2], extmark[3], opts)
      end
    end
  end
end

--- @param namespace integer
--- @param bufnr? integer
local function save_extmarks(namespace, bufnr)
  bufnr = get_bufnr(bufnr)
  if not diagnostic_attached_buffers[bufnr] then
    api.nvim_buf_attach(bufnr, false, {
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
    api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
end

--- @type table<string,true>
local registered_autocmds = {}

local function make_augroup_key(namespace, bufnr)
  local ns = M.get_namespace(namespace)
  return string.format('DiagnosticInsertLeave:%s:%s', bufnr, ns.name)
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

--- Table of autocmd events to fire the update for displaying new diagnostic information
local insert_leave_auto_cmds = { 'InsertLeave', 'CursorHoldI' }

--- @param namespace integer
--- @param bufnr integer
--- @param args any[]
local function schedule_display(namespace, bufnr, args)
  bufs_waiting_to_update[bufnr][namespace] = args

  local key = make_augroup_key(namespace, bufnr)
  if not registered_autocmds[key] then
    local group = api.nvim_create_augroup(key, { clear = true })
    api.nvim_create_autocmd(insert_leave_auto_cmds, {
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

--- @param namespace integer
--- @param bufnr integer
local function clear_scheduled_display(namespace, bufnr)
  local key = make_augroup_key(namespace, bufnr)

  if registered_autocmds[key] then
    api.nvim_del_augroup_by_name(key)
    registered_autocmds[key] = nil
  end
end

--- @param bufnr integer?
--- @param opts vim.diagnostic.GetOpts?
--- @param clamp boolean
--- @return vim.Diagnostic[]
local function get_diagnostics(bufnr, opts, clamp)
  opts = opts or {}

  local namespace = opts.namespace

  if type(namespace) == 'number' then
    namespace = { namespace }
  end

  ---@cast namespace integer[]

  local diagnostics = {}

  -- Memoized results of buf_line_count per bufnr
  --- @type table<integer,integer>
  local buf_line_count = setmetatable({}, {
    --- @param t table<integer,integer>
    --- @param k integer
    --- @return integer
    __index = function(t, k)
      t[k] = api.nvim_buf_line_count(k)
      return rawget(t, k)
    end,
  })

  local match_severity = opts.severity and severity_predicate(opts.severity)
    or function(_)
      return true
    end

  ---@param b integer
  ---@param d vim.Diagnostic
  local function add(b, d)
    if
      match_severity(d)
      and (not opts.lnum or (opts.lnum >= d.lnum and opts.lnum <= (d.end_lnum or d.lnum)))
    then
      if clamp and api.nvim_buf_is_loaded(b) then
        local line_count = buf_line_count[b] - 1
        if
          d.lnum > line_count
          or d.end_lnum > line_count
          or d.lnum < 0
          or d.end_lnum < 0
          or d.col < 0
          or d.end_col < 0
        then
          d = vim.deepcopy(d, true)
          d.lnum = math.max(math.min(d.lnum, line_count), 0)
          d.end_lnum = math.max(math.min(assert(d.end_lnum), line_count), 0)
          d.col = math.max(d.col, 0)
          d.end_col = math.max(d.end_col, 0)
        end
      end
      table.insert(diagnostics, d)
    end
  end

  --- @param buf integer
  --- @param diags vim.Diagnostic[]
  local function add_all_diags(buf, diags)
    for _, diagnostic in pairs(diags) do
      add(buf, diagnostic)
    end
  end

  if namespace == nil and bufnr == nil then
    for b, t in pairs(diagnostic_cache) do
      for _, v in pairs(t) do
        add_all_diags(b, v)
      end
    end
  elseif namespace == nil then
    bufnr = get_bufnr(bufnr)
    for iter_namespace in pairs(diagnostic_cache[bufnr]) do
      add_all_diags(bufnr, diagnostic_cache[bufnr][iter_namespace])
    end
  elseif bufnr == nil then
    for b, t in pairs(diagnostic_cache) do
      for _, iter_namespace in ipairs(namespace) do
        add_all_diags(b, t[iter_namespace] or {})
      end
    end
  else
    bufnr = get_bufnr(bufnr)
    for _, iter_namespace in ipairs(namespace) do
      add_all_diags(bufnr, diagnostic_cache[bufnr][iter_namespace] or {})
    end
  end

  return diagnostics
end

--- @param loclist boolean
--- @param opts vim.diagnostic.setqflist.Opts|vim.diagnostic.setloclist.Opts?
local function set_list(loclist, opts)
  opts = opts or {}
  local open = if_nil(opts.open, true)
  local title = opts.title or 'Diagnostics'
  local winnr = opts.winnr or 0
  local bufnr --- @type integer?
  if loclist then
    bufnr = api.nvim_win_get_buf(winnr)
  end
  -- Don't clamp line numbers since the quickfix list can already handle line
  -- numbers beyond the end of the buffer
  local diagnostics = get_diagnostics(bufnr, opts --[[@as vim.diagnostic.GetOpts]], false)
  local items = M.toqflist(diagnostics)
  if loclist then
    vim.fn.setloclist(winnr, {}, ' ', { title = title, items = items })
  else
    vim.fn.setqflist({}, ' ', { title = title, items = items })
  end
  if open then
    api.nvim_command(loclist and 'lwindow' or 'botright cwindow')
  end
end

--- Jump to the diagnostic with the highest severity. First sort the
--- diagnostics by severity. The first diagnostic then contains the highest severity, and we can
--- discard all diagnostics with a lower severity.
--- @param diagnostics vim.Diagnostic[]
local function filter_highest(diagnostics)
  table.sort(diagnostics, function(a, b)
    return a.severity < b.severity
  end)

  -- Find the first diagnostic where the severity does not match the highest severity, and remove
  -- that element and all subsequent elements from the array
  local worst = (diagnostics[1] or {}).severity
  local len = #diagnostics
  for i = 2, len do
    if diagnostics[i].severity ~= worst then
      for j = i, len do
        diagnostics[j] = nil
      end
      break
    end
  end
end

--- @param search_forward boolean
--- @param opts vim.diagnostic.JumpOpts?
--- @return vim.Diagnostic?
local function next_diagnostic(search_forward, opts)
  opts = opts or {}

  -- Support deprecated win_id alias
  if opts.win_id then
    vim.deprecate('opts.win_id', 'opts.winid', '0.13')
    opts.winid = opts.win_id
    opts.win_id = nil
  end

  -- Support deprecated cursor_position alias
  if opts.cursor_position then
    vim.deprecate('opts.cursor_position', 'opts.pos', '0.13')
    opts.pos = opts.cursor_position
    opts.cursor_position = nil
  end

  local winid = opts.winid or api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)
  local position = opts.pos or api.nvim_win_get_cursor(winid)

  -- Adjust row to be 0-indexed
  position[1] = position[1] - 1

  local wrap = if_nil(opts.wrap, true)

  local diagnostics = get_diagnostics(bufnr, opts, true)

  if opts._highest then
    filter_highest(diagnostics)
  end

  local line_diagnostics = diagnostic_lines(diagnostics)

  local line_count = api.nvim_buf_line_count(bufnr)
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
      local line_length = #api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, true)[1]
      --- @type function, function
      local sort_diagnostics, is_next
      if search_forward then
        sort_diagnostics = function(a, b)
          return a.col < b.col
        end
        is_next = function(d)
          return math.min(d.col, math.max(line_length - 1, 0)) > position[2]
        end
      else
        sort_diagnostics = function(a, b)
          return a.col > b.col
        end
        is_next = function(d)
          return math.min(d.col, math.max(line_length - 1, 0)) < position[2]
        end
      end
      table.sort(line_diagnostics[lnum], sort_diagnostics)
      if i == 0 then
        for _, v in
          pairs(line_diagnostics[lnum] --[[@as table<string,any>]])
        do
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

--- Move the cursor to the given diagnostic.
---
--- @param diagnostic vim.Diagnostic?
--- @param opts vim.diagnostic.JumpOpts?
local function goto_diagnostic(diagnostic, opts)
  if not diagnostic then
    api.nvim_echo({ { 'No more valid diagnostics to move to', 'WarningMsg' } }, true, {})
    return
  end

  opts = opts or {}

  -- Support deprecated win_id alias
  if opts.win_id then
    vim.deprecate('opts.win_id', 'opts.winid', '0.13')
    opts.winid = opts.win_id
    opts.win_id = nil
  end

  local winid = opts.winid or api.nvim_get_current_win()

  api.nvim_win_call(winid, function()
    -- Save position in the window's jumplist
    vim.cmd("normal! m'")
    api.nvim_win_set_cursor(winid, { diagnostic.lnum + 1, diagnostic.col })
    -- Open folds under the cursor
    vim.cmd('normal! zv')
  end)

  local float = if_nil(opts.float, true)
  if float then
    local float_opts = type(float) == 'table' and float or {}
    vim.schedule(function()
      M.open_float(vim.tbl_extend('keep', float_opts, {
        bufnr = api.nvim_win_get_buf(winid),
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
---
--- ```lua
--- vim.diagnostic.config({ virtual_text = true })
--- ```
---
--- and a diagnostic producer sets diagnostics with
---
--- ```lua
--- vim.diagnostic.set(ns, 0, diagnostics, { virtual_text = false })
--- ```
---
--- then virtual text will not be enabled for those diagnostics.
---
---@param opts vim.diagnostic.Opts? When omitted or `nil`, retrieve the current
---       configuration. Otherwise, a configuration table (see |vim.diagnostic.Opts|).
---@param namespace integer? Update the options for the given namespace.
---                          When omitted, update the global diagnostic options.
---@return vim.diagnostic.Opts? : Current diagnostic config if {opts} is omitted.
function M.config(opts, namespace)
  vim.validate({
    opts = { opts, 't', true },
    namespace = { namespace, 'n', true },
  })

  local t --- @type vim.diagnostic.Opts
  if namespace then
    local ns = M.get_namespace(namespace)
    t = ns.opts
  else
    t = global_diagnostic_options
  end

  if not opts then
    -- Return current config
    return vim.deepcopy(t, true)
  end

  for k, v in
    pairs(opts --[[@as table<any,any>]])
  do
    t[k] = v
  end

  if namespace then
    for bufnr, v in pairs(diagnostic_cache) do
      if v[namespace] then
        M.show(namespace, bufnr)
      end
    end
  else
    for bufnr, v in pairs(diagnostic_cache) do
      for ns in pairs(v) do
        M.show(ns, bufnr)
      end
    end
  end
end

--- Set diagnostics for the given namespace and buffer.
---
---@param namespace integer The diagnostic namespace
---@param bufnr integer Buffer number
---@param diagnostics vim.Diagnostic[]
---@param opts? vim.diagnostic.Opts Display options to pass to |vim.diagnostic.show()|
function M.set(namespace, bufnr, diagnostics, opts)
  vim.validate({
    namespace = { namespace, 'n' },
    bufnr = { bufnr, 'n' },
    diagnostics = {
      diagnostics,
      vim.islist,
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

  M.show(namespace, bufnr, nil, opts)

  api.nvim_exec_autocmds('DiagnosticChanged', {
    modeline = false,
    buffer = bufnr,
    -- TODO(lewis6991): should this be deepcopy()'d like they are in vim.diagnostic.get()
    data = { diagnostics = diagnostics },
  })
end

--- Get namespace metadata.
---
---@param namespace integer Diagnostic namespace
---@return vim.diagnostic.NS : Namespace metadata
function M.get_namespace(namespace)
  vim.validate({ namespace = { namespace, 'n' } })
  if not all_namespaces[namespace] then
    local name --- @type string?
    for k, v in pairs(api.nvim_get_namespaces()) do
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
---@return table<integer,vim.diagnostic.NS> : List of active diagnostic namespaces |vim.diagnostic|.
function M.get_namespaces()
  return vim.deepcopy(all_namespaces, true)
end

--- Get current diagnostics.
---
--- Modifying diagnostics in the returned table has no effect.
--- To set diagnostics in a buffer, use |vim.diagnostic.set()|.
---
---@param bufnr integer? Buffer number to get diagnostics from. Use 0 for
---                      current buffer or nil for all buffers.
---@param opts? vim.diagnostic.GetOpts
---@return vim.Diagnostic[] : Fields `bufnr`, `end_lnum`, `end_col`, and `severity`
---                           are guaranteed to be present.
function M.get(bufnr, opts)
  vim.validate({
    bufnr = { bufnr, 'n', true },
    opts = { opts, 't', true },
  })

  return vim.deepcopy(get_diagnostics(bufnr, opts, false), true)
end

--- Get current diagnostics count.
---
---@param bufnr? integer Buffer number to get diagnostics from. Use 0 for
---                      current buffer or nil for all buffers.
---@param opts? vim.diagnostic.GetOpts
---@return table : Table with actually present severity values as keys
---                (see |diagnostic-severity|) and integer counts as values.
function M.count(bufnr, opts)
  vim.validate({
    bufnr = { bufnr, 'n', true },
    opts = { opts, 't', true },
  })

  local diagnostics = get_diagnostics(bufnr, opts, false)
  local count = {} --- @type table<integer,integer>
  for i = 1, #diagnostics do
    local severity = diagnostics[i].severity --[[@as integer]]
    count[severity] = (count[severity] or 0) + 1
  end
  return count
end

--- Get the previous diagnostic closest to the cursor position.
---
---@param opts? vim.diagnostic.JumpOpts
---@return vim.Diagnostic? : Previous diagnostic
function M.get_prev(opts)
  return next_diagnostic(false, opts)
end

--- Return the position of the previous diagnostic in the current buffer.
---
---@param opts? vim.diagnostic.JumpOpts
---@return table|false: Previous diagnostic position as a `(row, col)` tuple
---                     or `false` if there is no prior diagnostic.
---@deprecated
function M.get_prev_pos(opts)
  vim.deprecate(
    'vim.diagnostic.get_prev_pos()',
    'access the lnum and col fields from get_prev() instead',
    '0.13'
  )
  local prev = M.get_prev(opts)
  if not prev then
    return false
  end

  return { prev.lnum, prev.col }
end

--- Move to the previous diagnostic in the current buffer.
---@param opts? vim.diagnostic.JumpOpts
---@deprecated
function M.goto_prev(opts)
  vim.deprecate('vim.diagnostic.goto_prev()', 'vim.diagnostic.jump()', '0.13')
  goto_diagnostic(M.get_prev(opts), opts)
end

--- Get the next diagnostic closest to the cursor position.
---
---@param opts? vim.diagnostic.JumpOpts
---@return vim.Diagnostic? : Next diagnostic
function M.get_next(opts)
  return next_diagnostic(true, opts)
end

--- Return the position of the next diagnostic in the current buffer.
---
---@param opts? vim.diagnostic.JumpOpts
---@return table|false : Next diagnostic position as a `(row, col)` tuple or false if no next
---                      diagnostic.
---@deprecated
function M.get_next_pos(opts)
  vim.deprecate(
    'vim.diagnostic.get_next_pos()',
    'access the lnum and col fields from get_next() instead',
    '0.13'
  )
  local next = M.get_next(opts)
  if not next then
    return false
  end

  return { next.lnum, next.col }
end

--- A table with the following keys:
--- @class vim.diagnostic.GetOpts
---
--- Limit diagnostics to one or more namespaces.
--- @field namespace? integer[]|integer
---
--- Limit diagnostics to those spanning the specified line number.
--- @field lnum? integer
---
--- See |diagnostic-severity|.
--- @field severity? vim.diagnostic.SeverityFilter

--- Configuration table with the keys listed below. Some parameters can have their default values
--- changed with |vim.diagnostic.config()|.
--- @class vim.diagnostic.JumpOpts : vim.diagnostic.GetOpts
---
--- The diagnostic to jump to. Mutually exclusive with {count}, {namespace},
--- and {severity}.
--- @field diagnostic? vim.Diagnostic
---
--- The number of diagnostics to move by, starting from {pos}. A positive
--- integer moves forward by {count} diagnostics, while a negative integer moves
--- backward by {count} diagnostics. Mutually exclusive with {diagnostic}.
--- @field count? integer
---
--- Cursor position as a `(row, col)` tuple. See |nvim_win_get_cursor()|. Used
--- to find the nearest diagnostic when {count} is used. Only used when {count}
--- is non-nil. Default is the current cursor position.
--- @field pos? [integer,integer]
---
--- Whether to loop around file or not. Similar to 'wrapscan'.
--- (default: `true`)
--- @field wrap? boolean
---
--- See |diagnostic-severity|.
--- @field severity? vim.diagnostic.SeverityFilter
---
--- Go to the diagnostic with the highest severity.
--- (default: `false`)
--- @field package _highest? boolean
---
--- If `true`, call |vim.diagnostic.open_float()| after moving.
--- If a table, pass the table as the {opts} parameter to |vim.diagnostic.open_float()|.
--- Unless overridden, the float will show diagnostics at the new cursor
--- position (as if "cursor" were passed to the "scope" option).
--- (default: `true`)
--- @field float? boolean|vim.diagnostic.Opts.Float
---
--- Window ID
--- (default: `0`)
--- @field winid? integer

--- Move to a diagnostic.
---
--- @param opts vim.diagnostic.JumpOpts
--- @return vim.Diagnostic? # The diagnostic that was moved to.
function M.jump(opts)
  vim.validate('opts', opts, 'table')

  -- One of "diagnostic" or "count" must be provided
  assert(
    opts.diagnostic or opts.count,
    'One of "diagnostic" or "count" must be specified in the options to vim.diagnostic.jump()'
  )

  -- Apply configuration options from vim.diagnostic.config()
  opts = vim.tbl_deep_extend('keep', opts, global_diagnostic_options.jump)

  if opts.diagnostic then
    goto_diagnostic(opts.diagnostic, opts)
    return opts.diagnostic
  end

  local count = opts.count
  if count == 0 then
    return nil
  end

  -- Support deprecated cursor_position alias
  if opts.cursor_position then
    vim.deprecate('opts.cursor_position', 'opts.pos', '0.13')
    opts.pos = opts.cursor_position
    opts.cursor_position = nil
  end

  local diag = nil
  while count ~= 0 do
    local next = next_diagnostic(count > 0, opts)
    if not next then
      break
    end

    -- Update cursor position
    opts.pos = { next.lnum + 1, next.col }

    if count > 0 then
      count = count - 1
    else
      count = count + 1
    end
    diag = next
  end

  goto_diagnostic(diag, opts)

  return diag
end

--- Move to the next diagnostic.
---
---@param opts? vim.diagnostic.JumpOpts
---@deprecated
function M.goto_next(opts)
  vim.deprecate('vim.diagnostic.goto_next()', 'vim.diagnostic.jump()', '0.13')
  goto_diagnostic(M.get_next(opts), opts)
end

M.handlers.signs = {
  show = function(namespace, bufnr, diagnostics, opts)
    vim.validate({
      namespace = { namespace, 'n' },
      bufnr = { bufnr, 'n' },
      diagnostics = {
        diagnostics,
        vim.islist,
        'a list of diagnostics',
      },
      opts = { opts, 't', true },
    })

    bufnr = get_bufnr(bufnr)
    opts = opts or {}

    if not api.nvim_buf_is_loaded(bufnr) then
      return
    end

    if opts.signs and opts.signs.severity then
      diagnostics = filter_by_severity(opts.signs.severity, diagnostics)
    end

    -- 10 is the default sign priority when none is explicitly specified
    local priority = opts.signs and opts.signs.priority or 10
    local get_priority --- @type function
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
    if not ns.user_data.sign_ns then
      ns.user_data.sign_ns =
        api.nvim_create_namespace(string.format('%s/diagnostic/signs', ns.name))
    end

    -- Handle legacy diagnostic sign definitions
    -- These were deprecated in 0.10 and will be removed in 0.12
    if opts.signs and not opts.signs.text and not opts.signs.numhl then
      for _, v in ipairs({ 'Error', 'Warn', 'Info', 'Hint' }) do
        local name = string.format('DiagnosticSign%s', v)
        local sign = vim.fn.sign_getdefined(name)[1]
        if sign then
          local severity = M.severity[v:upper()]
          vim.deprecate(
            'Defining diagnostic signs with :sign-define or sign_define()',
            'vim.diagnostic.config()',
            '0.12'
          )

          if not opts.signs.text then
            opts.signs.text = {}
          end

          if not opts.signs.numhl then
            opts.signs.numhl = {}
          end

          if not opts.signs.linehl then
            opts.signs.linehl = {}
          end

          if opts.signs.text[severity] == nil then
            opts.signs.text[severity] = sign.text or ''
          end

          if opts.signs.numhl[severity] == nil then
            opts.signs.numhl[severity] = sign.numhl
          end

          if opts.signs.linehl[severity] == nil then
            opts.signs.linehl[severity] = sign.linehl
          end
        end
      end
    end

    local text = {} ---@type table<vim.diagnostic.Severity|string, string>
    for k in pairs(M.severity) do
      if opts.signs.text and opts.signs.text[k] then
        text[k] = opts.signs.text[k]
      elseif type(k) == 'string' and not text[k] then
        text[k] = string.sub(k, 1, 1):upper()
      end
    end

    local numhl = opts.signs.numhl or {}
    local linehl = opts.signs.linehl or {}

    local line_count = api.nvim_buf_line_count(bufnr)

    for _, diagnostic in ipairs(diagnostics) do
      if diagnostic.lnum <= line_count then
        api.nvim_buf_set_extmark(bufnr, ns.user_data.sign_ns, diagnostic.lnum, 0, {
          sign_text = text[diagnostic.severity] or text[M.severity[diagnostic.severity]] or 'U',
          sign_hl_group = sign_highlight_map[diagnostic.severity],
          number_hl_group = numhl[diagnostic.severity],
          line_hl_group = linehl[diagnostic.severity],
          priority = get_priority(diagnostic.severity),
        })
      end
    end
  end,

  --- @param namespace integer
  --- @param bufnr integer
  hide = function(namespace, bufnr)
    local ns = M.get_namespace(namespace)
    if ns.user_data.sign_ns and api.nvim_buf_is_valid(bufnr) then
      api.nvim_buf_clear_namespace(bufnr, ns.user_data.sign_ns, 0, -1)
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
        vim.islist,
        'a list of diagnostics',
      },
      opts = { opts, 't', true },
    })

    bufnr = get_bufnr(bufnr)
    opts = opts or {}

    if not vim.api.nvim_buf_is_loaded(bufnr) then
      return
    end

    if opts.underline and opts.underline.severity then
      diagnostics = filter_by_severity(opts.underline.severity, diagnostics)
    end

    local ns = M.get_namespace(namespace)
    if not ns.user_data.underline_ns then
      ns.user_data.underline_ns =
        api.nvim_create_namespace(string.format('%s/diagnostic/underline', ns.name))
    end

    local underline_ns = ns.user_data.underline_ns
    for _, diagnostic in ipairs(diagnostics) do
      --- @type string?
      local higroup = underline_highlight_map[assert(diagnostic.severity)]

      if higroup == nil then
        -- Default to error if we don't have a highlight associated
        -- TODO(lewis6991): this is always nil since underline_highlight_map only has integer keys
        higroup = underline_highlight_map.Error
      end

      if diagnostic._tags then
        -- TODO(lewis6991): we should be able to stack these.
        if diagnostic._tags.unnecessary then
          higroup = 'DiagnosticUnnecessary'
        end
        if diagnostic._tags.deprecated then
          higroup = 'DiagnosticDeprecated'
        end
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
      if api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_clear_namespace(bufnr, ns.user_data.underline_ns, 0, -1)
      end
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
        vim.islist,
        'a list of diagnostics',
      },
      opts = { opts, 't', true },
    })

    bufnr = get_bufnr(bufnr)
    opts = opts or {}

    if not vim.api.nvim_buf_is_loaded(bufnr) then
      return
    end

    local severity --- @type vim.diagnostic.SeverityFilter?
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
      ns.user_data.virt_text_ns =
        api.nvim_create_namespace(string.format('%s/diagnostic/virtual_text', ns.name))
    end

    local virt_text_ns = ns.user_data.virt_text_ns
    local buffer_line_diagnostics = diagnostic_lines(diagnostics)
    for line, line_diagnostics in pairs(buffer_line_diagnostics) do
      if severity then
        line_diagnostics = filter_by_severity(severity, line_diagnostics)
      end
      local virt_texts = M._get_virt_text_chunks(line_diagnostics, opts.virtual_text)

      if virt_texts then
        api.nvim_buf_set_extmark(bufnr, virt_text_ns, line, 0, {
          hl_mode = opts.virtual_text.hl_mode or 'combine',
          virt_text = virt_texts,
          virt_text_pos = opts.virtual_text.virt_text_pos,
          virt_text_hide = opts.virtual_text.virt_text_hide,
          virt_text_win_col = opts.virtual_text.virt_text_win_col,
        })
      end
    end
    save_extmarks(virt_text_ns, bufnr)
  end,
  hide = function(namespace, bufnr)
    local ns = M.get_namespace(namespace)
    if ns.user_data.virt_text_ns then
      diagnostic_cache_extmarks[bufnr][ns.user_data.virt_text_ns] = {}
      if api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_clear_namespace(bufnr, ns.user_data.virt_text_ns, 0, -1)
      end
    end
  end,
}

--- Get virtual text chunks to display using |nvim_buf_set_extmark()|.
---
--- Exported for backward compatibility with
--- vim.lsp.diagnostic.get_virtual_text_chunks_for_line(). When that function is eventually removed,
--- this can be made local.
--- @private
--- @param line_diags table<integer,vim.Diagnostic>
--- @param opts vim.diagnostic.Opts.VirtualText
function M._get_virt_text_chunks(line_diags, opts)
  if #line_diags == 0 then
    return nil
  end

  opts = opts or {}
  local prefix = opts.prefix or '■'
  local suffix = opts.suffix or ''
  local spacing = opts.spacing or 4

  -- Create a little more space between virtual text and contents
  local virt_texts = { { string.rep(' ', spacing) } }

  for i = 1, #line_diags do
    local resolved_prefix = prefix
    if type(prefix) == 'function' then
      resolved_prefix = prefix(line_diags[i], i, #line_diags) or ''
    end
    table.insert(
      virt_texts,
      { resolved_prefix, virtual_text_highlight_map[line_diags[i].severity] }
    )
  end
  local last = line_diags[#line_diags]

  -- TODO(tjdevries): Allow different servers to be shown first somehow?
  -- TODO(tjdevries): Display server name associated with these?
  if last.message then
    if type(suffix) == 'function' then
      suffix = suffix(last) or ''
    end
    table.insert(virt_texts, {
      string.format(' %s%s', last.message:gsub('\r', ''):gsub('\n', '  '), suffix),
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
--- |vim.diagnostic.enable()|.
---
---@param namespace integer? Diagnostic namespace. When omitted, hide
---                          diagnostics from all namespaces.
---@param bufnr integer? Buffer number, or 0 for current buffer. When
---                      omitted, hide diagnostics in all buffers.
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

--- Check whether diagnostics are enabled.
---
--- @param filter vim.diagnostic.Filter?
--- @return boolean
--- @since 12
function M.is_enabled(filter)
  filter = filter or {}
  if filter.ns_id and M.get_namespace(filter.ns_id).disabled then
    return false
  elseif filter.bufnr == nil then
    -- See enable() logic.
    return vim.tbl_isempty(diagnostic_disabled) and not diagnostic_disabled[1]
  end

  local bufnr = get_bufnr(filter.bufnr)
  if type(diagnostic_disabled[bufnr]) == 'table' then
    return not diagnostic_disabled[bufnr][filter.ns_id]
  end

  return diagnostic_disabled[bufnr] == nil
end

--- @deprecated use `vim.diagnostic.is_enabled()`
function M.is_disabled(bufnr, namespace)
  vim.deprecate('vim.diagnostic.is_disabled()', 'vim.diagnostic.is_enabled()', '0.12')
  return not M.is_enabled { bufnr = bufnr or 0, ns_id = namespace }
end

--- Display diagnostics for the given namespace and buffer.
---
---@param namespace integer? Diagnostic namespace. When omitted, show
---                          diagnostics from all namespaces.
---@param bufnr integer? Buffer number, or 0 for current buffer. When omitted, show
---                      diagnostics in all buffers.
---@param diagnostics vim.Diagnostic[]? The diagnostics to display. When omitted, use the
---                             saved diagnostics for the given namespace and
---                             buffer. This can be used to display a list of diagnostics
---                             without saving them or to display only a subset of
---                             diagnostics. May not be used when {namespace}
---                             or {bufnr} is nil.
---@param opts? vim.diagnostic.Opts Display options.
function M.show(namespace, bufnr, diagnostics, opts)
  vim.validate({
    namespace = { namespace, 'n', true },
    bufnr = { bufnr, 'n', true },
    diagnostics = {
      diagnostics,
      function(v)
        return v == nil or vim.islist(v)
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

  if not M.is_enabled { bufnr = bufnr or 0, ns_id = namespace } then
    return
  end

  M.hide(namespace, bufnr)

  diagnostics = diagnostics or get_diagnostics(bufnr, { namespace = namespace }, true)

  if vim.tbl_isempty(diagnostics) then
    return
  end

  local opts_res = get_resolved_options(opts, namespace, bufnr)

  if opts_res.update_in_insert then
    clear_scheduled_display(namespace, bufnr)
  else
    local mode = api.nvim_get_mode()
    if string.sub(mode.mode, 1, 1) == 'i' then
      schedule_display(namespace, bufnr, opts_res)
      return
    end
  end

  if if_nil(opts_res.severity_sort, false) then
    if type(opts_res.severity_sort) == 'table' and opts_res.severity_sort.reverse then
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
    if handler.show and opts_res[handler_name] then
      handler.show(namespace, bufnr, diagnostics, opts_res)
    end
  end
end

--- Show diagnostics in a floating window.
---
---@param opts vim.diagnostic.Opts.Float?
---@return integer? float_bufnr
---@return integer? winid
function M.open_float(opts, ...)
  -- Support old (bufnr, opts) signature
  local bufnr --- @type integer?
  if opts == nil or type(opts) == 'number' then
    bufnr = opts
    opts = ... --- @type vim.diagnostic.Opts.Float
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
  local lnum, col --- @type integer, integer
  local opts_pos = opts.pos
  if scope == 'line' or scope == 'cursor' then
    if not opts_pos then
      local pos = api.nvim_win_get_cursor(0)
      lnum = pos[1] - 1
      col = pos[2]
    elseif type(opts_pos) == 'number' then
      lnum = opts_pos
    elseif type(opts_pos) == 'table' then
      lnum, col = opts_pos[1], opts_pos[2]
    else
      error("Invalid value for option 'pos'")
    end
  elseif scope ~= 'buffer' then
    error("Invalid value for option 'scope'")
  end

  local diagnostics = get_diagnostics(bufnr, opts --[[@as vim.diagnostic.GetOpts]], true)

  if scope == 'line' then
    --- @param d vim.Diagnostic
    diagnostics = vim.tbl_filter(function(d)
      return lnum >= d.lnum
        and lnum <= d.end_lnum
        and (d.lnum == d.end_lnum or lnum ~= d.end_lnum or d.end_col ~= 0)
    end, diagnostics)
  elseif scope == 'cursor' then
    -- If `col` is past the end of the line, show if the cursor is on the last char in the line
    local line_length = #api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, true)[1]
    --- @param d vim.Diagnostic
    diagnostics = vim.tbl_filter(function(d)
      return lnum >= d.lnum
        and lnum <= d.end_lnum
        and (lnum ~= d.lnum or col >= math.min(d.col, line_length - 1))
        and ((d.lnum == d.end_lnum and d.col == d.end_col) or lnum ~= d.end_lnum or col < d.end_col)
    end, diagnostics)
  end

  if vim.tbl_isempty(diagnostics) then
    return
  end

  local severity_sort = if_nil(opts.severity_sort, global_diagnostic_options.severity_sort)
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

  local lines = {} --- @type string[]
  local highlights = {} --- @type table[]
  local header = if_nil(opts.header, 'Diagnostics:')
  if header then
    vim.validate({
      header = {
        header,
        { 'string', 'table' },
        "'string' or 'table'",
      },
    })
    if type(header) == 'table' then
      -- Don't insert any lines for an empty string
      if string.len(if_nil(header[1], '')) > 0 then
        table.insert(lines, header[1])
        table.insert(highlights, { hlname = header[2] or 'Bold' })
      end
    elseif #header > 0 then
      table.insert(lines, header)
      table.insert(highlights, { hlname = 'Bold' })
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

  local prefix, prefix_hl_group --- @type string?, string?
  if prefix_opt then
    vim.validate({
      prefix = {
        prefix_opt,
        { 'string', 'table', 'function' },
        "'string' or 'table' or 'function'",
      },
    })
    if type(prefix_opt) == 'string' then
      prefix, prefix_hl_group = prefix_opt, 'NormalFloat'
    elseif type(prefix_opt) == 'table' then
      prefix, prefix_hl_group = prefix_opt[1] or '', prefix_opt[2] or 'NormalFloat'
    end
  end

  local suffix_opt = if_nil(opts.suffix, function(diagnostic)
    return diagnostic.code and string.format(' [%s]', diagnostic.code) or ''
  end)

  local suffix, suffix_hl_group --- @type string?, string?
  if suffix_opt then
    vim.validate({
      suffix = {
        suffix_opt,
        { 'string', 'table', 'function' },
        "'string' or 'table' or 'function'",
      },
    })
    if type(suffix_opt) == 'string' then
      suffix, suffix_hl_group = suffix_opt, 'NormalFloat'
    elseif type(suffix_opt) == 'table' then
      suffix, suffix_hl_group = suffix_opt[1] or '', suffix_opt[2] or 'NormalFloat'
    end
  end

  for i, diagnostic in ipairs(diagnostics) do
    if type(prefix_opt) == 'function' then
      --- @cast prefix_opt fun(...): string?, string?
      local prefix0, prefix_hl_group0 = prefix_opt(diagnostic, i, #diagnostics)
      prefix, prefix_hl_group = prefix0 or '', prefix_hl_group0 or 'NormalFloat'
    end
    if type(suffix_opt) == 'function' then
      --- @cast suffix_opt fun(...): string?, string?
      local suffix0, suffix_hl_group0 = suffix_opt(diagnostic, i, #diagnostics)
      suffix, suffix_hl_group = suffix0 or '', suffix_hl_group0 or 'NormalFloat'
    end
    --- @type string?
    local hiname = floating_highlight_map[assert(diagnostic.severity)]
    local message_lines = vim.split(diagnostic.message, '\n')
    for j = 1, #message_lines do
      local pre = j == 1 and prefix or string.rep(' ', #prefix)
      local suf = j == #message_lines and suffix or ''
      table.insert(lines, pre .. message_lines[j] .. suf)
      table.insert(highlights, {
        hlname = hiname,
        prefix = {
          length = j == 1 and #prefix or 0,
          hlname = prefix_hl_group,
        },
        suffix = {
          length = j == #message_lines and #suffix or 0,
          hlname = suffix_hl_group,
        },
      })
    end
  end

  -- Used by open_floating_preview to allow the float to be focused
  if not opts.focus_id then
    opts.focus_id = scope
  end
  local float_bufnr, winnr = vim.lsp.util.open_floating_preview(lines, 'plaintext', opts)
  for i, hl in ipairs(highlights) do
    local line = lines[i]
    local prefix_len = hl.prefix and hl.prefix.length or 0
    local suffix_len = hl.suffix and hl.suffix.length or 0
    if prefix_len > 0 then
      api.nvim_buf_add_highlight(float_bufnr, -1, hl.prefix.hlname, i - 1, 0, prefix_len)
    end
    api.nvim_buf_add_highlight(float_bufnr, -1, hl.hlname, i - 1, prefix_len, #line - suffix_len)
    if suffix_len > 0 then
      api.nvim_buf_add_highlight(float_bufnr, -1, hl.suffix.hlname, i - 1, #line - suffix_len, -1)
    end
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
---@param namespace integer? Diagnostic namespace. When omitted, remove
---                          diagnostics from all namespaces.
---@param bufnr integer? Remove diagnostics for the given buffer. When omitted,
---                     diagnostics are removed for all buffers.
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

    if api.nvim_buf_is_valid(iter_bufnr) then
      api.nvim_exec_autocmds('DiagnosticChanged', {
        modeline = false,
        buffer = iter_bufnr,
        data = { diagnostics = {} },
      })
    else
      diagnostic_cache[iter_bufnr] = nil
    end
  end
end

--- Configuration table with the following keys:
--- @class vim.diagnostic.setqflist.Opts
--- @inlinedoc
---
--- Only add diagnostics from the given namespace.
--- @field namespace? integer
---
--- Open quickfix list after setting.
--- (default: `true`)
--- @field open? boolean
---
--- Title of quickfix list. Defaults to "Diagnostics".
--- @field title? string
---
--- See |diagnostic-severity|.
--- @field severity? vim.diagnostic.Severity

--- Add all diagnostics to the quickfix list.
---
---@param opts? vim.diagnostic.setqflist.Opts
function M.setqflist(opts)
  set_list(false, opts)
end

---Configuration table with the following keys:
--- @class vim.diagnostic.setloclist.Opts
--- @inlinedoc
---
--- Only add diagnostics from the given namespace.
--- @field namespace? integer
---
--- Window number to set location list for.
--- (default: `0`)
--- @field winnr? integer
---
--- Open the location list after setting.
--- (default: `true`)
--- @field open? boolean
---
--- Title of the location list. Defaults to "Diagnostics".
--- @field title? string
---
--- See |diagnostic-severity|.
--- @field severity? vim.diagnostic.Severity

--- Add buffer diagnostics to the location list.
---
---@param opts? vim.diagnostic.setloclist.Opts
function M.setloclist(opts)
  set_list(true, opts)
end

--- @deprecated use `vim.diagnostic.enable(false, …)`
function M.disable(bufnr, namespace)
  vim.deprecate('vim.diagnostic.disable()', 'vim.diagnostic.enable(false, …)', '0.12')
  M.enable(false, { bufnr = bufnr, ns_id = namespace })
end

--- Enables or disables diagnostics.
---
--- To "toggle", pass the inverse of `is_enabled()`:
---
--- ```lua
--- vim.diagnostic.enable(not vim.diagnostic.is_enabled())
--- ```
---
--- @param enable (boolean|nil) true/nil to enable, false to disable
--- @param filter vim.diagnostic.Filter?
function M.enable(enable, filter)
  -- Deprecated signature. Drop this in 0.12
  local legacy = (enable or filter)
    and vim.tbl_contains({ 'number', 'nil' }, type(enable))
    and vim.tbl_contains({ 'number', 'nil' }, type(filter))

  if legacy then
    vim.deprecate(
      'vim.diagnostic.enable(buf:number, namespace:number)',
      'vim.diagnostic.enable(enable:boolean, filter:table)',
      '0.12'
    )

    vim.validate({
      enable = { enable, 'n', true }, -- Legacy `bufnr` arg.
      filter = { filter, 'n', true }, -- Legacy `namespace` arg.
    })

    local ns_id = type(filter) == 'number' and filter or nil
    filter = {}
    filter.ns_id = ns_id
    filter.bufnr = type(enable) == 'number' and enable or nil
    enable = true
  else
    filter = filter or {}
    vim.validate({
      enable = { enable, 'b', true },
      filter = { filter, 't', true },
    })
  end

  enable = enable == nil and true or enable
  local bufnr = filter.bufnr

  if bufnr == nil then
    if filter.ns_id == nil then
      diagnostic_disabled = (
        enable
          -- Enable everything by setting diagnostic_disabled to an empty table.
          and {}
        -- Disable everything (including as yet non-existing buffers and namespaces) by setting
        -- diagnostic_disabled to an empty table and set its metatable to always return true.
        or setmetatable({}, {
          __index = function()
            return true
          end,
        })
      )
    else
      local ns = M.get_namespace(filter.ns_id)
      ns.disabled = not enable
    end
  else
    bufnr = get_bufnr(bufnr)
    if filter.ns_id == nil then
      diagnostic_disabled[bufnr] = (not enable) and true or nil
    else
      if type(diagnostic_disabled[bufnr]) ~= 'table' then
        if enable then
          return
        else
          diagnostic_disabled[bufnr] = {}
        end
      end
      diagnostic_disabled[bufnr][filter.ns_id] = (not enable) and true or nil
    end
  end

  if enable then
    M.show(filter.ns_id, bufnr)
  else
    M.hide(filter.ns_id, bufnr)
  end
end

--- Parse a diagnostic from a string.
---
--- For example, consider a line of output from a linter:
---
--- ```
--- WARNING filename:27:3: Variable 'foo' does not exist
--- ```
---
--- This can be parsed into |vim.Diagnostic| structure with:
---
--- ```lua
--- local s = "WARNING filename:27:3: Variable 'foo' does not exist"
--- local pattern = "^(%w+) %w+:(%d+):(%d+): (.+)$"
--- local groups = { "severity", "lnum", "col", "message" }
--- vim.diagnostic.match(s, pattern, groups, { WARNING = vim.diagnostic.WARN })
--- ```
---
---@param str string String to parse diagnostics from.
---@param pat string Lua pattern with capture groups.
---@param groups string[] List of fields in a |vim.Diagnostic| structure to
---                    associate with captures from {pat}.
---@param severity_map table A table mapping the severity field from {groups}
---                          with an item from |vim.diagnostic.severity|.
---@param defaults table? Table of default values for any fields not listed in {groups}.
---                       When omitted, numeric values default to 0 and "severity" defaults to
---                       ERROR.
---@return vim.Diagnostic?: |vim.Diagnostic| structure or `nil` if {pat} fails to match {str}.
function M.match(str, pat, groups, severity_map, defaults)
  vim.validate({
    str = { str, 's' },
    pat = { pat, 's' },
    groups = { groups, 't' },
    severity_map = { severity_map, 't', true },
    defaults = { defaults, 't', true },
  })

  --- @type table<string,vim.diagnostic.Severity>
  severity_map = severity_map or M.severity

  local matches = { str:match(pat) } --- @type any[]
  if vim.tbl_isempty(matches) then
    return
  end

  local diagnostic = {} --- @type type<string,any>

  for i, match in ipairs(matches) do
    local field = groups[i]
    if field == 'severity' then
      match = severity_map[match]
    elseif field == 'lnum' or field == 'end_lnum' or field == 'col' or field == 'end_col' then
      match = assert(tonumber(match)) - 1
    end
    diagnostic[field] = match --- @type any
  end

  diagnostic = vim.tbl_extend('keep', diagnostic, defaults or {}) --- @type vim.Diagnostic
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
---@param diagnostics vim.Diagnostic[]
---@return table[] : Quickfix list items |setqflist-what|
function M.toqflist(diagnostics)
  vim.validate({
    diagnostics = {
      diagnostics,
      vim.islist,
      'a list of diagnostics',
    },
  })

  local list = {} --- @type table[]
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
      if a.lnum == b.lnum then
        return a.col < b.col
      else
        return a.lnum < b.lnum
      end
    else
      return a.bufnr < b.bufnr
    end
  end)
  return list
end

--- Convert a list of quickfix items to a list of diagnostics.
---
---@param list table[] List of quickfix items from |getqflist()| or |getloclist()|.
---@return vim.Diagnostic[]
function M.fromqflist(list)
  vim.validate({
    list = {
      list,
      vim.islist,
      'a list of quickfix items',
    },
  })

  local diagnostics = {} --- @type vim.Diagnostic[]
  for _, item in ipairs(list) do
    if item.valid == 1 then
      local lnum = math.max(0, item.lnum - 1)
      local col = math.max(0, item.col - 1)
      local end_lnum = item.end_lnum > 0 and (item.end_lnum - 1) or lnum
      local end_col = item.end_col > 0 and (item.end_col - 1) or col
      local severity = item.type ~= '' and M.severity[item.type] or M.severity.ERROR
      diagnostics[#diagnostics + 1] = {
        bufnr = item.bufnr,
        lnum = lnum,
        col = col,
        end_lnum = end_lnum,
        end_col = end_col,
        severity = severity,
        message = item.text,
      }
    end
  end
  return diagnostics
end

return M
