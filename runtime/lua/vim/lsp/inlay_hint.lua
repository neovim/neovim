local api = vim.api
local fn = vim.fn
local log = require('vim.lsp.log')
local nvim_on = require('vim._core.util').nvim_on
local util = require('vim.lsp.util')

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
    if vim.fn.win_gettype(vim.fn.bufwinid(bufnr)) == '' then
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

  if vim.fn.win_gettype(vim.fn.bufwinid(bufnr)) == '' then
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

      if not vim.tbl_isempty(vim.fn.win_findbuf(bufnr)) then
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
            local text = ''
            local label = hint.label
            if type(label) == 'string' then
              text = label
            else
              for _, part in ipairs(label) do
                text = text .. part.value
              end
            end
            local vt = hint_virtual_texts[hint.position.character] or {}
            if hint.paddingLeft then
              vt[#vt + 1] = { ' ' }
            end
            vt[#vt + 1] = { text, 'LspInlayHint' }
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

--- @class (private) vim.lsp.inlay_hint.action.hint_label
--- @field hint lsp.InlayHint
--- @field label lsp.InlayHintLabelPart

--- Turn an inlay hint object into the visible text, merging any label parts.
--- Paddings can be optionally included.
--- @param hint lsp.InlayHint
--- @param with_padding boolean?
--- @return string
local function get_label_text(hint, with_padding)
  --- @type string?
  local label
  if type(hint.label) == 'string' then
    label = tostring(hint.label)
  elseif vim.islist(hint.label) then
    ---@type string
    label = vim
      .iter(hint.label)
      :map(
        --- @param part lsp.InlayHintLabelPart
        function(part)
          return part.value
        end
      )
      :join('')
  end

  assert(label ~= nil, 'Failed to extract the label value from the inlay hint')

  if with_padding then
    if hint.paddingLeft then
      label = ' ' .. label
    end
    if hint.paddingRight then
      label = label .. ' '
    end
  end

  return label
end

--- A wrapper of `vim.ui.select` that skips the menu when there's only one item.
--- @generic T
--- @param items T[] Arbitrary items
--- @param opts vim.ui.select.Opts Additional options
--- @param on_choice fun(item: T|nil, idx: integer|nil)
local function do_or_select(items, opts, on_choice)
  if #items == 0 then
    return error('Empty items!')
  end
  if #items == 1 then
    return on_choice(items[1], 1)
  end
  return vim.ui.select(items, opts, on_choice)
end

--- @param path string
--- @param base string?
--- @return string
local function cleanup_path(path, base)
  ---@type string?
  local result = nil
  if base then
    -- relative to `base`
    result = vim.fs.relpath(base, path)
  end
  if result == nil then
    result = fn.fnamemodify(path, ':p:~')
  end
  return result
end

--- Build the range from normal or visual mode based on cursor position.
--- @return vim.Range
local function make_range()
  local bufnr = api.nvim_get_current_buf()
  local winid = fn.bufwinid(bufnr)
  local mode = fn.mode()

  if mode == 'n' then
    local cursor = api.nvim_win_get_cursor(winid)
    -- Include the hints on either side of the cursor.
    local row, col = cursor[1] - 1, cursor[2]
    return vim.range(bufnr, row, col, row, col + 1)
  end

  local start_pos = fn.getpos('v')
  local end_pos = fn.getpos('.')
  if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
    --- @type [integer, integer, integer, integer]
    start_pos, end_pos = end_pos, start_pos
  end
  local start_row, start_col = start_pos[2] - 1, start_pos[3] - 1
  local end_row, end_col = end_pos[2] - 1, end_pos[3]

  if mode == 'V' or mode == 'Vs' then
    start_col = 0
    end_row = end_row + 1
    end_col = 0
  end
  return vim.range(bufnr, start_row, start_col, end_row, end_col)
end

--- Append `new_label` to `labels` if there are no duplicates.
---@param labels vim.lsp.inlay_hint.action.hint_label[]
---@param new_label vim.lsp.inlay_hint.action.hint_label
---@param by_attribute ('location'|'command'|'tooltip')[]|nil When provided, only check for these attributes (and `value`) for equality
local function add_new_label(labels, new_label, by_attribute)
  if
    vim.iter(labels):any(
      ---@param existing_label vim.lsp.inlay_hint.action.hint_label
      function(existing_label)
        -- Check for duplications with existing hint_labels
        if by_attribute then
          -- Check for concerned attributes
          return vim.iter(by_attribute):all(function(attr)
            return existing_label.label.value == new_label.label.value
              and vim.deep_equal(existing_label.label[attr], new_label.label[attr])
          end)
        else
          -- Check the entire label
          return vim.deep_equal(existing_label.label, new_label.label)
        end
      end
    )
  then
    return
  end
  table.insert(labels, new_label)
end

---Return a non-empty list of hint labels, or `nil` if not found.
--- @param hint lsp.InlayHint
--- @param needed_fields ("location"|"command"|"tooltip")[]
--- @return vim.lsp.inlay_hint.action.hint_label[]?
local function get_hint_labels(hint, needed_fields)
  --- @type vim.lsp.inlay_hint.action.hint_label[]
  local hint_labels = {}

  if type(hint.label) == 'table' and #hint.label > 0 then
    vim.iter(hint.label):each(
      --- @param label lsp.InlayHintLabelPart
      function(label)
        if
          vim.iter(needed_fields):any(function(field_name)
            return label[field_name] ~= nil
          end)
        then
          add_new_label(hint_labels, { hint = hint, label = label }, needed_fields)
        end
      end
    )
  end

  if #hint_labels > 0 then
    return hint_labels
  end
end

--- The built-in action handlers.
--- @type table<vim.lsp.inlay_hint.action.name, vim.lsp.inlay_hint.action.handler>
local action_handlers = {
  textEdits = function(hints, ctx, on_done)
    ---@type lsp.InlayHint[]
    local valid_hints = vim
      .iter(hints)
      :filter(
        --- @param hint lsp.InlayHint
        function(hint)
          -- only keep those that have text edits.
          return hint ~= nil and hint.textEdits ~= nil and not vim.tbl_isempty(hint.textEdits)
        end
      )
      :totable()
    --- @type lsp.TextEdit[]
    local text_edits = vim
      .iter(valid_hints)
      :map(
        --- @param hint lsp.InlayHint
        function(hint)
          return hint.textEdits
        end
      )
      :flatten(1)
      :totable()
    if #text_edits == 0 then
      return false
    end
    vim.schedule(function()
      util.apply_text_edits(text_edits, ctx.buf, ctx.client.offset_encoding)
      if on_done then
        on_done({ buf = ctx.buf, client = ctx.client })
      end
    end)
    return true
  end,
  location = function(hints, ctx, on_done)
    --- @type vim.lsp.inlay_hint.action.hint_label[]
    local hint_labels = {}

    vim.iter(hints):each(
      --- @param item lsp.InlayHint
      function(item)
        if type(item.label) == 'table' and #item.label > 0 then
          local labels_from_this = get_hint_labels(item, { 'location' })
          if labels_from_this then
            vim.list_extend(hint_labels, labels_from_this)
          end
        end
      end
    )

    if vim.tbl_isempty(hint_labels) then
      return false
    end

    do_or_select(
      vim
        .iter(hint_labels)
        :map(
          --- @param loc vim.lsp.inlay_hint.action.hint_label
          function(loc)
            local label = loc.label
            return string.format(
              '%s\t%s:%d',
              label.value,
              cleanup_path(vim.uri_to_fname(label.location.uri), ctx.client.root_dir),
              label.location.range.start.line
            )
          end
        )
        :totable(),
      { prompt = 'Location to jump to' },
      function(_, idx)
        if idx == nil then
          -- `vim.ui.select` was cancelled
          if on_done then
            on_done({ buf = ctx.buf })
          end
          return
        end
        util.show_document(
          hint_labels[idx].label.location,
          ctx.client.offset_encoding,
          { reuse_win = true, focus = true }
        )

        if on_done then
          on_done({ buf = api.nvim_get_current_buf(), client = ctx.client })
        end
      end
    )

    return true
  end,

  hover = function(hints, ctx, on_done)
    if #hints == 0 then
      return false
    end
    if #hints ~= 1 then
      vim.schedule(function()
        vim.notify(
          'vim.lsp.inlay_hint.action("hover") only supports showing hover for a single inlay hint.',
          vim.log.levels.WARN
        )
      end)
    end
    local hint = assert(hints[1])
    local hint_labels = get_hint_labels(hint, { 'location' })
    if hint_labels == nil then
      return false
    end

    ---@type string[]
    local lines = {}

    --- Go through the labels to build the content of the hover
    ---@param idx integer?
    ---@param item vim.lsp.inlay_hint.action.hint_label?
    local function get_hover(idx, item)
      if idx == nil or item == nil then
        -- all locations have been processed
        -- open the hover window
        if #lines == 0 then
          lines = { 'Empty' }
        end
        local float_buf, _ = util.open_floating_preview(lines, 'markdown')
        if on_done then
          on_done({ client = ctx.client, buf = float_buf })
        end
        return
      end

      -- `get_hint_labels` makes sure `item.label` has location attribute
      local label_loc = assert(item.label.location)
      ---@type lsp.HoverParams
      local hover_param = {
        textDocument = { uri = label_loc.uri },
        position = label_loc.range.start,
      }
      ctx.client:request(
        'textDocument/hover',
        hover_param,
        ---@param result lsp.Hover?
        function(_, result, _, _)
          if result then
            local md_lines = util.convert_input_to_markdown_lines(result.contents)
            if #md_lines > 0 then
              if #lines > 0 then
                -- Blank line between label parts
                lines[#lines + 1] = ''
              end
              lines[#lines + 1] = string.format('# `%s`', item.label.value)
              vim.list_extend(lines, md_lines)
            end
          end
          get_hover(next(hint_labels, idx))
        end,
        ctx.buf
      )
    end

    get_hover(next(hint_labels))
    return true
  end,

  tooltip = function(hints, ctx, on_done)
    if #hints == 0 then
      return false
    end
    if #hints ~= 1 then
      vim.schedule(function()
        vim.notify(
          'vim.lsp.inlay_hint.action("tooltip") only supports showing tooltips for a single inlay hint.',
          vim.log.levels.WARN
        )
      end)
    end

    local hint = assert(hints[1])
    local hint_labels = get_hint_labels(hint, { 'location', 'command' })

    -- The level 1 heading is the full hint object
    local lines = { string.format('# `%s`', get_label_text(hint, false)), '' }

    if hint.tooltip then
      util.convert_input_to_markdown_lines(hint.tooltip, lines)
    end

    if hint_labels then
      vim.iter(hint_labels):each(
        --- @param hint_label vim.lsp.inlay_hint.action.hint_label
        function(hint_label)
          local label = hint_label.label
          lines[#lines + 1] = ''
          -- each of the level 2 headings is the text of a label part
          lines[#lines + 1] = string.format('## `%s`', label.value)
          lines[#lines + 1] = ''
          if label.tooltip then
            -- borrowed from `vim.lsp.buf.hover()`
            util.convert_input_to_markdown_lines(label.tooltip, lines)
          end
          if label.location then
            -- include the location in this label part
            lines[#lines + 1] = string.format(
              '_Location_: `%s`:%d',
              cleanup_path(vim.uri_to_fname(label.location.uri), ctx.client.root_dir),
              label.location.range.start.line
            )
          end
          if label.command then
            -- include the command associated to this label part
            local command_line = string.format('_Command_: %s', label.command.title)
            if label.command.tooltip then
              command_line = command_line .. string.format(' (%s)', label.command.tooltip)
            end
            lines[#lines + 1] = command_line
          end
        end
      )
    end

    if #lines == 2 then
      -- No tooltip/command/location has been found. Skip this hint.
      return false
    end

    ---@type integer, integer
    local buf, _ = util.open_floating_preview(lines, 'markdown')

    if on_done then
      on_done({ buf = buf, client = ctx.client })
    end
    return true
  end,

  command = function(hints, ctx, on_done)
    if #hints == 0 then
      return false
    end
    if #hints ~= 1 then
      vim.schedule(function()
        vim.notify(
          'vim.lsp.inlay_hint.action("command") only supports showing commands for a single inlay hint.',
          vim.log.levels.WARN
        )
      end)
    end
    local hint_labels = get_hint_labels(assert(hints[1]), { 'command' })
    if hint_labels == nil or #hint_labels == 0 then
      -- no commands in this hint
      return false
    end

    do_or_select(
      vim
        .iter(hint_labels)
        :map(
          --- @param item vim.lsp.inlay_hint.action.hint_label
          function(item)
            local label = item.label
            local entry_line = string.format('%s: %s', label.value, assert(label.command).title)
            if label.tooltip then
              entry_line = entry_line .. string.format(' (%s)', label.tooltip)
            end
            return entry_line
          end
        )
        :totable(),
      { prompt = 'Command to execute' },
      function(_, idx)
        if idx == nil then
          -- `vim.ui.select` was cancelled
          if on_done then
            on_done({ buf = ctx.buf })
          end
          return
        end
        ctx.client:request('workspace/executeCommand', hint_labels[idx].label.command, function(...)
          local default_handler = ctx.client.handlers['workspace/executeCommand']
            or vim.lsp.handlers['workspace/executeCommand']
          if default_handler then
            default_handler(...)
          end
          if on_done then
            on_done({ buf = api.nvim_get_current_buf(), client = ctx.client })
          end
        end, ctx.buf)
      end
    )

    return true
  end,
}

--- @alias vim.lsp.inlay_hint.action.name
---| 'textEdits' -- Insert texts into the buffer
---| 'command' -- See 'workspace/executeCommand'
---| 'location' -- Jump to the location (usually the definition of the identifier or type)
---| 'hover' -- Show a hover window of the symbols shown in the inlay hint
---| 'tooltip' -- Show a hover-like window, containing available tooltips, commands and locations

--- @alias vim.lsp.inlay_hint.action
---| vim.lsp.inlay_hint.action.name
---| vim.lsp.inlay_hint.action.handler

--- @class vim.lsp.inlay_hint.action.context
--- @inlinedoc
--- @field buf integer
--- @field client vim.lsp.Client

--- @class vim.lsp.inlay_hint.action.on_done.context
--- @inlinedoc
---
--- The buffer that ends up focused by the action. If the action opened or jumped to a new
--- buffer, this is that buffer; otherwise it's the buffer the action started from.
--- @field buf integer
---
--- The `vim.lsp.Client` used to invoke the action. `nil` when no action was invoked.
--- @field client? vim.lsp.Client

--- This should be called __exactly__ once in the action handler.
--- @alias vim.lsp.inlay_hint.action.on_done.callback fun(ctx: vim.lsp.inlay_hint.action.on_done.context)

--- @alias vim.lsp.inlay_hint.action.handler fun(hints: lsp.InlayHint[], ctx: vim.lsp.inlay_hint.action.context, on_done: vim.lsp.inlay_hint.action.on_done.callback?):boolean

--- @class vim.lsp.inlay_hint.action.Opts
--- @inlinedoc
---
--- Inlay hints (returned by `vim.lsp.inlay_hint.get()`) to take actions on.
--- When not specified:
---   - in |Normal-mode|, it uses hints on either side of the cursor.
---   - in |Visual-mode|, it uses hints inside the selected range.
--- @field hints? vim.lsp.inlay_hint.get.ret[]
---
--- A callback invoked exactly once (asynchronously) at the end of the action.
--- @field on_done? vim.lsp.inlay_hint.action.on_done.callback

--- Apply some actions provided by inlay hints in the selected range.
---
--- Example usage:
--- ```lua
--- vim.keymap.set(
---   { 'n', 'v' },
---   'gI',
---   function()
---     vim.lsp.inlay_hint.action('textEdits')
---   end,
---   { desc = 'Apply inlay hint textEdits' }
--- )
--- ```
---
--- @param action vim.lsp.inlay_hint.action
--- Possible actions:
--- - `"textEdits"`: insert `textEdits` that comes with the inlay hints.
--- - `"location"`: jump to one of the locations associated with the inlay hints.
--- - `"command"`: execute one of the `lsp.Command`s that comes with the inlay hint.
--- - `"hover"`: if there are some locations associated with the inlay hint, show the hover
---   information of the identifiers at those locations.
--- - `"tooltip"`: show a hover-like window that contains the `tooltip`, available `command`s and
---   `location`s that comes with the inlay hint.
--- - a custom handler with 3 parameters:
---   - `hints`: `lsp.InlayHint[]` a list of inlay hints in the requested range.
---   - `ctx`: `{buf: integer, client: vim.lsp.Client}` the buffer on which the action is taken, and the LSP client that provides `hints`.
---   - `on_done`: `fun(ctx: {buf: integer, client?: vim.lsp.Client})` see `on_done` in {opts}.
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

  local action_handler = action
  if type(action) == 'string' then
    action_handler = action_handlers[action]
    --- @cast action_handler -vim.lsp.inlay_hint.action.name
  end

  local bufnr = api.nvim_get_current_buf()

  local on_done_called = false
  local on_done = opts.on_done
  if on_done then
    local original_on_done = on_done
    -- Decorate `on_done` to make sure it is only called once.
    ---@type vim.lsp.inlay_hint.action.on_done.callback
    on_done = function(...)
      assert(not on_done_called, '`on_done` should only be called once.')
      on_done_called = true
      return original_on_done(...)
    end
  end

  local hints = opts.hints
  if hints == nil then
    local range = make_range()
    hints = M.get({
      range = {
        -- In `M.on_inlayhint`,
        -- the inlay hints are stored by byte indices, not lsp positions (utf-*),
        -- so we can't use `vim.range.to_lsp`
        start = { line = range.start_row, character = range.start_col },
        ['end'] = { line = range.end_row, character = range.end_col },
      },
      bufnr = bufnr,
    })
  end
  --- Group inlay hints by clients.
  ---@type table<integer, lsp.InlayHint[]>
  local hints_by_clients = vim.defaulttable()

  vim.iter(hints):each(
    ---@param item vim.lsp.inlay_hint.get.ret
    function(item)
      table.insert(hints_by_clients[item.client_id], item.inlay_hint)
    end
  )

  local client_ids = vim.tbl_keys(hints_by_clients)
  -- `vim.tbl_keys` ordering is not deterministic; try clients in a stable order.
  table.sort(client_ids)

  ---@type vim.lsp.Client[]
  local clients = vim
    .iter(client_ids)
    :map(function(cli_id)
      return vim.lsp.get_client_by_id(cli_id)
    end)
    :totable()

  --- Iterate through `clients` and requests for inlay hints.
  --- If a client provides no inlay hint (`nil` or `{}`) for the given range, or the provided hints don't contain
  --- the attributes needed for the action, proceed to the next client. Otherwise, the action is
  --- successful. Terminate the iteration.
  --- @param idx? integer
  --- @param client? vim.lsp.Client
  local function do_action(idx, client)
    if idx == nil or client == nil or on_done_called then
      -- all clients have been consumed. Terminate the iteration.
      if on_done and not on_done_called then
        on_done({ buf = api.nvim_get_current_buf() })
      end
      return
    end

    local _hints = hints_by_clients[client.id]

    if #_hints == 0 then
      -- no hints in the given range.
      return do_action(next(clients, idx))
    end

    local support_resolve = client:supports_method('inlayHint/resolve', bufnr)
    local action_ctx = { buf = bufnr, client = client }

    if not support_resolve then
      -- no need to resolve because the client doesn't support it.
      if not action_handler(_hints, action_ctx, on_done) then
        -- no actions invoked. proceed with the client.
        return do_action(next(clients, idx))
      else
        -- actions were taken. we're done with the actions.
        return
      end
    end

    --- NOTE: make async `inlayHint/resolve` requests in parallel

    -- Use `num_processed` to keep track of the number of resolved hints.
    -- When this equals `#hints`, it means we're ready to invoke the actions.
    --- @type integer
    local num_processed = 0

    for i, h in ipairs(_hints) do
      client:request('inlayHint/resolve', h, function(_, _result, _, _)
        if _result ~= nil and _hints[i] then
          _hints[i] = vim.tbl_deep_extend('force', _hints[i], _result)
        end
        num_processed = num_processed + 1

        if num_processed == #_hints then
          -- all hints have been resolved. we're now ready to invoke the action.
          if not action_handler(_hints, action_ctx, on_done) then
            return do_action(next(clients, idx))
          else
            -- Actions were taken. we're done with the actions.
            return
          end
        end
      end, bufnr)
    end
  end

  do_action(next(clients))
end

return M
