local M = {}

local api = vim.api
local lsp = vim.lsp
local protocol = lsp.protocol
local ms = protocol.Methods

local rtt_ms = 50
local ns_to_ms = 0.000001

--- @alias vim.lsp.CompletionResult lsp.CompletionList | lsp.CompletionItem[]

-- TODO(mariasolos): Remove this declaration once we figure out a better way to handle
-- literal/anonymous types (see https://github.com/neovim/neovim/pull/27542/files#r1495259331).
--- @nodoc
--- @class lsp.ItemDefaults
--- @field editRange lsp.Range | { insert: lsp.Range, replace: lsp.Range } | nil
--- @field insertTextFormat lsp.InsertTextFormat?
--- @field insertTextMode lsp.InsertTextMode?
--- @field data any

--- @nodoc
--- @class vim.lsp.completion.BufHandle
--- @field clients table<integer, vim.lsp.Client>
--- @field triggers table<string, vim.lsp.Client[]>

--- @type table<integer, vim.lsp.completion.BufHandle>
local buf_handles = {}

--- @nodoc
--- @class vim.lsp.completion.Context
local Context = {
  cursor = nil, --- @type [integer, integer]?
  last_request_time = nil, --- @type integer?
  pending_requests = {}, --- @type function[]
  isIncomplete = false,
}

--- @nodoc
function Context:cancel_pending()
  for _, cancel in ipairs(self.pending_requests) do
    cancel()
  end

  self.pending_requests = {}
end

--- @nodoc
function Context:reset()
  -- Note that the cursor isn't reset here, it needs to survive a `CompleteDone` event.
  self.isIncomplete = false
  self.last_request_time = nil
  self:cancel_pending()
end

--- @type uv.uv_timer_t?
local completion_timer = nil

--- @return uv.uv_timer_t
local function new_timer()
  return assert(vim.uv.new_timer())
end

local function reset_timer()
  if completion_timer then
    completion_timer:stop()
    completion_timer:close()
  end

  completion_timer = nil
end

--- @param window integer
--- @param warmup integer
--- @return fun(sample: number): number
local function exp_avg(window, warmup)
  local count = 0
  local sum = 0
  local value = 0

  return function(sample)
    if count < warmup then
      count = count + 1
      sum = sum + sample
      value = sum / count
    else
      local factor = 2.0 / (window + 1)
      value = value * (1 - factor) + sample * factor
    end
    return value
  end
end
local compute_new_average = exp_avg(10, 10)

--- @return number
local function next_debounce()
  if not Context.last_request_time then
    return rtt_ms
  end

  local ms_since_request = (vim.uv.hrtime() - Context.last_request_time) * ns_to_ms
  return math.max((ms_since_request - rtt_ms) * -1, 0)
end

--- @param input string Unparsed snippet
--- @return string # Parsed snippet if successful, else returns its input
local function parse_snippet(input)
  local ok, parsed = pcall(function()
    return lsp._snippet_grammar.parse(input)
  end)
  return ok and tostring(parsed) or input
end

--- @param item lsp.CompletionItem
--- @param suffix? string
local function apply_snippet(item, suffix)
  if item.textEdit then
    vim.snippet.expand(item.textEdit.newText .. suffix)
  elseif item.insertText then
    vim.snippet.expand(item.insertText .. suffix)
  end
end

--- Returns text that should be inserted when a selecting completion item. The
--- precedence is as follows: textEdit.newText > insertText > label
---
--- See https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
---
--- @param item lsp.CompletionItem
--- @return string
local function get_completion_word(item)
  if item.insertTextFormat == protocol.InsertTextFormat.Snippet then
    if item.textEdit then
      -- Use label instead of text if text has different starting characters.
      -- label is used as abbr (=displayed), but word is used for filtering
      -- This is required for things like postfix completion.
      -- E.g. in lua:
      --
      --    local f = {}
      --    f@|
      --      ▲
      --      └─ cursor
      --
      --    item.textEdit.newText: table.insert(f, $0)
      --    label: insert
      --
      -- Typing `i` would remove the candidate because newText starts with `t`.
      local text = parse_snippet(item.insertText or item.textEdit.newText)
      return #text < #item.label and vim.fn.matchstr(text, '\\k*') or item.label
    elseif item.insertText and item.insertText ~= '' then
      return parse_snippet(item.insertText)
    else
      return item.label
    end
  elseif item.textEdit then
    local word = item.textEdit.newText
    return word:match('^(%S*)') or word
  elseif item.insertText and item.insertText ~= '' then
    return item.insertText
  end
  return item.label
end

--- Applies the given defaults to the completion item, modifying it in place.
---
--- @param item lsp.CompletionItem
--- @param defaults lsp.ItemDefaults?
local function apply_defaults(item, defaults)
  if not defaults then
    return
  end

  item.insertTextFormat = item.insertTextFormat or defaults.insertTextFormat
  item.insertTextMode = item.insertTextMode or defaults.insertTextMode
  item.data = item.data or defaults.data
  if defaults.editRange then
    local textEdit = item.textEdit or {}
    item.textEdit = textEdit
    textEdit.newText = textEdit.newText or item.textEditText or item.insertText
    if defaults.editRange.start then
      textEdit.range = textEdit.range or defaults.editRange
    elseif defaults.editRange.insert then
      textEdit.insert = defaults.editRange.insert
      textEdit.replace = defaults.editRange.replace
    end
  end
end

--- @param result vim.lsp.CompletionResult
--- @return lsp.CompletionItem[]
local function get_items(result)
  if result.items then
    -- When we have a list, apply the defaults and return an array of items.
    for _, item in ipairs(result.items) do
      ---@diagnostic disable-next-line: param-type-mismatch
      apply_defaults(item, result.itemDefaults)
    end
    return result.items
  else
    -- Else just return the items as they are.
    return result
  end
end

---@param item lsp.CompletionItem
---@return string
local function get_doc(item)
  local doc = item.documentation
  if not doc then
    return ''
  end
  if type(doc) == 'string' then
    return doc
  end
  if type(doc) == 'table' and type(doc.value) == 'string' then
    return doc.value
  end

  vim.notify('invalid documentation value: ' .. vim.inspect(doc), vim.log.levels.WARN)
  return ''
end

--- Turns the result of a `textDocument/completion` request into vim-compatible
--- |complete-items|.
---
--- @private
--- @param result vim.lsp.CompletionResult Result of `textDocument/completion`
--- @param prefix string prefix to filter the completion items
--- @param client_id integer? Client ID
--- @return table[]
--- @see complete-items
function M._lsp_to_complete_items(result, prefix, client_id)
  local items = get_items(result)
  if vim.tbl_isempty(items) then
    return {}
  end

  local matches = prefix == '' and function()
    return true
  end or function(item)
    if item.filterText then
      return next(vim.fn.matchfuzzy({ item.filterText }, prefix))
    end
    return true
  end
  local candidates = {}
  for _, item in ipairs(items) do
    if matches(item) then
      local word = get_completion_word(item)
      table.insert(candidates, {
        word = word,
        abbr = item.label,
        kind = protocol.CompletionItemKind[item.kind] or 'Unknown',
        menu = item.detail or '',
        info = get_doc(item),
        icase = 1,
        dup = 1,
        empty = 1,
        user_data = {
          nvim = {
            lsp = {
              completion_item = item,
              client_id = client_id,
            },
          },
        },
      })
    end
  end
  ---@diagnostic disable-next-line: no-unknown
  table.sort(candidates, function(a, b)
    ---@type lsp.CompletionItem
    local itema = a.user_data.nvim.lsp.completion_item
    ---@type lsp.CompletionItem
    local itemb = b.user_data.nvim.lsp.completion_item
    return (itema.sortText or itema.label) < (itemb.sortText or itemb.label)
  end)

  return candidates
end

--- @param lnum integer 0-indexed
--- @param line string
--- @param items lsp.CompletionItem[]
--- @param encoding string
--- @return integer?
local function adjust_start_col(lnum, line, items, encoding)
  local min_start_char = nil
  for _, item in pairs(items) do
    if item.textEdit and item.textEdit.range.start.line == lnum then
      if min_start_char and min_start_char ~= item.textEdit.range.start.character then
        return nil
      end
      min_start_char = item.textEdit.range.start.character
    end
  end
  if min_start_char then
    return lsp.util._str_byteindex_enc(line, min_start_char, encoding)
  else
    return nil
  end
end

--- @private
--- @param line string line content
--- @param lnum integer 0-indexed line number
--- @param cursor_col integer
--- @param client_id integer client ID
--- @param client_start_boundary integer 0-indexed word boundary
--- @param server_start_boundary? integer 0-indexed word boundary, based on textEdit.range.start.character
--- @param result vim.lsp.CompletionResult
--- @param encoding string
--- @return table[] matches
--- @return integer? server_start_boundary
function M._convert_results(
  line,
  lnum,
  cursor_col,
  client_id,
  client_start_boundary,
  server_start_boundary,
  result,
  encoding
)
  -- Completion response items may be relative to a position different than `client_start_boundary`.
  -- Concrete example, with lua-language-server:
  --
  -- require('plenary.asy|
  --         ▲       ▲   ▲
  --         │       │   └── cursor_pos:                     20
  --         │       └────── client_start_boundary:          17
  --         └────────────── textEdit.range.start.character: 9
  --                                 .newText = 'plenary.async'
  --                  ^^^
  --                  prefix (We'd remove everything not starting with `asy`,
  --                  so we'd eliminate the `plenary.async` result
  --
  -- `adjust_start_col` is used to prefer the language server boundary.
  --
  local candidates = get_items(result)
  local curstartbyte = adjust_start_col(lnum, line, candidates, encoding)
  if server_start_boundary == nil then
    server_start_boundary = curstartbyte
  elseif curstartbyte ~= nil and curstartbyte ~= server_start_boundary then
    server_start_boundary = client_start_boundary
  end
  local prefix = line:sub((server_start_boundary or client_start_boundary) + 1, cursor_col)
  local matches = M._lsp_to_complete_items(result, prefix, client_id)
  return matches, server_start_boundary
end

--- @param clients table<integer, vim.lsp.Client> # keys != client_id
--- @param bufnr integer
--- @param win integer
--- @param callback fun(responses: table<integer, { err: lsp.ResponseError, result: vim.lsp.CompletionResult }>)
--- @return function # Cancellation function
local function request(clients, bufnr, win, callback)
  local responses = {} --- @type table<integer, { err: lsp.ResponseError, result: any }>
  local request_ids = {} --- @type table<integer, integer>
  local remaining_requests = vim.tbl_count(clients)

  for _, client in pairs(clients) do
    local client_id = client.id
    local params = lsp.util.make_position_params(win, client.offset_encoding)
    local ok, request_id = client.request(ms.textDocument_completion, params, function(err, result)
      responses[client_id] = { err = err, result = result }
      remaining_requests = remaining_requests - 1
      if remaining_requests == 0 then
        callback(responses)
      end
    end, bufnr)

    if ok then
      request_ids[client_id] = request_id
    end
  end

  return function()
    for client_id, request_id in pairs(request_ids) do
      local client = lsp.get_client_by_id(client_id)
      if client then
        client.cancel_request(request_id)
      end
    end
  end
end

local function trigger(bufnr, clients)
  reset_timer()
  Context:cancel_pending()

  local win = api.nvim_get_current_win()
  local cursor_row, cursor_col = unpack(api.nvim_win_get_cursor(win)) --- @type integer, integer
  local line = api.nvim_get_current_line()
  local line_to_cursor = line:sub(1, cursor_col)
  local word_boundary = vim.fn.match(line_to_cursor, '\\k*$')
  local start_time = vim.uv.hrtime()
  Context.last_request_time = start_time

  local cancel_request = request(clients, bufnr, win, function(responses)
    local end_time = vim.uv.hrtime()
    rtt_ms = compute_new_average((end_time - start_time) * ns_to_ms)

    Context.pending_requests = {}
    Context.isIncomplete = false

    local row_changed = api.nvim_win_get_cursor(win)[1] ~= cursor_row
    local mode = api.nvim_get_mode().mode
    if row_changed or not (mode == 'i' or mode == 'ic') then
      return
    end

    local matches = {}
    local server_start_boundary --- @type integer?
    for client_id, response in pairs(responses) do
      if response.err then
        vim.notify_once(response.err.message, vim.log.levels.warn)
      end

      local result = response.result
      if result then
        Context.isIncomplete = Context.isIncomplete or result.isIncomplete
        local client = lsp.get_client_by_id(client_id)
        local encoding = client and client.offset_encoding or 'utf-16'
        local client_matches
        client_matches, server_start_boundary = M._convert_results(
          line,
          cursor_row - 1,
          cursor_col,
          client_id,
          word_boundary,
          nil,
          result,
          encoding
        )
        vim.list_extend(matches, client_matches)
      end
    end
    local start_col = (server_start_boundary or word_boundary) + 1
    vim.fn.complete(start_col, matches)
  end)

  table.insert(Context.pending_requests, cancel_request)
end

--- @param handle vim.lsp.completion.BufHandle
local function on_insert_char_pre(handle)
  if tonumber(vim.fn.pumvisible()) == 1 then
    if Context.isIncomplete then
      reset_timer()

      local debounce_ms = next_debounce()
      if debounce_ms == 0 then
        vim.schedule(M.trigger)
      else
        completion_timer = new_timer()
        completion_timer:start(debounce_ms, 0, vim.schedule_wrap(M.trigger))
      end
    end

    return
  end

  local char = api.nvim_get_vvar('char')
  if not completion_timer and handle.triggers[char] then
    completion_timer = assert(vim.uv.new_timer())
    completion_timer:start(25, 0, function()
      reset_timer()
      vim.schedule(M.trigger)
    end)
  end
end

local function on_insert_leave()
  reset_timer()
  Context.cursor = nil
  Context:reset()
end

local function on_complete_done()
  local completed_item = api.nvim_get_vvar('completed_item')
  if not completed_item or not completed_item.user_data or not completed_item.user_data.nvim then
    Context:reset()
    return
  end

  local cursor_row, cursor_col = unpack(api.nvim_win_get_cursor(0)) --- @type integer, integer
  cursor_row = cursor_row - 1
  local completion_item = completed_item.user_data.nvim.lsp.completion_item --- @type lsp.CompletionItem
  local client_id = completed_item.user_data.nvim.lsp.client_id --- @type integer
  if not completion_item or not client_id then
    Context:reset()
    return
  end

  local bufnr = api.nvim_get_current_buf()
  local expand_snippet = completion_item.insertTextFormat == protocol.InsertTextFormat.Snippet
    and (completion_item.textEdit ~= nil or completion_item.insertText ~= nil)

  Context:reset()

  local client = lsp.get_client_by_id(client_id)
  if not client then
    return
  end

  local offset_encoding = client.offset_encoding or 'utf-16'
  local resolve_provider = (client.server_capabilities.completionProvider or {}).resolveProvider

  local function clear_word()
    if not expand_snippet then
      return nil
    end

    -- Remove the already inserted word.
    local start_char = cursor_col - #completed_item.word
    local line = api.nvim_buf_get_lines(bufnr, cursor_row, cursor_row + 1, true)[1]
    api.nvim_buf_set_text(bufnr, cursor_row, start_char, cursor_row, #line, { '' })
    return line:sub(cursor_col + 1)
  end

  --- @param suffix? string
  local function apply_snippet_and_command(suffix)
    if expand_snippet then
      apply_snippet(completion_item, suffix)
    end

    local command = completion_item.command
    if command then
      client:_exec_cmd(command, { bufnr = bufnr }, nil, function()
        vim.lsp.log.warn(
          string.format(
            'Language server `%s` does not support command `%s`. This command may require a client extension.',
            client.name,
            command.command
          )
        )
      end)
    end
  end

  if completion_item.additionalTextEdits and next(completion_item.additionalTextEdits) then
    local suffix = clear_word()
    lsp.util.apply_text_edits(completion_item.additionalTextEdits, bufnr, offset_encoding)
    apply_snippet_and_command(suffix)
  elseif resolve_provider and type(completion_item) == 'table' then
    local changedtick = vim.b[bufnr].changedtick

    --- @param result lsp.CompletionItem
    client.request(ms.completionItem_resolve, completion_item, function(err, result)
      if changedtick ~= vim.b[bufnr].changedtick then
        return
      end

      local suffix = clear_word()
      if err then
        vim.notify_once(err.message, vim.log.levels.WARN)
      elseif result and result.additionalTextEdits then
        lsp.util.apply_text_edits(result.additionalTextEdits, bufnr, offset_encoding)
        if result.command then
          completion_item.command = result.command
        end
      end

      apply_snippet_and_command(suffix)
    end, bufnr)
  else
    local suffix = clear_word()
    apply_snippet_and_command(suffix)
  end
end

--- @class vim.lsp.completion.BufferOpts
--- @field autotrigger? boolean Whether to trigger completion automatically. Default: false

--- @param client_id integer
---@param bufnr integer
---@param opts vim.lsp.completion.BufferOpts
local function enable_completions(client_id, bufnr, opts)
  local buf_handle = buf_handles[bufnr]
  if not buf_handle then
    buf_handle = { clients = {}, triggers = {} }
    buf_handles[bufnr] = buf_handle

    -- Attach to buffer events.
    api.nvim_buf_attach(bufnr, false, {
      on_detach = function(_, buf)
        buf_handles[buf] = nil
      end,
      on_reload = function(_, buf)
        M.enable(true, client_id, buf, opts)
      end,
    })

    -- Set up autocommands.
    local group =
      api.nvim_create_augroup(string.format('vim/lsp/completion-%d', bufnr), { clear = true })
    api.nvim_create_autocmd('CompleteDone', {
      group = group,
      buffer = bufnr,
      callback = function()
        local reason = api.nvim_get_vvar('event').reason --- @type string
        if reason == 'accept' then
          on_complete_done()
        end
      end,
    })
    if opts.autotrigger then
      api.nvim_create_autocmd('InsertCharPre', {
        group = group,
        buffer = bufnr,
        callback = function()
          on_insert_char_pre(buf_handles[bufnr])
        end,
      })
      api.nvim_create_autocmd('InsertLeave', {
        group = group,
        buffer = bufnr,
        callback = on_insert_leave,
      })
    end
  end

  if not buf_handle.clients[client_id] then
    local client = lsp.get_client_by_id(client_id)
    assert(client, 'invalid client ID')

    -- Add the new client to the buffer's clients.
    buf_handle.clients[client_id] = client

    -- Add the new client to the clients that should be triggered by its trigger characters.
    --- @type string[]
    local triggers = vim.tbl_get(
      client.server_capabilities,
      'completionProvider',
      'triggerCharacters'
    ) or {}
    for _, char in ipairs(triggers) do
      local clients_for_trigger = buf_handle.triggers[char]
      if not clients_for_trigger then
        clients_for_trigger = {}
        buf_handle.triggers[char] = clients_for_trigger
      end
      local client_exists = vim.iter(clients_for_trigger):any(function(c)
        return c.id == client_id
      end)
      if not client_exists then
        table.insert(clients_for_trigger, client)
      end
    end
  end
end

--- @param client_id integer
--- @param bufnr integer
local function disable_completions(client_id, bufnr)
  local handle = buf_handles[bufnr]
  if not handle then
    return
  end

  handle.clients[client_id] = nil
  if not next(handle.clients) then
    buf_handles[bufnr] = nil
    api.nvim_del_augroup_by_name(string.format('vim/lsp/completion-%d', bufnr))
  else
    for char, clients in pairs(handle.triggers) do
      --- @param c vim.lsp.Client
      handle.triggers[char] = vim.tbl_filter(function(c)
        return c.id ~= client_id
      end, clients)
    end
  end
end

--- Enables or disables completions from the given language client in the given buffer.
---
--- @param enable boolean True to enable, false to disable
--- @param client_id integer Client ID
--- @param bufnr integer Buffer handle, or 0 for the current buffer
--- @param opts? vim.lsp.completion.BufferOpts
function M.enable(enable, client_id, bufnr, opts)
  bufnr = (bufnr == 0 and api.nvim_get_current_buf()) or bufnr

  if enable then
    enable_completions(client_id, bufnr, opts or {})
  else
    disable_completions(client_id, bufnr)
  end
end

--- Trigger LSP completion in the current buffer.
function M.trigger()
  local bufnr = api.nvim_get_current_buf()
  local clients = (buf_handles[bufnr] or {}).clients or {}
  trigger(bufnr, clients)
end

--- Implements 'omnifunc' compatible LSP completion.
---
--- @see |complete-functions|
--- @see |complete-items|
--- @see |CompleteDone|
---
--- @param findstart integer 0 or 1, decides behavior
--- @param base integer findstart=0, text to match against
---
--- @return integer|table Decided by {findstart}:
--- - findstart=0: column where the completion starts, or -2 or -3
--- - findstart=1: list of matches (actually just calls |complete()|)
function M._omnifunc(findstart, base)
  vim.lsp.log.debug('omnifunc.findstart', { findstart = findstart, base = base })
  assert(base) -- silence luals
  local bufnr = api.nvim_get_current_buf()
  local clients = lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_completion })
  local remaining = #clients
  if remaining == 0 then
    return findstart == 1 and -1 or {}
  end

  trigger(bufnr, clients)

  -- Return -2 to signal that we should continue completion so that we can
  -- async complete.
  return -2
end

return M
