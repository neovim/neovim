--- @brief
--- This module provides the LSP "inline completion" feature, for completing multiline text (e.g.,
--- whole methods) instead of just a word or line, which may result in "syntactically or
--- semantically incorrect" code. Unlike regular completion, this is typically presented as overlay
--- text instead of a menu of completion candidates.
---
--- LSP spec: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocument_inlineCompletion
---
--- To try it out, here is a quickstart example using Copilot: [lsp-copilot]()
---
--- 1. Install Copilot:
---    ```sh
---    npm install --global @github/copilot-language-server
---    ```
--- 2. Define a config, (or copy `lsp/copilot.lua` from https://github.com/neovim/nvim-lspconfig):
---    ```lua
---    vim.lsp.config('copilot', {
---      cmd = { 'copilot-language-server', '--stdio', },
---      root_markers = { '.git' },
---    })
---    ```
--- 3. Activate the config:
---    ```lua
---    vim.lsp.enable('copilot')
---    ```
--- 4. Sign in to Copilot, or use the `:LspCopilotSignIn` command from https://github.com/neovim/nvim-lspconfig
--- 5. Enable inline completion:
---    ```lua
---    vim.lsp.inline_completion.enable()
---    ```
--- 6. Set a keymap for `vim.lsp.inline_completion.get()` and invoke the keymap.

local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local protocol = require('vim.lsp.protocol')
local grammar = require('vim.lsp._snippet_grammar')
local api = vim.api

local Capability = require('vim.lsp._capability')

local M = {}

local namespace = api.nvim_create_namespace('nvim.lsp.inline_completion')

---@class vim.lsp.inline_completion.Item
---@field _index integer The index among all items form all clients.
---@field client_id integer Client ID
---@field insert_text string|lsp.StringValue The text to be inserted, can be a snippet.
---@field _filter_text? string
---@field range? vim.Range Which range it be applied.
---@field command? lsp.Command Corresponding server command.

---@class (private) vim.lsp.inline_completion.ClientState
---@field items? lsp.InlineCompletionItem[]

---@class (private) vim.lsp.inline_completion.Completor : vim.lsp.Capability
---@field active table<integer, vim.lsp.inline_completion.Completor?>
---@field timer? uv.uv_timer_t Timer for debouncing automatic requests
---@field current? vim.lsp.inline_completion.Item Currently selected item
---@field client_state table<integer, vim.lsp.inline_completion.ClientState>
local Completor = {
  name = 'inline_completion',
  method = 'textDocument/inlineCompletion',
  active = {},
}
Completor.__index = Completor
setmetatable(Completor, Capability)
Capability.all[Completor.name] = Completor

---@package
---@param bufnr integer
---@return vim.lsp.inline_completion.Completor
function Completor:new(bufnr)
  self = Capability.new(self, bufnr)
  self.client_state = {}
  api.nvim_create_autocmd({ 'InsertEnter', 'CursorMovedI', 'TextChangedP' }, {
    group = self.augroup,
    buffer = bufnr,
    callback = function()
      self:automatic_request()
    end,
  })
  api.nvim_create_autocmd({ 'InsertLeave' }, {
    group = self.augroup,
    buffer = bufnr,
    callback = function()
      self:abort()
    end,
  })
  return self
end

---@package
function Completor:destroy()
  api.nvim_buf_clear_namespace(self.bufnr, namespace, 0, -1)
  api.nvim_del_augroup_by_id(self.augroup)
  self.active[self.bufnr] = nil
end

--- Longest common prefix
---
---@param a string
---@param b string
---@return integer index where the common prefix ends, exclusive
local function lcp(a, b)
  local i, la, lb = 1, #a, #b
  while i <= la and i <= lb and a:sub(i, i) == b:sub(i, i) do
    i = i + 1
  end
  return i
end

--- `lsp.Handler` for `textDocument/inlineCompletion`.
---
---@package
---@param err? lsp.ResponseError
---@param result? lsp.InlineCompletionItem[]|lsp.InlineCompletionList
---@param ctx lsp.HandlerContext
function Completor:handler(err, result, ctx)
  if err then
    log.error('inlinecompletion', err)
    return
  end
  if not result or not vim.startswith(api.nvim_get_mode().mode, 'i') then
    return
  end

  local items = result.items or result
  self.client_state[ctx.client_id].items = items
  self:select(1)
end

---@package
function Completor:count_items()
  local n = 0
  for _, state in pairs(self.client_state) do
    local items = state.items
    if items then
      n = n + #items
    end
  end
  return n
end

---@package
---@param i integer
---@return integer?, lsp.InlineCompletionItem?
function Completor:get_item(i)
  local n = self:count_items()
  i = i % (n + 1)
  ---@type integer[]
  local client_ids = vim.tbl_keys(self.client_state)
  table.sort(client_ids)
  for _, client_id in ipairs(client_ids) do
    local items = self.client_state[client_id].items
    if items then
      if i > #items then
        i = i - #items
      else
        return client_id, items[i]
      end
    end
  end
end

--- Select the {index}-th completion item.
---
---@package
---@param index integer
---@param show_index? boolean
function Completor:select(index, show_index)
  self.current = nil
  local client_id, item = self:get_item(index)
  if not client_id or not item then
    self:hide()
    return
  end

  local client = assert(vim.lsp.get_client_by_id(client_id))
  local range = item.range and vim.range.lsp(self.bufnr, item.range, client.offset_encoding)
  self.current = {
    _index = index,
    client_id = client_id,
    insert_text = item.insertText,
    range = range,
    _filter_text = item.filterText,
    command = item.command,
  }

  local hint = show_index and (' (%d/%d)'):format(index, self:count_items()) or nil
  self:show(hint)
end

--- Show or update the current completion item.
---
---@package
---@param hint? string
function Completor:show(hint)
  self:hide()
  local current = self.current
  if not current then
    return
  end

  local insert_text = current.insert_text
  local text = type(insert_text) == 'string' and insert_text
    or tostring(grammar.parse(insert_text.value))
  local lines = {} ---@type [string, string][][]
  for s in vim.gsplit(text, '\n', { plain = true }) do
    table.insert(lines, { { s, 'ComplHint' } })
  end
  if hint then
    table.insert(lines[#lines], { hint, 'ComplHintMore' })
  end

  local pos = current.range and current.range.start:to_extmark()
    or vim.pos.cursor(api.nvim_win_get_cursor(vim.fn.bufwinid(self.bufnr))):to_extmark()
  local row, col = unpack(pos)

  -- To ensure that virtual text remains visible continuously (without flickering)
  -- while the user is editing the buffer, we allow displaying expired virtual text.
  -- Since the position of virtual text may become invalid after document changes,
  -- out-of-range items are ignored.
  local line_text = api.nvim_buf_get_lines(self.bufnr, row, row + 1, false)[1]
  if not (line_text and #line_text >= col) then
    self.current = nil
    return
  end

  -- The first line of the text to be inserted
  -- usually contains characters entered by the user,
  -- which should be skipped before displaying the virtual text.
  local virt_text = lines[1]
  local skip = lcp(line_text:sub(col + 1), virt_text[1][1])
  local winid = api.nvim_get_current_win()
  -- At least, characters before the cursor should be skipped.
  if api.nvim_win_get_buf(winid) == self.bufnr then
    local cursor_row, cursor_col =
      unpack(vim.pos.cursor(api.nvim_win_get_cursor(winid)):to_extmark())
    if row == cursor_row then
      skip = math.max(skip, cursor_col - col + 1)
    end
  end
  virt_text[1][1] = virt_text[1][1]:sub(skip)
  col = col + skip - 1

  local virt_lines = { unpack(lines, 2) }
  api.nvim_buf_set_extmark(self.bufnr, namespace, row, col, {
    virt_text = virt_text,
    virt_lines = virt_lines,
    virt_text_pos = (current.range and not current.range:is_empty() and 'overlay') or 'inline',
    hl_mode = 'combine',
  })
end

--- Hide the current completion item.
---
---@package
function Completor:hide()
  api.nvim_buf_clear_namespace(self.bufnr, namespace, 0, -1)
end

---@package
---@param kind lsp.InlineCompletionTriggerKind
function Completor:request(kind)
  for client_id in pairs(self.client_state) do
    local client = assert(vim.lsp.get_client_by_id(client_id))
    ---@type lsp.InlineCompletionContext
    local context = { triggerKind = kind }
    if
      kind == protocol.InlineCompletionTriggerKind.Invoked and api.nvim_get_mode().mode:match('^v')
    then
      context.selectedCompletionInfo = {
        range = util.make_given_range_params(nil, nil, self.bufnr, client.offset_encoding).range,
        text = table.concat(vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>")), '\n'),
      }
    end

    ---@type lsp.InlineCompletionParams
    local params = {
      textDocument = util.make_text_document_params(self.bufnr),
      position = util.make_position_params(0, client.offset_encoding).position,
      context = context,
    }
    client:request('textDocument/inlineCompletion', params, function(...)
      self:handler(...)
    end, self.bufnr)
  end
end

---@private
function Completor:reset_timer()
  local timer = self.timer
  if timer then
    self.timer = nil
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
end

--- Automatically request with debouncing, used as callbacks in autocmd events.
---
---@package
function Completor:automatic_request()
  self:show()
  self:reset_timer()
  self.timer = vim.defer_fn(function()
    self:request(protocol.InlineCompletionTriggerKind.Automatic)
  end, 200)
end

--- Abort the current completion item and pending requests.
---
---@package
function Completor:abort()
  util._cancel_requests({
    bufnr = self.bufnr,
    method = 'textDocument/inlineCompletion',
    type = 'pending',
  })
  self:reset_timer()
  self:hide()
  self.current = nil
end

--- Accept the current completion item to the buffer.
---
---@package
---@param item vim.lsp.inline_completion.Item
function Completor:accept(item)
  local insert_text = item.insert_text
  if type(insert_text) == 'string' then
    local range = item.range
    if range then
      local lines = vim.split(insert_text, '\n')
      api.nvim_buf_set_text(
        self.bufnr,
        range.start.row,
        range.start.col,
        range.end_.row,
        range.end_.col,
        lines
      )
      local pos = item.range.start:to_cursor()
      local win = api.nvim_get_current_win()
      win = api.nvim_win_get_buf(win) == self.bufnr and win or vim.fn.bufwinid(self.bufnr)
      api.nvim_win_set_cursor(win, {
        pos[1] + #lines - 1,
        (#lines == 1 and pos[2] or 0) + #lines[#lines],
      })
    else
      api.nvim_paste(insert_text, false, 0)
    end
  elseif insert_text.kind == 'snippet' then
    vim.snippet.expand(insert_text.value)
  end

  -- Execute the command *after* inserting this completion.
  if item.command then
    local client = assert(vim.lsp.get_client_by_id(item.client_id))
    client:exec_cmd(item.command, { bufnr = self.bufnr })
  end
end

--- Query whether inline completion is enabled in the {filter}ed scope
---@param filter? vim.lsp.capability.enable.Filter
function M.is_enabled(filter)
  return vim.lsp._capability.is_enabled('inline_completion', filter)
end

--- Enables or disables inline completion for the {filter}ed scope,
--- inline completion will automatically be refreshed when you are in insert mode.
---
--- To "toggle", pass the inverse of `is_enabled()`:
---
--- ```lua
--- vim.lsp.inline_completion.enable(not vim.lsp.inline_completion.is_enabled())
--- ```
---
---@param enable? boolean true/nil to enable, false to disable
---@param filter? vim.lsp.capability.enable.Filter
function M.enable(enable, filter)
  vim.lsp._capability.enable('inline_completion', enable, filter)
end

---@class vim.lsp.inline_completion.select.Opts
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

--- Switch between available inline completion candidates.
---
---@param opts? vim.lsp.inline_completion.select.Opts
function M.select(opts)
  vim.validate('opts', opts, 'table', true)
  opts = opts or {}
  local bufnr = vim._resolve_bufnr(opts.bufnr)
  local completor = Completor.active[bufnr]
  if not completor then
    return
  end

  local count = opts.count or vim.v.count1
  local wrap = opts.wrap ~= false

  local current = completor.current
  if not current then
    return
  end

  local n = completor:count_items()
  local index = current._index + count
  if wrap then
    index = (index - 1) % n + 1
  else
    index = math.max(1, math.min(index, n))
  end
  completor:select(index, true)
end

---@class vim.lsp.inline_completion.get.Opts
---@inlinedoc
---
--- Buffer handle, or 0 for current.
--- (default: 0)
---@field bufnr? integer
---
--- Accept handler, called with the accepted item.
--- If not provided, the default handler is used,
--- which applies changes to the buffer based on the completion item.
---@field on_accept? fun(item: vim.lsp.inline_completion.Item)

--- Accept the currently displayed completion candidate to the buffer.
---
--- It returns false when no candidate can be accepted,
--- so you can use the return value to implement a fallback:
---
--- ```lua
---  vim.keymap.set('i', '<Tab>', function()
---   if not vim.lsp.inline_completion.get() then
---     return '<Tab>'
---   end
--- end, { expr = true, desc = 'Accept the current inline completion' })
--- ````
---@param opts? vim.lsp.inline_completion.get.Opts
---@return boolean `true` if a completion was applied, else `false`.
function M.get(opts)
  vim.validate('opts', opts, 'table', true)
  opts = opts or {}

  local bufnr = vim._resolve_bufnr(opts.bufnr)
  local on_accept = opts.on_accept

  local completor = Completor.active[bufnr]
  if completor and completor.current then
    -- Schedule apply to allow `get()` can be mapped with `<expr>`.
    vim.schedule(function()
      local item = completor.current
      completor:abort()
      if not item then
        return
      end

      if on_accept then
        on_accept(item)
      else
        completor:accept(item)
      end
    end)
    return true
  end

  return false
end

return M
