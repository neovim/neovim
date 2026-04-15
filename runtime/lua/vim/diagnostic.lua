local api = vim.api

-- TODO(lewis6991): deprecate some top level functions in favour of the submodule version
-- e.g. vim.diagnostic.get_namespace() -> vim.diagnostic.namespace.get()
local M = vim._defer_require('vim.diagnostic', {
  _config = ..., --- @module 'vim.diagnostic._config'
  _display = ..., --- @module 'vim.diagnostic._display'
  _float = ..., --- @module 'vim.diagnostic._float'
  _jump = ..., --- @module 'vim.diagnostic._jump'
  _severity = ..., --- @module 'vim.diagnostic._severity'
  _store = ..., --- @module 'vim.diagnostic._store'
  _handlers = ..., --- @module 'vim.diagnostic._handlers'
})

--- Diagnostics use the same indexing as the rest of the Nvim API (i.e. 0-based
--- rows and columns). |api-indexing|
--- @class vim.Diagnostic.Set
---
--- The starting line of the diagnostic (0-indexed)
--- @field lnum integer
---
--- The starting column of the diagnostic (0-indexed)
--- (default: `0`)
--- @field col? integer
---
--- The final line of the diagnostic (0-indexed)
--- (default: `lnum`)
--- @field end_lnum? integer
---
--- The final column of the diagnostic (0-indexed)
--- (default: `col`)
--- @field end_col? integer
---
--- The severity of the diagnostic |vim.diagnostic.severity|
--- (default: `vim.diagnostic.severity.ERROR`)
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

--- [diagnostic-structure]()
---
--- Diagnostics use the same indexing as the rest of the Nvim API (i.e. 0-based
--- rows and columns). |api-indexing|
--- @class vim.Diagnostic : vim.Diagnostic.Set
--- @field bufnr integer Buffer number
--- @field end_lnum integer The final line of the diagnostic (0-indexed)
--- @field col integer The starting column of the diagnostic (0-indexed)
--- @field end_col integer The final column of the diagnostic (0-indexed)
--- @field severity vim.diagnostic.Severity The severity of the diagnostic |vim.diagnostic.severity|
--- @field namespace? integer
--- @field _extmark_id? integer

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
--- (default: `false`)
--- @field virtual_text? boolean|vim.diagnostic.Opts.VirtualText|fun(namespace: integer, bufnr:integer): vim.diagnostic.Opts.VirtualText
---
--- Use virtual lines for diagnostics.
--- (default: `false`)
--- @field virtual_lines? boolean|vim.diagnostic.Opts.VirtualLines|fun(namespace: integer, bufnr:integer): vim.diagnostic.Opts.VirtualLines
---
--- Use signs for diagnostics |diagnostic-signs|.
--- (default: `true`)
--- @field signs? boolean|vim.diagnostic.Opts.Signs|fun(namespace: integer, bufnr:integer): vim.diagnostic.Opts.Signs
---
--- Options for floating windows. See |vim.diagnostic.Opts.Float|.
--- @field float? boolean|vim.diagnostic.Opts.Float|fun(namespace?: integer|integer[], bufnr:integer): vim.diagnostic.Opts.Float
---
--- Options for the statusline component.
--- @field status? vim.diagnostic.Opts.Status
---
--- Update diagnostics in Insert mode
--- (if `false`, diagnostics are updated on |InsertLeave|)
--- (default: `false`)
--- @field update_in_insert? boolean
---
--- Sort diagnostics by severity. This affects the order in which signs,
--- virtual text, and highlights are displayed. When true, higher severities are
--- displayed before lower severities (e.g. ERROR is displayed before WARN).
--- Options:
---   - {reverse}? (boolean) Reverse sort order
--- (default: `false`)
--- @field severity_sort? boolean|{reverse?:boolean}
---
--- Default values for |vim.diagnostic.jump()|. See |vim.diagnostic.Opts.Jump|.
--- @field jump? vim.diagnostic.Opts.Jump

--- @class vim.diagnostic.Opts.Float : vim.lsp.util.open_floating_preview.Opts
---
--- Buffer number to show diagnostics from.
--- (default: current buffer)
--- @field bufnr? integer
---
--- Limit diagnostics to the given namespace(s).
--- @field namespace? integer|integer[]
---
--- Show diagnostics from the whole buffer (`buffer`), the current cursor line
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
--- A function that takes a diagnostic as input and returns a string or nil.
--- If the return value is nil, the diagnostic is not displayed by the handler.
--- Else the output text is used to display the diagnostic.
--- Overrides the setting from |vim.diagnostic.config()|.
--- @field format? fun(diagnostic:vim.Diagnostic): string?
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

--- @class vim.diagnostic.Opts.Status
---
--- Either:
--- - a table mapping |diagnostic-severity| to the text to use for each
---   existing severity section.
--- - a function that accepts a mapping of |diagnostic-severity| to the
---   number of diagnostics of the corresponding severity (only those
---   severity levels that have at least 1 diagnostic) and returns
---   a 'statusline' component. In this case highlights must be applied
---   by the user in the `format` function. Example:
---   ```lua
---   local signs = {
---     [vim.diagnostic.severity.ERROR] = "A",
---     -- ...
---   }
---   local hl_map = {
---     [vim.diagnostic.severity.ERROR] = 'DiagnosticSignError',
---     -- ...
---   }
---   vim.diagnostic.config({
---     status = {
---       format = function(counts)
---         local items = {}
---         for level, _ in ipairs(vim.diagnostic.severity) do
---           local count = counts[level] or 0
---           table.insert(items, ("%%#%s#%s %s"):format(hl_map[level], signs[level], count))
---         end
---         return table.concat(items, " ")
---       end
---     }
---   })
---   ```
--- @field format? table<vim.diagnostic.Severity,string>|(fun(counts:table<vim.diagnostic.Severity,integer>): string)

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
--- Show or hide diagnostics based on the current cursor line.  If `true`, only diagnostics on the
--- current cursor line are shown.  If `false`, all diagnostics are shown except on the current
--- cursor line.  If `nil`, all diagnostics are shown.
--- (default `nil`)
--- @field current_line? boolean
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
--- If not nil, the return value is the text used to display the diagnostic. Example:
--- ```lua
--- function(diagnostic)
---   if diagnostic.severity == vim.diagnostic.severity.ERROR then
---     return string.format("E: %s", diagnostic.message)
---   end
---   return diagnostic.message
--- end
--- ```
--- If the return value is nil, the diagnostic is not displayed by the handler.
--- @field format? fun(diagnostic:vim.Diagnostic): string?
---
--- See |nvim_buf_set_extmark()|.
--- @field hl_mode? 'replace'|'combine'|'blend'
---
--- See |nvim_buf_set_extmark()|.
--- @field virt_text? [string,any][]
---
--- See |nvim_buf_set_extmark()|.
--- @field virt_text_pos? 'eol'|'eol_right_align'|'inline'|'overlay'|'right_align'
---
--- See |nvim_buf_set_extmark()|.
--- @field virt_text_win_col? integer
---
--- See |nvim_buf_set_extmark()|.
--- @field virt_text_hide? boolean

--- @class vim.diagnostic.Opts.VirtualLines
---
--- Only show virtual lines for diagnostics matching the given
--- severity |diagnostic-severity|
--- @field severity? vim.diagnostic.SeverityFilter
---
--- Only show diagnostics for the current line.
--- (default: `false`)
--- @field current_line? boolean
---
--- A function that takes a diagnostic as input and returns a string or nil.
--- If the return value is nil, the diagnostic is not displayed by the handler.
--- Else the output text is used to display the diagnostic.
--- @field format? fun(diagnostic:vim.Diagnostic): string?

--- @class vim.diagnostic.Opts.Signs
---
--- Only show signs for diagnostics matching the given
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
--- Default value of the {on_jump} parameter of |vim.diagnostic.jump()|.
--- @field on_jump? fun(diagnostic:vim.Diagnostic?, bufnr:integer)
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

--- See |diagnostic-severity| and |vim.diagnostic.get()|
--- @alias vim.diagnostic.SeverityFilter
--- | vim.diagnostic.Severity
--- | vim.diagnostic.Severity[]
--- | {min:vim.diagnostic.Severity,max:vim.diagnostic.Severity}

--- @nodoc
--- @enum vim.diagnostic.Severity
M.severity = {
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  HINT = 4,
}

--- @enum vim.diagnostic.SeverityName
local severity_invert = {
  [1] = 'ERROR',
  [2] = 'WARN',
  [3] = 'INFO',
  [4] = 'HINT',
}

do
  --- Set extra fields through table alias to hide from analysis tools
  local s = M.severity --- @type table<any,any>

  for i, name in ipairs(severity_invert) do
    s[i] = name
  end

  --- Mappings from qflist/loclist error types to severities
  s.E = 1
  s.W = 2
  s.I = 3
  s.N = 4
end

local builtin_handler_names = {
  signs = true,
  underline = true,
  virtual_text = true,
  virtual_lines = true,
}

--- @nodoc
--- @type table<string,vim.diagnostic.Handler>
M.handlers = setmetatable({}, {
  __newindex = function(t, name, handler)
    vim.validate('handler', handler, 'table')
    rawset(t, name, handler)
    if not builtin_handler_names[name] then
      M._config.enable_handler(name)
    end
  end,
})

--- @type table<integer,true|table<integer,true>>
local diagnostic_disabled = {}

--- @class vim.diagnostic.NS
--- @field name string
--- @field opts vim.diagnostic.Opts
--- @field user_data table
--- @field disabled? boolean

--- @type table<integer, vim.diagnostic.NS>
local all_namespaces = {}

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
  return M._config.config(opts, namespace)
end

--- Set diagnostics for the given namespace and buffer.
---
---@param namespace integer The diagnostic namespace
---@param bufnr integer Buffer number
---@param diagnostics vim.Diagnostic.Set[]
---@param opts? vim.diagnostic.Opts Display options to pass to |vim.diagnostic.show()|
function M.set(namespace, bufnr, diagnostics, opts)
  vim.validate('opts', opts, 'table', true)
  M._store.set(namespace, bufnr, diagnostics)
  M.show(namespace, bufnr, nil, opts)

  api.nvim_exec_autocmds('DiagnosticChanged', {
    modeline = false,
    buf = vim._resolve_bufnr(bufnr),
    -- TODO(lewis6991): should this be deepcopy()'d like they are in vim.diagnostic.get()
    data = { diagnostics = diagnostics },
  })
end

--- Get namespace metadata.
---
---@param namespace integer Diagnostic namespace
---@return vim.diagnostic.NS : Namespace metadata
function M.get_namespace(namespace)
  vim.validate('namespace', namespace, 'number')

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
  return M._store.get(bufnr, opts)
end

--- Get current diagnostics count.
---
---@param bufnr? integer Buffer number to get diagnostics from. Use 0 for
---                      current buffer or nil for all buffers.
---@param opts? vim.diagnostic.GetOpts
---@return table<integer, integer> : Table with actually present severity values as keys
---                (see |diagnostic-severity|) and integer counts as values.
function M.count(bufnr, opts)
  return M._store.count(bufnr, opts)
end

--- Get the previous diagnostic closest to the cursor position.
---
---@param opts? vim.diagnostic.JumpOpts
---@return vim.Diagnostic? : Previous diagnostic
function M.get_prev(opts)
  return M._jump.get_prev(opts)
end

--- Return the position of the previous diagnostic in the current buffer.
---
---@param opts? vim.diagnostic.JumpOpts
---@return table|false: Previous diagnostic position as a `(row, col)` tuple
---                     or `false` if there is no prior diagnostic.
---@deprecated
function M.get_prev_pos(opts)
  return M._jump.get_prev_pos(opts)
end

--- Move to the previous diagnostic in the current buffer.
---@param opts? vim.diagnostic.JumpOpts
---@deprecated
function M.goto_prev(opts)
  return M._jump.goto_prev(opts)
end

--- Get the next diagnostic closest to the cursor position.
---
---@param opts? vim.diagnostic.JumpOpts
---@return vim.Diagnostic? : Next diagnostic
function M.get_next(opts)
  return M._jump.get_next(opts)
end

--- Return the position of the next diagnostic in the current buffer.
---
---@param opts? vim.diagnostic.JumpOpts
---@return table|false : Next diagnostic position as a `(row, col)` tuple or false if no next
---                      diagnostic.
---@deprecated
function M.get_next_pos(opts)
  return M._jump.get_next_pos(opts)
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
---
--- Limit diagnostics to only enabled or disabled. If nil, enablement is ignored.
--- See |vim.diagnostic.enable()|
--- (default: `nil`)
--- @field enabled? boolean

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
--- Optional callback invoked with the diagnostic that was jumped to.
--- @field on_jump? fun(diagnostic:vim.Diagnostic?, bufnr:integer)
---
--- Window ID
--- (default: `0`)
--- @field winid? integer

--- @nodoc
--- @class vim.diagnostic.JumpOpts1 : vim.diagnostic.JumpOpts
--- @field win_id? integer (deprecated) use winid
--- @field cursor_position? [integer, integer] (deprecated) use pos
--- @field float? table|boolean (deprecated) use on_jump

--- Move to a diagnostic.
---
--- @param opts vim.diagnostic.JumpOpts
--- @return vim.Diagnostic? # The diagnostic that was moved to.
function M.jump(opts)
  return M._jump.jump(opts)
end

--- Move to the next diagnostic.
---
---@param opts? vim.diagnostic.JumpOpts
---@deprecated
function M.goto_next(opts)
  return M._jump.goto_next(opts)
end

M.handlers.signs = {
  show = function(...)
    return M._handlers.signs.show(...)
  end,
  hide = function(namespace, bufnr)
    return M._handlers.signs.hide(namespace, bufnr)
  end,
}

M.handlers.underline = {
  show = function(...)
    return M._handlers.underline.show(...)
  end,
  hide = function(namespace, bufnr)
    return M._handlers.underline.hide(namespace, bufnr)
  end,
}

M.handlers.virtual_text = {
  show = function(...)
    return M._handlers.virtual_text.show(...)
  end,
  hide = function(namespace, bufnr)
    return M._handlers.virtual_text.hide(namespace, bufnr)
  end,
}

M.handlers.virtual_lines = {
  show = function(...)
    return M._handlers.virtual_lines.show(...)
  end,
  hide = function(namespace, bufnr)
    return M._handlers.virtual_lines.hide(namespace, bufnr)
  end,
}

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
  return M._display.hide(namespace, bufnr)
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

  local bufnr = vim._resolve_bufnr(filter.bufnr)
  if type(diagnostic_disabled[bufnr]) == 'table' then
    return not diagnostic_disabled[bufnr][filter.ns_id]
  end

  return diagnostic_disabled[bufnr] == nil
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
  return M._display.show(namespace, bufnr, diagnostics, opts)
end

--- Show diagnostics in a floating window.
---
---@param opts vim.diagnostic.Opts.Float?
---@return integer? float_bufnr
---@return integer? winid
function M.open_float(opts, ...)
  return M._float.open(opts, ...)
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
  vim.validate('namespace', namespace, 'number', true)
  vim.validate('bufnr', bufnr, 'number', true)

  local buffers = bufnr and { vim._resolve_bufnr(bufnr) } or M._store.get_bufnrs()
  for _, iter_bufnr in ipairs(buffers) do
    local namespaces = namespace and { namespace } or M._store.get_buf_namespaces(iter_bufnr)
    for _, iter_namespace in ipairs(namespaces) do
      M._store.clear(iter_namespace, iter_bufnr)
      M.hide(iter_namespace, iter_bufnr)
    end

    if api.nvim_buf_is_valid(iter_bufnr) then
      api.nvim_exec_autocmds('DiagnosticChanged', {
        modeline = false,
        buf = iter_bufnr,
        data = { diagnostics = {} },
      })
    else
      M._store.drop_buf(iter_bufnr)
    end
  end
end

--- @type table<vim.diagnostic.Severity, string>
local errlist_type_map = {
  [M.severity.ERROR] = 'E',
  [M.severity.WARN] = 'W',
  [M.severity.INFO] = 'I',
  [M.severity.HINT] = 'N',
}

--- @param title string
--- @return integer?
local function get_qf_id_for_title(title)
  local lastqflist = vim.fn.getqflist({ nr = '$' })
  for i = 1, lastqflist.nr do
    local qflist = vim.fn.getqflist({ nr = i, id = 0, title = 0 })
    if qflist.title == title then
      return qflist.id
    end
  end

  return nil
end

--- @param loclist boolean
--- @param opts? vim.diagnostic.setqflist.Opts|vim.diagnostic.setloclist.Opts
local function set_list(loclist, opts)
  opts = opts or {}
  local open = vim.F.if_nil(opts.open, true)
  local title = opts.title or 'Diagnostics'
  local winnr = opts.winnr or 0
  local bufnr --- @type integer?
  if loclist then
    bufnr = api.nvim_win_get_buf(winnr)
  end

  -- Don't clamp line numbers since the quickfix list can already handle line
  -- numbers beyond the end of the buffer
  local diagnostics = M._store.get_diagnostics(bufnr, opts --[[@as vim.diagnostic.GetOpts]], false)
  if opts.format then
    diagnostics = require('vim.diagnostic._shared').reformat_diagnostics(opts.format, diagnostics)
  end
  local items = M.toqflist(diagnostics)
  local qf_id = nil
  if loclist then
    vim.fn.setloclist(winnr, {}, 'u', { title = title, items = items })
  else
    qf_id = get_qf_id_for_title(title)
    -- If we already have a diagnostics quickfix, update it rather than creating a new one.
    -- This avoids polluting the finite set of quickfix lists, and preserves the currently selected
    -- entry.
    vim.fn.setqflist({}, qf_id and 'u' or ' ', {
      title = title,
      items = items,
      id = qf_id,
    })
  end

  if open then
    if not loclist then
      -- First navigate to the diagnostics quickfix list.
      local qflist = vim.fn.getqflist({ id = qf_id, nr = 0 }) --- @type { nr: integer }
      local nr = qflist.nr
      api.nvim_command(('silent %dchistory'):format(nr))
      -- Now open the quickfix list.
      api.nvim_command('botright cwindow')
    else
      api.nvim_command('lwindow')
    end
  end
end

--- Configuration table with the following keys:
--- @class vim.diagnostic.setqflist.Opts
--- @inlinedoc
---
--- Only add diagnostics from the given namespace(s).
--- @field namespace? integer[]|integer
---
--- Open quickfix list after setting.
--- (default: `true`)
--- @field open? boolean
---
--- Title of quickfix list. Defaults to "Diagnostics". If there's already a quickfix list with this
--- title, it's updated. If not, a new quickfix list is created.
--- @field title? string
---
--- See |diagnostic-severity|.
--- @field severity? vim.diagnostic.SeverityFilter
---
--- A function that takes a diagnostic as input and returns a string or nil.
--- If the return value is nil, the diagnostic is not displayed in the quickfix list.
--- Else the output text is used to display the diagnostic.
--- @field format? fun(diagnostic:vim.Diagnostic): string?

--- Add all diagnostics to the quickfix list.
---
---@param opts? vim.diagnostic.setqflist.Opts
function M.setqflist(opts)
  return set_list(false, opts)
end

---Configuration table with the following keys:
--- @class vim.diagnostic.setloclist.Opts
--- @inlinedoc
---
--- Only add diagnostics from the given namespace(s).
--- @field namespace? integer[]|integer
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
--- @field severity? vim.diagnostic.SeverityFilter
---
--- A function that takes a diagnostic as input and returns a string or nil.
--- If the return value is nil, the diagnostic is not displayed in the location list.
--- Else the output text is used to display the diagnostic.
--- @field format? fun(diagnostic:vim.Diagnostic): string?

--- Add buffer diagnostics to the location list.
---
---@param opts? vim.diagnostic.setloclist.Opts
function M.setloclist(opts)
  return set_list(true, opts)
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
  filter = filter or {}
  vim.validate('enable', enable, 'boolean', true)
  vim.validate('filter', filter, 'table', true)

  enable = enable == nil and true or enable
  local bufnr = filter.bufnr
  local ns_id = filter.ns_id

  if not bufnr then
    if not ns_id then
      --- @type table<integer,true|table<integer,true>>
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
      local ns = M.get_namespace(ns_id)
      ns.disabled = not enable
    end
  else
    bufnr = vim._resolve_bufnr(bufnr)
    if not ns_id then
      diagnostic_disabled[bufnr] = (not enable) and true or nil
    else
      if type(diagnostic_disabled[bufnr]) ~= 'table' then
        if enable then
          return
        end
        diagnostic_disabled[bufnr] = {}
      end
      diagnostic_disabled[bufnr][ns_id] = (not enable) and true or nil
    end
  end

  if enable then
    M.show(ns_id, bufnr)
  else
    M.hide(ns_id, bufnr)
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
  return M._severity.match(str, pat, groups, severity_map, defaults)
end

--- Convert a list of diagnostics to a list of quickfix items that can be
--- passed to |setqflist()| or |setloclist()|.
---
---@param diagnostics vim.Diagnostic[]
---@return table[] : Quickfix list items |setqflist-what|
function M.toqflist(diagnostics)
  vim.validate('diagnostics', diagnostics, vim.islist, 'a list of diagnostics')

  local list = {} --- @type table[]
  for _, diagnostic in ipairs(diagnostics) do
    list[#list + 1] = {
      bufnr = diagnostic.bufnr,
      lnum = diagnostic.lnum + 1,
      col = diagnostic.col and (diagnostic.col + 1) or nil,
      end_lnum = diagnostic.end_lnum and (diagnostic.end_lnum + 1) or nil,
      end_col = diagnostic.end_col and (diagnostic.end_col + 1) or nil,
      text = diagnostic.message,
      nr = tonumber(diagnostic.code),
      type = errlist_type_map[diagnostic.severity] or 'E',
      valid = 1,
    }
  end

  table.sort(list, function(a, b)
    if a.bufnr == b.bufnr then
      if a.lnum == b.lnum then
        return a.col < b.col
      end

      return a.lnum < b.lnum
    end

    return a.bufnr < b.bufnr
  end)

  return list
end

--- Configuration table with the following keys:
--- @class vim.diagnostic.fromqflist.Opts
--- @inlinedoc
---
--- When true, items with valid=0 are appended to the previous valid item's
--- message with a newline. (default: false)
--- @field merge_lines? boolean

--- Convert a list of quickfix items to a list of diagnostics.
---
---@param list vim.quickfix.entry[] List of quickfix items from |getqflist()| or |getloclist()|.
---@param opts? vim.diagnostic.fromqflist.Opts
---@return vim.Diagnostic[]
function M.fromqflist(list, opts)
  vim.validate('list', list, 'table')

  opts = opts or {}
  local merge = opts.merge_lines

  local diagnostics = {} --- @type vim.Diagnostic[]
  local last_diag --- @type vim.Diagnostic?
  for _, item in ipairs(list) do
    if item.valid == 1 then
      local lnum = math.max(0, item.lnum - 1)
      local col = math.max(0, item.col - 1)
      local end_lnum = item.end_lnum > 0 and (item.end_lnum - 1) or lnum
      local end_col = item.end_col > 0 and (item.end_col - 1) or col
      local code = item.nr > 0 and item.nr or nil
      local item_type = item.type or ''
      --- @type vim.Diagnostic
      local diag = {
        bufnr = item.bufnr,
        lnum = lnum,
        col = col,
        end_lnum = end_lnum,
        end_col = end_col,
        severity = item_type ~= '' and M.severity[item_type:upper()] or M.severity.ERROR,
        message = item.text,
        code = code,
      }
      diagnostics[#diagnostics + 1] = diag
      last_diag = diag
    elseif merge and last_diag then
      last_diag.message = last_diag.message .. '\n' .. item.text
    end
  end

  return diagnostics
end

--- @type table<vim.diagnostic.Severity, string>
local status_hl_map = {
  [M.severity.ERROR] = 'DiagnosticSignError',
  [M.severity.WARN] = 'DiagnosticSignWarn',
  [M.severity.INFO] = 'DiagnosticSignInfo',
  [M.severity.HINT] = 'DiagnosticSignHint',
}

--- @type table<vim.diagnostic.Severity, string>
local default_status_signs = {
  [M.severity.ERROR] = 'E',
  [M.severity.WARN] = 'W',
  [M.severity.INFO] = 'I',
  [M.severity.HINT] = 'H',
}

--- Returns formatted string with diagnostics for the current buffer.
--- The severities with 0 diagnostics are left out.
--- Example `E:2 W:3 I:4 H:5`
---
--- To customise appearance, see |vim.diagnostic.Opts.Status|.
---
---@param bufnr? integer Buffer number to get diagnostics from.
---                      Defaults to 0 for the current buffer
---
---@return string
function M.status(bufnr)
  vim.validate('bufnr', bufnr, 'number', true)
  bufnr = bufnr or 0
  local config = assert(vim.diagnostic.config()).status or {} --- @type vim.diagnostic.Opts.Status
  vim.validate('config.format', config.format, { 'table', 'function' }, true)

  local counts = M.count(bufnr)
  local format = config.format or default_status_signs
  local result_str --- @type string
  if type(format) == 'table' then
    local signs = vim.tbl_extend('keep', format, default_status_signs)
    result_str = vim
      .iter(pairs(counts))
      :map(function(level, value)
        return ('%%#%s#%s:%s'):format(status_hl_map[level], signs[level], value)
      end)
      :join(' ')
  else
    result_str = format(counts)
  end

  if result_str:len() > 0 then
    result_str = result_str .. '%##'
  end

  return result_str
end

api.nvim_create_autocmd('DiagnosticChanged', {
  group = api.nvim_create_augroup('nvim.diagnostic.status', {}),
  callback = function(ev)
    if api.nvim_buf_is_loaded(ev.buf) then
      api.nvim__redraw({ buf = ev.buf, statusline = true })
    end
  end,
  desc = 'diagnostics component for the statusline',
})

return M
