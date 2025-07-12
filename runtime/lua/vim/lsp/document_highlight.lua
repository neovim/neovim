local bit = require('bit')
local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local Range = require('vim.treesitter._range')
local api = vim.api

local Capability = require('vim.lsp._capability')

local M = {}

local namespace = api.nvim_create_namespace('nvim.lsp.document_highlight')

---Buffer-local state for document highlights
---@class (private) vim.lsp.document_highlight.State : vim.lsp.Capability
---@field bufnr integer
---@field augroup integer
---
---Each buffer attached by at least one supported LSP server must exists,
---otherwise it should not exists or be cleaned up.
---
---Index in the form of bufnr -> state
---@field active table<integer, vim.lsp.document_highlight.State?>
---
---Each data change generates a unique version,
---not garanteed, numbers may be reused over time.
---@field version? integer
---
---Each client attached to this buffer must exists, highlights are sorted.
---
---Index in the form of client_id -> highlights
---@field client_state table<integer, lsp.DocumentHighlight[]?>
local State = { name = 'document_highlight', active = {} }
State.__index = State
setmetatable(State, Capability)

---@param f function
---@param timeout integer
local function debunce(f, timeout)
  ---@type uv.uv_timer_t?
  local timer = nil
  return function(...)
    local args = { ... }
    if timer then
      vim.uv.timer_stop(timer)
      timer:close()
      timer = nil
    end
    timer = assert(vim.uv.new_timer())
    vim.uv.timer_start(
      timer,
      timeout,
      0,
      vim.schedule_wrap(function()
        if timer then
          vim.uv.timer_stop(timer)
          timer:close()
          timer = nil
        end
        f(unpack(args))
      end)
    )
  end
end

---@package
---@param bufnr integer
---@return vim.lsp.document_highlight.State
function State:new(bufnr)
  self = Capability.new(self, bufnr)

  api.nvim_create_autocmd('LspAttach', {
    group = self.augroup,
    buffer = bufnr,
    callback = function(args)
      ---@type integer
      local client_id = args.data.client_id
      if
        assert(vim.lsp.get_client_by_id(client_id)):supports_method(
          ms.textDocument_documentHighlight
        )
      then
        self.client_state[client_id] = {}
      end
    end,
  })
  api.nvim_create_autocmd('CursorMoved', {
    group = self.augroup,
    desc = 'Refresh document highlights on cursor movement',
    buffer = bufnr,
    callback = function()
      debunce(function()
        self:refresh()
      end, 100)()
    end,
  })
  api.nvim_create_autocmd('LspNotify', {
    group = self.augroup,
    buffer = bufnr,
    desc = 'Refresh document highlights on document change or open',
    callback = function(args)
      local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
      if
        client:supports_method(ms.textDocument_documentHighlight, bufnr)
        and (
          args.data.method == ms.textDocument_didChange
          or args.data.method == ms.textDocument_didOpen
        )
      then
        self:refresh(client.id)
      end
    end,
  })

  return self
end

---@package
---@param client_id integer
function State:on_detach(client_id)
  api.nvim_buf_clear_namespace(self.bufnr, namespace, 0, -1)
  self.client_state[client_id] = nil
  self:refresh()
end

---Store highlights for a specific buffer and client
---@package
---@param result? lsp.DocumentHighlight[]
---@param ctx lsp.HandlerContext
function State:handler(err, result, ctx)
  if err then
    log.error('document highlight', err)
  end

  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))

  result = result or {}
  for _, highlight in pairs(result) do
    highlight.range['start'].character = util._get_line_byte_from_position(
      self.bufnr,
      highlight.range['start'],
      client.offset_encoding
    )
    highlight.range['end'].character =
      util._get_line_byte_from_position(self.bufnr, highlight.range['end'], client.offset_encoding)
  end
  table.sort(result, function(a, b)
    return Range.cmp_pos.lt(
      a.range['end'].line,
      a.range['end'].character,
      b.range['start'].line,
      b.range['start'].character
    )
  end)

  self.client_state[client.id] = result
  self.version = ctx.version

  api.nvim__redraw({ buf = self.bufnr, valid = true })
end

---@package
---@param client_id? integer
---@param sync? boolean
function State:refresh(client_id, sync)
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
    if sync then
      local response = client:request_sync(method, params, nil, self.bufnr)
      if response == nil then
        return
      end

      self:handler(
        response.err,
        response.result,
        { bufnr = self.bufnr, client_id = client.id, method = method }
      )
    else
      client:request(method, params, function(...)
        self:handler(...)
      end, self.bufnr)
    end
  end
end

--- Do a binary search of the highlights in the half-open range [lo, hi).
---
--- Return the index i in range such that
--- highlights[j].range.end < pos for all j < i, and
--- highlights[j].range.end >= pos for all j >= i,
--- or return hi if no such index is found.
---@param highlights lsp.DocumentHighlight[]
---@param pos [integer, integer]
---@param lo integer
---@param hi integer
local function lower_bound(highlights, pos, lo, hi)
  while lo < hi do
    local mid = bit.rshift(lo + hi, 1) -- Equivalent to floor((lo + hi) / 2).
    if
      highlights[mid].range['end'].line < pos[1]
      or (
        highlights[mid].range['end'].line == pos[1]
        and highlights[mid].range['end'].character < pos[2]
      )
    then
      lo = mid + 1
    else
      hi = mid
    end
  end
  return lo
end

--- Do a binary search of the highlights in the half-open range [lo, hi).
---
--- Return the index i in range such that
--- highlights[j].range.start <= line for all j < i, and
--- highlights[j].range.start > line for all j >= i,
--- or return hi if no such index is found.
---@param highlights lsp.DocumentHighlight[]
---@param pos [integer, integer]
---@param lo integer
---@param hi integer
local function upper_bound(highlights, pos, lo, hi)
  while lo < hi do
    local mid = bit.rshift(lo + hi, 1) -- Equivalent to floor((lo + hi) / 2).
    if
      pos[1] < highlights[mid].range['start'].line
      or (
        pos[1] == highlights[mid].range['start'].line
        and pos[2] < highlights[mid].range['start'].character
      )
    then
      hi = mid
    else
      lo = mid + 1
    end
  end
  return lo
end

---@param kind lsp.DocumentHighlightKind
---@return string
local function hl_group_from_kind(kind)
  if kind == 2 then
    return 'LspReferenceRead'
  elseif kind == 3 then
    return 'LspReferenceWrite'
  else -- kind == 1 also the default
    return 'LspReferenceText'
  end
end

api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, _, bufnr, toprow, botrow)
    local state = State.active[bufnr]
    if not state or state.version ~= util.buf_versions[bufnr] then
      return
    end

    api.nvim_buf_clear_namespace(bufnr, namespace, toprow, botrow)

    for _, highlights in pairs(state.client_state) do
      -- Only set extmarks for visible lines
      local first = lower_bound(highlights, { toprow, 0 }, 1, #highlights + 1)
      local last = upper_bound(highlights, { botrow, math.huge }, first, #highlights + 1) - 1

      for i = first, last do
        local row = highlights[i].range['start'].line
        local col = highlights[i].range['start'].character
        local end_row = highlights[i].range['end'].line
        local end_col = highlights[i].range['end'].character

        api.nvim_buf_set_extmark(bufnr, namespace, row, col, {
          end_row = end_row,
          end_col = end_col,
          ephemeral = false,
          hl_group = hl_group_from_kind(highlights[i].kind),
        })
      end
    end
  end,
})

function M._start(bufnr, client_id)
  local state = State.active[bufnr]

  if not state then
    state = State:new(bufnr)
  end

  state.client_state[client_id] = {}
  state:refresh(client_id)
end

---@class vim.lsp.document_highlight.jump.Opts
---@inlinedoc
---
---The number of highlights to move by, starting from {pos}. A positive
---integer moves forward by {count} highlights, while a negative integer moves
---backward by {count} highlights.
---@field count integer
---
---Window ID
---(default: `0`)
---@field winid? integer
---
---Refresh documents highlights immediately before jumping.
---(default: `false`)
---@field refresh? boolean

---Move to a document highlight
---@param opts vim.lsp.document_highlight.jump.Opts
function M.jump(opts)
  vim.validate('opts', opts, 'table')
  vim.validate('count', opts.count, 'number')

  local count = opts.count

  local winid = opts.winid or api.nvim_get_current_win()
  local pos = api.nvim_win_get_cursor(winid)
  ---@cast pos [integer, integer]
  pos = { pos[1] - 1, pos[2] }

  local bufnr = api.nvim_win_get_buf(winid)
  local state = State.active[bufnr]
  if not state then
    return
  end

  if opts.refresh then
    state:refresh(nil, true)
  end

  local _, highlights = next(state.client_state)
  if not highlights then
    return
  end

  local i = lower_bound(highlights, pos, 1, #highlights + 1) + count
  i = math.min(math.max(1, i), #highlights)
  if highlights[i] then
    pos = {
      highlights[i].range['start'].line,
      highlights[i].range['start'].character,
    }
  end
  vim._with({ win = winid }, function()
    -- Save position in the window's jumplist
    vim.cmd("normal! m'")
    vim.api.nvim_win_set_cursor(winid, { pos[1] + 1, pos[2] })
    -- Open folds under the cursor
    vim.cmd('normal! zv')
  end)
end

return M
