local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local protocol = require('vim.lsp.protocol')
local ms = require('vim.lsp.protocol').Methods
local grammar = require('vim.lsp._snippet_grammar')
local api = vim.api

local Capability = require('vim.lsp._capability')

local M = {}

---@class (private) vim.lsp.inline_completion.CurrentItem
---@field index integer
---@field extmark integer
---@field autocmd integer

---@class (private) vim.lsp.inline_completion.Item
---@field client_id integer
---@field item lsp.InlineCompletionItem

---@class (private) vim.lsp.inline_completion.State : vim.lsp.Capability
---@field active table<integer, vim.lsp.inline_completion.State?>
---@field items vim.lsp.inline_completion.Item[]
---@field current? vim.lsp.inline_completion.CurrentItem
local State = { name = 'inline_completion', active = {} }
State.__index = State
setmetatable(State, Capability)

---@package
---@param bufnr integer
---@return vim.lsp.inline_completion.State
function State:new(bufnr)
  return Capability.new(self, bufnr)
end

local namespace = api.nvim_create_namespace('nvim.lsp.inline_completion')

--- Longest common prefix
---@param a string
---@param b string
---@return integer index where the common prefix ends, exclusive
local function lcp(a, b)
  local i = 1
  while a:sub(i, i) == b:sub(i, i) do
    i = i + 1
  end
  return i
end

---@param bufnr integer
---@param item lsp.InlineCompletionItem
---@param suffix? string
local function set_extmark(bufnr, item, suffix)
  ---@type integer, integer
  local line, col

  if item.range then
    line = item.range['start'].line
    col = item.range['start'].character
  else
    local winid = vim.fn.bufwinid(bufnr)
    local pos = api.nvim_win_get_cursor(winid)
    line = pos[1] - 1
    col = pos[2]
  end

  local text = item.insertText
  if type(text) ~= 'string' then
    text = tostring(grammar.parse(text.value))
  end

  ---@type [string, string][][]
  local lines = {}
  for s in vim.gsplit(text, '\n') do
    table.insert(lines, { { s, 'LspInlineCompletion' } })
  end
  if suffix then
    table.insert(lines[#lines], { suffix, 'LspInlineCompletionSuffix' })
  end

  local virt_text = lines[1]
  local virt_lines = { unpack(lines, 2) }
  local skip =
    lcp(api.nvim_buf_get_lines(bufnr, line, line + 1, true)[1]:sub(col + 1), virt_text[1][1])
  virt_text[1][1] = virt_text[1][1]:sub(skip)
  return api.nvim_buf_set_extmark(bufnr, namespace, line, col + skip - 1, {
    virt_text = virt_text,
    virt_lines = virt_lines,
    virt_text_pos = 'overlay',
  })
end

---@package
---@param results table<integer, { err: lsp.ResponseError?, result: lsp.InlineCompletionItem[]|lsp.InlineCompletionList? }>
function State:handler(results)
  ---@type vim.lsp.inline_completion.Item[]
  local items = {}

  for client_id, result in pairs(results) do
    local client = assert(vim.lsp.get_client_by_id(client_id))
    if result.err then
      log.error(result.err)
    elseif result.result then
      for _, item in ipairs(result.result.items or result.result) do
        item.range['start'].character =
          util._get_line_byte_from_position(self.bufnr, item.range['start'], client.offset_encoding)
        item.range['end'].character =
          util._get_line_byte_from_position(self.bufnr, item.range['end'], client.offset_encoding)
        table.insert(items, { client_id = client_id, item = item })
      end
    end
  end

  if #items ~= 0 then
    self.items = items
    self:present(1)
  end
end

---@package
---@param index integer
---@param show_index? boolean
function State:present(index, show_index)
  if self.current then
    self:dismiss()
  end
  self.current = {
    index = index,
    extmark = set_extmark(
      self.bufnr,
      self.items[index].item,
      show_index and (' (%d/%d)'):format(index, #self.items) or nil
    ),
    autocmd = api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
      buffer = self.bufnr,
      desc = 'Clean up candidate inline completion items',
      callback = function()
        self:dismiss()
      end,
    }),
  }
end

---@package
function State:dismiss()
  local current = assert(self.current)
  api.nvim_buf_del_extmark(self.bufnr, namespace, current.extmark)
  api.nvim_del_autocmd(current.autocmd)
  self.current = nil
end

---@package
---@param bufnr integer
---@param context? lsp.InlineCompletionContext
function State:request(bufnr, context)
  context = context or {
    triggerKind = protocol.InlineCompletionTriggerKind.Automatic,
  }

  vim.lsp.buf_request_all(bufnr, ms.textDocument_inlineCompletion, function(client)
    local params = util.make_position_params(nil, client.offset_encoding)
    ---@cast params lsp.InlineCompletionParams
    params.context = context
    return params
  end, function(...)
    self:handler(...)
  end)
end

---@param bufnr integer
function M._start(bufnr)
  local completor = State.active[bufnr]
  if not completor then
    completor = State:new(bufnr)
    State.active[bufnr] = completor
  end
end

---@class vim.lsp.inline_completion.JumpOpts
---@inlinedoc
---
--- (default: current buffer)
---@field bufnr? integer
---
--- The number of candidates to move by.
--- A positive integer moves forward by {count} candidates,
--- while a negative integer moves backward by {count} candidates.
--- (default: v:count1)
---@field count? integer
---
--- Whether to loop around file or not. Similar to 'wrapscan'.
--- (default: `true`)
---@field wrap? boolean

--- Jumps to another inline completion candidate.
---@param opts? vim.lsp.inline_completion.JumpOpts
function M.jump(opts)
  opts = opts or {}
  local bufnr = vim._resolve_bufnr(opts.bufnr)
  local completor = State.active[bufnr]
  if not completor then
    return
  end

  local count = opts.count or vim.v.count1
  local wrap = opts.wrap == nil or opts.wrap

  local items = completor.items
  local index = completor.current.index + count
  index = wrap and (index - 1) % #items + 1 or math.min(math.max(1, index), #items)
  completor:present(index, true)
end

--- Accepts the currently presented inline completion candidate,
--- or requests a new inline completion.
---@param bufnr? integer
function M.accept(bufnr)
  bufnr = vim._resolve_bufnr(bufnr)
  local completor = State.active[bufnr]
  if not completor then
    return
  end

  local current = completor.current
  if current then
    completor:dismiss()
    local item = completor.items[current.index]
    local text = item.item.insertText
    local range = item.item.range
    if range and type(text) == 'string' then
      local lines = vim.split(text, '\n')
      api.nvim_buf_set_text(
        bufnr,
        range['start'].line,
        range['start'].character,
        range['end'].line,
        range['end'].character,
        lines
      )
      api.nvim_win_set_cursor(vim.fn.bufwinid(bufnr), {
        range['start'].line + #lines,
        #lines == 1 and range['start'].character or 0 + #lines[#lines],
      })
      local client = assert(vim.lsp.get_client_by_id(item.client_id))
      client:exec_cmd(item.item.command, { bufnr = bufnr })
    else
      vim.snippet.expand(text.value)
    end
  else
    ---@type lsp.InlineCompletionContext
    local context = { triggerKind = protocol.InlineCompletionTriggerKind.Invoked }
    completor:request(bufnr, context)
  end
end

return M
