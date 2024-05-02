local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local api = vim.api
local M = {}

---@class (private) vim.lsp.inlay_hint.bufstate
---@field version? integer
---@field client_hints? table<integer, table<integer, lsp.InlayHint[]>> client_id -> (lnum -> hints)
---@field applied table<integer, integer> Last version of hints applied to this line
---@field enabled boolean|integer[]  The client_id of inlay_hint is enabled on this buffer, true for all
---@type table<integer, vim.lsp.inlay_hint.bufstate>
local bufstates = {}

---@type table<integer, integer> client_id -> namespace
local namespaces = vim.defaulttable(function(client_id)
  return api.nvim_create_namespace('vim_lsp_inlayhint:' .. client_id)
end)

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
  local client_hints = bufstate.client_hints
  local client = assert(vim.lsp.get_client_by_id(client_id))

  local new_lnum_hints = vim.defaulttable()
  local num_unprocessed = #result
  if num_unprocessed == 0 then
    client_hints[client_id] = {}
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
    table.insert(new_lnum_hints[lnum], hint)
  end

  client_hints[client_id] = new_lnum_hints
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
--- @field client_id integer?
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
  ---@param c vim.lsp.Client
  clients = vim.tbl_filter(function(c)
    return not filter.client_id or c.id == filter.client_id
  end, clients)

  local range = filter.range
  if not range then
    range = {
      start = { line = 0, character = 0 },
      ['end'] = { line = api.nvim_buf_line_count(bufnr), character = 0 },
    }
  end

  --- @type vim.lsp.inlay_hint.get.ret[]
  local result = {}
  for _, client in pairs(clients) do
    local lnum_hints = bufstate.client_hints[client.id]
    if lnum_hints then
      for lnum = range.start.line, range['end'].line do
        local hints = lnum_hints[lnum] or {}
        for _, hint in pairs(hints) do
          local line, char = hint.position.line, hint.position.character
          if
            (line > range.start.line or char >= range.start.character)
            and (line < range['end'].line or char <= range['end'].character)
          then
            table.insert(result, {
              bufnr = bufnr,
              client_id = client.id,
              inlay_hint = hint,
            })
          end
        end
      end
    end
  end
  return result
end

--- Clear inlay hints
---@param bufnr (integer) Buffer handle, or 0 for current
---@param client_id (integer|nil) Client id, or nil for all
local function clear(bufnr, client_id)
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

  if client_id then
    api.nvim_buf_clear_namespace(bufnr, namespaces[client_id], 0, -1)
  else
    for _, namespace in pairs(namespaces) do
      api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    end
  end
  api.nvim__buf_redraw_range(bufnr, 0, -1)
end

--- Disable inlay hints for a buffer
---@param bufnr (integer|nil) Buffer handle, or 0 or nil for current
---@param client_id (integer|nil) Client id, or nil for all
local function _disable(bufnr, client_id)
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  clear(bufnr, client_id)
  if bufstates[bufnr] then
    local enabled = bufstates[bufnr].enabled
    if client_id and type(enabled) == 'table' and #enabled ~= 1 then
      vim.list_remove(enabled, client_id)
      bufstates[bufnr] = { enabled = enabled, applied = {} }
    else
      bufstates[bufnr] = { enabled = false, applied = {} }
    end
  end
end

--- Refresh inlay hints, only if we have attached clients that support it
---@param bufnr (integer) Buffer handle, or 0 for current
---@param client_id (integer|nil) Client id, or nil for all
---@param opts? vim.lsp.util._refresh.Opts Additional options to pass to util._refresh
---@private
local function _refresh(bufnr, client_id, opts)
  opts = opts or {}
  opts['bufnr'] = bufnr
  opts['client_id'] = client_id
  util._refresh(ms.textDocument_inlayHint, opts)
end

--- Enable inlay hints for a buffer
---@param bufnr (integer|nil) Buffer handle, or 0 or nil for current
---@param client_id (integer|nil) Client id, or nil for all
local function _enable(bufnr, client_id)
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  local bufstate = bufstates[bufnr]
  if not bufstate then
    bufstates[bufnr] = { applied = {}, enabled = client_id and { client_id } or true }
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
          local enabled = bufstates[bufnr].enabled
          if type(enabled) ~= 'table' or vim.tbl_contains(enabled, opts.data.client_id) then
            _refresh(bufnr, opts.data.client_id)
          end
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
    local enabled = bufstate.enabled
    if type(enabled) == 'table' then
      if not vim.tbl_contains(enabled, client_id) then
        table.insert(enabled, client_id)
      end
    else
      bufstate.enabled = true
    end
    _refresh(bufnr)
  end
end

do
  local namespace = api.nvim_create_namespace('vim_lsp_inlayhint')
  api.nvim_set_decoration_provider(namespace, {
    on_win = function(_, _, bufnr, topline, botline)
      local bufstate = bufstates[bufnr]
      if not bufstate then
        return
      end

      if bufstate.version ~= util.buf_versions[bufnr] then
        return
      end

      if not bufstate.client_hints then
        return
      end
      local client_hints = assert(bufstate.client_hints)

      for lnum = topline, botline do
        if bufstate.applied[lnum] ~= bufstate.version then
          for client_id, lnum_hints in pairs(client_hints) do
            api.nvim_buf_clear_namespace(bufnr, namespaces[client_id], lnum, lnum + 1)
            local hints = lnum_hints[lnum] or {}
            for _, hint in pairs(hints) do
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
              api.nvim_buf_set_extmark(
                bufnr,
                namespaces[client_id],
                lnum,
                hint.position.character,
                {
                  virt_text_pos = 'inline',
                  ephemeral = false,
                  virt_text = vt,
                }
              )
            end
          end
          bufstate.applied[lnum] = bufstate.version
        end
      end
    end,
  })
end

--- @param bufnr (integer|nil) Buffer handle, or 0 for current
--- @param client_id (integer|nil) Client id, or nil for all
--- @return boolean
--- @since 12
function M.is_enabled(bufnr, client_id)
  vim.validate({ bufnr = { bufnr, 'number', true } })
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  if bufstates[bufnr] then
    local enabled = bufstates[bufnr].enabled
    if type(enabled) == 'table' then
      return vim.tbl_contains(enabled, client_id)
    end
    return enabled
  else
    return false
  end
end

--- Optional filters |kwargs|, or `nil` for all.
--- @class vim.lsp.inlay_hint.enable.Filter
--- @inlinedoc
--- Buffer number, or 0/nil for current buffer.
--- @field bufnr integer?
--- Client id, or nil for all.
--- @field client_id integer?

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
      'vim.lsp.inlay_hint.enable(enable:boolean, filter:table)',
      '0.10-dev'
    )
    error('see :help vim.lsp.inlay_hint.enable() for updated parameters')
  end

  vim.validate({ enable = { enable, 'boolean', true }, filter = { filter, 'table', true } })
  filter = filter or {}
  if enable == false then
    _disable(filter.bufnr, filter.client_id)
  else
    _enable(filter.bufnr, filter.client_id)
  end
end

return M
