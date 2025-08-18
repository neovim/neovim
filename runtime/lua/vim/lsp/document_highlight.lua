---@brief This module provides LSP support for highlighting patterns in a document,
--- utility functions for interaction are also provided.
--- Highlighting is disabled by default.

local bit = require('bit')
local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local protocol = require('vim.lsp.protocol')
local ms = require('vim.lsp.protocol').Methods
local api = vim.api

local Capability = require('vim.lsp._capability')

local M = {}

---@class (private) vim.lsp.document_highlight.Highlight
---@field kind lsp.DocumentHighlightKind
---@field range vim.Range

---@class (private) vim.lsp.document_highlight.ClientState
---@field namespace integer
---@field highlights vim.lsp.document_highlight.Highlight[]
---@field version integer

---@class (private) vim.lsp.document_highlight.State : vim.lsp.Capability
---@field active table<integer, vim.lsp.document_highlight.State?>
---@field client_state table<integer, vim.lsp.document_highlight.ClientState?>
---@field timer uv.uv_timer_t
---@field version integer
local State = { name = 'document_highlight', active = {} }
State.__index = State
setmetatable(State, Capability)

---@package
---@param bufnr integer
---@return vim.lsp.document_highlight.State
function State:new(bufnr)
  self = Capability.new(self, bufnr)
  self.version = 0

  api.nvim_buf_attach(bufnr, false, {
    on_lines = function()
      local state = State.active[bufnr]
      if not state then
        return true
      end
      if M.is_enabled({ bufnr = bufnr }) then
        state:update()
      end
    end,
  })
  api.nvim_create_autocmd('CursorMoved', {
    group = self.augroup,
    buffer = bufnr,
    callback = function()
      if M.is_enabled({ bufnr = bufnr }) then
        self:on_cursor_moved()
      end
    end,
  })

  return self
end

---@package
---@param client_id integer
function State:on_attach(client_id)
  local state = self.client_state[client_id]
  if not state then
    self.client_state[client_id] = {
      namespace = api.nvim_create_namespace('nvim.lsp.document_highlight:' .. client_id),
      highlights = {},
      version = 0,
    }
  end
end

---@package
---@param client_id integer
function State:on_detach(client_id)
  local state = self.client_state[client_id]
  if state then
    self.client_state[client_id] = nil
    api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
    api.nvim__redraw({ buf = self.bufnr, valid = true, flush = false })
  end
end

---@package
function State:on_cursor_moved()
  local pos = vim.pos.cursor(api.nvim_win_get_cursor(0))
  --- Clear and re-request document highlights
  --- only when the cursor moves outside the current highlight range.
  --- This avoids the illusion of lag and reduces unnecessary resource usage.
  local update = false
  for _, state in pairs(self.client_state) do
    local highlights = state.highlights
    local i = vim.list.bisect(state.highlights, { range = vim.range(pos, pos) }, {
      key = function(highlight)
        return highlight.range
      end,
    })
    local range = highlights[i] and highlights[i].range

    if not range or not range:has(vim.range(pos, pos)) then
      api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
      update = true
    end
  end
  if update then
    self:update()
  end
end

---@package
function State:reset()
  self.version = 0
  for _, state in pairs(self.client_state) do
    api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
    state.highlights = {}
    state.version = 0
  end
end

---@package
function State:update()
  self.version = bit.band(self.version + 1, 0xffffffff)
  self:reset_timer()
  self.timer = vim.defer_fn(function()
    self:request()
    -- In most environments,
    -- holding down a key triggers repeated input every 30–40ms,
    -- so a debounce value of 50ms is sufficient.
  end, 50)
end

---@private
function State:reset_timer()
  local timer = self.timer
  if timer then
    self.timer = nil
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
end

---Store highlights for a specific buffer and client
---@package
---@param result? lsp.DocumentHighlight[]
---@param ctx lsp.HandlerContext
function State:handler(err, result, ctx)
  if err then
    log.error('document highlight', err)
  end

  local state = self.client_state[ctx.client_id]
  if not state then
    return
  end

  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  ---@type vim.lsp.document_highlight.Highlight[]
  local highlights = {}
  for _, raw in ipairs(result or {}) do
    highlights[#highlights + 1] = {
      kind = raw.kind,
      range = vim.range.lsp(self.bufnr, raw.range, client.offset_encoding),
    }
  end
  table.sort(highlights, function(a, b)
    return a.range < b.range
  end)

  state.highlights = highlights
  state.version = self.version

  api.nvim__redraw({ buf = self.bufnr, valid = true })
end

---@package
---@param client_id? integer
function State:request(client_id)
  local method = ms.textDocument_documentHighlight

  for id in pairs(client_id and { client_id } or self.client_state) do
    local client = assert(vim.lsp.get_client_by_id(id))
    local params = util.make_position_params(0, client.offset_encoding)

    util._cancel_requests({
      bufnr = self.bufnr,
      clients = { client },
      method = method,
      type = 'pending',
    })

    client:request(method, params, function(...)
      self:handler(...)
    end, self.bufnr)
  end
end

---@param kind lsp.DocumentHighlightKind
---@return string
local function kind_hl(kind)
  if kind == protocol.DocumentHighlightKind.Read then
    return 'LspReferenceRead'
  elseif kind == protocol.DocumentHighlightKind.Write then
    return 'LspReferenceWrite'
  else -- kind == 1 also the default
    return 'LspReferenceText'
  end
end

---@package
---@param toprow integer
---@param botrow integer
function State:on_win(toprow, botrow)
  for _, state in pairs(self.client_state) do
    -- Buffer changes may invalidate the original highlight ranges,
    -- never set outdated highlights as extmarks.
    if state.version == self.version then
      api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)

      -- Only set extmarks for visible lines
      local highlights = state.highlights
      local first = vim.list.bisect(highlights, { range = { end_ = vim.pos(toprow, 0) } }, {
        key = function(highlight)
          return highlight.range.end_
        end,
      })
      local last = vim.list.bisect(highlights, { range = { start = vim.pos(botrow, 0) } }, {
        key = function(highlight)
          return highlight.range.start
        end,
        lo = first,
        bound = 'upper',
      }) - 1

      for i = first, last do
        local range = highlights[i].range

        api.nvim_buf_set_extmark(self.bufnr, state.namespace, range.start.row, range.start.col, {
          end_row = range.end_.row,
          end_col = range.end_.col,
          hl_group = kind_hl(highlights[i].kind),
          -- Although we want to avoid
          -- showing outdated document highlights when the cursor moves,
          -- updating highlights after a document change
          -- requires waiting for the server's response.
          -- This delay can cause flickering, so we don't use ephemeral extmarks here.
          ephemeral = false,
        })
      end
    end
  end
end

local namespace = api.nvim_create_namespace('nvim.lsp.document_highlight')
api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, _, bufnr, toprow, botrow)
    local state = State.active[bufnr]
    if state then
      state:on_win(toprow, botrow)
    end
  end,
})

function M._start(bufnr, client_id)
  local state = State.active[bufnr]

  if not state then
    state = State:new(bufnr)
  end

  state:on_attach(client_id)
  if M.is_enabled({ bufnr = bufnr }) then
    state:update()
  end
end

--- Enables or disables document highlights for the {filter}ed scope.
---
--- To "toggle", pass the inverse of `is_enabled()`:
---
--- ```lua
--- vim.lsp.document_highlight.enable(not vim.lsp.document_highlight.is_enabled())
--- ```
---
--- Note: Usage of |vim.lsp.document_highlight.enable()| requires
--- the following highlight groups to be defined
--- or you won't be able to see the actual highlights.
---   |hl-LspReferenceText|
---   |hl-LspReferenceRead|
---   |hl-LspReferenceWrite|
---@param enable? boolean
---@param filter? vim.lsp.enable.Filter
function M.enable(enable, filter)
  util._enable('document_highlight', enable, filter)

  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    local state = State.active[bufnr]
    if state then
      if M.is_enabled({ bufnr = bufnr }) then
        state:request()
      else
        state:reset()
      end
    end
  end
end

--- Query whether document highlight is enabled in the {filter}ed scope
---@param filter? vim.lsp.enable.Filter
function M.is_enabled(filter)
  return util._is_enabled('document_highlight', filter)
end

---@class vim.lsp.document_highlight.jump.Opts
---@inlinedoc
---
--- The number of highlights to move by.
--- A positive integer moves forward by {count} highlights,
--- while a negative integer moves backward by {count} highlights.
---
--- (default: |v:count1|)
---@field count integer
---
--- Window ID, or 0 for the current window
--- (default: `0`)
---@field winid? integer

--- Jump to a document highlight.
---
---@param opts? vim.lsp.document_highlight.jump.Opts
function M.jump(opts)
  vim.validate('opts', opts, 'table', true)
  opts = opts or {}

  vim.validate('count', opts.count, 'number', true)
  vim.validate('count', opts.winid, 'number', true)
  local count = opts.count or vim.v.count1
  local winid = opts.winid or api.nvim_get_current_win()

  local bufnr = api.nvim_win_get_buf(winid)
  local state = State.active[bufnr]
  if not state then
    return
  end

  local cursor_pos = vim.pos.cursor(vim.api.nvim_win_get_cursor(winid))
  local pos ---@type vim.Pos
  for _, client_state in pairs(state.client_state) do
    local highlights = client_state.highlights
    local i = vim.list.bisect(highlights, {
      range = vim.range(cursor_pos, cursor_pos),
    }, {
      key = function(highlight)
        return highlight.range
      end,
    }) + count
    i = math.min(math.max(1, i), #highlights)
    local range = highlights[i] and highlights[i].range

    -- For multiple clients support,
    -- Select the (row, col) closest to (cursor_row, cursor_col).
    if range then
      if count < 0 and range.start < cursor_pos then
        if not pos or pos > range.start then
          pos = range.start
        end
      elseif count > 0 and cursor_pos < range.start then
        if not pos or range.start < pos then
          pos = range.start
        end
      end
    end
  end

  if pos then
    vim._with({ win = winid }, function()
      -- Save position in the window's jumplist
      vim.cmd("normal! m'")
      vim.api.nvim_win_set_cursor(winid, pos:to_cursor())
      -- Open folds under the cursor
      vim.cmd('normal! zv')
    end)
  end
end

M.__DocumentHighlighter = State

util._enable('document_highlight', false)

return M
