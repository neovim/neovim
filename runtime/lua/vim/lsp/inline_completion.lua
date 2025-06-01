local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local grammar = require('vim.lsp._snippet_grammar')
local api = vim.api

local M = {}

---@class vim.lsp.inline_completion.BufState
---@field items lsp.InlineCompletionItem[]
---@field active integer index of currently active completion item
---@field extmark integer id of the currently visible extmark
---@field autocmd integer id of the autocmd

---@type table<integer, vim.lsp.inline_completion.BufState?>
local bufstates = {}

local namespace = api.nvim_create_namespace('nvim.lsp.inline_completion')
local augroup = api.nvim_create_augroup('nvim.lsp.inline_completion', {})

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
  local virt_lines = { select(2, unpack(lines)) }
  local skip =
    lcp(api.nvim_buf_get_lines(bufnr, line, line + 1, true)[1]:sub(col + 1), virt_text[1][1])
  virt_text[1][1] = virt_text[1][1]:sub(skip)
  return api.nvim_buf_set_extmark(bufnr, namespace, line, col + skip - 1, {
    virt_text = virt_text,
    virt_lines = virt_lines,
    virt_text_pos = 'overlay',
  })
end

local function clear(bufnr)
  local bufstate = assert(bufstates[bufnr])
  api.nvim_buf_del_extmark(bufnr, namespace, bufstate.extmark)
  api.nvim_del_autocmd(bufstate.autocmd)
  bufstates[bufnr] = nil
end

---@param results table<integer, { err: lsp.ResponseError?, result: lsp.InlineCompletionItem[]|lsp.InlineCompletionList? }>
---@type lsp.MultiHandler
local function handler(results, ctx)
  local items = {}
  for _, result in pairs(results) do
    if result.err then
      log.error(result.err)
    elseif result.result then
      for _, item in ipairs(result.result.items or result.result) do
        table.insert(items, item)
      end
    end
  end

  if #items == 0 then
    return
  end
  local bufnr = assert(ctx.bufnr)
  bufstates[bufnr] = {
    items = items,
    active = 1,
    extmark = set_extmark(bufnr, items[1]),
    autocmd = api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
      group = augroup,
      buffer = bufnr,
      desc = 'Clean up candidate inline completion items',
      callback = function()
        clear(bufnr)
      end,
    }),
  }
end

---@param bufnr integer
---@param context? lsp.InlineCompletionContext
local function request(bufnr, context)
  context = context or { triggerKind = 2 }

  vim.lsp.buf_request_all(bufnr, ms.textDocument_inlineCompletion, function(client)
    ---@type lsp.InlineCompletionParams
    return {
      context = context,
      textDocument = util.make_text_document_params(bufnr),
      position = util.make_position_params(nil, client.offset_encoding).position,
    }
  end, handler)
end

---@class vim.lsp.inline_completion.JumpOpts
---@inlinedoc
---
---(default: current)
---@field bufnr? integer
---
---(default: 1)
---@field count? integer
---
---(default: true)
---@field wrap? boolean

---@param opts vim.lsp.inline_completion.JumpOpts
function M.jump(opts)
  opts = opts or {}
  local bufnr = vim._resolve_bufnr(opts.bufnr)
  local bufstate = bufstates[bufnr]
  if not bufstate then
    return
  end

  local count = opts.count or 1
  local wrap = opts.wrap or true

  local items = bufstate.items
  local active = bufstate.active + count
  active = wrap and (active - 1) % #items + 1 or math.min(math.max(1, active), #items)
  api.nvim_buf_del_extmark(bufnr, namespace, bufstate.extmark)
  bufstate.extmark = set_extmark(bufnr, items[active], (' (%d/%d)'):format(active, #items))
  bufstate.active = active
end

---@param bufnr? integer
function M.trigger(bufnr)
  bufnr = vim._resolve_bufnr(bufnr)
  local bufstate = bufstates[bufnr]
  if not bufstate then -- Trigger
    ---@type lsp.InlineCompletionContext
    local context = { triggerKind = 1 }
    request(bufnr, context)
  else -- Accept
    local item = bufstate.items[bufstate.active]
    local text = item.insertText
    local range = item.range
    if type(text) ~= 'string' then
      vim.snippet.expand(text.value)
    elseif range then
      util.apply_text_edits({ { newText = text, range = range } }, bufnr, 'utf-16')
    end
    clear(bufnr)
  end
end

---@generic T: function
---@param f T
---@param timeout integer
---@return T
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
local function automatic_request(bufnr)
  request(bufnr, { triggerKind = 2 })
end

---(default: true)
---@param enable? boolean
---
---(default: current)
---@param bufnr? integer
function M.enable(enable, bufnr)
  enable = enable == nil or enable
  bufnr = vim._resolve_bufnr(bufnr)
  local debounced_request = debunce(automatic_request, 100)
  api.nvim_create_autocmd({
    'CursorMovedI',
    'InsertEnter',
    'CompleteChanged',
  }, {
    group = augroup,
    buffer = bufnr,
    desc = 'Schedule inline completion request',
    callback = function()
      debounced_request(bufnr)
    end,
  })
end

return M
