local api = vim.api
local fn = vim.fn
local log = require('vim.lsp.log')
local core_util = require('vim._core.util')
local nvim_on = core_util.nvim_on
local util = require('vim.lsp.util')
-- TODO(oriori1703): remove this import by replacing its usage with `vim.pos`.
local get_line = require('vim.pos._util').get_line

local Capability = require('vim.lsp._capability')

local M = {}

---@class (private) vim.lsp.inlay_hint.LineHints
---@field hints lsp.InlayHint[]
---@field applied boolean whether this line's hints have had extmarks applied

---@class (private) vim.lsp.inlay_hint.CurrentResult Info for current result
---@field version? integer document version associated with this result
---@field namespace_cleared? boolean whether the namespace was cleared for this result yet
---@field hints? table<integer, vim.lsp.inlay_hint.LineHints> lnum -> hints

---@class (private) vim.lsp.inlay_hint.ActiveRequest
---@field request_id? integer the LSP request ID of the most recent request sent to the server
---@field version? integer the document version associated with the most recent request

---@class (private) vim.lsp.inlay_hint.ClientState Buffer local state for inlay hints
---@field namespace integer
---@field active_request vim.lsp.inlay_hint.ActiveRequest
---@field current_result vim.lsp.inlay_hint.CurrentResult

---@class (private) InlayHints : vim.lsp.Capability
---@field active table<integer, InlayHints>
---@field client_state table<integer, vim.lsp.inlay_hint.ClientState?>
local InlayHint = {
  name = 'inlay_hint',
  method = 'textDocument/inlayHint',
  active = {},
}
InlayHint.__index = InlayHint
setmetatable(InlayHint, Capability)
Capability.all[InlayHint.name] = InlayHint

---@package
---@param bufnr integer
function InlayHint:new(bufnr)
  self = Capability.new(self, bufnr)

  nvim_on('BufWinEnter', self.augroup, { buf = self.bufnr }, function()
    for client_id, _ in pairs(self.client_state) do
      self:refresh(client_id)
    end
  end)

  return self
end

---@package
---@param client_id integer
function InlayHint:on_attach(client_id)
  if not self.client_state[client_id] then
    self.client_state[client_id] = {
      namespace = api.nvim_create_namespace('nvim.lsp.inlay_hint:' .. client_id),
      active_request = {},
      current_result = {},
    }
  end
  self:refresh(client_id)
end

---@package
---@param client_id integer
function InlayHint:on_detach(client_id)
  local state = self.client_state[client_id]
  if state then
    self:reset(client_id)
    self.client_state[client_id] = nil
  end
end

---@private
---@param client_id integer
function InlayHint:on_close(client_id)
  self:reset(client_id)
end

---@private
---@param client_id integer
function InlayHint:on_change(client_id)
  self:refresh(client_id)
end

--- Reset the buffer's inlay hint state and clear the extmarks
---@package
---@param client_id integer
function InlayHint:reset(client_id)
  local state = assert(self.client_state[client_id])
  self:cancel_active_request(client_id)
  api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
  state.current_result = {}
end

--- Refresh inlay hints by requesting them from the server
---
--- Only sends a request if there is no active request in flight for the current document version.
--- Otherwise, it cancels any previous in-progress request before sending a new one.
---
---@package
---@param client_id integer
function InlayHint:refresh(client_id)
  local version = util.buf_versions[self.bufnr]
  local state = self.client_state[client_id]
  local client = vim.lsp.get_client_by_id(client_id)

  if state and client then
    local current_result = state.current_result
    local active_request = state.active_request

    -- Only send a request for this client if the current result is out of date and
    -- there isn't a current a request in flight for this version
    if current_result.version == version or active_request.version == version then
      return
    end

    -- cancel stale in-flight request
    self:cancel_active_request(client_id)

    ---@type lsp.InlayHintParams
    local params = {
      textDocument = util.make_text_document_params(self.bufnr),
      range = vim
        .range(self.bufnr, 0, 0, api.nvim_buf_line_count(self.bufnr), 0)
        :to_lsp(client.offset_encoding),
    }

    local success, request_id = client:request('textDocument/inlayHint', params, nil, self.bufnr)

    if success then
      active_request.request_id = request_id
      active_request.version = version
    end
  end
end

--- |lsp-handler| for the method `textDocument/inlayHint`
--- Store hints for a specific buffer and client
---@param err lsp.ResponseError?
---@param result lsp.InlayHint[]?
---@param ctx lsp.HandlerContext
---@internal
function M.on_inlayhint(err, result, ctx)
  local bufnr = assert(ctx.bufnr)
  local provider = InlayHint.active[bufnr]
  if not provider then
    return
  end

  local state = provider.client_state[ctx.client_id]
  if not state then
    return
  end

  if err then
    log.error('inlay_hint', err)
    state.active_request = {}
    return
  end

  if util.buf_versions[bufnr] ~= ctx.version or not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  -- ignore stale responses
  if state.active_request.request_id and ctx.request_id ~= state.active_request.request_id then
    return
  end

  -- If there's no error but the result is nil, clear existing hints.
  result = result or {}

  local new_lnum_hints = {} ---@type table<integer, vim.lsp.inlay_hint.LineHints>
  local num_unprocessed = #result
  if num_unprocessed == 0 then
    state.active_request = {}
    state.current_result = {}
    if fn.win_gettype(fn.bufwinid(bufnr)) == '' then
      api.nvim__redraw({ buf = bufnr, valid = true, flush = false })
    end
    return
  end

  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))

  for _, hint in ipairs(result) do
    local lnum = hint.position.line
    local line = lines and lines[lnum + 1] or ''
    hint.position.character =
      vim.str_byteindex(line, client.offset_encoding, hint.position.character, false)
    if not new_lnum_hints[lnum] then
      new_lnum_hints[lnum] = {
        hints = {},
        applied = false,
      }
    end
    table.insert(new_lnum_hints[lnum].hints, hint)
  end

  state.active_request = {}
  state.current_result = {
    hints = new_lnum_hints,
    version = ctx.version,
    namespace_cleared = false,
  }

  if fn.win_gettype(fn.bufwinid(bufnr)) == '' then
    api.nvim__redraw({ buf = bufnr, valid = true, flush = false })
  end
end

---@private
---@param client_id integer
function InlayHint:cancel_active_request(client_id)
  local state = assert(self.client_state[client_id])
  local client = vim.lsp.get_client_by_id(client_id)
  local active_request = state.active_request

  if client and active_request.request_id then
    client:cancel_request(active_request.request_id)
    active_request.request_id = nil
    active_request.version = nil
  end
end

--- |lsp-handler| for the method `workspace/inlayHint/refresh`
---@param err lsp.ResponseError?
---@param ctx lsp.HandlerContext
---@internal
function M.on_refresh(err, _, ctx)
  if err then
    return vim.NIL
  end

  for bufnr, provider in pairs(InlayHint.active) do
    if provider.client_state[ctx.client_id] then
      provider:reset(ctx.client_id)

      if not vim.tbl_isempty(fn.win_findbuf(bufnr)) then
        provider:refresh(ctx.client_id)
      end
    end
  end

  return vim.NIL
end

--- Optional filters |kwargs|:
--- @class vim.lsp.inlay_hint.get.Filter
--- @inlinedoc
--- @field bufnr integer?
--- @field range lsp.Range?

--- @class vim.lsp.inlay_hint.get.ret
--- @inlinedoc
--- @field bufnr integer
--- @field client_id integer
--- @field inlay_hint lsp.InlayHint

--- Get the list of inlay hints, (optionally) restricted by buffer or range.
---
--- Example usage:
---
--- ```lua
--- local hint = vim.lsp.inlay_hint.get({ bufnr = 0 })[1] -- 0 for current buffer
---
--- local client = vim.lsp.get_client_by_id(hint.client_id)
--- local resp = client:request_sync('inlayHint/resolve', hint.inlay_hint, 100, 0)
--- local resolved_hint = assert(
---   resp and resp.result,
---   resp and resp.err and vim.lsp.rpc.format_rpc_error(resp.err) or 'request failed'
--- )
--- vim.lsp.util.apply_text_edits(resolved_hint.textEdits, 0, client.encoding)
---
--- location = resolved_hint.label[1].location
--- client:request('textDocument/hover', {
---   textDocument = { uri = location.uri },
---   position = location.range.start,
--- })
--- ```
---
--- |vim.lsp.inlay_hint.action()| does all of the above for you.
---
--- @param filter vim.lsp.inlay_hint.get.Filter?
--- @return vim.lsp.inlay_hint.get.ret[]
--- @since 12
function M.get(filter)
  vim.validate('filter', filter, 'table', true)
  filter = filter or {}

  local bufnr = filter.bufnr
  if not bufnr then
    return vim
      .iter(api.nvim_list_bufs())
      :map(function(buf)
        return M.get(vim.tbl_extend('keep', { bufnr = buf }, filter))
      end)
      :flatten()
      :totable()
  else
    bufnr = vim._resolve_bufnr(bufnr)
  end

  local provider = InlayHint.active[bufnr]
  if not provider then
    return {}
  end

  local range = filter.range
  if not range then
    range = {
      start = { line = 0, character = 0 },
      ['end'] = { line = api.nvim_buf_line_count(bufnr), character = 0 },
    }
  end

  --- @type vim.lsp.inlay_hint.get.ret[]
  local result = {}
  for client_id, state in pairs(provider.client_state) do
    local lnum_hints = state.current_result.hints
    if lnum_hints then
      for lnum = range.start.line, range['end'].line do
        local line_hints = lnum_hints[lnum] or { hints = {}, applied = false }
        for _, hint in pairs(line_hints.hints) do
          local line, char = hint.position.line, hint.position.character
          if
            (line > range.start.line or char >= range.start.character)
            and (line < range['end'].line or char <= range['end'].character)
          then
            table.insert(result, {
              bufnr = bufnr,
              client_id = client_id,
              inlay_hint = hint,
            })
          end
        end
      end
    end
  end
  return result
end

--- Turn an inlay hint into the visible text, merging any label parts.
--- @param hint lsp.InlayHint
--- @return string
local function get_label_text(hint)
  local label = hint.label
  if type(label) == 'string' then
    return label
  end
  local parts = {} --- @type string[]
  for i, part in ipairs(label) do
    parts[i] = part.value
  end
  return table.concat(parts)
end

--- on_win handler for the decoration provider (see |nvim_set_decoration_provider|)
---@package
---@param topline integer
---@param botline integer
function InlayHint:on_win(topline, botline)
  for _, state in pairs(self.client_state) do
    local current_result = state.current_result
    if current_result.version == util.buf_versions[self.bufnr] then
      if not current_result.namespace_cleared then
        api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
        current_result.namespace_cleared = true
      end

      local hints = assert(current_result.hints)

      for lnum = topline, botline do
        local hint_virtual_texts = {} --- @type table<integer, [string, string?][]>
        local line_hints = hints[lnum]
        if line_hints and not line_hints.applied then
          line_hints.applied = true
          for _, hint in pairs(line_hints.hints) do
            local vt = hint_virtual_texts[hint.position.character] or {}
            if hint.paddingLeft then
              vt[#vt + 1] = { ' ' }
            end
            vt[#vt + 1] = { get_label_text(hint), 'LspInlayHint' }
            if hint.paddingRight then
              vt[#vt + 1] = { ' ' }
            end
            hint_virtual_texts[hint.position.character] = vt
          end
        end

        for pos, vt in pairs(hint_virtual_texts) do
          api.nvim_buf_set_extmark(self.bufnr, state.namespace, lnum, pos, {
            virt_text_pos = 'inline',
            ephemeral = false,
            virt_text = vt,
          })
        end
      end
    end
  end
end

--- Query whether inlay hint is enabled in the {filter}ed scope
--- @param filter? vim.lsp.capability.enable.Filter
--- @return boolean
--- @since 12
function M.is_enabled(filter)
  return Capability.is_enabled('inlay_hint', filter)
end

--- Enables or disables inlay hints for the {filter}ed scope.
---
--- To "toggle", pass the inverse of `is_enabled()`:
---
--- ```lua
--- vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
--- ```
---
--- @param enable boolean? true/nil to enable, false to disable
--- @param filter? vim.lsp.capability.enable.Filter
--- @since 12
function M.enable(enable, filter)
  Capability.enable('inlay_hint', enable, filter)
end

--- Build ranges from the cursor or visual selection, one per selected line.
--- @return vim.Range[]
local function make_ranges()
  local bufnr = api.nvim_get_current_buf()
  local mode = fn.mode()
  --- End-exclusive column just past the character at `col`, clamped to the line end.
  --- @param line string
  --- @param col integer
  local function after_char(line, col)
    return col >= #line and #line or col + vim.str_utf_end(line, col + 1) + 1
  end
  if mode ~= 'v' and mode ~= 'V' and mode ~= '\22' then
    local cursor = vim.pos.cursor(0)
    local row, col = cursor[1], cursor[2]
    return { vim.range(bufnr, row, col, row, after_char(get_line(bufnr, row), col)) }
  end

  local ranges = {} --- @type vim.Range[]
  for _, segment in
    ipairs(fn.getregionpos(fn.getpos('v'), fn.getpos('.'), {
      type = mode,
      exclusive = vim.o.selection == 'exclusive',
      eol = true,
    }))
  do
    local start_pos, end_pos = segment[1], segment[2]
    local row, start_col, end_col = start_pos[2] - 1, start_pos[3] - 1, end_pos[3] - 1
    -- The fourth element is the offset into a multi-cell character. A start that lands
    -- inside one begins at the next character; an end that lands on one covers all of it.
    if start_pos[4] > 0 or end_pos[4] == 0 then
      local line = get_line(bufnr, row)
      if start_pos[4] > 0 then
        start_col = after_char(line, start_col)
      end
      if end_pos[4] == 0 then
        end_col = after_char(line, end_col)
      end
    end
    -- An empty segment (an empty line, or a blockwise column past the end of a short
    -- line) can end before it starts; `vim.range` rejects those.
    if start_col <= end_col then
      ranges[#ranges + 1] = vim.range(bufnr, row, start_col, row, end_col)
    end
  end
  return ranges
end

--- Append `new_label` to `labels` unless an equal label (comparing `value` and each of
--- `by_attribute`) is already there.
---@param labels lsp.InlayHintLabelPart[]
---@param new_label lsp.InlayHintLabelPart
---@param by_attribute ('location'|'command'|'tooltip')[]
local function add_new_label(labels, new_label, by_attribute)
  for _, existing_label in ipairs(labels) do
    if existing_label.value == new_label.value then
      local same = true
      for _, attr in ipairs(by_attribute) do
        if not vim.deep_equal(existing_label[attr], new_label[attr]) then
          same = false
          break
        end
      end
      if same then
        return
      end
    end
  end
  table.insert(labels, new_label)
end

---Return the deduplicated hint label parts carrying at least one of `needed_fields`.
--- @param hint lsp.InlayHint
--- @param needed_fields ("location"|"command"|"tooltip")[]
--- @return lsp.InlayHintLabelPart[]
local function get_hint_labels(hint, needed_fields)
  --- @type lsp.InlayHintLabelPart[]
  local hint_labels = {}

  if type(hint.label) == 'table' then
    for _, label in ipairs(hint.label) do
      for _, field_name in ipairs(needed_fields) do
        if label[field_name] ~= nil then
          add_new_label(hint_labels, label, needed_fields)
          break
        end
      end
    end
  end

  return hint_labels
end

--- @class (private) vim.lsp.inlay_hint.action.internal_context : vim.lsp.inlay_hint.action.context
--- @field is_valid fun(): boolean
--- @field win integer

--- Whether the action can still show something: the source buffer is unchanged and the
--- window the action started from is still around.
--- @param ctx vim.lsp.inlay_hint.action.internal_context
local function can_show(ctx)
  return ctx.is_valid() and api.nvim_win_is_valid(ctx.win)
end

--- The hint an action that handles a single hint should use, warning when several were given.
--- @param hints lsp.InlayHint[]
--- @param action vim.lsp.inlay_hint.action.name
--- @return lsp.InlayHint?
local function single_hint(hints, action)
  if #hints > 1 then
    vim.schedule(function()
      vim.notify(
        ('vim.lsp.inlay_hint.action(%q) only supports a single inlay hint.'):format(action),
        vim.log.levels.WARN
      )
    end)
  end
  return hints[1]
end

--- The built-in action handlers.
--- @type table<vim.lsp.inlay_hint.action.name, fun(hints: lsp.InlayHint[], ctx: vim.lsp.inlay_hint.action.internal_context, on_done: vim.lsp.inlay_hint.action.on_done.callback): boolean>
local action_handlers = {
  textEdits = function(hints, ctx, on_done)
    local text_edits = {} --- @type lsp.TextEdit[]
    for _, hint in ipairs(hints) do
      vim.list_extend(text_edits, hint.textEdits or {})
    end
    if #text_edits == 0 then
      return false
    end
    vim.schedule(function()
      if not ctx.is_valid() then
        on_done({ buf = ctx.buf })
        return
      end
      util.apply_text_edits(text_edits, ctx.buf, ctx.client.offset_encoding)
      on_done({ buf = ctx.buf, client = ctx.client })
    end)
    return true
  end,
  location = function(hints, ctx, on_done)
    --- @type lsp.InlayHintLabelPart[]
    local hint_labels = {}

    for _, item in ipairs(hints) do
      vim.list_extend(hint_labels, get_hint_labels(item, { 'location' }))
    end

    if vim.tbl_isempty(hint_labels) then
      return false
    end

    core_util.do_or_select(hint_labels, {
      prompt = 'Location to jump to',
      kind = 'inlay_hint_location',
      --- @param item lsp.InlayHintLabelPart
      format_item = function(item)
        local location = assert(item.location)
        return string.format(
          '%s\t%s:%d',
          item.value,
          core_util.shorten_path(vim.uri_to_fname(location.uri), ctx.client.root_dir),
          location.range.start.line
        )
      end,
    }, function(item, idx)
      if idx == nil or not can_show(ctx) then
        -- `vim.ui.select` was cancelled
        on_done({ buf = ctx.buf })
        return
      end
      api.nvim_set_current_win(ctx.win)
      local shown = util.show_document(
        assert(item.location),
        ctx.client.offset_encoding,
        { reuse_win = true, focus = true }
      )
      on_done({
        buf = shown and api.nvim_get_current_buf() or ctx.buf,
        client = shown and ctx.client or nil,
      })
    end)

    return true
  end,

  hover = function(hints, ctx, on_done)
    local hint = single_hint(hints, 'hover')
    if not hint then
      return false
    end
    local hint_labels = get_hint_labels(hint, { 'location' })
    if #hint_labels == 0 then
      return false
    end

    local function abort()
      on_done({ buf = ctx.buf })
    end

    --- Assemble the sections in label order and show them.
    ---@param sections table<integer, string[]>
    local function show(sections)
      if not can_show(ctx) then
        return abort()
      end
      local lines = {} --- @type string[]
      for i = 1, #hint_labels do
        if sections[i] then
          if #lines > 0 then
            -- Blank line between label parts
            lines[#lines + 1] = ''
          end
          vim.list_extend(lines, sections[i])
        end
      end
      if #lines == 0 then
        return abort()
      end
      local float_buf = api.nvim_win_call(ctx.win, function()
        return util.open_floating_preview(lines, 'markdown')
      end)
      on_done({ client = ctx.client, buf = float_buf })
    end

    -- The locations are independent, so request them all at once and assemble the
    -- hover once the last reply arrives.
    local sections = {} --- @type table<integer, string[]>
    local remaining = #hint_labels
    for i, item in ipairs(hint_labels) do
      ---@param section string[]?
      local function complete(section)
        sections[i] = section
        remaining = remaining - 1
        if remaining == 0 then
          show(sections)
        end
      end

      -- `get_hint_labels` makes sure `item` has a location attribute
      local label_loc = assert(item.location)
      ---@type lsp.HoverParams
      local hover_param = {
        textDocument = { uri = label_loc.uri },
        position = label_loc.range.start,
      }
      local success = ctx.client:request(
        'textDocument/hover',
        hover_param,
        ---@param result lsp.Hover?
        function(_, result)
          local md_lines = result and util.convert_input_to_markdown_lines(result.contents) or {}
          if #md_lines == 0 then
            return complete(nil)
          end
          complete(vim.list_extend({ string.format('# `%s`', item.value) }, md_lines))
        end,
        ctx.buf
      )
      if not success then
        complete(nil)
      end
    end

    return true
  end,

  tooltip = function(hints, ctx, on_done)
    local hint = single_hint(hints, 'tooltip')
    if not hint then
      return false
    end
    local hint_labels = get_hint_labels(hint, { 'location', 'command', 'tooltip' })

    -- The level 1 heading is the full hint object
    local lines = { string.format('# `%s`', get_label_text(hint)), '' }

    if hint.tooltip then
      util.convert_input_to_markdown_lines(hint.tooltip, lines)
    end

    for _, label in ipairs(hint_labels) do
      lines[#lines + 1] = ''
      -- Each of the level 2 headings is the text of a label part.
      lines[#lines + 1] = string.format('## `%s`', label.value)
      lines[#lines + 1] = ''
      if label.tooltip then
        util.convert_input_to_markdown_lines(label.tooltip, lines)
      end
      if label.location then
        lines[#lines + 1] = string.format(
          '_Location_: `%s`:%d',
          core_util.shorten_path(vim.uri_to_fname(label.location.uri), ctx.client.root_dir),
          label.location.range.start.line
        )
      end
      if label.command then
        local command_line = string.format('_Command_: %s', label.command.title)
        if label.command.tooltip then
          command_line = command_line .. string.format(' (%s)', label.command.tooltip)
        end
        lines[#lines + 1] = command_line
      end
    end

    if #lines == 2 then
      -- No tooltip/command/location has been found. Skip this hint.
      return false
    end

    if not can_show(ctx) then
      on_done({ buf = ctx.buf })
      return true
    end
    local buf = api.nvim_win_call(ctx.win, function()
      return util.open_floating_preview(lines, 'markdown')
    end)
    on_done({ buf = buf, client = ctx.client })
    return true
  end,

  command = function(hints, ctx, on_done)
    local hint = single_hint(hints, 'command')
    if not hint then
      return false
    end
    local hint_labels = get_hint_labels(hint, { 'command' })
    if #hint_labels == 0 then
      -- no commands in this hint
      return false
    end

    core_util.do_or_select(hint_labels, {
      prompt = 'Command to execute',
      kind = 'inlay_hint_command',
      --- @param item lsp.InlayHintLabelPart
      format_item = function(item)
        local entry_line = string.format('%s: %s', item.value, assert(item.command).title)
        if item.tooltip then
          entry_line = entry_line .. string.format(' (%s)', item.tooltip)
        end
        return entry_line
      end,
    }, function(item, idx)
      if idx == nil or not ctx.is_valid() then
        -- `vim.ui.select` was cancelled
        on_done({ buf = ctx.buf })
        return
      end
      local cmd = assert(item.command)
      local success, request_id = ctx.client:exec_cmd(cmd, { bufnr = ctx.buf }, function(err, ...)
        -- A caller-supplied handler replaces the default one, so run it explicitly to
        -- keep the standard error reporting.
        assert(ctx.client:_resolve_handler('workspace/executeCommand'))(err, ...)
        on_done({ buf = ctx.buf, client = not err and ctx.client or nil })
      end)
      if not success then
        on_done({ buf = ctx.buf })
      elseif not request_id then
        -- The command ran locally, so the handler above is never called.
        on_done({ buf = ctx.buf, client = ctx.client })
      end
    end)

    return true
  end,
}

--- @alias vim.lsp.inlay_hint.action.name
---| 'textEdits' -- Insert texts into the buffer
---| 'command' -- See 'workspace/executeCommand'
---| 'location' -- Jump to the location (usually the definition of the identifier or type)
---| 'hover' -- Show a hover window of the symbols shown in the inlay hint
---| 'tooltip' -- Show a hover-like window, containing available tooltips, commands and locations

--- A built-in action name, or a custom handler.
--- @alias vim.lsp.inlay_hint.action.spec
---| vim.lsp.inlay_hint.action.name
---| vim.lsp.inlay_hint.action.handler

--- @class vim.lsp.inlay_hint.action.context
--- @inlinedoc
--- @field buf integer
--- @field client vim.lsp.Client

--- @class vim.lsp.inlay_hint.action.on_done.context
--- @inlinedoc
---
--- The buffer opened or jumped to by the action, or the source buffer otherwise.
--- The source buffer may no longer be valid if it was deleted during the action.
--- @field buf integer
---
--- The `vim.lsp.Client` used to invoke the action. `nil` when no action was invoked.
--- @field client? vim.lsp.Client

--- Always supplied to action handlers. Call exactly once when a handled action finishes.
--- @alias vim.lsp.inlay_hint.action.on_done.callback fun(ctx: vim.lsp.inlay_hint.action.on_done.context)

--- @alias vim.lsp.inlay_hint.action.handler fun(hints: lsp.InlayHint[], ctx: vim.lsp.inlay_hint.action.context, on_done: vim.lsp.inlay_hint.action.on_done.callback):boolean

--- @class vim.lsp.inlay_hint.action.Opts
--- @inlinedoc
---
--- Inlay hints (returned by `vim.lsp.inlay_hint.get()`) to take actions on.
--- All hints must belong to the same buffer, which need not be the current buffer.
--- Mixed-buffer lists are rejected before any action is taken.
--- When not specified:
---   - in |Normal-mode|, it uses hints on either side of the cursor.
---   - in |Visual-mode|, it uses hints inside the selected range.
--- @field hints? vim.lsp.inlay_hint.get.ret[]
---
--- A callback invoked exactly once (asynchronously) at the end of the action.
--- Also invoked when no action is taken, selection is cancelled, or a request fails.
--- Receives a context with these fields:
---   - `buf`: the preview buffer for hover/tooltip, the destination buffer for location,
---     or the source buffer otherwise. The source buffer may have been deleted.
---   - `client`: the client used by the action, or nil when no action was taken.
--- @field on_done? vim.lsp.inlay_hint.action.on_done.callback

--- Apply some actions provided by inlay hints in the selected range.
--- Built-in actions are abandoned if the source buffer changes or is unloaded before
--- they can be applied. The "hover", "tooltip", and "command" actions use only the first
--- hint from each client, and warn if multiple hints were supplied for that client.
---
--- Example usage:
--- ```lua
--- vim.keymap.set(
---   { 'n', 'v' },
---   'grI',
---   function()
---     vim.lsp.inlay_hint.action('textEdits')
---   end,
---   { desc = 'Apply inlay hint textEdits' }
--- )
--- ```
---
--- @param action vim.lsp.inlay_hint.action.spec
--- Possible actions:
--- - `"textEdits"`: insert `textEdits` that comes with the inlay hints.
--- - `"location"`: jump to one of the locations associated with the inlay hints.
--- - `"command"`: execute one of the `lsp.Command`s that comes with the inlay hint.
--- - `"hover"`: if there are some locations associated with the inlay hint, show the hover
---   information of the identifiers at those locations.
--- - `"tooltip"`: show a hover-like window that contains the `tooltip`, available `command`s and
---   `location`s that comes with the inlay hint.
--- - a custom handler with 3 parameters:
---   - `hints`: `lsp.InlayHint[]` a list of inlay hints in the requested range. Hint positions
---     use byte indices, as in `vim.lsp.inlay_hint.get()`.
---   - `ctx`: `{buf: integer, client: vim.lsp.Client}` the buffer on which the action is taken, and the LSP client that provides `hints`.
---   - `on_done`: `fun(ctx: {buf: integer, client?: vim.lsp.Client})` see `on_done` in {opts}.
---     Always supplied, even when {opts} omits `on_done`.
---
---   The handler must return `true` if it handled the action (and then call `on_done` exactly
---   once when the action finishes), or `false` if `hints` did not contain what the action
---   needs, in which case the hints of the next available client are tried.
--- @param opts? vim.lsp.inlay_hint.action.Opts
function M.action(action, opts)
  vim.validate('action', action, function(val)
    return type(val) == 'function' or type(action_handlers[val]) == 'function'
  end, false)
  vim.validate('opts', opts, 'table', true)

  opts = opts or {}
  vim.validate('opts.on_done', opts.on_done, 'function', true)
  vim.validate('opts.hints', opts.hints, vim.islist, true, 'list')

  local win = api.nvim_get_current_win()
  local bufnr = api.nvim_get_current_buf()
  local hints = opts.hints
  if hints == nil then
    hints = {}
    for _, range in ipairs(make_ranges()) do
      -- Cached hint positions are byte-indexed, so use UTF-8 rather than the
      -- client's encoding. get() includes both endpoints, selecting hints on
      -- either side of the cursor or selected characters.
      vim.list_extend(hints, M.get({ bufnr = range.buf, range = range:to_lsp('utf-8') }))
    end
  else
    for _, item in ipairs(hints) do
      vim.validate('hint.bufnr', item.bufnr, 'number')
      vim.validate('hint.client_id', item.client_id, 'number')
      vim.validate('hint.inlay_hint', item.inlay_hint, 'table')
    end
  end
  if hints[1] then
    bufnr = vim._resolve_bufnr(hints[1].bufnr)
  end

  -- Group the whole list before scheduling any work.
  ---@type table<integer, lsp.InlayHint[]>
  local hints_by_clients = vim.defaulttable()
  for _, item in ipairs(hints) do
    assert(vim._resolve_bufnr(item.bufnr) == bufnr, 'All hints must belong to the same buffer')
    table.insert(hints_by_clients[item.client_id], item.inlay_hint)
  end

  local changedtick = api.nvim_buf_is_loaded(bufnr) and api.nvim_buf_get_changedtick(bufnr)
  local finished = false
  --- @type vim.lsp.inlay_hint.action.on_done.callback
  local function on_done(ctx)
    if finished then
      return
    end
    finished = true
    if opts.on_done then
      vim.schedule(function()
        opts.on_done(ctx)
      end)
    end
  end

  local function is_valid()
    return not finished
      and api.nvim_buf_is_loaded(bufnr)
      and api.nvim_buf_get_changedtick(bufnr) == changedtick
  end

  local client_ids = vim.tbl_keys(hints_by_clients)
  -- `vim.tbl_keys` ordering is not deterministic; try clients in a stable order.
  table.sort(client_ids)

  --- Try clients in order until one handles the action.
  --- @param idx integer
  local function do_action(idx)
    if not is_valid() or not client_ids[idx] then
      on_done({ buf = bufnr })
      return
    end
    local client = vim.lsp.get_client_by_id(client_ids[idx])
    if not client or client:is_stopped() then
      return do_action(idx + 1)
    end

    --- @param resolved lsp.InlayHint[]
    local function apply(resolved)
      if not is_valid() then
        on_done({ buf = bufnr })
        return
      end
      local handled
      if type(action) == 'function' then
        handled = action(resolved, { buf = bufnr, client = client }, on_done)
      else
        --- @cast action vim.lsp.inlay_hint.action.name
        handled = action_handlers[action](resolved, {
          buf = bufnr,
          client = client,
          win = win,
          is_valid = is_valid,
        }, on_done)
      end
      if not handled and not finished then
        do_action(idx + 1)
      end
    end

    -- Copy so that handlers cannot mutate the cached hints. Only the clients actually
    -- tried pay for this.
    local client_hints = vim.deepcopy(hints_by_clients[client.id], true)
    if not client:supports_method('inlayHint/resolve', bufnr) then
      apply(client_hints)
      return
    end

    -- Resolve in parallel, retaining input order even when replies arrive out of order.
    local remaining = #client_hints
    local resolved = {} --- @type table<integer, lsp.InlayHint>
    for i, hint in ipairs(client_hints) do
      --- @param result lsp.InlayHint?
      local function complete(result)
        resolved[i] = result
        remaining = remaining - 1
        if remaining == 0 then
          local ordered = {} --- @type lsp.InlayHint[]
          for j = 1, #client_hints do
            if resolved[j] then
              ordered[#ordered + 1] = resolved[j]
            end
          end
          apply(ordered)
        end
      end
      if action == 'textEdits' and hint.textEdits ~= nil then
        complete(hint)
      else
        -- Only `position` is replaced, so the rest can stay shared with `hint`.
        local params = vim.tbl_extend('force', {}, hint) --[[@as lsp.InlayHint]]
        params.position =
          vim.pos(bufnr, hint.position.line, hint.position.character):to_lsp(client.offset_encoding)
        local success = client:request('inlayHint/resolve', params, function(err, result)
          if err or not result then
            complete(nil)
          else
            local merged = vim.tbl_deep_extend('force', hint, result)
            -- Keep handler positions byte-indexed, like get(), without changing the cache.
            merged.position = hint.position
            complete(merged)
          end
        end, bufnr)
        if not success then
          complete(nil)
        end
      end
    end
  end

  vim.schedule(function()
    do_action(1)
  end)
end

return M
