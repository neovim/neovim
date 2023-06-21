local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local api = vim.api
local M = {}

---@class lsp._inlay_hint.bufstate
---@field version integer
---@field client_hint table<integer, table<integer, lsp.InlayHint[]>> client_id -> (lnum -> hints)
---@field enabled boolean Whether inlay hints are enabled for the buffer
---@field timer uv.uv_timer_t? Debounce timer associated with the buffer
---@field color_column boolean Whether to use color column for inlay hints

---@type table<integer, lsp._inlay_hint.bufstate>
local bufstates = {}

local namespace = api.nvim_create_namespace('vim_lsp_inlayhint')
local augroup = api.nvim_create_augroup('vim_lsp_inlayhint', {})

--- Reset the request debounce timer of a buffer
---@private
local function reset_timer(reset_bufnr)
  local timer = bufstates[reset_bufnr].timer
  if timer then
    bufstates[reset_bufnr].timer = nil
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
end

--- |lsp-handler| for the method `textDocument/inlayHint`
--- Store hints for a specific buffer and client
---@private
function M.on_inlayhint(err, result, ctx, _)
  if err then
    local _ = log.error() and log.error('inlayhint', err)
    return
  end
  local bufnr = ctx.bufnr
  if util.buf_versions[bufnr] ~= ctx.version then
    return
  end
  local client_id = ctx.client_id
  if not result then
    return
  end
  local bufstate = bufstates[bufnr]
  if not (bufstate.client_hint and bufstate.version) then
    bufstate.client_hint = vim.defaulttable()
    bufstate.version = ctx.version
  end
  local hints_by_client = bufstate.client_hint
  local client = vim.lsp.get_client_by_id(client_id)

  local new_hints_by_lnum = vim.defaulttable()
  local num_unprocessed = #result
  if num_unprocessed == 0 then
    hints_by_client[client_id] = {}
    bufstate.version = ctx.version
    api.nvim__buf_redraw_range(bufnr, 0, -1)
    return
  end

  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  ---@private
  local function pos_to_byte(position)
    local col = position.character
    if col > 0 then
      local line = lines[position.line + 1] or ''
      local ok, convert_result
      ok, convert_result = pcall(util._str_byteindex_enc, line, col, client.offset_encoding)
      if ok then
        return convert_result
      end
      return math.min(#line, col)
    end
    return col
  end

  for _, hint in ipairs(result) do
    local lnum = hint.position.line
    hint.position.character = pos_to_byte(hint.position)
    table.insert(new_hints_by_lnum[lnum], hint)
  end

  hints_by_client[client_id] = new_hints_by_lnum
  bufstate.version = ctx.version
  api.nvim__buf_redraw_range(bufnr, 0, -1)
end

---@private
local function resolve_bufnr(bufnr)
  return bufnr > 0 and bufnr or api.nvim_get_current_buf()
end

--- Refresh inlay hints for a buffer
---
---@param opts (nil|table) Optional arguments
---  - bufnr (integer, default: 0): Buffer whose hints to refresh
---  - only_visible (boolean, default: false): Whether to only refresh hints for the visible regions of the buffer
---
---@private
function M.refresh(opts)
  opts = opts or {}
  local bufnr = resolve_bufnr(opts.bufnr or 0)
  local bufstate = bufstates[bufnr]
  if not (bufstate and bufstate.enabled) then
    return
  end

  local only_visible = opts.only_visible or false
  local buffer_windows = {}
  for _, winid in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_buf(winid) == bufnr then
      table.insert(buffer_windows, winid)
    end
  end
  for _, window in ipairs(buffer_windows) do
    local first = vim.fn.line('w0', window)
    local last = vim.fn.line('w$', window)
    local params = {
      textDocument = util.make_text_document_params(bufnr),
      range = {
        start = { line = first - 1, character = 0 },
        ['end'] = { line = last, character = 0 },
      },
    }
    vim.lsp.buf_request(bufnr, 'textDocument/inlayHint', params)
  end
  if not only_visible then
    local params = {
      textDocument = util.make_text_document_params(bufnr),
      range = {
        start = { line = 0, character = 0 },
        ['end'] = { line = api.nvim_buf_line_count(bufnr), character = 0 },
      },
    }
    vim.lsp.buf_request(bufnr, 'textDocument/inlayHint', params)
  end
end

--- Clear inlay hints
---@param bufnr (integer) Buffer handle, or 0 for current
---@private
local function clear(bufnr)
  bufnr = resolve_bufnr(bufnr)
  reset_timer(bufnr)
  local bufstate = bufstates[bufnr]
  local client_lens = (bufstate or {}).client_hint or {}
  local client_ids = vim.tbl_keys(client_lens)
  for _, iter_client_id in ipairs(client_ids) do
    if bufstate then
      bufstate.client_hint[iter_client_id] = {}
    end
  end
  api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  api.nvim__buf_redraw_range(bufnr, 0, -1)
end

---@private
local function make_request(request_bufnr)
  reset_timer(request_bufnr)
  M.refresh({ bufnr = request_bufnr })
end

---@private
local function add_color_column_extmark(bufnr, line, lnum, color_columns, text_width, ephemeral, offsets)
  for _, column in ipairs(color_columns) do
    local first_char = column:sub(1, 1)

    if first_char == '+' then
      column = text_width + column:sub(2)
    end

    if first_char == '-' then
      column = text_width - column:sub(2)
    end

    local col = math.floor(tonumber(column) or 0)

    if col < 0 then
      return
    end

    local virt_text_value = ' '
    if #line >= col then
      virt_text_value = line:sub(col + 1, col + 1)
    end

    if #virt_text_value == 0 then
      virt_text_value = ' '
    end

    local offset = 0

    if offsets ~= nil and next(offsets) ~= nil then
      for pos, iter_offset in pairs(offsets) do
        if pos - 1 <= col then
          offset = offset + iter_offset + 1
        end
      end
    end

    api.nvim_buf_set_extmark(bufnr, namespace, lnum, 0, {
      virt_text_win_col = col + offset,
      virt_text_pos = 'overlay',
      priority = 1,
      hl_mode = 'combine',
      ephemeral = ephemeral or false,
      virt_text = {
        { virt_text_value, 'LspInlayHintsColorColumn' } }
    })
  end
end

---@private
local function swap_highlights(ns_ids, groups)
  if next(ns_ids) == nil then
    return
  end

  if next(groups) == nil then
    return
  end

  local ns_id_a = ns_ids[1]
  local ns_id_b = ns_ids[2] or ns_id_a

  local group_a = groups[1]
  local group_b = groups[2] or group_a

  local opts_a = api.nvim_get_hl(ns_id_a, { name = group_a })
  local opts_b = api.nvim_get_hl(ns_id_b, { name = group_b })

  if next(opts_a) == nil or (next(opts_a) == nil and next(opts_b) == nil) then
    return
  end

  if next(opts_b) == nil then
    if (ns_id_b ~= 0) then
      api.nvim_set_hl_ns(ns_id_b)
    end

    api.nvim_set_hl(ns_id_a, group_a, {})
    api.nvim_set_hl(ns_id_b, group_b, opts_a)
    return
  end

  api.nvim_set_hl(ns_id_a, group_a, opts_b)
  api.nvim_set_hl(ns_id_b, group_b, opts_a)
end

---@class InlayHintsOpts
---@field color_column (boolean|nil)

--- Enable inlay hints for a buffer
---@param bufnr (integer) Buffer handle, or 0 for current
---@param opts (InlayHintsOpts|nil) Optional keyword arguments
---   - color_column (boolean|nil) Shift color column to the right for accurate column highlighting
---@private
function M.enable(bufnr, opts)
  if opts and opts.color_column then
    swap_highlights({ 0, namespace }, { 'ColorColumn', 'LspInlayHintsColorColumn' })
  end

  bufnr = resolve_bufnr(bufnr)
  local bufstate = bufstates[bufnr]
  if not (bufstate and bufstate.enabled) then
    bufstates[bufnr] = { enabled = true, timer = nil, color_column = (opts and opts.color_column) or false }
    M.refresh({ bufnr = bufnr })
    api.nvim_buf_attach(bufnr, true, {
      on_lines = function(_, cb_bufnr)
        if not bufstates[cb_bufnr].enabled then
          return true
        end
        reset_timer(cb_bufnr)
        bufstates[cb_bufnr].timer = vim.defer_fn(function()
          make_request(cb_bufnr)
        end, 200)
      end,
      on_reload = function(_, cb_bufnr)
        clear(cb_bufnr)
        bufstates[cb_bufnr] = nil
        M.refresh({ bufnr = cb_bufnr })
      end,
      on_detach = function(_, cb_bufnr)
        clear(cb_bufnr)
        bufstates[cb_bufnr] = nil
      end,
    })
    api.nvim_create_autocmd('LspDetach', {
      buffer = bufnr,
      callback = function(opts)
        clear(opts.buf)
      end,
      once = true,
      group = augroup,
    })
  end
end

--- Disable inlay hints for a buffer
---@param bufnr (integer) Buffer handle, or 0 for current
---@private
function M.disable(bufnr)
  bufnr = resolve_bufnr(bufnr)
  if bufstates[bufnr] and bufstates[bufnr].enabled then
    clear(bufnr)
    bufstates[bufnr].enabled = nil
    bufstates[bufnr].timer = nil

    if bufstates[bufnr].color_column then
      swap_highlights({ namespace, 0 }, { 'LspInlayHintsColorColumn', 'ColorColumn' })
    end

    bufstates[bufnr].color_column = nil
  end
end

--- Toggle inlay hints for a buffer
---@param bufnr (integer) Buffer handle, or 0 for current
---@param opts (InlayHintsOpts|nil) Optional keyword arguments
---   - color_column (boolean|nil) Shift color column to the right for accurate column highlighting
---@private
function M.toggle(bufnr, opts)
  bufnr = resolve_bufnr(bufnr)
  local bufstate = bufstates[bufnr]
  if bufstate and bufstate.enabled then
    M.disable(bufnr)
  else
    M.enable(bufnr, opts)
  end
end

api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, _, bufnr, topline, botline)
    local bufstate = bufstates[bufnr]
    if not bufstate then
      return
    end

    if bufstate.version ~= util.buf_versions[bufnr] then
      return
    end
    local hints_by_client = bufstate.client_hint
    api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

    local lines = {}
    local color_columns = {}
    local text_width = 0

    if bufstate.color_column then
      for column in string.gmatch(vim.wo.colorcolumn, '[^,]+') do
        table.insert(color_columns, column)
      end
      text_width = vim.bo.textwidth
      lines = api.nvim_buf_get_lines(bufnr, topline, botline, false)
    end

    for lnum = topline, botline do
      local line = lines[lnum - topline + 1]
      for _, hints_by_lnum in pairs(hints_by_client) do
        local line_hints = hints_by_lnum[lnum] or {}

        if bufstate.color_column and next(line_hints) == nil and line ~= nil then
          add_color_column_extmark(bufnr, line, lnum, color_columns, text_width)
        end

        local offsets = {}
        for _, hint in pairs(line_hints) do
          local text = ''
          if type(hint.label) == 'string' then
            text = hint.label
          else
            for _, part in ipairs(hint.label) do
              text = text .. part.value
            end
          end
          local vt = {}
          if hint.paddingLeft then
            vt[#vt + 1] = { ' ' }
          end
          vt[#vt + 1] = { text, 'LspInlayHint' }
          if hint.paddingRight then
            vt[#vt + 1] = { ' ' }
          end
          api.nvim_buf_set_extmark(bufnr, namespace, lnum, hint.position.character, {
            virt_text_pos = 'inline',
            ephemeral = false,
            virt_text = vt,
            hl_mode = 'combine',
          })

          offsets[hint.position.character] = #text
        end

        if bufstate.color_column and line ~= nil then
          add_color_column_extmark(bufnr, line, lnum, color_columns, text_width, true, offsets)
        end
      end
    end
  end,
})

return M
