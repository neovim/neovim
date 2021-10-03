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
  update_in_insert = false,
  severity_sort = false,
}

-- Local functions {{{

---@private
local function to_severity(severity)
  return type(severity) == 'string' and M.severity[string.upper(severity)] or severity
end

---@private
local function filter_by_severity(severity, diagnostics)
  if not severity then
    return diagnostics
  end

  if type(severity) ~= "table" then
    severity = to_severity(severity)
    return vim.tbl_filter(function(t) return t.severity == severity end, diagnostics)
  end

  local min_severity = to_severity(severity.min) or M.severity.HINT
  local max_severity = to_severity(severity.max) or M.severity.ERROR

  return vim.tbl_filter(function(t) return t.severity <= min_severity and t.severity >= max_severity end, diagnostics)
end

---@private
local function prefix_source(source, diagnostics)
  vim.validate { source = {source, function(v)
    return v == "always" or v == "if_many"
  end, "Invalid value for option 'source'" } }

  if source == "if_many" then
    local sources = {}
    for _, d in pairs(diagnostics) do
      if d.source then
        sources[d.source] = true
      end
    end
    if #vim.tbl_keys(sources) <= 1 then
      return diagnostics
    end
  end

  return vim.tbl_map(function(d)
    if not d.source then
      return d
    end

    local t = vim.deepcopy(d)
    t.message = string.format("%s: %s", d.source, d.message)
    return t
  end, diagnostics)
end

---@private
local function reformat_diagnostics(format, diagnostics)
  vim.validate {
    format = {format, 'f'},
    diagnostics = {diagnostics, 't'},
  }

  local formatted = vim.deepcopy(diagnostics)
  for _, diagnostic in ipairs(formatted) do
    diagnostic.message = format(diagnostic)
  end
  return formatted
end

---@private
local function resolve_optional_value(option, namespace, bufnr)
  local enabled_val = {}

  if not option then
    return false
  elseif option == true then
    return enabled_val
  elseif type(option) == 'function' then
    local val = option(namespace, bufnr)
    if val == true then
      return enabled_val
    else
      return val
    end
  elseif type(option) == 'table' then
    return option
  else
    error("Unexpected option type: " .. vim.inspect(option))
  end
end

local all_namespaces = {}

---@private
local function get_namespace(ns)
  if not all_namespaces[ns] then
    local name
    for k, v in pairs(vim.api.nvim_get_namespaces()) do
      if ns == v then
        name = k
        break
      end
    end

    if not name then
      return vim.notify("namespace does not exist or is anonymous", vim.log.levels.ERROR)
    end

    all_namespaces[ns] = {
      name = name,
      sign_group = string.format("vim.diagnostic.%s", name),
      opts = {}
    }
  end
  return all_namespaces[ns]
end

---@private
local function get_resolved_options(opts, namespace, bufnr)
  local ns = get_namespace(namespace)
  local resolved = vim.tbl_extend('keep', opts or {}, ns.opts, global_diagnostic_options)
  for k in pairs(global_diagnostic_options) do
    if resolved[k] ~= nil then
      resolved[k] = resolve_optional_value(resolved[k], namespace, bufnr)
    end
  end
  return resolved
end

-- Default diagnostic highlights
local diagnostic_severities = {
  [M.severity.ERROR] = { ctermfg = 1, guifg = "Red" };
  [M.severity.WARN] = { ctermfg = 3, guifg = "Orange" };
  [M.severity.INFO] = { ctermfg = 4, guifg = "LightBlue" };
  [M.severity.HINT] = { ctermfg = 7, guifg = "LightGrey" };
}

-- Make a map from DiagnosticSeverity -> Highlight Name
---@private
local function make_highlight_map(base_name)
  local result = {}
  for k in pairs(diagnostic_severities) do
    local name = M.severity[k]
    name = name:sub(1, 1) .. name:sub(2):lower()
    result[k] = "Diagnostic" .. base_name .. name
  end

  return result
end

local virtual_text_highlight_map = make_highlight_map("VirtualText")
local underline_highlight_map = make_highlight_map("Underline")
local floating_highlight_map = make_highlight_map("Floating")
local sign_highlight_map = make_highlight_map("Sign")

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

-- Metatable that automatically creates an empty table when assigning to a missing key
local bufnr_and_namespace_cacher_mt = {
  __index = function(t, bufnr)
    if not bufnr or bufnr == 0 then
      bufnr = vim.api.nvim_get_current_buf()
    end

    if rawget(t, bufnr) == nil then
      rawset(t, bufnr, {})
    end

    return rawget(t, bufnr)
  end,

  __newindex = function(t, bufnr, v)
    if not bufnr or bufnr == 0 then
      bufnr = vim.api.nvim_get_current_buf()
    end

    rawset(t, bufnr, v)
  end,
}

local diagnostic_cleanup = setmetatable({}, bufnr_and_namespace_cacher_mt)
local diagnostic_cache = setmetatable({}, bufnr_and_namespace_cacher_mt)
local diagnostic_cache_extmarks = setmetatable({}, bufnr_and_namespace_cacher_mt)
local diagnostic_attached_buffers = {}
local diagnostic_disabled = {}
local bufs_waiting_to_update = setmetatable({}, bufnr_and_namespace_cacher_mt)

---@private
local function is_disabled(namespace, bufnr)
  if type(diagnostic_disabled[bufnr]) == "table" then
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
    diagnostic.severity = diagnostic.severity and to_severity(diagnostic.severity) or M.severity.ERROR
    diagnostic.end_lnum = diagnostic.end_lnum or diagnostic.lnum
    diagnostic.end_col = diagnostic.end_col or diagnostic.col
    diagnostic.namespace = namespace
    diagnostic.bufnr = bufnr
  end
  diagnostic_cache[bufnr][namespace] = diagnostics
end

---@private
local function clear_diagnostic_cache(namespace, bufnr)
  diagnostic_cache[bufnr][namespace] = nil
end

---@private
local function restore_extmarks(bufnr, last)
  for ns, extmarks in pairs(diagnostic_cache_extmarks[bufnr]) do
    local extmarks_current = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {details = true})
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
        -- HACK: end_row should be end_line
        if opts.end_row then
          opts.end_line = opts.end_row
          opts.end_row = nil
        end
        pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, extmark[2], extmark[3], opts)
      end
    end
  end
end

---@private
local function save_extmarks(namespace, bufnr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  if not diagnostic_attached_buffers[bufnr] then
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = function(_, _, _, _, _, last)
        restore_extmarks(bufnr, last - 1)
      end,
      on_detach = function()
        diagnostic_cache_extmarks[bufnr] = nil
      end})
    diagnostic_attached_buffers[bufnr] = true
  end
  diagnostic_cache_extmarks[bufnr][namespace] = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {details = true})
end

local registered_autocmds = {}

---@private
local function make_augroup_key(namespace, bufnr)
  local ns = get_namespace(namespace)
  return string.format("DiagnosticInsertLeave:%s:%s", bufnr, ns.name)
end

--- Table of autocmd events to fire the update for displaying new diagnostic information
local insert_leave_auto_cmds = { "InsertLeave", "CursorHoldI" }

---@private
local function schedule_display(namespace, bufnr, args)
  bufs_waiting_to_update[bufnr][namespace] = args

  local key = make_augroup_key(namespace, bufnr)
  if not registered_autocmds[key] then
    vim.cmd(string.format("augroup %s", key))
    vim.cmd("  au!")
    vim.cmd(
      string.format(
        [[autocmd %s <buffer=%s> lua vim.diagnostic._execute_scheduled_display(%s, %s)]],
        table.concat(insert_leave_auto_cmds, ","),
        bufnr,
        namespace,
        bufnr
      )
    )
    vim.cmd("augroup END")

    registered_autocmds[key] = true
  end
end

---@private
local function clear_scheduled_display(namespace, bufnr)
  local key = make_augroup_key(namespace, bufnr)

  if registered_autocmds[key] then
    vim.cmd(string.format("augroup %s", key))
    vim.cmd("  au!")
    vim.cmd("augroup END")

    registered_autocmds[key] = nil
  end
end

---@private
--- Open a floating window with the provided diagnostics
---@param opts table Configuration table
---     - show_header (boolean, default true): Show "Diagnostics:" header
---     - all opts for |vim.util.open_floating_preview()| can be used here
---@param diagnostics table: The diagnostics to display
---@return table {popup_bufnr, win_id}
local function show_diagnostics(opts, diagnostics)
  if not diagnostics or vim.tbl_isempty(diagnostics) then
    return
  end
  local lines = {}
  local highlights = {}
  local show_header = vim.F.if_nil(opts.show_header, true)
  if show_header then
    table.insert(lines, "Diagnostics:")
    table.insert(highlights, {0, "Bold"})
  end

  if opts.format then
    diagnostics = reformat_diagnostics(opts.format, diagnostics)
  end

  if opts.source then
    diagnostics = prefix_source(opts.source, diagnostics)
  end

  for i, diagnostic in ipairs(diagnostics) do
    local prefix = string.format("%d. ", i)
    local hiname = floating_highlight_map[diagnostic.severity]
    assert(hiname, 'unknown severity: ' .. tostring(diagnostic.severity))

    local message_lines = vim.split(diagnostic.message, '\n', true)
    table.insert(lines, prefix..message_lines[1])
    table.insert(highlights, {#prefix, hiname})
    for j = 2, #message_lines do
      table.insert(lines, string.rep(' ', #prefix) .. message_lines[j])
      table.insert(highlights, {0, hiname})
    end
  end

  local popup_bufnr, winnr = require('vim.lsp.util').open_floating_preview(lines, 'plaintext', opts)
  for i, hi in ipairs(highlights) do
    local prefixlen, hiname = unpack(hi)
    -- Start highlight after the prefix
    vim.api.nvim_buf_add_highlight(popup_bufnr, -1, hiname, i-1, prefixlen, -1)
  end

  return popup_bufnr, winnr
end

---@private
local function set_list(loclist, opts)
  opts = opts or {}
  local open = vim.F.if_nil(opts.open, true)
  local title = opts.title or "Diagnostics"
  local winnr = opts.winnr or 0
  local bufnr
  if loclist then
    bufnr = vim.api.nvim_win_get_buf(winnr)
  end
  local diagnostics = M.get(bufnr, opts)
  local items = M.toqflist(diagnostics)
  if loclist then
    vim.fn.setloclist(winnr, {}, ' ', { title = title, items = items })
  else
    vim.fn.setqflist({}, ' ', { title = title, items = items })
  end
  if open then
    vim.api.nvim_command(loclist and "lopen" or "copen")
  end
end

---@private
local function clamp_line_numbers(bufnr, diagnostics)
  local buf_line_count = vim.api.nvim_buf_line_count(bufnr)
  if buf_line_count == 0 then
    return
  end

  for _, diagnostic in ipairs(diagnostics) do
    diagnostic.lnum = math.max(math.min(diagnostic.lnum, buf_line_count - 1), 0)
    diagnostic.end_lnum = math.max(math.min(diagnostic.end_lnum, buf_line_count - 1), 0)
  end
end

---@private
local function next_diagnostic(position, search_forward, bufnr, opts, namespace)
  position[1] = position[1] - 1
  bufnr = get_bufnr(bufnr)
  local wrap = vim.F.if_nil(opts.wrap, true)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local diagnostics = M.get(bufnr, vim.tbl_extend("keep", opts, {namespace = namespace}))
  clamp_line_numbers(bufnr, diagnostics)
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
      local sort_diagnostics, is_next
      if search_forward then
        sort_diagnostics = function(a, b) return a.col < b.col end
        is_next = function(diagnostic) return diagnostic.col > position[2] end
      else
        sort_diagnostics = function(a, b) return a.col > b.col end
        is_next = function(diagnostic) return diagnostic.col < position[2] end
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

  local enable_popup = vim.F.if_nil(opts.enable_popup, true)
  local win_id = opts.win_id or vim.api.nvim_get_current_win()

  if not pos then
    vim.api.nvim_echo({{"No more valid diagnostics to move to", "WarningMsg"}}, true, {})
    return
  end

  vim.api.nvim_win_set_cursor(win_id, {pos[1] + 1, pos[2]})

  if enable_popup then
    -- This is a bit weird... I'm surprised that we need to wait til the next tick to do this.
    vim.schedule(function()
      M.show_position_diagnostics(opts.popup_opts, vim.api.nvim_win_get_buf(win_id))
    end)
  end
end

-- }}}

-- Public API {{{

--- Configure diagnostic options globally or for a specific diagnostic
--- namespace.
---
---@note Each of the configuration options below accepts one of the following:
---         - `false`: Disable this feature
---         - `true`: Enable this feature, use default settings.
---         - `table`: Enable this feature with overrides.
---         - `function`: Function with signature (namespace, bufnr) that returns any of the above.
---
---@param opts table Configuration table with the following keys:
---       - underline: (default true) Use underline for diagnostics. Options:
---                    * severity: Only underline diagnostics matching the given severity
---                    |diagnostic-severity|
---       - virtual_text: (default true) Use virtual text for diagnostics. Options:
---                       * severity: Only show virtual text for diagnostics matching the given
---                       severity |diagnostic-severity|
---                       * source: (string) Include the diagnostic source in virtual
---                       text. One of "always" or "if_many".
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
---       - update_in_insert: (default false) Update diagnostics in Insert mode (if false,
---                           diagnostics are updated on InsertLeave)
---       - severity_sort: (default false) Sort diagnostics by severity. This affects the order in
---                         which signs and virtual text are displayed. When true, higher severities
---                         are displayed before lower severities (e.g. ERROR is displayed before WARN).
---                         Options:
---                         * reverse: (boolean) Reverse sort order
---@param namespace number|nil Update the options for the given namespace. When omitted, update the
---                            global diagnostic options.
function M.config(opts, namespace)
  vim.validate {
    opts = { opts, 't' },
    namespace = { namespace, 'n', true },
  }

  local t
  if namespace then
    local ns = get_namespace(namespace)
    t = ns.opts
  else
    t = global_diagnostic_options
  end

  for opt in pairs(global_diagnostic_options) do
    if opts[opt] ~= nil then
      t[opt] = opts[opt]
    end
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
  vim.validate {
    namespace = {namespace, 'n'},
    bufnr = {bufnr, 'n'},
    diagnostics = {diagnostics, 't'},
    opts = {opts, 't', true},
  }

  if vim.tbl_isempty(diagnostics) then
    clear_diagnostic_cache(namespace, bufnr)
  else
    if not diagnostic_cleanup[bufnr][namespace] then
      diagnostic_cleanup[bufnr][namespace] = true

      -- Clean up our data when the buffer unloads.
      vim.api.nvim_buf_attach(bufnr, false, {
        on_detach = function(_, b)
          clear_diagnostic_cache(b, namespace)
          diagnostic_cleanup[b][namespace] = nil
        end
      })
    end
    set_diagnostic_cache(namespace, bufnr, diagnostics)
  end

  if vim.api.nvim_buf_is_loaded(bufnr) then
    M.show(namespace, bufnr, diagnostics, opts)
  elseif opts then
    M.config(opts, namespace)
  end

  vim.api.nvim_command("doautocmd <nomodeline> User DiagnosticsChanged")
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
  vim.validate {
    bufnr = { bufnr, 'n', true },
    opts = { opts, 't', true },
  }

  opts = opts or {}

  local namespace = opts.namespace
  local diagnostics = {}

  ---@private
  local function add(d)
    if not opts.lnum or d.lnum == opts.lnum then
      table.insert(diagnostics, d)
    end
  end

  if namespace == nil and bufnr == nil then
    for _, t in pairs(diagnostic_cache) do
      for _, v in pairs(t) do
        for _, diagnostic in pairs(v) do
          add(diagnostic)
        end
      end
    end
  elseif namespace == nil then
    for iter_namespace in pairs(diagnostic_cache[bufnr]) do
      for _, diagnostic in pairs(diagnostic_cache[bufnr][iter_namespace]) do
        add(diagnostic)
      end
    end
  elseif bufnr == nil then
    for _, t in pairs(diagnostic_cache) do
      for _, diagnostic in pairs(t[namespace] or {}) do
        add(diagnostic)
      end
    end
  else
    for _, diagnostic in pairs(diagnostic_cache[bufnr][namespace] or {}) do
      add(diagnostic)
    end
  end

  if opts.severity then
    diagnostics = filter_by_severity(opts.severity, diagnostics)
  end

  return diagnostics
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

  return {prev.lnum, prev.col}
end

--- Move to the previous diagnostic in the current buffer.
---@param opts table See |vim.diagnostic.goto_next()|
function M.goto_prev(opts)
  return diagnostic_move_pos(
    opts,
    M.get_prev_pos(opts)
  )
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

  return {next.lnum, next.col}
end

--- Move to the next diagnostic.
---
---@param opts table|nil Configuration table with the following keys:
---         - namespace: (number) Only consider diagnostics from the given namespace.
---         - cursor_position: (cursor position) Cursor position as a (row, col) tuple. See
---                          |nvim_win_get_cursor()|. Defaults to the current cursor position.
---         - wrap: (boolean, default true) Whether to loop around file or not. Similar to 'wrapscan'.
---         - severity: See |diagnostic-severity|.
---         - enable_popup: (boolean, default true) Call |vim.diagnostic.show_line_diagnostics()|
---                       on jump.
---         - popup_opts: (table) Table to pass as {opts} parameter to
---                     |vim.diagnostic.show_line_diagnostics()|
---         - win_id: (number, default 0) Window ID
function M.goto_next(opts)
  return diagnostic_move_pos(
    opts,
    M.get_next_pos(opts)
  )
end

-- Diagnostic Setters {{{

--- Set signs for given diagnostics.
---
---@param namespace number The diagnostic namespace
---@param bufnr number Buffer number
---@param diagnostics table A list of diagnostic items |diagnostic-structure|. When omitted the
---                       current diagnostics in the given buffer are used.
---@param opts table Configuration table with the following keys:
---            - priority: Set the priority of the signs |sign-priority|.
---@private
function M._set_signs(namespace, bufnr, diagnostics, opts)
  vim.validate {
    namespace = {namespace, 'n'},
    bufnr = {bufnr, 'n'},
    diagnostics = {diagnostics, 't'},
    opts = {opts, 't', true},
  }

  bufnr = get_bufnr(bufnr)
  opts = get_resolved_options({ signs = opts }, namespace, bufnr)

  if opts.signs and opts.signs.severity then
    diagnostics = filter_by_severity(opts.signs.severity, diagnostics)
  end

  local ns = get_namespace(namespace)

  define_default_signs()

  -- 10 is the default sign priority when none is explicitly specified
  local priority = opts.signs and opts.signs.priority or 10
  local get_priority
  if opts.severity_sort then
    if type(opts.severity_sort) == "table" and opts.severity_sort.reverse then
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

  for _, diagnostic in ipairs(diagnostics) do
    vim.fn.sign_place(
      0,
      ns.sign_group,
      sign_highlight_map[diagnostic.severity],
      bufnr,
      {
        priority = get_priority(diagnostic.severity),
        lnum = diagnostic.lnum + 1
      }
    )
  end
end

--- Set underline for given diagnostics.
---
---@param namespace number The diagnostic namespace
---@param bufnr number Buffer number
---@param diagnostics table A list of diagnostic items |diagnostic-structure|. When omitted the
---                       current diagnostics in the given buffer are used.
---@param opts table Configuration table. Currently unused.
---@private
function M._set_underline(namespace, bufnr, diagnostics, opts)
  vim.validate {
    namespace = {namespace, 'n'},
    bufnr = {bufnr, 'n'},
    diagnostics = {diagnostics, 't'},
    opts = {opts, 't', true},
  }

  bufnr = get_bufnr(bufnr)
  opts = get_resolved_options({ underline = opts }, namespace, bufnr).underline

  if opts and opts.severity then
    diagnostics = filter_by_severity(opts.severity, diagnostics)
  end

  for _, diagnostic in ipairs(diagnostics) do
    local higroup = underline_highlight_map[diagnostic.severity]

    if higroup == nil then
      -- Default to error if we don't have a highlight associated
      higroup = underline_highlight_map.Error
    end

    vim.highlight.range(
      bufnr,
      namespace,
      higroup,
      { diagnostic.lnum, diagnostic.col },
      { diagnostic.end_lnum, diagnostic.end_col }
    )
  end
end

--- Set virtual text for given diagnostics.
---
---@param namespace number The diagnostic namespace
---@param bufnr number Buffer number
---@param diagnostics table A list of diagnostic items |diagnostic-structure|. When omitted the
---                       current diagnostics in the given buffer are used.
---@param opts table|nil Configuration table with the following keys:
---            - prefix: (string) Prefix to display before virtual text on line.
---            - spacing: (number) Number of spaces to insert before virtual text.
---            - source: (string) Include the diagnostic source in virtual text. One of "always" or
---                      "if_many".
---@private
function M._set_virtual_text(namespace, bufnr, diagnostics, opts)
  vim.validate {
    namespace = {namespace, 'n'},
    bufnr = {bufnr, 'n'},
    diagnostics = {diagnostics, 't'},
    opts = {opts, 't', true},
  }

  bufnr = get_bufnr(bufnr)
  opts = get_resolved_options({ virtual_text = opts }, namespace, bufnr).virtual_text

  if opts and opts.format then
    diagnostics = reformat_diagnostics(opts.format, diagnostics)
  end

  if opts and opts.source then
    diagnostics = prefix_source(opts.source, diagnostics)
  end

  local buffer_line_diagnostics = diagnostic_lines(diagnostics)
  for line, line_diagnostics in pairs(buffer_line_diagnostics) do
    if opts and opts.severity then
      line_diagnostics = filter_by_severity(opts.severity, line_diagnostics)
    end
    local virt_texts = M._get_virt_text_chunks(line_diagnostics, opts)

    if virt_texts then
      vim.api.nvim_buf_set_extmark(bufnr, namespace, line, 0, {
        hl_mode = "combine",
        virt_text = virt_texts,
      })
    end
  end
end

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
  local prefix = opts.prefix or "■"
  local spacing = opts.spacing or 4

  -- Create a little more space between virtual text and contents
  local virt_texts = {{string.rep(" ", spacing)}}

  for i = 1, #line_diags - 1 do
    table.insert(virt_texts, {prefix, virtual_text_highlight_map[line_diags[i].severity]})
  end
  local last = line_diags[#line_diags]

  -- TODO(tjdevries): Allow different servers to be shown first somehow?
  -- TODO(tjdevries): Display server name associated with these?
  if last.message then
    table.insert(
      virt_texts,
      {
        string.format("%s %s", prefix, last.message:gsub("\r", ""):gsub("\n", "  ")),
        virtual_text_highlight_map[last.severity]
      }
    )

    return virt_texts
  end
end

--- Callback scheduled when leaving Insert mode.
---
--- This function must be exported publicly so that it is available to be
--- called from the Vimscript autocommand.
---
--- See @ref schedule_display()
---
---@private
function M._execute_scheduled_display(namespace, bufnr)
  local args = bufs_waiting_to_update[bufnr][namespace]
  if not args then
    return
  end

  -- Clear the args so we don't display unnecessarily.
  bufs_waiting_to_update[bufnr][namespace] = nil

  M.show(namespace, bufnr, nil, args)
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
---@param namespace number The diagnostic namespace
---@param bufnr number|nil Buffer number. Defaults to the current buffer.
function M.hide(namespace, bufnr)
  vim.validate {
    namespace = { namespace, 'n' },
    bufnr = { bufnr, 'n', true },
  }

  bufnr = get_bufnr(bufnr)
  diagnostic_cache_extmarks[bufnr][namespace] = {}

  local ns = get_namespace(namespace)

  -- clear sign group
  vim.fn.sign_unplace(ns.sign_group, {buffer=bufnr})

  -- clear virtual text namespace
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
end


--- Display diagnostics for the given namespace and buffer.
---
---@param namespace number Diagnostic namespace
---@param bufnr number|nil Buffer number. Defaults to the current buffer.
---@param diagnostics table|nil The diagnostics to display. When omitted, use the
---                             saved diagnostics for the given namespace and
---                             buffer. This can be used to display a list of diagnostics
---                             without saving them or to display only a subset of
---                             diagnostics.
---@param opts table|nil Display options. See |vim.diagnostic.config()|.
function M.show(namespace, bufnr, diagnostics, opts)
  vim.validate {
    namespace = { namespace, 'n' },
    bufnr = { bufnr, 'n', true },
    diagnostics = { diagnostics, 't', true },
    opts = { opts, 't', true },
  }

  bufnr = get_bufnr(bufnr)
  if is_disabled(namespace, bufnr) then
    return
  end

  M.hide(namespace, bufnr)

  diagnostics = diagnostics or M.get(bufnr, {namespace=namespace})

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
    if type(opts.severity_sort) == "table" and opts.severity_sort.reverse then
      table.sort(diagnostics, function(a, b) return a.severity < b.severity end)
    else
      table.sort(diagnostics, function(a, b) return a.severity > b.severity end)
    end
  end

  clamp_line_numbers(bufnr, diagnostics)

  if opts.underline then
    M._set_underline(namespace, bufnr, diagnostics, opts.underline)
  end

  if opts.virtual_text then
    M._set_virtual_text(namespace, bufnr, diagnostics, opts.virtual_text)
  end

  if opts.signs then
    M._set_signs(namespace, bufnr, diagnostics, opts.signs)
  end

  save_extmarks(namespace, bufnr)
end

--- Open a floating window with the diagnostics at the given position.
---
---@param opts table|nil Configuration table with the same keys as
---            |vim.lsp.util.open_floating_preview()| in addition to the following:
---            - namespace: (number) Limit diagnostics to the given namespace
---            - severity: See |diagnostic-severity|.
---            - show_header: (boolean, default true) Show "Diagnostics:" header
---            - source: (string) Include the diagnostic source in
---                      the message. One of "always" or "if_many".
---            - format: (function) A function that takes a diagnostic as input and returns a
---                      string. The return value is the text used to display the diagnostic.
---@param bufnr number|nil Buffer number. Defaults to the current buffer.
---@param position table|nil The (0,0)-indexed position. Defaults to the current cursor position.
---@return tuple ({popup_bufnr}, {win_id})
function M.show_position_diagnostics(opts, bufnr, position)
  vim.validate {
    opts = { opts, 't', true },
    bufnr = { bufnr, 'n', true },
    position = { position, 't', true },
  }

  opts = opts or {}

  opts.focus_id = "position_diagnostics"
  bufnr = get_bufnr(bufnr)
  if not position then
    local curr_position = vim.api.nvim_win_get_cursor(0)
    curr_position[1] = curr_position[1] - 1
    position = curr_position
  end
  local match_position_predicate = function(diag)
    return position[1] == diag.lnum and
    position[2] >= diag.col and
    (position[2] <= diag.end_col or position[1] < diag.end_lnum)
  end
  local diagnostics = M.get(bufnr, opts)
  clamp_line_numbers(bufnr, diagnostics)
  local position_diagnostics = vim.tbl_filter(match_position_predicate, diagnostics)
  table.sort(position_diagnostics, function(a, b) return a.severity < b.severity end)
  return show_diagnostics(opts, position_diagnostics)
end

--- Open a floating window with the diagnostics from the given line.
---
---@param opts table Configuration table. See |vim.diagnostic.show_position_diagnostics()|.
---@param bufnr number|nil Buffer number. Defaults to the current buffer.
---@param lnum number|nil Line number. Defaults to line number of cursor.
---@return tuple ({popup_bufnr}, {win_id})
function M.show_line_diagnostics(opts, bufnr, lnum)
  vim.validate {
    opts = { opts, 't', true },
    bufnr = { bufnr, 'n', true },
    lnum = { lnum, 'n', true },
  }

  opts = opts or {}
  opts.focus_id = "line_diagnostics"
  bufnr = get_bufnr(bufnr)
  local diagnostics = M.get(bufnr, opts)
  clamp_line_numbers(bufnr, diagnostics)
  lnum = lnum or (vim.api.nvim_win_get_cursor(0)[1] - 1)
  local line_diagnostics = diagnostic_lines(diagnostics)[lnum]
  return show_diagnostics(opts, line_diagnostics)
end

--- Remove all diagnostics from the given namespace.
---
--- Unlike |vim.diagnostic.hide()|, this function removes all saved
--- diagnostics. They cannot be redisplayed using |vim.diagnostic.show()|. To
--- simply remove diagnostic decorations in a way that they can be
--- re-displayed, use |vim.diagnostic.hide()|.
---
---@param namespace number
---@param bufnr number|nil Remove diagnostics for the given buffer. When omitted,
---             diagnostics are removed for all buffers.
function M.reset(namespace, bufnr)
  if bufnr == nil then
    for iter_bufnr, namespaces in pairs(diagnostic_cache) do
      if namespaces[namespace] then
        M.reset(namespace, iter_bufnr)
      end
    end
  else
    clear_diagnostic_cache(namespace, bufnr)
    M.hide(namespace, bufnr)
  end

  vim.api.nvim_command("doautocmd <nomodeline> User DiagnosticsChanged")
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
---@param bufnr number|nil Buffer number. Defaults to the current buffer.
---@param namespace number|nil Only disable diagnostics for the given namespace.
function M.disable(bufnr, namespace)
  vim.validate { bufnr = {bufnr, 'n', true}, namespace = {namespace, 'n', true} }
  bufnr = get_bufnr(bufnr)
  if namespace == nil then
    diagnostic_disabled[bufnr] = true
    for ns in pairs(diagnostic_cache[bufnr]) do
      M.hide(ns, bufnr)
    end
  else
    if type(diagnostic_disabled[bufnr]) ~= "table" then
      diagnostic_disabled[bufnr] = {}
    end
    diagnostic_disabled[bufnr][namespace] = true
    M.hide(namespace, bufnr)
  end
end

--- Enable diagnostics in the given buffer.
---
---@param bufnr number|nil Buffer number. Defaults to the current buffer.
---@param namespace number|nil Only enable diagnostics for the given namespace.
function M.enable(bufnr, namespace)
  vim.validate { bufnr = {bufnr, 'n', true}, namespace = {namespace, 'n', true} }
  bufnr = get_bufnr(bufnr)
  if namespace == nil then
    diagnostic_disabled[bufnr] = nil
    for ns in pairs(diagnostic_cache[bufnr]) do
      M.show(ns, bufnr)
    end
  else
    if type(diagnostic_disabled[bufnr]) ~= "table" then
      return
    end
    diagnostic_disabled[bufnr][namespace] = nil
    M.show(namespace, bufnr)
  end
end

--- Parse a diagnostic from a string.
---
--- For example, consider a line of output from a linter:
--- <pre>
--- WARNING filename:27:3: Variable 'foo' does not exist
--- </pre>
--- This can be parsed into a diagnostic |diagnostic-structure|
--- with:
--- <pre>
--- local s = "WARNING filename:27:3: Variable 'foo' does not exist"
--- local pattern = "^(%w+) %w+:(%d+):(%d+): (.+)$"
--- local groups = {"severity", "lnum", "col", "message"}
--- vim.diagnostic.match(s, pattern, groups, {WARNING = vim.diagnostic.WARN})
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
  vim.validate {
    str = { str, 's' },
    pat = { pat, 's' },
    groups = { groups, 't' },
    severity_map = { severity_map, 't', true },
    defaults = { defaults, 't', true },
  }

  severity_map = severity_map or M.severity

  local diagnostic = {}
  local matches = {string.match(str, pat)}
  if vim.tbl_isempty(matches) then
    return
  end

  for i, match in ipairs(matches) do
    local field = groups[i]
    if field == "severity" then
      match = severity_map[match]
    elseif field == "lnum" or field == "end_lnum" or field == "col" or field == "end_col" then
      match = assert(tonumber(match)) - 1
    end
    diagnostic[field] = match
  end

  diagnostic = vim.tbl_extend("keep", diagnostic, defaults or {})
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
  vim.validate { diagnostics = {diagnostics, 't'} }

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
  vim.validate { list = {list, 't'} }

  local diagnostics = {}
  for _, item in ipairs(list) do
    if item.valid == 1 then
      local lnum = math.max(0, item.lnum - 1)
      local col = item.col > 0 and (item.col - 1) or nil
      local end_lnum = item.end_lnum > 0 and (item.end_lnum - 1) or lnum
      local end_col = item.end_col > 0 and (item.end_col - 1) or col
      local severity = item.type ~= "" and M.severity[item.type] or M.severity.ERROR
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

-- }}}

return M
