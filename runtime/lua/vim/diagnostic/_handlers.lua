local api = vim.api
local diagnostic = vim.diagnostic
local diagnostic_shared = require('vim.diagnostic._shared')

local severity = diagnostic.severity

--- @class vim.diagnostic.Handler
--- @field show? fun(namespace: integer, bufnr: integer, diagnostics: vim.Diagnostic[], opts?: vim.diagnostic.OptsResolved)
--- @field hide? fun(namespace:integer, bufnr:integer)

--- @class (private) vim.diagnostic._handlers._extmark : vim.api.keyset.get_extmark_item
--- @field [1] integer extmark_id
--- @field [2] integer row
--- @field [3] integer col
--- @field [4] vim.api.keyset.extmark_details

local M = {}

-- Default diagnostic highlights
--- @type table<vim.diagnostic.Severity, string>
local severity_names = {
  [severity.ERROR] = 'Error',
  [severity.WARN] = 'Warn',
  [severity.INFO] = 'Info',
  [severity.HINT] = 'Hint',
}

--- @param base_name string
--- @return table<vim.diagnostic.Severity, string>
local function make_highlight_map(base_name)
  local result = {} --- @type table<vim.diagnostic.Severity, string>

  for level, name in pairs(severity_names) do
    result[level] = ('Diagnostic%s%s'):format(base_name, name)
  end

  return result
end

local sign_highlight_map = make_highlight_map('Sign')
local underline_highlight_map = make_highlight_map('Underline')
local virtual_text_highlight_map = make_highlight_map('VirtualText')
local virtual_lines_highlight_map = make_highlight_map('VirtualLines')

-- Metatable that automatically creates an empty table when assigning to a missing key
local bufnr_and_namespace_cacher_mt = {
  --- @param t table<integer, table>
  --- @param bufnr integer
  --- @return table
  __index = function(t, bufnr)
    assert(bufnr > 0, 'Invalid buffer number')
    t[bufnr] = {}
    return t[bufnr]
  end,
}

--- @type table<integer, table<integer, vim.diagnostic._handlers._extmark[]>>
local diagnostic_cache_extmarks = setmetatable({}, bufnr_and_namespace_cacher_mt)

--- @type table<integer, true>
local diagnostic_attached_buffers = {}

--- @param bufnr integer
--- @param last integer
local function restore_extmarks(bufnr, last)
  for ns, extmarks in pairs(diagnostic_cache_extmarks[bufnr]) do
    local extmarks_current = api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
    local found = {} --- @type table<integer, true>

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
        --- @diagnostic disable-next-line: inject-field
        opts.id = extmark[1]
        pcall(api.nvim_buf_set_extmark, bufnr, ns, extmark[2], extmark[3], opts)
      end
    end
  end
end

--- @param namespace integer
--- @param bufnr? integer
local function save_extmarks(namespace, bufnr)
  bufnr = vim._resolve_bufnr(bufnr)

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

--- @param bufnr integer
--- @param namespace integer
local function clear_extmarks(bufnr, namespace)
  diagnostic_cache_extmarks[bufnr][namespace] = {}
  if api.nvim_buf_is_valid(bufnr) then
    api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  end
end

--- @param bufnr integer
--- @param fn fun()
--- @return integer?
local function once_buf_loaded(bufnr, fn)
  if api.nvim_buf_is_loaded(bufnr) then
    fn()
  else
    return api.nvim_create_autocmd('BufRead', {
      buf = bufnr,
      once = true,
      callback = function()
        fn()
      end,
    })
  end
end

--- @param autocmd_key string
--- @param ns vim.diagnostic.NS
local function cleanup_show_autocmd(autocmd_key, ns)
  if ns.user_data[autocmd_key] then
    api.nvim_del_autocmd(ns.user_data[autocmd_key])
    --- @type integer?
    ns.user_data[autocmd_key] = nil
  end
end

--- @param autocmd_key string
--- @param ns vim.diagnostic.NS
--- @param bufnr integer
--- @param fn fun()
local function show_once_loaded(autocmd_key, ns, bufnr, fn)
  cleanup_show_autocmd(autocmd_key, ns)

  --- @type integer?
  ns.user_data[autocmd_key] = once_buf_loaded(bufnr, function()
    --- @type integer?
    ns.user_data[autocmd_key] = nil
    fn()
  end)
end

--- @param priority integer
--- @param opts? { severity_sort?: {reverse?:boolean} }
--- @return fun(severity: vim.diagnostic.Severity): integer
local function severity_to_extmark_priority(priority, opts)
  opts = opts or {}
  if opts.severity_sort then
    if type(opts.severity_sort) == 'table' and opts.severity_sort.reverse then
      return function(level)
        return priority + (level - severity.ERROR)
      end
    end

    return function(level)
      return priority + (severity.HINT - level)
    end
  end

  return function()
    return priority
  end
end

M.signs = {}

--- @param namespace integer
--- @param bufnr integer
--- @param diagnostics vim.Diagnostic[]
--- @param opts? vim.diagnostic.OptsResolved
function M.signs.show(namespace, bufnr, diagnostics, opts)
  vim.validate('namespace', namespace, 'number')
  vim.validate('bufnr', bufnr, 'number')
  vim.validate('diagnostics', diagnostics, vim.islist, 'a list of diagnostics')
  vim.validate('opts', opts, 'table', true)
  vim.validate('opts.signs', (opts and opts or {}).signs, 'table', true)

  bufnr = vim._resolve_bufnr(bufnr)

  local sopts = opts and opts.signs or {}
  local ns = diagnostic.get_namespace(namespace)
  show_once_loaded('sign_show_autocmd', ns, bufnr, function()
    -- 10 is the default sign priority when none is explicitly specified
    local priority = sopts.priority or 10
    local get_priority = severity_to_extmark_priority(priority, opts)

    if not ns.user_data.sign_ns then
      ns.user_data.sign_ns =
        api.nvim_create_namespace(string.format('nvim.%s.diagnostic.signs', ns.name))
    end

    local text = {} --- @type table<vim.diagnostic.Severity|string, string>
    for level in pairs(severity) do
      if sopts.text and sopts.text[level] then
        text[level] = sopts.text[level]
      elseif type(level) == 'string' and not text[level] then
        text[level] = level:sub(1, 1):upper()
      end
    end

    local numhl = sopts.numhl or {}
    local linehl = sopts.linehl or {}
    local line_count = api.nvim_buf_line_count(bufnr)

    for _, diagnostic0 in ipairs(diagnostics) do
      if diagnostic0.lnum <= line_count then
        api.nvim_buf_set_extmark(bufnr, ns.user_data.sign_ns, diagnostic0.lnum, 0, {
          sign_text = text[diagnostic0.severity] or text[severity[diagnostic0.severity]] or 'U',
          sign_hl_group = sign_highlight_map[diagnostic0.severity],
          number_hl_group = numhl[diagnostic0.severity],
          line_hl_group = linehl[diagnostic0.severity],
          priority = get_priority(diagnostic0.severity),
        })
      end
    end
  end)
end

--- @param namespace integer
--- @param bufnr integer
function M.signs.hide(namespace, bufnr)
  local ns = diagnostic.get_namespace(namespace)
  cleanup_show_autocmd('sign_show_autocmd', ns)
  if ns.user_data.sign_ns and api.nvim_buf_is_valid(bufnr) then
    api.nvim_buf_clear_namespace(bufnr, ns.user_data.sign_ns, 0, -1)
  end
end

M.underline = {}

--- @param namespace integer
--- @param bufnr integer
--- @param diagnostics vim.Diagnostic[]
--- @param opts? vim.diagnostic.OptsResolved
function M.underline.show(namespace, bufnr, diagnostics, opts)
  vim.validate('namespace', namespace, 'number')
  vim.validate('bufnr', bufnr, 'number')
  vim.validate('diagnostics', diagnostics, vim.islist, 'a list of diagnostics')
  vim.validate('opts', opts, 'table', true)

  bufnr = vim._resolve_bufnr(bufnr)

  local ns = diagnostic.get_namespace(namespace)
  show_once_loaded('underline_show_autocmd', ns, bufnr, function()
    if not ns.user_data.underline_ns then
      ns.user_data.underline_ns =
        api.nvim_create_namespace(string.format('nvim.%s.diagnostic.underline', ns.name))
    end

    local underline_ns = ns.user_data.underline_ns
    local get_priority = severity_to_extmark_priority(vim.hl.priorities.diagnostics, opts)

    for _, diagnostic0 in ipairs(diagnostics) do
      local higroups = { underline_highlight_map[diagnostic0.severity] }

      if diagnostic0._tags then
        if diagnostic0._tags.unnecessary then
          table.insert(higroups, 'DiagnosticUnnecessary')
        end
        if diagnostic0._tags.deprecated then
          table.insert(higroups, 'DiagnosticDeprecated')
        end
      end

      local lines =
        api.nvim_buf_get_lines(diagnostic0.bufnr, diagnostic0.lnum, diagnostic0.lnum + 1, true)

      for _, higroup in ipairs(higroups) do
        vim.hl.range(
          bufnr,
          underline_ns,
          higroup,
          { diagnostic0.lnum, math.min(diagnostic0.col, #lines[1] - 1) },
          { diagnostic0.end_lnum, diagnostic0.end_col },
          { priority = get_priority(diagnostic0.severity) }
        )
      end
    end

    save_extmarks(underline_ns, bufnr)
  end)
end

--- @param namespace integer
--- @param bufnr integer
function M.underline.hide(namespace, bufnr)
  local ns = diagnostic.get_namespace(namespace)
  cleanup_show_autocmd('underline_show_autocmd', ns)
  if ns.user_data.underline_ns then
    clear_extmarks(bufnr, ns.user_data.underline_ns)
  end
end

--- @param line_diags table<integer, vim.Diagnostic>
--- @param opts vim.diagnostic.Opts.VirtualText
--- @return [string, any][]?
local function get_virt_text_chunks(line_diags, opts)
  if #line_diags == 0 then
    return
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

--- @param namespace integer
--- @param bufnr integer
--- @param diagnostics table<integer, vim.Diagnostic[]>
--- @param opts vim.diagnostic.Opts.VirtualText
local function render_virtual_text(namespace, bufnr, diagnostics, opts)
  local lnum = api.nvim_win_get_cursor(0)[1] - 1
  local buf_len = api.nvim_buf_line_count(bufnr)
  api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

  --- @param line integer
  --- @return boolean
  local function should_render(line)
    if
      line >= buf_len
      or (opts.current_line == true and line ~= lnum)
      or (opts.current_line == false and line == lnum)
    then
      return false
    end

    return true
  end

  for line, line_diagnostics in pairs(diagnostics) do
    if should_render(line) then
      local virt_texts = get_virt_text_chunks(line_diagnostics, opts)
      if virt_texts then
        api.nvim_buf_set_extmark(bufnr, namespace, line, 0, {
          hl_mode = opts.hl_mode or 'combine',
          virt_text = virt_texts,
          virt_text_pos = opts.virt_text_pos,
          virt_text_hide = opts.virt_text_hide,
          virt_text_win_col = opts.virt_text_win_col,
        })
      end
    end
  end
end

M.virtual_text = {}

--- @param namespace integer
--- @param bufnr integer
--- @param diagnostics vim.Diagnostic[]
--- @param opts? vim.diagnostic.OptsResolved
function M.virtual_text.show(namespace, bufnr, diagnostics, opts)
  vim.validate('namespace', namespace, 'number')
  vim.validate('bufnr', bufnr, 'number')
  vim.validate('diagnostics', diagnostics, vim.islist, 'a list of diagnostics')
  vim.validate('opts', opts, 'table', true)

  bufnr = vim._resolve_bufnr(bufnr)
  local vopts = opts and opts.virtual_text or {}

  local ns = diagnostic.get_namespace(namespace)
  show_once_loaded('virtual_text_show_autocmd', ns, bufnr, function()
    if vopts.format then
      diagnostics = diagnostic_shared.reformat_diagnostics(vopts.format, diagnostics)
    end

    if
      vopts.source and (vopts.source ~= 'if_many' or diagnostic_shared.count_sources(bufnr) > 1)
    then
      diagnostics = diagnostic_shared.prefix_source(diagnostics)
    end

    if not ns.user_data.virt_text_ns then
      ns.user_data.virt_text_ns =
        api.nvim_create_namespace(string.format('nvim.%s.diagnostic.virtual_text', ns.name))
    end
    if not ns.user_data.virt_text_augroup then
      ns.user_data.virt_text_augroup = api.nvim_create_augroup(
        string.format('nvim.%s.diagnostic.virt_text', ns.name),
        { clear = true }
      )
    end

    api.nvim_clear_autocmds({ group = ns.user_data.virt_text_augroup, buf = bufnr })

    local line_diagnostics = diagnostic_shared.diagnostic_lines(diagnostics, true)

    if vopts.current_line ~= nil then
      api.nvim_create_autocmd('CursorMoved', {
        buf = bufnr,
        group = ns.user_data.virt_text_augroup,
        callback = function()
          render_virtual_text(ns.user_data.virt_text_ns, bufnr, line_diagnostics, vopts)
        end,
      })
    end

    render_virtual_text(ns.user_data.virt_text_ns, bufnr, line_diagnostics, vopts)
    save_extmarks(ns.user_data.virt_text_ns, bufnr)
  end)
end

--- @param namespace integer
--- @param bufnr integer
function M.virtual_text.hide(namespace, bufnr)
  local ns = diagnostic.get_namespace(namespace)
  cleanup_show_autocmd('virtual_text_show_autocmd', ns)
  if ns.user_data.virt_text_ns then
    clear_extmarks(bufnr, ns.user_data.virt_text_ns)
    if api.nvim_buf_is_valid(bufnr) then
      api.nvim_clear_autocmds({ group = ns.user_data.virt_text_augroup, buf = bufnr })
    end
  end
end

--- @param bufnr integer
--- @param lnum integer
--- @param start_col integer
--- @param end_col integer
--- @return integer
local function distance_between_cols(bufnr, lnum, start_col, end_col)
  return api.nvim_buf_call(bufnr, function()
    local s = vim.fn.virtcol({ lnum + 1, start_col })
    local e = vim.fn.virtcol({ lnum + 1, end_col + 1 })
    return e - 1 - s
  end)
end

--- @param namespace integer
--- @param bufnr integer
--- @param diagnostics vim.Diagnostic[]
local function render_virtual_lines(namespace, bufnr, diagnostics)
  table.sort(diagnostics, function(d1, d2)
    return diagnostic_shared.diagnostic_cmp(d1, d2, 'lnum', false)
  end)

  api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

  if not next(diagnostics) then
    return
  end

  -- This loop reads each line, putting them into stacks with some extra data since
  -- rendering each line requires understanding what is beneath it.
  local ElementType = { Space = 1, Diagnostic = 2, Overlap = 3, Blank = 4 } --- @enum ElementType
  --- @type table<integer, [ElementType, string|vim.diagnostic.Severity|vim.Diagnostic][]>
  local line_stacks = {}
  --- @type table<integer, integer>
  local line_anchor = {}
  local prev_lnum = -1
  local prev_col = 0

  for _, diag in ipairs(diagnostics) do
    if not line_stacks[diag.lnum] then
      line_stacks[diag.lnum] = {}
    end

    local stack = line_stacks[diag.lnum]
    local end_lnum = diag.end_lnum or diag.lnum
    if not line_anchor[diag.lnum] or end_lnum > line_anchor[diag.lnum] then
      line_anchor[diag.lnum] = end_lnum
    end

    if diag.lnum ~= prev_lnum then
      table.insert(stack, {
        ElementType.Space,
        string.rep(' ', distance_between_cols(bufnr, diag.lnum, 0, diag.col)),
      })
    elseif diag.col ~= prev_col then
      table.insert(stack, {
        ElementType.Space,
        -- +1 because indexing starts at 0 in one API but at 1 in the other.
        string.rep(' ', distance_between_cols(bufnr, diag.lnum, prev_col + 1, diag.col)),
      })
    else
      table.insert(stack, { ElementType.Overlap, diag.severity })
    end

    if diag.message:find('^%s*$') then
      table.insert(stack, { ElementType.Blank, diag })
    else
      table.insert(stack, { ElementType.Diagnostic, diag })
    end

    prev_lnum, prev_col = diag.lnum, diag.col
  end

  local chars = {
    cross = '┼',
    horizontal = '─',
    horizontal_up = '┴',
    up_right = '└',
    vertical = '│',
    vertical_right = '├',
  }

  for lnum, stack in pairs(line_stacks) do
    local virt_lines = {}

    -- Note that we read in the order opposite to insertion.
    for i = #stack, 1, -1 do
      if stack[i][1] == ElementType.Diagnostic then
        local diagnostic0 = stack[i][2]
        local left = {} --- @type [string, string]
        local overlap = false
        local multi = false

        -- Iterate the stack for this line to find elements on the left.
        for j = 1, i - 1 do
          local element_type = stack[j][1]
          local data = stack[j][2]
          if element_type == ElementType.Space then
            if multi then
              --- @cast data string
              table.insert(left, {
                string.rep(chars.horizontal, data:len()),
                virtual_lines_highlight_map[diagnostic0.severity],
              })
            else
              table.insert(left, { data, '' })
            end
          elseif element_type == ElementType.Diagnostic then
            -- If an overlap follows this line, don't add an extra column.
            if stack[j + 1][1] ~= ElementType.Overlap then
              table.insert(left, { chars.vertical, virtual_lines_highlight_map[data.severity] })
            end
            overlap = false
          elseif element_type == ElementType.Blank then
            if multi then
              table.insert(
                left,
                { chars.horizontal_up, virtual_lines_highlight_map[data.severity] }
              )
            else
              table.insert(left, { chars.up_right, virtual_lines_highlight_map[data.severity] })
            end
            multi = true
          elseif element_type == ElementType.Overlap then
            overlap = true
          end
        end

        local center_char --- @type string
        if overlap and multi then
          center_char = chars.cross
        elseif overlap then
          center_char = chars.vertical_right
        elseif multi then
          center_char = chars.horizontal_up
        else
          center_char = chars.up_right
        end

        local center = {
          {
            string.format('%s%s', center_char, string.rep(chars.horizontal, 4) .. ' '),
            virtual_lines_highlight_map[diagnostic0.severity],
          },
        }

        -- We can draw on the left side if and only if:
        -- a. Is the last one stacked this line.
        -- b. Has enough space on the left.
        -- c. Is just one line.
        -- d. Is not an overlap.
        for msg_line in diagnostic0.message:gmatch('([^\n]+)') do
          local vline = {}
          vim.list_extend(vline, left)
          vim.list_extend(vline, center)
          vim.list_extend(vline, {
            { msg_line, virtual_lines_highlight_map[diagnostic0.severity] },
          })

          table.insert(virt_lines, vline)

          -- Special-case for continuation lines:
          if overlap then
            center = {
              { chars.vertical, virtual_lines_highlight_map[diagnostic0.severity] },
              { '     ', '' },
            }
          else
            center = { { '      ', '' } }
          end
        end
      end
    end

    api.nvim_buf_set_extmark(bufnr, namespace, line_anchor[lnum] or lnum, 0, {
      virt_lines_overflow = 'scroll',
      virt_lines = virt_lines,
    })
  end
end

--- @param diagnostic0 vim.Diagnostic
--- @return string
local function format_virtual_lines(diagnostic0)
  if diagnostic0.code then
    return string.format('%s: %s', diagnostic0.code, diagnostic0.message)
  end

  return diagnostic0.message
end

M.virtual_lines = {}

--- @param namespace integer
--- @param bufnr integer
--- @param diagnostics vim.Diagnostic[]
--- @param opts? vim.diagnostic.OptsResolved
function M.virtual_lines.show(namespace, bufnr, diagnostics, opts)
  vim.validate('namespace', namespace, 'number')
  vim.validate('bufnr', bufnr, 'number')
  vim.validate('diagnostics', diagnostics, vim.islist, 'a list of diagnostics')
  vim.validate('opts', opts, 'table', true)

  bufnr = vim._resolve_bufnr(bufnr)
  local vopts = opts and opts.virtual_lines or {}

  local ns = diagnostic.get_namespace(namespace)
  show_once_loaded('virtual_lines_show_autocmd', ns, bufnr, function()
    if not ns.user_data.virt_lines_ns then
      ns.user_data.virt_lines_ns =
        api.nvim_create_namespace(string.format('nvim.%s.diagnostic.virtual_lines', ns.name))
    end
    if not ns.user_data.virt_lines_augroup then
      ns.user_data.virt_lines_augroup = api.nvim_create_augroup(
        string.format('nvim.%s.diagnostic.virt_lines', ns.name),
        { clear = true }
      )
    end

    api.nvim_clear_autocmds({ group = ns.user_data.virt_lines_augroup, buf = bufnr })

    diagnostics =
      diagnostic_shared.reformat_diagnostics(vopts.format or format_virtual_lines, diagnostics)

    if vopts.current_line == true then
      -- Create a mapping from line -> diagnostics so that we can quickly get the
      -- diagnostics we need when the cursor line doesn't change.
      local line_diagnostics = diagnostic_shared.diagnostic_lines(diagnostics, true)
      api.nvim_create_autocmd('CursorMoved', {
        buf = bufnr,
        group = ns.user_data.virt_lines_augroup,
        callback = function()
          render_virtual_lines(
            ns.user_data.virt_lines_ns,
            bufnr,
            diagnostic_shared.diagnostics_at_cursor(line_diagnostics)
          )
        end,
      })

      -- Also show diagnostics for the current line before the first CursorMoved event.
      render_virtual_lines(
        ns.user_data.virt_lines_ns,
        bufnr,
        diagnostic_shared.diagnostics_at_cursor(line_diagnostics)
      )
    else
      render_virtual_lines(ns.user_data.virt_lines_ns, bufnr, diagnostics)
    end

    save_extmarks(ns.user_data.virt_lines_ns, bufnr)
  end)
end

--- @param namespace integer
--- @param bufnr integer
function M.virtual_lines.hide(namespace, bufnr)
  local ns = diagnostic.get_namespace(namespace)
  cleanup_show_autocmd('virtual_lines_show_autocmd', ns)
  if ns.user_data.virt_lines_ns then
    clear_extmarks(bufnr, ns.user_data.virt_lines_ns)
    if api.nvim_buf_is_valid(bufnr) then
      api.nvim_clear_autocmds({ group = ns.user_data.virt_lines_augroup, buf = bufnr })
    end
  end
end

return M
