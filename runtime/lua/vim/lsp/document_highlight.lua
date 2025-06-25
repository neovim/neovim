local bit = require('bit')
local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local Range = require('vim.treesitter._range')
local api = vim.api

local M = {}

local namespace = api.nvim_create_namespace('nvim.lsp.document_highlight')

---Buffer-local state for document highlights
---@class (private) vim.lsp.document_highlight.Highlighter
---@field bufnr integer
---@field augroup integer
---
---Each buffer attached by at least one supported LSP server must exists,
---otherwise it should not exists or be cleaned up.
---
---Index in the form of bufnr -> highlighter
---@field active table<integer, vim.lsp.document_highlight.Highlighter?>
---
---Whether document highlights are enabled for this buffer,
---`nil` indicates following the global state.
---@field enabled? boolean
---
---Each data change generates a unique version,
---not garanteed, numbers may be reused over time.
---@field version? integer
---
---Each client attached to this buffer must exists, highlights are sorted.
---
---Index in the form of client_id -> highlights
---@field client_highlights table<integer, lsp.DocumentHighlight[]?>
local Highlighter = { active = {} }

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

---@param bufnr integer
---@return vim.lsp.document_highlight.Highlighter
function Highlighter.new(bufnr)
  local self = setmetatable({}, { __index = Highlighter })
  self.bufnr = bufnr
  self.augroup = api.nvim_create_augroup('nvim.lsp.document_highlight:' .. bufnr, { clear = true })
  self.client_highlights = {}

  Highlighter.active[bufnr] = self

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
        self.client_highlights[client_id] = {}
      end
    end,
  })
  api.nvim_create_autocmd('LspDetach', {
    group = self.augroup,
    buffer = bufnr,
    callback = function(args)
      ---@type integer
      local client_id = args.data.client_id
      self.client_highlights[client_id] = nil
      self:refresh()
      if vim.tbl_isempty(self.client_highlights) then
        Highlighter.active[bufnr] = nil
      end
    end,
  })
  api.nvim_create_autocmd('CursorMoved', {
    group = self.augroup,
    desc = 'Refresh document highlights on cursor movement',
    callback = function()
      debunce(function()
        self:refresh()
      end, 100)()
    end,
  })
  api.nvim_create_autocmd('LspNotify', {
    group = self.augroup,
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

---Store highlights for a specific buffer and client
---@param result? lsp.DocumentHighlight[]
---@param ctx lsp.HandlerContext
function Highlighter:handler(err, result, ctx)
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

  self.client_highlights[client.id] = result
  self.version = ctx.version

  api.nvim__redraw({ buf = self.bufnr, valid = true })
end

---@param client_id? integer
---@param sync? boolean
function Highlighter:refresh(client_id, sync)
  local clients = client_id and { assert(vim.lsp.get_client_by_id(client_id)) }
    or vim.lsp.get_clients({ bufnr = self.bufnr, method = ms.textDocument_documentHighlight })

  for _, client in ipairs(clients) do
    local params = util.make_position_params(0, client.offset_encoding)

    if sync then
      local response =
        client:request_sync(ms.textDocument_documentHighlight, params, nil, self.bufnr)
      if response == nil then
        return
      end

      self:handler(
        response.err,
        response.result,
        { bufnr = self.bufnr, client_id = client.id, method = ms.textDocument_documentHighlight }
      )
    else
      client:request(ms.textDocument_documentHighlight, params, function(...)
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
    local highlighter = Highlighter.active[bufnr]
    if not highlighter or highlighter.version ~= util.buf_versions[bufnr] then
      return
    end

    api.nvim_buf_clear_namespace(bufnr, namespace, toprow, botrow)

    for _, highlights in pairs(highlighter.client_highlights) do
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

function M.start(bufnr, client_id)
  local highlighter = Highlighter.active[bufnr]

  if not highlighter then
    highlighter = Highlighter.new(bufnr)
  end

  highlighter.client_highlights[client_id] = {}
  highlighter:refresh(client_id)
end

---@class vim.lsp.document_highlight.JumpOpts
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
---@param opts vim.lsp.document_highlight.JumpOpts
function M.jump(opts)
  vim.validate('opts', opts, 'table')
  vim.validate('count', opts.count, 'number')

  local count = opts.count

  local winid = opts.winid or api.nvim_get_current_win()
  local pos = api.nvim_win_get_cursor(winid)
  ---@cast pos [integer, integer]
  pos = { pos[1] - 1, pos[2] }

  local bufnr = api.nvim_win_get_buf(winid)
  local highlighter = Highlighter.active[bufnr]
  if not highlighter then
    return
  end

  if opts.refresh then
    highlighter:refresh(nil, true)
  end

  local _, highlights = next(highlighter.client_highlights)
  if not highlights then
    return
  end

  local i = lower_bound(highlights, pos, 1, #highlights + 1) + count
  if 0 < i and i < #highlights + 1 then
    vim._with({ win = winid }, function()
      -- Save position in the window's jumplist
      vim.cmd("normal! m'")
      vim.api.nvim_win_set_cursor(winid, {
        highlights[i].range['start'].line + 1,
        highlights[i].range['start'].character,
      })
      -- Open folds under the cursor
      vim.cmd('normal! zv')
    end)
  end
end

return M
