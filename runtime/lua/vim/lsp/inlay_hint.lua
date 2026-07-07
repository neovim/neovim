local api = vim.api
local log = require('vim.lsp.log')
local nvim_on = require('vim._core.util').nvim_on
local util = require('vim.lsp.util')

local Capability = require('vim.lsp._capability')

local M = {}

---@class (private) vim.lsp.inlay_hint.LineHints
---@field hints lsp.InlayHint[]
---@field applied boolean whether this line's hints have had extmarks applied

---@class (private) vim.lsp.inlay_hint.CurrentResult Info for current result
---@field version? integer document version associated with this result
---@field namespace_cleared? boolean whether the namespace was cleared for this result yet
---@field hints? table<integer, vim.lsp.inlay_hint.LineHints> lnum -> hints

---@class (private) vim.lsp.inlay_hint.ActiveRequest
---@field request_id? integer the LSP request ID of the most recent request sent to the server
---@field version? integer the document version associated with the most recent request

---@class (private) vim.lsp.inlay_hint.ClientState Buffer local state for inlay hints
---@field namespace integer
---@field active_request vim.lsp.inlay_hint.ActiveRequest
---@field current_result vim.lsp.inlay_hint.CurrentResult

---@class (private) InlayHints : vim.lsp.Capability
---@field active table<integer, InlayHints>
---@field client_state table<integer, vim.lsp.inlay_hint.ClientState>
local InlayHint = {
  name = 'inlay_hint',
  method = 'textDocument/inlayHint',
  active = {},
}
InlayHint.__index = InlayHint
setmetatable(InlayHint, Capability)
Capability.all[InlayHint.name] = InlayHint

---@package
function InlayHint:new(bufnr)
  self = Capability.new(self, bufnr)

  nvim_on('LspNotify', self.augroup, { buf = self.bufnr }, function(ev)
    local client_id = ev.data.client_id ---@type integer

    if not self.client_state[client_id] then
      return
    end

    if ev.data.method == 'textDocument/didClose' then
      self:reset(client_id)
    end

    if ev.data.method == 'textDocument/didChange' or ev.data.method == 'textDocument/didOpen' then
      self:refresh(client_id)
    end
  end)

  nvim_on('BufWinEnter', self.augroup, { buf = self.bufnr }, function()
    for client_id, _ in pairs(self.client_state) do
      self:refresh(client_id)
    end
  end)

  return self
end

---@package
function InlayHint:on_attach(client_id)
  if not self.client_state[client_id] then
    self.client_state[client_id] = {
      namespace = api.nvim_create_namespace('nvim.lsp.inlay_hint:' .. client_id),
      active_request = {},
      current_result = {},
    }
  end
  self:refresh(client_id)
end

---@package
function InlayHint:on_detach(client_id)
  local state = self.client_state[client_id]
  if state then
    self:reset(client_id)
    self.client_state[client_id] = nil
  end
end

--- Reset the buffer's inlay hint state and clear the extmarks
---@package
---@param client_id integer
function InlayHint:reset(client_id)
  local state = assert(self.client_state[client_id])
  self:cancel_active_request(client_id)
  api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
  state.current_result = {}
end

--- Refresh inlay hints by requesting them from the server
---
--- Only sends a request if there is no active request in flight for the current document version.
--- Otherwise, it cancels any previous in-progress request before sending a new one.
---
---@package
---@param client_id integer
function InlayHint:refresh(client_id)
  local version = util.buf_versions[self.bufnr]
  local state = self.client_state[client_id]
  local client = vim.lsp.get_client_by_id(client_id)

  if state and client then
    local current_result = state.current_result
    local active_request = state.active_request

    -- Only send a request for this client if the current result is out of date and
    -- there isn't a current a request in flight for this version
    if current_result.version == version or active_request.version == version then
      return
    end

    -- cancel stale in-flight request
    self:cancel_active_request(client_id)

    ---@type lsp.InlayHintParams
    local params = {
      textDocument = util.make_text_document_params(self.bufnr),
      range = vim
        .range(self.bufnr, 0, 0, api.nvim_buf_line_count(self.bufnr), 0)
        :to_lsp(client.offset_encoding),
    }

    local success, request_id = client:request('textDocument/inlayHint', params, nil, self.bufnr)

    if success then
      active_request.request_id = request_id
      active_request.version = version
    end
  end
end

--- |lsp-handler| for the method `textDocument/inlayHint`
--- Store hints for a specific buffer and client
---@param result lsp.InlayHint[]?
---@param ctx lsp.HandlerContext
---@private
function M.on_inlayhint(err, result, ctx)
  local bufnr = assert(ctx.bufnr)
  local provider = InlayHint.active[bufnr]
  if not provider then
    return
  end

  local state = provider.client_state[ctx.client_id]
  if not state then
    return
  end

  if err then
    log.error('inlay_hint', err)
    state.active_request = {}
    return
  end

  if util.buf_versions[bufnr] ~= ctx.version or not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  -- ignore stale responses
  if state.active_request.request_id and ctx.request_id ~= state.active_request.request_id then
    return
  end

  -- If there's no error but the result is nil, clear existing hints.
  result = result or {}

  local new_lnum_hints = {} ---@type table<integer, vim.lsp.inlay_hint.LineHints>
  local num_unprocessed = #result
  if num_unprocessed == 0 then
    state.active_request = {}
    state.current_result = {}
    if vim.fn.win_gettype(vim.fn.bufwinid(bufnr)) == '' then
      api.nvim__redraw({ buf = bufnr, valid = true, flush = false })
    end
    return
  end

  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))

  for _, hint in ipairs(result) do
    local lnum = hint.position.line
    local line = lines and lines[lnum + 1] or ''
    hint.position.character =
      vim.str_byteindex(line, client.offset_encoding, hint.position.character, false)
    if not new_lnum_hints[lnum] then
      new_lnum_hints[lnum] = {
        hints = {},
        applied = false,
      }
    end
    table.insert(new_lnum_hints[lnum].hints, hint)
  end

  state.active_request = {}
  state.current_result = {
    hints = new_lnum_hints,
    version = ctx.version,
    namespace_cleared = false,
  }

  if vim.fn.win_gettype(vim.fn.bufwinid(bufnr)) == '' then
    api.nvim__redraw({ buf = bufnr, valid = true, flush = false })
  end
end

---@private
function InlayHint:cancel_active_request(client_id)
  local state = assert(self.client_state[client_id])
  local client = vim.lsp.get_client_by_id(client_id)
  local active_request = state.active_request

  if client and active_request.request_id then
    client:cancel_request(active_request.request_id)
    active_request.request_id = nil
    active_request.version = nil
  end
end

--- |lsp-handler| for the method `workspace/inlayHint/refresh`
---@param ctx lsp.HandlerContext
---@private
function M.on_refresh(err, _, ctx)
  if err then
    return vim.NIL
  end

  for bufnr, provider in pairs(InlayHint.active) do
    if provider.client_state[ctx.client_id] then
      provider:reset(ctx.client_id)

      if not vim.tbl_isempty(vim.fn.win_findbuf(bufnr)) then
        provider:refresh(ctx.client_id)
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
--- local resp = client:request_sync('inlayHint/resolve', hint.inlay_hint, 100, 0)
--- local resolved_hint = assert(
---   resp and resp.result,
---   resp and resp.err and vim.lsp.rpc.format_rpc_error(resp.err) or 'request failed'
--- )
--- vim.lsp.util.apply_text_edits(resolved_hint.textEdits, 0, client.encoding)
---
--- location = resolved_hint.label[1].location
--- client:request('textDocument/hover', {
---   textDocument = { uri = location.uri },
---   position = location.range.start,
--- })
--- ```
---
--- @param filter vim.lsp.inlay_hint.get.Filter?
--- @return vim.lsp.inlay_hint.get.ret[]
--- @since 12
function M.get(filter)
  vim.validate('filter', filter, 'table', true)
  filter = filter or {}

  local bufnr = filter.bufnr
  if not bufnr then
    return vim
      .iter(api.nvim_list_bufs())
      :map(function(buf)
        return M.get(vim.tbl_extend('keep', { bufnr = buf }, filter))
      end)
      :flatten()
      :totable()
  else
    bufnr = vim._resolve_bufnr(bufnr)
  end

  local provider = InlayHint.active[bufnr]
  if not provider then
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
  local result = {}
  for client_id, state in pairs(provider.client_state) do
    local lnum_hints = state.current_result.hints
    if lnum_hints then
      for lnum = range.start.line, range['end'].line do
        local line_hints = lnum_hints[lnum] or { hints = {}, applied = false }
        for _, hint in pairs(line_hints.hints) do
          local line, char = hint.position.line, hint.position.character
          if
            (line > range.start.line or char >= range.start.character)
            and (line < range['end'].line or char <= range['end'].character)
          then
            table.insert(result, {
              bufnr = bufnr,
              client_id = client_id,
              inlay_hint = hint,
            })
          end
        end
      end
    end
  end
  return result
end

--- on_win handler for the decoration provider (see |nvim_set_decoration_provider|)
---@package
---@param topline integer
---@param botline integer
function InlayHint:on_win(topline, botline)
  for _, state in pairs(self.client_state) do
    local current_result = state.current_result
    if current_result.version == util.buf_versions[self.bufnr] then
      if not current_result.namespace_cleared then
        api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
        current_result.namespace_cleared = true
      end

      local hints = assert(current_result.hints)

      for lnum = topline, botline do
        local hint_virtual_texts = {} --- @type table<integer, [string, string?][]>
        local line_hints = hints[lnum]
        if line_hints and not line_hints.applied then
          line_hints.applied = true
          for _, hint in pairs(line_hints.hints) do
            local text = ''
            local label = hint.label
            if type(label) == 'string' then
              text = label
            else
              for _, part in ipairs(label) do
                text = text .. part.value
              end
            end
            local vt = hint_virtual_texts[hint.position.character] or {}
            if hint.paddingLeft then
              vt[#vt + 1] = { ' ' }
            end
            vt[#vt + 1] = { text, 'LspInlayHint' }
            if hint.paddingRight then
              vt[#vt + 1] = { ' ' }
            end
            hint_virtual_texts[hint.position.character] = vt
          end
        end

        for pos, vt in pairs(hint_virtual_texts) do
          api.nvim_buf_set_extmark(self.bufnr, state.namespace, lnum, pos, {
            virt_text_pos = 'inline',
            ephemeral = false,
            virt_text = vt,
          })
        end
      end
    end
  end
end

--- Query whether inlay hint is enabled in the {filter}ed scope
--- @param filter? vim.lsp.capability.enable.Filter
--- @return boolean
--- @since 12
function M.is_enabled(filter)
  return Capability.is_enabled('inlay_hint', filter)
end

--- Enables or disables inlay hints for the {filter}ed scope.
---
--- To "toggle", pass the inverse of `is_enabled()`:
---
--- ```lua
--- vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
--- ```
---
--- @param enable boolean? true/nil to enable, false to disable
--- @param filter? vim.lsp.capability.enable.Filter
--- @since 12
function M.enable(enable, filter)
  Capability.enable('inlay_hint', enable, filter)
end

local namespace = api.nvim_create_namespace('nvim.lsp.inlay_hint')
api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, _, bufnr, topline, botline)
    local provider = InlayHint.active[bufnr]
    if provider then
      provider:on_win(topline, botline)
    end
  end,
})

return M
