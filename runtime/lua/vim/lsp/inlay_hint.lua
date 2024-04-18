local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local api = vim.api
local M = {}

---@class (private) vim.lsp.inlay_hint.bufstate
---@field version? integer
---@field client_hints? table<integer, table<integer, lsp.InlayHint[]>> client_id -> (lnum -> hints)
---@field applied table<integer, integer> Last version of hints applied to this line
---@field enabled boolean Whether inlay hints are enabled for this buffer
---@type table<integer, vim.lsp.inlay_hint.bufstate>
local bufstates = {}

local namespace = api.nvim_create_namespace('vim_lsp_inlayhint')
local augroup = api.nvim_create_augroup('vim_lsp_inlayhint', {})

--- |lsp-handler| for the method `textDocument/inlayHint`
--- Store hints for a specific buffer and client
---@param result lsp.InlayHint[]?
---@param ctx lsp.HandlerContext
---@private
function M.on_inlayhint(err, result, ctx, _)
  if err then
    log.error('inlayhint', err)
    return
  end
  local bufnr = assert(ctx.bufnr)
  if util.buf_versions[bufnr] ~= ctx.version then
    return
  end
  local client_id = ctx.client_id
  if not result then
    return
  end
  local bufstate = bufstates[bufnr]
  if not bufstate or not bufstate.enabled then
    return
  end
  if not (bufstate.client_hints and bufstate.version) then
    bufstate.client_hints = vim.defaulttable()
    bufstate.version = ctx.version
  end
  local hints_by_client = bufstate.client_hints
  local client = assert(vim.lsp.get_client_by_id(client_id))

  local new_hints_by_lnum = vim.defaulttable()
  local num_unprocessed = #result
  if num_unprocessed == 0 then
    hints_by_client[client_id] = {}
    bufstate.version = ctx.version
    api.nvim__buf_redraw_range(bufnr, 0, -1)
    return
  end

  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  ---@param position lsp.Position
  ---@return integer
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

--- |lsp-handler| for the method `textDocument/inlayHint/refresh`
---@param ctx lsp.HandlerContext
---@private
function M.on_refresh(err, _, ctx, _)
  if err then
    return vim.NIL
  end
  for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(ctx.client_id)) do
    for _, winid in ipairs(api.nvim_list_wins()) do
      if api.nvim_win_get_buf(winid) == bufnr then
        local bufstate = bufstates[bufnr]
        if bufstate then
          util._refresh(ms.textDocument_inlayHint, { bufnr = bufnr })
          break
        end
      end
    end
  end

  return vim.NIL
end

--- Optional filters |kwargs|:
--- @class vim.lsp.inlay_hint.get.Filter
--- @inlinedoc
--- @field bufnr integer?
--- @field range lsp.Range?

--- @class vim.lsp.inlay_hint.get.ret
--- @inlinedoc
--- @field bufnr integer
--- @field client_id integer
--- @field inlay_hint lsp.InlayHint

--- Get the list of inlay hints, (optionally) restricted by buffer or range.
---
--- Example usage:
---
--- ```lua
--- local hint = vim.lsp.inlay_hint.get({ bufnr = 0 })[1] -- 0 for current buffer
---
--- local client = vim.lsp.get_client_by_id(hint.client_id)
--- resolved_hint = client.request_sync('inlayHint/resolve', hint.inlay_hint, 100, 0).result
--- vim.lsp.util.apply_text_edits(resolved_hint.textEdits, 0, client.encoding)
---
--- location = resolved_hint.label[1].location
--- client.request('textDocument/hover', {
---   textDocument = { uri = location.uri },
---   position = location.range.start,
--- })
--- ```
---
--- @param filter vim.lsp.inlay_hint.get.Filter?
--- @return vim.lsp.inlay_hint.get.ret[]
--- @since 12
function M.get(filter)
  vim.validate({ filter = { filter, 'table', true } })
  filter = filter or {}

  local bufnr = filter.bufnr
  if not bufnr then
    --- @type vim.lsp.inlay_hint.get.ret[]
    local hints = {}
    --- @param buf integer
    vim.tbl_map(function(buf)
      vim.list_extend(hints, M.get(vim.tbl_extend('keep', { bufnr = buf }, filter)))
    end, vim.api.nvim_list_bufs())
    return hints
  elseif bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end

  local bufstate = bufstates[bufnr]
  if not (bufstate and bufstate.client_hints) then
    return {}
  end

  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    method = ms.textDocument_inlayHint,
  })
  if #clients == 0 then
    return {}
  end

  local range = filter.range
  if not range then
    range = {
      start = { line = 0, character = 0 },
      ['end'] = { line = api.nvim_buf_line_count(bufnr), character = 0 },
    }
  end

  --- @type vim.lsp.inlay_hint.get.ret[]
  local hints = {}
  for _, client in pairs(clients) do
    local hints_by_lnum = bufstate.client_hints[client.id]
    if hints_by_lnum then
      for lnum = range.start.line, range['end'].line do
        local line_hints = hints_by_lnum[lnum] or {}
        for _, hint in pairs(line_hints) do
          local line, char = hint.position.line, hint.position.character
          if
            (line > range.start.line or char >= range.start.character)
            and (line < range['end'].line or char <= range['end'].character)
          then
            table.insert(hints, {
              bufnr = bufnr,
              client_id = client.id,
              inlay_hint = hint,
            })
          end
        end
      end
    end
  end
  return hints
end

--- Clear inlay hints
---@param bufnr (integer) Buffer handle, or 0 for current
local function clear(bufnr)
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  if not bufstates[bufnr] then
    return
  end
  local bufstate = bufstates[bufnr]
  local client_lens = (bufstate or {}).client_hints or {}
  local client_ids = vim.tbl_keys(client_lens) --- @type integer[]
  for _, iter_client_id in ipairs(client_ids) do
    if bufstate then
      bufstate.client_hints[iter_client_id] = {}
    end
  end
  api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  api.nvim__buf_redraw_range(bufnr, 0, -1)
end

--- Disable inlay hints for a buffer
---@param bufnr (integer|nil) Buffer handle, or 0 or nil for current
local function _disable(bufnr)
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  clear(bufnr)
  if bufstates[bufnr] then
    bufstates[bufnr] = { enabled = false, applied = {} }
  end
end

--- Refresh inlay hints, only if we have attached clients that support it
---@param bufnr (integer) Buffer handle, or 0 for current
---@param opts? vim.lsp.util._refresh.Opts Additional options to pass to util._refresh
---@private
local function _refresh(bufnr, opts)
  opts = opts or {}
  opts['bufnr'] = bufnr
  util._refresh(ms.textDocument_inlayHint, opts)
end

--- Enable inlay hints for a buffer
---@param bufnr (integer|nil) Buffer handle, or 0 or nil for current
local function _enable(bufnr)
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  local bufstate = bufstates[bufnr]
  if not bufstate then
    bufstates[bufnr] = { applied = {}, enabled = true }
    api.nvim_create_autocmd('LspNotify', {
      buffer = bufnr,
      callback = function(opts)
        if
          opts.data.method ~= ms.textDocument_didChange
          and opts.data.method ~= ms.textDocument_didOpen
        then
          return
        end
        if bufstates[bufnr] and bufstates[bufnr].enabled then
          _refresh(bufnr, { client_id = opts.data.client_id })
        end
      end,
      group = augroup,
    })
    _refresh(bufnr)
    api.nvim_buf_attach(bufnr, false, {
      on_reload = function(_, cb_bufnr)
        clear(cb_bufnr)
        if bufstates[cb_bufnr] and bufstates[cb_bufnr].enabled then
          bufstates[cb_bufnr].applied = {}
          _refresh(cb_bufnr)
        end
      end,
      on_detach = function(_, cb_bufnr)
        _disable(cb_bufnr)
      end,
    })
    api.nvim_create_autocmd('LspDetach', {
      buffer = bufnr,
      callback = function(args)
        local clients = vim.lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_inlayHint })

        if
          not vim.iter(clients):any(function(c)
            return c.id ~= args.data.client_id
          end)
        then
          _disable(bufnr)
        end
      end,
      group = augroup,
    })
  else
    bufstate.enabled = true
    _refresh(bufnr)
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
    local hints_by_client = assert(bufstate.client_hints)

    for lnum = topline, botline do
      if bufstate.applied[lnum] ~= bufstate.version then
        api.nvim_buf_clear_namespace(bufnr, namespace, lnum, lnum + 1)
        for _, hints_by_lnum in pairs(hints_by_client) do
          local line_hints = hints_by_lnum[lnum] or {}
          for _, hint in pairs(line_hints) do
            local text = ''
            local label = hint.label
            if type(label) == 'string' then
              text = label
            else
              for _, part in ipairs(label) do
                text = text .. part.value
              end
            end
            local vt = {} --- @type {[1]: string, [2]: string?}[]
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
            })
          end
        end
        bufstate.applied[lnum] = bufstate.version
      end
    end
  end,
})

--- @param bufnr (integer|nil) Buffer handle, or 0 for current
--- @return boolean
--- @since 12
function M.is_enabled(bufnr)
  vim.validate({ bufnr = { bufnr, 'number', true } })
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  return bufstates[bufnr] and bufstates[bufnr].enabled or false
end

--- Optional filters |kwargs|, or `nil` for all.
--- @class vim.lsp.inlay_hint.enable.Filter
--- @inlinedoc
--- Buffer number, or 0/nil for current buffer.
--- @field bufnr integer?

--- Enables or disables inlay hints for a buffer.
---
--- To "toggle", pass the inverse of `is_enabled()`:
---
--- ```lua
--- vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
--- ```
---
--- @param enable (boolean|nil) true/nil to enable, false to disable
--- @param filter vim.lsp.inlay_hint.enable.Filter?
--- @since 12
function M.enable(enable, filter)
  if type(enable) == 'number' or type(filter) == 'boolean' then
    vim.deprecate(
      'vim.lsp.inlay_hint.enable(bufnr:number, enable:boolean)',
      'vim.diagnostic.enable(enable:boolean, filter:table)',
      '0.10-dev'
    )
    error('see :help vim.lsp.inlay_hint.enable() for updated parameters')
  end

  vim.validate({ enable = { enable, 'boolean', true }, filter = { filter, 'table', true } })
  filter = filter or {}
  if enable == false then
    _disable(filter.bufnr)
  else
    _enable(filter.bufnr)
  end
end

return M
