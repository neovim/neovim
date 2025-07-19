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
---@field kind 'text' | 'snippet'
---@field value string
---@field filter_text? string
---@field range Range4
---@field command? lsp.Command

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
---
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
---@param item vim.lsp.inline_completion.Item
---@param suffix? string
---@return integer extmark_id
local function set_extmark(bufnr, item, suffix)
  ---@type integer, integer
  local row, col = unpack(item.range)

  local text = item.value
  if item.kind == 'snippet' then
    text = tostring(grammar.parse(text))
  end

  ---@type [string, string][][]
  local lines = {}
  for s in vim.gsplit(text, '\n', { plain = true }) do
    table.insert(lines, { { s, 'ComplHint' } })
  end
  if suffix then
    table.insert(lines[#lines], { suffix, 'ComplHintMore' })
  end

  -- The first line of the text to be inserted
  -- usually contains characters entered by the user,
  -- which should be skipped before displaying the virtual text.
  local virt_text = lines[1]
  local skip =
    lcp(api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]:sub(col + 1), virt_text[1][1])
  virt_text[1][1] = virt_text[1][1]:sub(skip)
  col = col + skip - 1

  local virt_lines = { unpack(lines, 2) }
  return api.nvim_buf_set_extmark(bufnr, namespace, row, col, {
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
      for _, raw in ipairs(result.result.items or result.result) do
        ---@type Range4
        local range
        if raw.range then
          local start_row = raw.range['start'].line
          local start_col = util._get_line_byte_from_position(
            self.bufnr,
            raw.range['start'],
            client.offset_encoding
          )
          local end_row = raw.range['end'].line
          local end_col =
            util._get_line_byte_from_position(self.bufnr, raw.range['end'], client.offset_encoding)
          range = { start_row, start_col, end_row, end_col }
        else
          local row, col = unpack(api.nvim_win_get_cursor(vim.fn.bufwinid(self.bufnr)))
          row = row - 1 -- To 0-based index
          range = { row, col, row, col }
        end

        ---@type vim.lsp.inline_completion.Item
        local item
        local text = raw.insertText
        if type(text) == 'string' then
          item = {
            client_id = client_id,
            range = range,
            kind = 'text',
            value = text,
          }
        else
          item = {
            client_id = client_id,
            range = range,
            kind = 'snippet',
            value = text.value,
          }
        end
        item.filter_text = raw.filterText
        item.command = raw.command
        items[#items + 1] = item
      end
    end
  end

  if #items ~= 0 then
    self.items = items
    self:present(1)
  end
end

--- Set an item as the current one and present it.
---
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
      self.items[index],
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

--- Dismiss the current item.
---
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
  local state = State.active[bufnr]
  if not state then
    state = State:new(bufnr)
    State.active[bufnr] = state
  end
end

---@class vim.lsp.inline_completion.jump.Opts
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
--- Whether to loop around the file or not. Similar to 'wrapscan'.
--- (default: `true`)
---@field wrap? boolean

--- Switch between available inline completion candidates.
---
---@param opts? vim.lsp.inline_completion.jump.Opts
function M.jump(opts)
  vim.validate('opts', opts, 'table', true)
  opts = opts or {}
  local bufnr = vim._resolve_bufnr(opts.bufnr)
  local state = State.active[bufnr]
  if not state then
    return
  end

  local count = opts.count or vim.v.count1
  local wrap = opts.wrap == nil or opts.wrap

  local items = state.items
  local index = state.current.index + count
  index = wrap and (index - 1) % #items + 1 or math.min(math.max(1, index), #items)
  state:present(index, true)
end

---@class vim.lsp.inline_completion.get.Opts
---@inlinedoc
---
--- Buffer handle, or 0 for current.
--- (default: 0)
---@field bufnr? integer

--- Accepts the currently presented inline completion candidate,
--- or requests a new inline completion.
---
---@param opts? vim.lsp.inline_completion.get.Opts
function M.get(opts)
  vim.validate('opts', opts, 'table', true)
  opts = opts or {}

  local bufnr = vim._resolve_bufnr(opts.bufnr)
  local state = State.active[bufnr]
  if not state then
    return
  end

  local current = state.current
  if current then -- Accept the current completion item
    state:dismiss()

    local item = state.items[current.index]
    if item.kind == 'text' then
      local lines = vim.split(item.value, '\n')
      api.nvim_buf_set_text(
        bufnr,
        item.range[1],
        item.range[2],
        item.range[3],
        item.range[4],
        lines
      )
      api.nvim_win_set_cursor(vim.fn.bufwinid(bufnr), {
        item.range[1] + #lines,
        #lines == 1 and item.range[2] or 0 + #lines[#lines],
      })
    else
      vim.snippet.expand(item.value)
    end

    -- Execute the command *after* inserting this completion.
    if item.command then
      local client = assert(vim.lsp.get_client_by_id(item.client_id))
      client:exec_cmd(item.command, { bufnr = bufnr })
    end
  else -- Request new completion items
    ---@type lsp.InlineCompletionContext
    local context = { triggerKind = protocol.InlineCompletionTriggerKind.Invoked }
    state:request(bufnr, context)
  end
end

return M
