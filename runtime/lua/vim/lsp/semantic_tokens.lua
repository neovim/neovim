local api = vim.api
local bit = require('bit')
local ms = require('vim.lsp.protocol').Methods
local util = require('vim.lsp.util')
local uv = vim.uv

--- @class (private) STTokenRange
--- @field line integer line number 0-based
--- @field start_col integer start column 0-based
--- @field end_col integer end column 0-based
--- @field type string token type as string
--- @field modifiers table<string,boolean> token modifiers as a set. E.g., { static = true, readonly = true }
--- @field marked boolean whether this token has had extmarks applied
---
--- @class (private) STCurrentResult
--- @field version? integer document version associated with this result
--- @field result_id? string resultId from the server; used with delta requests
--- @field highlights? STTokenRange[] cache of highlight ranges for this document version
--- @field tokens? integer[] raw token array as received by the server. used for calculating delta responses
--- @field namespace_cleared? boolean whether the namespace was cleared for this result yet
---
--- @class (private) STActiveRequest
--- @field request_id? integer the LSP request ID of the most recent request sent to the server
--- @field version? integer the document version associated with the most recent request
---
--- @class (private) STClientState
--- @field namespace integer
--- @field active_request STActiveRequest
--- @field current_result STCurrentResult

---@class (private) STHighlighter
---@field active table<integer, STHighlighter>
---@field bufnr integer
---@field augroup integer augroup for buffer events
---@field debounce integer milliseconds to debounce requests for new tokens
---@field timer table uv_timer for debouncing requests for new tokens
---@field client_state table<integer, STClientState>
local STHighlighter = { active = {} }

--- Do a binary search of the tokens in the half-open range [lo, hi).
---
--- Return the index i in range such that tokens[j].line < line for all j < i, and
--- tokens[j].line >= line for all j >= i, or return hi if no such index is found.
local function lower_bound(tokens, line, lo, hi)
  while lo < hi do
    local mid = bit.rshift(lo + hi, 1) -- Equivalent to floor((lo + hi) / 2).
    if tokens[mid].line < line then
      lo = mid + 1
    else
      hi = mid
    end
  end
  return lo
end

--- Do a binary search of the tokens in the half-open range [lo, hi).
---
--- Return the index i in range such that tokens[j].line <= line for all j < i, and
--- tokens[j].line > line for all j >= i, or return hi if no such index is found.
local function upper_bound(tokens, line, lo, hi)
  while lo < hi do
    local mid = bit.rshift(lo + hi, 1) -- Equivalent to floor((lo + hi) / 2).
    if line < tokens[mid].line then
      hi = mid
    else
      lo = mid + 1
    end
  end
  return lo
end

--- Extracts modifier strings from the encoded number in the token array
---
---@param x integer
---@param modifiers_table table<integer,string>
---@return table<string, boolean>
local function modifiers_from_number(x, modifiers_table)
  local modifiers = {} ---@type table<string,boolean>
  local idx = 1
  while x > 0 do
    if bit.band(x, 1) == 1 then
      modifiers[modifiers_table[idx]] = true
    end
    x = bit.rshift(x, 1)
    idx = idx + 1
  end

  return modifiers
end

--- Converts a raw token list to a list of highlight ranges used by the on_win callback
---
---@param data integer[]
---@param bufnr integer
---@param client vim.lsp.Client
---@param request STActiveRequest
---@return STTokenRange[]
local function tokens_to_ranges(data, bufnr, client, request)
  local legend = client.server_capabilities.semanticTokensProvider.legend
  local token_types = legend.tokenTypes
  local token_modifiers = legend.tokenModifiers
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local ranges = {} ---@type STTokenRange[]

  local start = uv.hrtime()
  local ms_to_ns = 1000 * 1000
  local yield_interval_ns = 5 * ms_to_ns
  local co, is_main = coroutine.running()

  local line ---@type integer?
  local start_char = 0
  for i = 1, #data, 5 do
    -- if this function is called from the main coroutine, let it run to completion with no yield
    if not is_main then
      local elapsed_ns = uv.hrtime() - start

      if elapsed_ns > yield_interval_ns then
        vim.schedule(function()
          coroutine.resume(co, util.buf_versions[bufnr])
        end)
        if request.version ~= coroutine.yield() then
          -- request became stale since the last time the coroutine ran.
          -- abandon it by yielding without a way to resume
          coroutine.yield()
        end

        start = uv.hrtime()
      end
    end

    local delta_line = data[i]
    line = line and line + delta_line or delta_line
    local delta_start = data[i + 1]
    start_char = delta_line == 0 and start_char + delta_start or delta_start

    -- data[i+3] +1 because Lua tables are 1-indexed
    local token_type = token_types[data[i + 3] + 1]
    local modifiers = modifiers_from_number(data[i + 4], token_modifiers)

    local function _get_byte_pos(col)
      if col > 0 then
        local buf_line = lines[line + 1] or ''
        local ok, result
        ok, result = pcall(util._str_byteindex_enc, buf_line, col, client.offset_encoding)
        if ok then
          return result
        end
        return math.min(#buf_line, col)
      end
      return col
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
        marked = false,
      }
    end
  end

  return ranges
end

--- Construct a new STHighlighter for the buffer
---
---@private
---@param bufnr integer
---@return STHighlighter
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

---@package
function STHighlighter:destroy()
  for client_id, _ in pairs(self.client_state) do
    self:detach(client_id)
  end

  api.nvim_del_augroup_by_id(self.augroup)
  STHighlighter.active[self.bufnr] = nil
end

---@package
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

---@package
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
---@package
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
      local method = ms.textDocument_semanticTokens_full

      if hasEditProvider and current_result.result_id then
        method = method .. '/delta'
        params.previousResultId = current_result.result_id
      end
      local success, request_id = client.request(method, params, function(err, response, ctx)
        -- look client up again using ctx.client_id instead of using a captured
        -- client object
        local c = vim.lsp.get_client_by_id(ctx.client_id)
        local bufnr = assert(ctx.bufnr)
        local highlighter = STHighlighter.active[bufnr]
        if not err and c and highlighter then
          coroutine.wrap(STHighlighter.process_response)(highlighter, response, c, version)
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
---@param response lsp.SemanticTokens|lsp.SemanticTokensDelta
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

  -- skip nil responses
  if response == nil then
    state.active_request = {}
    return
  end

  -- if we have a response to a delta request, update the state of our tokens
  -- appropriately. if it's a full response, just use that
  local tokens ---@type integer[]
  local token_edits = response.edits
  if token_edits then
    table.sort(token_edits, function(a, b)
      return a.start < b.start
    end)

    tokens = {} --- @type integer[]
    local old_tokens = assert(state.current_result.tokens)
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

  -- convert token list to highlight ranges
  -- this could yield and run over multiple event loop iterations
  local highlights = tokens_to_ranges(tokens, self.bufnr, client, state.active_request)

  -- reset active request
  state.active_request = {}

  -- update the state with the new results
  local current_result = state.current_result
  current_result.version = version
  current_result.result_id = response.resultId
  current_result.tokens = tokens
  current_result.highlights = highlights
  current_result.namespace_cleared = false

  -- redraw all windows displaying buffer
  api.nvim__buf_redraw_range(self.bufnr, 0, -1)
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
---@package
---@param topline integer
---@param botline integer
function STHighlighter:on_win(topline, botline)
  for client_id, state in pairs(self.client_state) do
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
      --
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

      local set_mark = function(token, hl_group, delta)
        vim.api.nvim_buf_set_extmark(self.bufnr, state.namespace, token.line, token.start_col, {
          hl_group = hl_group,
          end_col = token.end_col,
          priority = vim.highlight.priorities.semantic_tokens + delta,
          strict = false,
        })
      end

      local ft = vim.bo[self.bufnr].filetype
      local highlights = assert(current_result.highlights)
      local first = lower_bound(highlights, topline, 1, #highlights + 1)
      local last = upper_bound(highlights, botline, first, #highlights + 1) - 1

      for i = first, last do
        local token = highlights[i]
        if not token.marked then
          set_mark(token, string.format('@lsp.type.%s.%s', token.type, ft), 0)
          for modifier, _ in pairs(token.modifiers) do
            set_mark(token, string.format('@lsp.mod.%s.%s', modifier, ft), 1)
            set_mark(token, string.format('@lsp.typemod.%s.%s.%s', token.type, modifier, ft), 2)
          end
          token.marked = true

          api.nvim_exec_autocmds('LspTokenUpdate', {
            buffer = self.bufnr,
            modeline = false,
            data = {
              token = token,
              client_id = client_id,
            },
          })
        end
      end
    end
  end
end

--- Reset the buffer's highlighting state and clears the extmark highlights.
---
---@package
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
---@package
---@param client_id integer
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

---@package
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
---
--- ```lua
--- client.server_capabilities.semanticTokensProvider = nil
--- ```
---
---@param bufnr integer
---@param client_id integer
---@param opts? table Optional keyword arguments
---  - debounce (integer, default: 200): Debounce token requests
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
---@param bufnr integer
---@param client_id integer
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

--- @nodoc
--- @class STTokenRangeInspect : STTokenRange
--- @field client_id integer

--- Return the semantic token(s) at the given position.
--- If called without arguments, returns the token under the cursor.
---
---@param bufnr integer|nil Buffer number (0 for current buffer, default)
---@param row integer|nil Position row (default cursor position)
---@param col integer|nil Position column (default cursor position)
---
---@return STTokenRangeInspect[]|nil (table|nil) List of tokens at position. Each token has
---        the following fields:
---        - line (integer) line number, 0-based
---        - start_col (integer) start column, 0-based
---        - end_col (integer) end column, 0-based
---        - type (string) token type as string, e.g. "variable"
---        - modifiers (table) token modifiers as a set. E.g., { static = true, readonly = true }
---        - client_id (integer)
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

  local tokens = {} --- @type STTokenRangeInspect[]
  for client_id, client in pairs(highlighter.client_state) do
    local highlights = client.current_result.highlights
    if highlights then
      local idx = lower_bound(highlights, row, 1, #highlights + 1)
      for i = idx, #highlights do
        local token = highlights[i]
        --- @cast token STTokenRangeInspect

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
---@param bufnr (integer|nil) filter by buffer. All buffers if nil, current
---       buffer if 0
function M.force_refresh(bufnr)
  vim.validate({
    bufnr = { bufnr, 'n', true },
  })

  local buffers = bufnr == nil and vim.tbl_keys(STHighlighter.active)
    or bufnr == 0 and { api.nvim_get_current_buf() }
    or { bufnr }

  for _, buffer in ipairs(buffers) do
    local highlighter = STHighlighter.active[buffer]
    if highlighter then
      highlighter:reset()
      highlighter:send_request()
    end
  end
end

--- @class vim.lsp.semantic_tokens.highlight_token.Opts
--- @inlinedoc
---
--- Priority for the applied extmark.
--- (Default: `vim.highlight.priorities.semantic_tokens + 3`)
--- @field priority? integer

--- Highlight a semantic token.
---
--- Apply an extmark with a given highlight group for a semantic token. The
--- mark will be deleted by the semantic token engine when appropriate; for
--- example, when the LSP sends updated tokens. This function is intended for
--- use inside |LspTokenUpdate| callbacks.
---@param token (table) a semantic token, found as `args.data.token` in |LspTokenUpdate|.
---@param bufnr (integer) the buffer to highlight
---@param client_id (integer) The ID of the |vim.lsp.Client|
---@param hl_group (string) Highlight group name
---@param opts? vim.lsp.semantic_tokens.highlight_token.Opts  Optional parameters:
function M.highlight_token(token, bufnr, client_id, hl_group, opts)
  local highlighter = STHighlighter.active[bufnr]
  if not highlighter then
    return
  end

  local state = highlighter.client_state[client_id]
  if not state then
    return
  end

  opts = opts or {}
  local priority = opts.priority or vim.highlight.priorities.semantic_tokens + 3

  vim.api.nvim_buf_set_extmark(bufnr, state.namespace, token.line, token.start_col, {
    hl_group = hl_group,
    end_col = token.end_col,
    priority = priority,
    strict = false,
  })
end

--- @package
--- |lsp-handler| for the method `workspace/semanticTokens/refresh`
---
--- Refresh requests are sent by the server to indicate a project-wide change
--- that requires all tokens to be re-requested by the client. This handler will
--- invalidate the current results of all buffers and automatically kick off a
--- new request for buffers that are displayed in a window. For those that aren't, a
--- the BufWinEnter event should take care of it next time it's displayed.
function M._refresh(err, _, ctx)
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
