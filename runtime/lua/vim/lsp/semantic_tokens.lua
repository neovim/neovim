local api = vim.api
local handlers = require('vim.lsp.handlers')
local util = require('vim.lsp.util')

--- @class STTokenRange
--- @field line number line number 0-based
--- @field start_col number start column 0-based
--- @field end_col number end column 0-based
--- @field type string token type as string
--- @field modifiers string[] token modifiers as strings
--- @field extmark_added boolean whether this extmark has been added to the buffer yet
---
--- @class STCurrentResult
--- @field version number document version associated with this result
--- @field result_id string resultId from the server; used with delta requests
--- @field highlights STTokenRange[] cache of highlight ranges for this document version
--- @field tokens number[] raw token array as received by the server. used for calculating delta responses
--- @field namespace_cleared boolean whether the namespace was cleared for this result yet
---
--- @class STActiveRequest
--- @field request_id number the LSP request ID of the most recent request sent to the server
--- @field version number the document version associated with the most recent request
---
--- @class STClientState
--- @field namespace number
--- @field active_request STActiveRequest
--- @field current_result STCurrentResult

---@class STHighlighter
---@field active table<number, STHighlighter>
---@field bufnr number
---@field augroup number augroup for buffer events
---@field debounce number milliseconds to debounce requests for new tokens
---@field timer table uv_timer for debouncing requests for new tokens
---@field client_state table<number, STClientState>
local STHighlighter = { active = {} }

---@private
local function binary_search(tokens, line)
  local lo = 1
  local hi = #tokens
  while lo < hi do
    local mid = math.floor((lo + hi) / 2)
    if tokens[mid].line < line then
      lo = mid + 1
    else
      hi = mid
    end
  end
  return lo
end

--- Extracts modifier strings from the encoded number in the token array
---
---@private
---@return string[]
local function modifiers_from_number(x, modifiers_table)
  local modifiers = {}
  local idx = 1
  while x > 0 do
    if _G.bit then
      if _G.bit.band(x, 1) == 1 then
        modifiers[#modifiers + 1] = modifiers_table[idx]
      end
      x = _G.bit.rshift(x, 1)
    else
      --TODO(jdrouhard): remove this branch once `bit` module is available for non-LuaJIT (#21222)
      if x % 2 == 1 then
        modifiers[#modifiers + 1] = modifiers_table[idx]
      end
      x = math.floor(x / 2)
    end
    idx = idx + 1
  end

  return modifiers
end

--- Converts a raw token list to a list of highlight ranges used by the on_win callback
---
---@private
---@return STTokenRange[]
local function tokens_to_ranges(data, bufnr, client)
  local legend = client.server_capabilities.semanticTokensProvider.legend
  local token_types = legend.tokenTypes
  local token_modifiers = legend.tokenModifiers
  local ranges = {}

  local line
  local start_char = 0
  for i = 1, #data, 5 do
    local delta_line = data[i]
    line = line and line + delta_line or delta_line
    local delta_start = data[i + 1]
    start_char = delta_line == 0 and start_char + delta_start or delta_start

    -- data[i+3] +1 because Lua tables are 1-indexed
    local token_type = token_types[data[i + 3] + 1]
    local modifiers = modifiers_from_number(data[i + 4], token_modifiers)

    ---@private
    local function _get_byte_pos(char_pos)
      return util._get_line_byte_from_position(bufnr, {
        line = line,
        character = char_pos,
      }, client.offset_encoding)
    end

    local start_col = _get_byte_pos(start_char)
    local end_col = _get_byte_pos(start_char + data[i + 2])

    if token_type then
      ranges[#ranges + 1] = {
        line = line,
        start_col = start_col,
        end_col = end_col,
        type = token_type,
        modifiers = modifiers,
        extmark_added = false,
      }
    end
  end

  return ranges
end

--- Construct a new STHighlighter for the buffer
---
---@private
---@param bufnr number
function STHighlighter.new(bufnr)
  local self = setmetatable({}, { __index = STHighlighter })

  self.bufnr = bufnr
  self.augroup = api.nvim_create_augroup('vim_lsp_semantic_tokens:' .. bufnr, { clear = true })
  self.client_state = {}

  STHighlighter.active[bufnr] = self

  api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf)
      local highlighter = STHighlighter.active[buf]
      if not highlighter then
        return true
      end
      highlighter:on_change()
    end,
    on_reload = function(_, buf)
      local highlighter = STHighlighter.active[buf]
      if highlighter then
        highlighter:reset()
        highlighter:send_request()
      end
    end,
    on_detach = function(_, buf)
      local highlighter = STHighlighter.active[buf]
      if highlighter then
        highlighter:destroy()
      end
    end,
  })

  api.nvim_create_autocmd({ 'BufWinEnter', 'InsertLeave' }, {
    buffer = self.bufnr,
    group = self.augroup,
    callback = function()
      self:send_request()
    end,
  })

  api.nvim_create_autocmd('LspDetach', {
    buffer = self.bufnr,
    group = self.augroup,
    callback = function(args)
      self:detach(args.data.client_id)
      if vim.tbl_isempty(self.client_state) then
        self:destroy()
      end
    end,
  })

  return self
end

---@private
function STHighlighter:destroy()
  for client_id, _ in pairs(self.client_state) do
    self:detach(client_id)
  end

  api.nvim_del_augroup_by_id(self.augroup)
  STHighlighter.active[self.bufnr] = nil
end

---@private
function STHighlighter:attach(client_id)
  local state = self.client_state[client_id]
  if not state then
    state = {
      namespace = api.nvim_create_namespace('vim_lsp_semantic_tokens:' .. client_id),
      active_request = {},
      current_result = {},
    }
    self.client_state[client_id] = state
  end
end

---@private
function STHighlighter:detach(client_id)
  local state = self.client_state[client_id]
  if state then
    --TODO: delete namespace if/when that becomes possible
    api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
    self.client_state[client_id] = nil
  end
end

--- This is the entry point for getting all the tokens in a buffer.
---
--- For the given clients (or all attached, if not provided), this sends a request
--- to ask for semantic tokens. If the server supports delta requests, that will
--- be prioritized if we have a previous requestId and token array.
---
--- This function will skip servers where there is an already an active request in
--- flight for the same version. If there is a stale request in flight, that is
--- cancelled prior to sending a new one.
---
--- Finally, if the request was successful, the requestId and document version
--- are saved to facilitate document synchronization in the response.
---
---@private
function STHighlighter:send_request()
  local version = util.buf_versions[self.bufnr]

  self:reset_timer()

  for client_id, state in pairs(self.client_state) do
    local client = vim.lsp.get_client_by_id(client_id)

    local current_result = state.current_result
    local active_request = state.active_request

    -- Only send a request for this client if the current result is out of date and
    -- there isn't a current a request in flight for this version
    if client and current_result.version ~= version and active_request.version ~= version then
      -- cancel stale in-flight request
      if active_request.request_id then
        client.cancel_request(active_request.request_id)
        active_request = {}
        state.active_request = active_request
      end

      local spec = client.server_capabilities.semanticTokensProvider.full
      local hasEditProvider = type(spec) == 'table' and spec.delta

      local params = { textDocument = util.make_text_document_params(self.bufnr) }
      local method = 'textDocument/semanticTokens/full'

      if hasEditProvider and current_result.result_id then
        method = method .. '/delta'
        params.previousResultId = current_result.result_id
      end
      local success, request_id = client.request(method, params, function(err, response, ctx)
        -- look client up again using ctx.client_id instead of using a captured
        -- client object
        local c = vim.lsp.get_client_by_id(ctx.client_id)
        local highlighter = STHighlighter.active[ctx.bufnr]
        if not err and c and highlighter then
          highlighter:process_response(response, c, version)
        end
      end, self.bufnr)

      if success then
        active_request.request_id = request_id
        active_request.version = version
      end
    end
  end
end

--- This function will parse the semantic token responses and set up the cache
--- (current_result). It also performs document synchronization by checking the
--- version of the document associated with the resulting request_id and only
--- performing work if the response is not out-of-date.
---
--- Delta edits are applied if necessary, and new highlight ranges are calculated
--- and stored in the buffer state.
---
--- Finally, a redraw command is issued to force nvim to redraw the screen to
--- pick up changed highlight tokens.
---
---@private
function STHighlighter:process_response(response, client, version)
  local state = self.client_state[client.id]
  if not state then
    return
  end

  -- ignore stale responses
  if state.active_request.version and version ~= state.active_request.version then
    return
  end

  -- reset active request
  state.active_request = {}

  -- skip nil responses
  if response == nil then
    return
  end

  -- if we have a response to a delta request, update the state of our tokens
  -- appropriately. if it's a full response, just use that
  local tokens
  local token_edits = response.edits
  if token_edits then
    table.sort(token_edits, function(a, b)
      return a.start < b.start
    end)

    tokens = {}
    local old_tokens = state.current_result.tokens
    local idx = 1
    for _, token_edit in ipairs(token_edits) do
      vim.list_extend(tokens, old_tokens, idx, token_edit.start)
      if token_edit.data then
        vim.list_extend(tokens, token_edit.data)
      end
      idx = token_edit.start + token_edit.deleteCount + 1
    end
    vim.list_extend(tokens, old_tokens, idx)
  else
    tokens = response.data
  end

  -- Update the state with the new results
  local current_result = state.current_result
  current_result.version = version
  current_result.result_id = response.resultId
  current_result.tokens = tokens
  current_result.highlights = tokens_to_ranges(tokens, self.bufnr, client)
  current_result.namespace_cleared = false

  api.nvim_command('redraw!')
end

--- on_win handler for the decoration provider (see |nvim_set_decoration_provider|)
---
--- If there is a current result for the buffer and the version matches the
--- current document version, then the tokens are valid and can be applied. As
--- the buffer is drawn, this function will add extmark highlights for every
--- token in the range of visible lines. Once a highlight has been added, it
--- sticks around until the document changes and there's a new set of matching
--- highlight tokens available.
---
--- If this is the first time a buffer is being drawn with a new set of
--- highlights for the current document version, the namespace is cleared to
--- remove extmarks from the last version. It's done here instead of the response
--- handler to avoid the "blink" that occurs due to the timing between the
--- response handler and the actual redraw.
---
---@private
function STHighlighter:on_win(topline, botline)
  for _, state in pairs(self.client_state) do
    local current_result = state.current_result
    if current_result.version and current_result.version == util.buf_versions[self.bufnr] then
      if not current_result.namespace_cleared then
        api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
        current_result.namespace_cleared = true
      end

      -- We can't use ephemeral extmarks because the buffer updates are not in
      -- sync with the list of semantic tokens. There's a delay between the
      -- buffer changing and when the LSP server can respond with updated
      -- tokens, and we don't want to "blink" the token highlights while
      -- updates are in flight, and we don't want to use stale tokens because
      -- they likely won't line up right with the actual buffer.
      --
      -- Instead, we have to use normal extmarks that can attach to locations
      -- in the buffer and are persisted between redraws.
      local highlights = current_result.highlights
      local idx = binary_search(highlights, topline)

      for i = idx, #highlights do
        local token = highlights[i]

        if token.line > botline then
          break
        end

        if not token.extmark_added then
          -- `strict = false` is necessary here for the 1% of cases where the
          -- current result doesn't actually match the buffer contents. Some
          -- LSP servers can respond with stale tokens on requests if they are
          -- still processing changes from a didChange notification.
          --
          -- LSP servers that do this _should_ follow up known stale responses
          -- with a refresh notification once they've finished processing the
          -- didChange notification, which would re-synchronize the tokens from
          -- our end.
          --
          -- The server I know of that does this is clangd when the preamble of
          -- a file changes and the token request is processed with a stale
          -- preamble while the new one is still being built. Once the preamble
          -- finishes, clangd sends a refresh request which lets the client
          -- re-synchronize the tokens.
          api.nvim_buf_set_extmark(self.bufnr, state.namespace, token.line, token.start_col, {
            hl_group = '@' .. token.type,
            end_col = token.end_col,
            priority = vim.highlight.priorities.semantic_tokens,
            strict = false,
          })

          -- TODO(bfredl) use single extmark when hl_group supports table
          if #token.modifiers > 0 then
            for _, modifier in pairs(token.modifiers) do
              api.nvim_buf_set_extmark(self.bufnr, state.namespace, token.line, token.start_col, {
                hl_group = '@' .. modifier,
                end_col = token.end_col,
                priority = vim.highlight.priorities.semantic_tokens + 1,
                strict = false,
              })
            end
          end

          token.extmark_added = true
        end
      end
    end
  end
end

--- Reset the buffer's highlighting state and clears the extmark highlights.
---
---@private
function STHighlighter:reset()
  for client_id, state in pairs(self.client_state) do
    api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
    state.current_result = {}
    if state.active_request.request_id then
      local client = vim.lsp.get_client_by_id(client_id)
      assert(client)
      client.cancel_request(state.active_request.request_id)
      state.active_request = {}
    end
  end
end

--- Mark a client's results as dirty. This method will cancel any active
--- requests to the server and pause new highlights from being added
--- in the on_win callback. The rest of the current results are saved
--- in case the server supports delta requests.
---
---@private
---@param client_id number
function STHighlighter:mark_dirty(client_id)
  local state = self.client_state[client_id]
  assert(state)

  -- if we clear the version from current_result, it'll cause the
  -- next request to be sent and will also pause new highlights
  -- from being added in on_win until a new result comes from
  -- the server
  if state.current_result then
    state.current_result.version = nil
  end

  if state.active_request.request_id then
    local client = vim.lsp.get_client_by_id(client_id)
    assert(client)
    client.cancel_request(state.active_request.request_id)
    state.active_request = {}
  end
end

---@private
function STHighlighter:on_change()
  self:reset_timer()
  if self.debounce > 0 then
    self.timer = vim.defer_fn(function()
      self:send_request()
    end, self.debounce)
  else
    self:send_request()
  end
end

---@private
function STHighlighter:reset_timer()
  local timer = self.timer
  if timer then
    self.timer = nil
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
end

local M = {}

--- Start the semantic token highlighting engine for the given buffer with the
--- given client. The client must already be attached to the buffer.
---
--- NOTE: This is currently called automatically by |vim.lsp.buf_attach_client()|. To
--- opt-out of semantic highlighting with a server that supports it, you can
--- delete the semanticTokensProvider table from the {server_capabilities} of
--- your client in your |LspAttach| callback or your configuration's
--- `on_attach` callback:
--- <pre>lua
---   client.server_capabilities.semanticTokensProvider = nil
--- </pre>
---
---@param bufnr number
---@param client_id number
---@param opts (nil|table) Optional keyword arguments
---  - debounce (number, default: 200): Debounce token requests
---        to the server by the given number in milliseconds
function M.start(bufnr, client_id, opts)
  vim.validate({
    bufnr = { bufnr, 'n', false },
    client_id = { client_id, 'n', false },
  })

  opts = opts or {}
  assert(
    (not opts.debounce or type(opts.debounce) == 'number'),
    'opts.debounce must be a number with the debounce time in milliseconds'
  )

  local client = vim.lsp.get_client_by_id(client_id)
  if not client then
    vim.notify('[LSP] No client with id ' .. client_id, vim.log.levels.ERROR)
    return
  end

  if not vim.lsp.buf_is_attached(bufnr, client_id) then
    vim.notify(
      '[LSP] Client with id ' .. client_id .. ' not attached to buffer ' .. bufnr,
      vim.log.levels.WARN
    )
    return
  end

  if not vim.tbl_get(client.server_capabilities, 'semanticTokensProvider', 'full') then
    vim.notify('[LSP] Server does not support semantic tokens', vim.log.levels.WARN)
    return
  end

  local highlighter = STHighlighter.active[bufnr]

  if not highlighter then
    highlighter = STHighlighter.new(bufnr)
    highlighter.debounce = opts.debounce or 200
  else
    highlighter.debounce = math.max(highlighter.debounce, opts.debounce or 200)
  end

  highlighter:attach(client_id)
  highlighter:send_request()
end

--- Stop the semantic token highlighting engine for the given buffer with the
--- given client.
---
--- NOTE: This is automatically called by a |LspDetach| autocmd that is set up as part
--- of `start()`, so you should only need this function to manually disengage the semantic
--- token engine without fully detaching the LSP client from the buffer.
---
---@param bufnr number
---@param client_id number
function M.stop(bufnr, client_id)
  vim.validate({
    bufnr = { bufnr, 'n', false },
    client_id = { client_id, 'n', false },
  })

  local highlighter = STHighlighter.active[bufnr]
  if not highlighter then
    return
  end

  highlighter:detach(client_id)

  if vim.tbl_isempty(highlighter.client_state) then
    highlighter:destroy()
  end
end

--- Return the semantic token(s) at the given position.
--- If called without arguments, returns the token under the cursor.
---
---@param bufnr number|nil Buffer number (0 for current buffer, default)
---@param row number|nil Position row (default cursor position)
---@param col number|nil Position column (default cursor position)
---
---@return table|nil (table|nil) List of tokens at position
function M.get_at_pos(bufnr, row, col)
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end

  local highlighter = STHighlighter.active[bufnr]
  if not highlighter then
    return
  end

  if row == nil or col == nil then
    local cursor = api.nvim_win_get_cursor(0)
    row, col = cursor[1] - 1, cursor[2]
  end

  local tokens = {}
  for client_id, client in pairs(highlighter.client_state) do
    local highlights = client.current_result.highlights
    if highlights then
      local idx = binary_search(highlights, row)
      for i = idx, #highlights do
        local token = highlights[i]

        if token.line > row then
          break
        end

        if token.start_col <= col and token.end_col > col then
          token.client_id = client_id
          tokens[#tokens + 1] = token
        end
      end
    end
  end
  return tokens
end

--- Force a refresh of all semantic tokens
---
--- Only has an effect if the buffer is currently active for semantic token
--- highlighting (|vim.lsp.semantic_tokens.start()| has been called for it)
---
---@param bufnr (nil|number) default: current buffer
function M.force_refresh(bufnr)
  vim.validate({
    bufnr = { bufnr, 'n', true },
  })

  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end

  local highlighter = STHighlighter.active[bufnr]
  if not highlighter then
    return
  end

  highlighter:reset()
  highlighter:send_request()
end

--- |lsp-handler| for the method `workspace/semanticTokens/refresh`
---
--- Refresh requests are sent by the server to indicate a project-wide change
--- that requires all tokens to be re-requested by the client. This handler will
--- invalidate the current results of all buffers and automatically kick off a
--- new request for buffers that are displayed in a window. For those that aren't, a
--- the BufWinEnter event should take care of it next time it's displayed.
---
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#semanticTokens_refreshRequest
handlers['workspace/semanticTokens/refresh'] = function(err, _, ctx)
  if err then
    return vim.NIL
  end

  for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(ctx.client_id)) do
    local highlighter = STHighlighter.active[bufnr]
    if highlighter and highlighter.client_state[ctx.client_id] then
      highlighter:mark_dirty(ctx.client_id)

      if not vim.tbl_isempty(vim.fn.win_findbuf(bufnr)) then
        highlighter:send_request()
      end
    end
  end

  return vim.NIL
end

local namespace = api.nvim_create_namespace('vim_lsp_semantic_tokens')
api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, _, bufnr, topline, botline)
    local highlighter = STHighlighter.active[bufnr]
    if highlighter then
      highlighter:on_win(topline, botline)
    end
  end,
})

--- for testing only! there is no guarantee of API stability with this!
---
---@private
M.__STHighlighter = STHighlighter

return M
