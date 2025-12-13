local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local api = vim.api
local fn = vim.fn
local M = {}

---@class (private) vim.lsp.inlay_hint.globalstate Global state for inlay hints
---@field enabled boolean Whether inlay hints are enabled for this scope
---@type vim.lsp.inlay_hint.globalstate
local globalstate = {
  enabled = false,
}

---@class (private) vim.lsp.inlay_hint.bufstate: vim.lsp.inlay_hint.globalstate Buffer local state for inlay hints
---@field version? integer
---@field client_hints? table<integer, table<integer, lsp.InlayHint[]>> client_id -> (lnum -> hints)
---@field applied table<integer, integer> Last version of hints applied to this line

---@type table<integer, vim.lsp.inlay_hint.bufstate>
local bufstates = vim.defaulttable(function(_)
  return setmetatable({ applied = {} }, {
    __index = globalstate,
    __newindex = function(state, key, value)
      if globalstate[key] == value then
        rawset(state, key, nil)
      else
        rawset(state, key, value)
      end
    end,
  })
end)

local namespace = api.nvim_create_namespace('nvim.lsp.inlayhint')
local augroup = api.nvim_create_augroup('nvim.lsp.inlayhint', {})

--- |lsp-handler| for the method `textDocument/inlayHint`
--- Store hints for a specific buffer and client
---@param result lsp.InlayHint[]?
---@param ctx lsp.HandlerContext
---@private
function M.on_inlayhint(err, result, ctx)
  if err then
    log.error('inlayhint', err)
    return
  end
  local bufnr = assert(ctx.bufnr)

  if
    util.buf_versions[bufnr] ~= ctx.version
    or not api.nvim_buf_is_loaded(bufnr)
    or not bufstates[bufnr].enabled
  then
    return
  end
  local client_id = ctx.client_id
  local bufstate = bufstates[bufnr]
  if not (bufstate.client_hints and bufstate.version) then
    bufstate.client_hints = vim.defaulttable()
    bufstate.version = ctx.version
  end
  local client_hints = bufstate.client_hints
  local client = assert(vim.lsp.get_client_by_id(client_id))

  -- If there's no error but the result is nil, clear existing hints.
  result = result or {}

  local new_lnum_hints = vim.defaulttable()
  local num_unprocessed = #result
  if num_unprocessed == 0 then
    client_hints[client_id] = {}
    bufstate.version = ctx.version
    api.nvim__redraw({ buf = bufnr, valid = true, flush = false })
    return
  end

  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for _, hint in ipairs(result) do
    local lnum = hint.position.line
    local line = lines and lines[lnum + 1] or ''
    hint.position.character =
      vim.str_byteindex(line, client.offset_encoding, hint.position.character, false)
    table.insert(new_lnum_hints[lnum], hint)
  end

  client_hints[client_id] = new_lnum_hints
  bufstate.version = ctx.version
  api.nvim__redraw({ buf = bufnr, valid = true, flush = false })
end

--- Refresh inlay hints, only if we have attached clients that support it
---@param bufnr (integer) Buffer handle, or 0 for current
---@param client_id? (integer) Client ID, or nil for all
local function refresh(bufnr, client_id)
  for _, client in
    ipairs(vim.lsp.get_clients({
      bufnr = bufnr,
      id = client_id,
      method = 'textDocument/inlayHint',
    }))
  do
    client:request('textDocument/inlayHint', {
      textDocument = util.make_text_document_params(bufnr),
      range = util._make_line_range_params(
        bufnr,
        0,
        api.nvim_buf_line_count(bufnr) - 1,
        client.offset_encoding
      ),
    }, nil, bufnr)
  end
end

--- |lsp-handler| for the method `workspace/inlayHint/refresh`
---@param ctx lsp.HandlerContext
---@private
function M.on_refresh(err, _, ctx)
  if err then
    return vim.NIL
  end
  for bufnr in pairs(vim.lsp.get_client_by_id(ctx.client_id).attached_buffers or {}) do
    for _, winid in ipairs(api.nvim_list_wins()) do
      if api.nvim_win_get_buf(winid) == bufnr then
        if bufstates[bufnr] and bufstates[bufnr].enabled then
          bufstates[bufnr].applied = {}
          refresh(bufnr)
        end
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
--- local resolved_hint = assert(resp and resp.result, resp.err)
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
    --- @type vim.lsp.inlay_hint.get.ret[]
    local hints = {}
    --- @param buf integer
    vim.tbl_map(function(buf)
      vim.list_extend(hints, M.get(vim.tbl_extend('keep', { bufnr = buf }, filter)))
    end, api.nvim_list_bufs())
    return hints
  else
    bufnr = vim._resolve_bufnr(bufnr)
  end

  local bufstate = bufstates[bufnr]
  if not bufstate.client_hints then
    return {}
  end

  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    method = 'textDocument/inlayHint',
  })
  if #clients == 0 then
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
  for _, client in pairs(clients) do
    local lnum_hints = bufstate.client_hints[client.id]
    if lnum_hints then
      for lnum = range.start.line, range['end'].line do
        local hints = lnum_hints[lnum] or {}
        for _, hint in pairs(hints) do
          local line, char = hint.position.line, hint.position.character
          if
            (line > range.start.line or char >= range.start.character)
            and (line < range['end'].line or char <= range['end'].character)
          then
            table.insert(result, {
              bufnr = bufnr,
              client_id = client.id,
              inlay_hint = hint,
            })
          end
        end
      end
    end
  end
  return result
end

--- Clear inlay hints
---@param bufnr (integer) Buffer handle, or 0 for current
local function clear(bufnr)
  bufnr = vim._resolve_bufnr(bufnr)
  local bufstate = bufstates[bufnr]
  local client_lens = (bufstate or {}).client_hints or {}
  local client_ids = vim.tbl_keys(client_lens) --- @type integer[]
  for _, iter_client_id in ipairs(client_ids) do
    if bufstate then
      bufstate.client_hints[iter_client_id] = {}
    end
  end
  api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  api.nvim__redraw({ buf = bufnr, valid = true, flush = false })
end

--- Disable inlay hints for a buffer
---@param bufnr (integer) Buffer handle, or 0 for current
local function _disable(bufnr)
  bufnr = vim._resolve_bufnr(bufnr)
  clear(bufnr)
  bufstates[bufnr] = nil
  bufstates[bufnr].enabled = false
end

--- Enable inlay hints for a buffer
---@param bufnr (integer) Buffer handle, or 0 for current
local function _enable(bufnr)
  bufnr = vim._resolve_bufnr(bufnr)
  bufstates[bufnr] = nil
  bufstates[bufnr].enabled = true
  refresh(bufnr)
end

api.nvim_create_autocmd('LspNotify', {
  callback = function(args)
    ---@type integer
    local bufnr = args.buf

    if
      args.data.method ~= 'textDocument/didChange'
      and args.data.method ~= 'textDocument/didOpen'
    then
      return
    end
    if bufstates[bufnr].enabled then
      refresh(bufnr, args.data.client_id)
    end
  end,
  group = augroup,
})
api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    ---@type integer
    local bufnr = args.buf

    api.nvim_buf_attach(bufnr, false, {
      on_reload = function(_, cb_bufnr)
        clear(cb_bufnr)
        if bufstates[cb_bufnr] and bufstates[cb_bufnr].enabled then
          bufstates[cb_bufnr].applied = {}
          refresh(cb_bufnr)
        end
      end,
      on_detach = function(_, cb_bufnr)
        _disable(cb_bufnr)
        bufstates[cb_bufnr] = nil
      end,
    })
  end,
  group = augroup,
})
api.nvim_create_autocmd('LspDetach', {
  callback = function(args)
    ---@type integer
    local bufnr = args.buf
    local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/inlayHint' })

    if not vim.iter(clients):any(function(c)
      return c.id ~= args.data.client_id
    end) then
      _disable(bufnr)
    end
  end,
  group = augroup,
})
api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, _, bufnr, topline, botline)
    ---@type vim.lsp.inlay_hint.bufstate
    local bufstate = rawget(bufstates, bufnr)
    if not bufstate then
      return
    end

    if bufstate.version ~= util.buf_versions[bufnr] then
      return
    end

    if not bufstate.client_hints then
      return
    end
    local client_hints = assert(bufstate.client_hints)

    for lnum = topline, botline do
      if bufstate.applied[lnum] ~= bufstate.version then
        api.nvim_buf_clear_namespace(bufnr, namespace, lnum, lnum + 1)

        local hint_virtual_texts = {} --- @type table<integer, [string, string?][]>
        for _, lnum_hints in pairs(client_hints) do
          local hints = lnum_hints[lnum] or {}
          for _, hint in pairs(hints) do
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
          api.nvim_buf_set_extmark(bufnr, namespace, lnum, pos, {
            virt_text_pos = 'inline',
            ephemeral = false,
            virt_text = vt,
          })
        end

        bufstate.applied[lnum] = bufstate.version
      end
    end
  end,
})

--- Query whether inlay hint is enabled in the {filter}ed scope
--- @param filter? vim.lsp.inlay_hint.enable.Filter
--- @return boolean
--- @since 12
function M.is_enabled(filter)
  vim.validate('filter', filter, 'table', true)
  filter = filter or {}
  local bufnr = filter.bufnr

  if bufnr == nil then
    return globalstate.enabled
  end
  return bufstates[vim._resolve_bufnr(bufnr)].enabled
end

--- Optional filters |kwargs|, or `nil` for all.
--- @class vim.lsp.inlay_hint.enable.Filter
--- @inlinedoc
--- Buffer number, or 0 for current buffer, or nil for all.
--- @field bufnr integer?

--- Enables or disables inlay hints for the {filter}ed scope.
---
--- To "toggle", pass the inverse of `is_enabled()`:
---
--- ```lua
--- vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
--- ```
---
--- @param enable (boolean|nil) true/nil to enable, false to disable
--- @param filter vim.lsp.inlay_hint.enable.Filter?
--- @since 12
function M.enable(enable, filter)
  vim.validate('enable', enable, 'boolean', true)
  vim.validate('filter', filter, 'table', true)
  enable = enable == nil or enable
  filter = filter or {}

  if filter.bufnr == nil then
    globalstate.enabled = enable
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
      if api.nvim_buf_is_loaded(bufnr) then
        if enable == false then
          _disable(bufnr)
        else
          _enable(bufnr)
        end
      else
        bufstates[bufnr] = nil
      end
    end
  else
    if enable == false then
      _disable(filter.bufnr)
    else
      _enable(filter.bufnr)
    end
  end
end

--- @class (private) vim.lsp.inlay_hint.action.LocationItem
--- @field hint_name string
--- @field hint_position lsp.Position
--- @field label_name string
--- @field location lsp.Location

--- @class (private) vim.lsp.inlay_hint.action.hint_label
--- @field hint lsp.InlayHint
--- @field label lsp.InlayHintLabelPart

local action_helpers = {
  --- turn an inlay hint object into the visible text, merging any label parts.
  --- paddings can be optionally included.
  --- @param hint lsp.InlayHint
  --- @param with_padding boolean?
  --- @return string
  get_label_text = function(hint, with_padding)
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
  end,

  --- a wrapper of `vim.ui.select` that skips the menu when there's only one item.
  --- @generic T
  --- @param items T[] Arbitrary items
  --- @param opts vim.ui.select.Opts Additional options
  --- @param on_choice fun(item: T|nil, idx: integer|nil)
  do_or_select = function(items, opts, on_choice)
    if #items == 0 then
      return error('Empty items!')
    end
    if #items == 1 then
      return on_choice(items[1], 1)
    end
    return vim.ui.select(items, opts, on_choice)
  end,

  --- @param path string
  --- @param base string?
  --- @return string
  cleanup_path = function(path, base)
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
  end,

  --- build the range from normal or visual mode based on cursor position.
  --- @return vim.Range
  make_range = function()
    local bufnr = api.nvim_get_current_buf()
    local winid = fn.bufwinid(bufnr)
    local mode = fn.mode()

    -- mark position, (1, 0) indexed, end-exclusive
    --- @type {start: vim.Pos, end: vim.Pos}
    local range = {}

    if mode == 'n' then
      local cursor = api.nvim_win_get_cursor(winid)
      range.start = vim.pos.cursor(cursor)
      range['end'] = vim.pos.cursor(cursor)
      range['end'].col = range['end'].col + 2
    else
      local start_pos = fn.getpos('v')
      local end_pos = fn.getpos('.')
      if
        start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3])
      then
        --- @type [integer, integer, integer, integer]
        start_pos, end_pos = end_pos, start_pos
      end
      range = {
        start = vim.pos.cursor({ start_pos[2], start_pos[3] - 1 }),
        ['end'] = vim.pos.cursor({ end_pos[2], end_pos[3] }),
      }

      if mode == 'V' or mode == 'Vs' then
        range.start.col = 0
        range['end'].row = range['end'].row + 1
        range['end'].col = 0
      end
    end
    range.start.buf = bufnr
    range['end'].buf = bufnr
    return vim.range(range.start, range['end'])
  end,

  --- Append `new_label` to `labels` if there's no duplicates.
  ---@param labels vim.lsp.inlay_hint.action.hint_label[]
  ---@param new_label vim.lsp.inlay_hint.action.hint_label
  ---@param by_attribute ('location'|'command'|'tooltip')[]|nil When provided, only check for these attributes (and `value`) for equality
  add_new_label = function(labels, new_label, by_attribute)
    if
      vim.iter(labels):any(
        ---@param existing_label vim.lsp.inlay_hint.action.hint_label
        function(existing_label)
          -- check for duplications with existing hint_labels
          if by_attribute then
            -- check for concerned attributes
            return vim.iter(by_attribute):all(function(attr)
              return existing_label.label.value == new_label.label.value
                and vim.deep_equal(existing_label.label[attr], new_label.label[attr])
            end)
          else
            -- check the entire label
            return vim.deep_equal(existing_label.label, new_label.label)
          end
        end
      )
    then
      return
    end
    table.insert(labels, new_label)
  end,
}

---Return a non-empty list of lsp locations, or `nil` if not found.
--- @param hint lsp.InlayHint
--- @param needed_fields ("location"|"command"|"tooltip")[]?
--- @return vim.lsp.inlay_hint.action.hint_label[]?
action_helpers.get_hint_labels = function(hint, needed_fields)
  vim.validate('needed_fields', needed_fields, function(val)
    return vim.islist(val)
      and vim.iter(needed_fields):any(function(field)
        return vim.list_contains({ 'location', 'command', 'tooltip' }, field)
      end)
  end, false)
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
          action_helpers.add_new_label(hint_labels, { hint = hint, label = label }, needed_fields)
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
local inlayhint_actions = {
  textEdits = function(hints, ctx, on_finish)
    ---@type lsp.InlayHint
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
    if #text_edits > 0 then
      vim.schedule(function()
        util.apply_text_edits(text_edits, ctx.bufnr, ctx.client.offset_encoding)
        if on_finish then
          on_finish({ bufnr = ctx.bufnr, client = ctx.client })
        end
      end)
    end
    return #valid_hints
  end,
  location = function(hints, ctx, on_finish)
    local count = 0

    --- @type vim.lsp.inlay_hint.action.hint_label[]
    local hint_labels = {}

    vim.iter(hints):each(
      --- @param item lsp.InlayHint
      function(item)
        if type(item.label) == 'table' and #item.label > 0 then
          local labels_from_this = action_helpers.get_hint_labels(item, { 'location' })
          if labels_from_this then
            count = count + 1
            vim.list_extend(hint_labels, labels_from_this)
          end
        end
      end
    )

    if vim.tbl_isempty(hint_labels) then
      return 0
    end

    action_helpers.do_or_select(
      vim
        .iter(hint_labels)
        :map(
          --- @param loc vim.lsp.inlay_hint.action.hint_label
          function(loc)
            local label = loc.label
            return string.format(
              '%s\t%s:%d',
              label.value,
              action_helpers.cleanup_path(vim.uri_to_fname(label.location.uri), ctx.client.root_dir),
              label.location.range.start.line
            )
          end
        )
        :totable(),
      { prompt = 'Location to jump to' },
      function(_, idx)
        if idx then
          util.show_document(
            hint_labels[idx].label.location,
            ctx.client.offset_encoding,
            { reuse_win = true, focus = true }
          )

          if on_finish then
            on_finish({ bufnr = api.nvim_get_current_buf(), client = ctx.client })
          end
        end
      end
    )

    return count
  end,

  hover = function(hints, ctx, on_finish)
    if #hints == 0 then
      return 0
    end
    if #hints ~= 1 then
      vim.schedule(function()
        vim.notify(
          'vim.lsp.inlay_hint.apply_action("tooltip") only supports showing tooltips for a single inlay hint.',
          vim.log.levels.WARN
        )
      end)
    end
    local hint = assert(hints[1])
    local hint_labels = action_helpers.get_hint_labels(hint, { 'location' })
    if hint_labels == nil then
      return 0
    end

    ---@type string[]
    local lines = {}

    --- Go though the labels to build the content of the hover
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
        if on_finish then
          on_finish({ client = ctx.client, bufnr = float_buf })
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
                -- blank line between label parts
                lines[#lines + 1] = ''
              end
              lines[#lines + 1] = string.format('# `%s`', item.label.value)
              vim.list_extend(lines, md_lines)
            end
          end
          get_hover(next(hint_labels, idx))
        end,
        ctx.bufnr
      )
    end

    get_hover(next(hint_labels))
    return 1
  end,

  tooltip = function(hints, ctx, on_finish)
    if #hints == 0 then
      return 0
    end
    if #hints ~= 1 then
      vim.schedule(function()
        vim.notify(
          'vim.lsp.inlay_hint.apply_action("tooltip") only supports showing tooltips for a single inlay hint.',
          vim.log.levels.WARN
        )
      end)
    end

    local hint = assert(hints[1])
    local hint_labels = action_helpers.get_hint_labels(hint, { 'location', 'command' })

    -- the level 1 heading is the full hint object
    local lines = { string.format('# `%s`', action_helpers.get_label_text(hint, false)), '' }

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
              action_helpers.cleanup_path(vim.uri_to_fname(label.location.uri), ctx.client.root_dir),
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
      -- no tooltip/command/location has been found. Skip this hint.
      return 0
    end

    ---@type integer, integer
    local buf, _ = util.open_floating_preview(lines, 'markdown')

    if on_finish then
      on_finish({ bufnr = buf, client = ctx.client })
    end
    return 1
  end,

  command = function(hints, ctx, on_finish)
    if #hints ~= 1 then
      vim.schedule(function()
        vim.notify(
          'vim.lsp.inlay_hint.apply_action("command") only supports showing commands for a single inlay hint.',
          vim.log.levels.WARN
        )
      end)
    end
    if #hints == 0 then
      return 0
    end
    local hint_labels = action_helpers.get_hint_labels(assert(hints[1]), { 'command' })
    if hint_labels == nil or #hint_labels == 0 then
      -- no commands in this hint
      return 0
    end

    action_helpers.do_or_select(
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
          if on_finish then
            on_finish({ bufnr = ctx.bufnr, client = ctx.client })
          end
          return
        end
        ctx.client:request('workspace/executeCommand', hint_labels[idx].label.command, function(...)
          local default_handler = ctx.client.handlers['workspace/executeCommand']
            or vim.lsp.handlers['workspace/executeCommand']
          if default_handler then
            default_handler(...)
          end
          if on_finish then
            on_finish({ bufnr = api.nvim_get_current_buf(), client = ctx.client })
          end
        end, ctx.bufnr)
      end
    )

    return 1
  end,
}

--- @alias vim.lsp.inlay_hint.action.name
---| 'textEdits' -- insert texts into the buffer
---| 'command' -- See 'workspace/executeCommand'
---| 'location' -- Jump to the location (usually the definition of the identifier or type)
---| 'hover' -- show a hover window of the symbols shown in the inlay hint
---| 'tooltip' -- show a hover-like window, containing available tooltips, commands and locations

--- @alias vim.lsp.inlay_hint.action
---| vim.lsp.inlay_hint.action.name
---| vim.lsp.inlay_hint.action.handler

--- @class vim.lsp.inlay_hint.action.context
--- @inlinedoc
--- @field bufnr integer
--- @field client vim.lsp.Client

--- @class vim.lsp.inlay_hint.action.on_finish.context
--- @inlinedoc
--- @field client? vim.lsp.Client The LSP client used to trigger the action if the action was successfully triggered.
--- If the action opened or jumped to a new buffer, this will be the buffer number.
--- Otherwise it'll be the original buffer.
--- @field bufnr integer

--- This should be called __exactly__ once in the action handler.
--- @alias vim.lsp.inlay_hint.action.on_finish.callback fun(ctx: vim.lsp.inlay_hint.action.on_finish.context)

--- @alias vim.lsp.inlay_hint.action.handler fun(hints: lsp.InlayHint[], ctx: vim.lsp.inlay_hint.action.context, on_finish: vim.lsp.inlay_hint.action.on_finish.callback?):integer

--- @class vim.lsp.inlay_hint.action.Opts
--- @inlinedoc
--- Inlay hints (returned by `vim.lsp.inlay_hint.get()`) to take actions on.
--- When not specified:
---   - in |Normal-mode|, it uses hints on either side of the cursor.
---   - in |Visual-mode|, it uses hints inside the selected range.
--- @field hints? vim.lsp.inlay_hint.get.ret[]

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
---   - `ctx`: `{bufnr: integer, client: vim.lsp.Client}` the buffer number on which the action is taken, and the LSP client that provides `hints`.
---   - `on_finish`: `fun(_ctx: {bufnr: integer, client?: vim.lsp.Client})` see the `callback` parameter of `vim.lsp.inlay_hint.apply_action`.
---     When implementing a custom handler, the `on_finish` callback should be called when the handler is returning a non-zero value.
---
---   This custom handler should also return the number of items in `hints` that contributed to the action. For example, the `location` handler should return `1` on a successful jump because the target location is from 1 inlay hint object, regardless of the number of hints in `hints`.
--- @param opts? vim.lsp.inlay_hint.action.Opts
--- @param callback? fun(ctx: {bufnr: integer, client?: vim.lsp.Client})
--- A callback function that will be triggered exactly once (asynchronously) at the end of the action.
--- It accepts a table with the following keys as the parameter:
--- - `bufnr`: the buffer number that is focused on. If there's any jump-to-location or pop-up,
---   this'll points you to the new buffer.
--- - `client?`: the `vim.lsp.Client` used to invoke the action. `nil` when the action failed
---   to be invoked.
function M.action(action, opts, callback)
  vim.validate('action', action, function(val)
    return type(val) == 'function' or type(inlayhint_actions[val]) == 'function'
  end, false)
  vim.validate('opts', opts, 'table', true)
  vim.validate('callback', callback, 'function', true)

  local action_handler = action
  if type(action) == 'string' then
    action_handler = inlayhint_actions[action]
    --- @cast action_handler -vim.lsp.inlay_hint.action.name
  end

  opts = opts or {}

  local bufnr = api.nvim_get_current_buf()

  local on_finish_cb_called = false
  if callback then
    local original_callback = callback
    -- decorate the `on_finish` callback to make sure it only called once.
    ---@type vim.lsp.inlay_hint.action.on_finish.callback
    callback = function(...)
      assert(not on_finish_cb_called, 'The callback should only be called once.')
      on_finish_cb_called = true
      return original_callback(...)
    end
  end

  local hints = opts.hints
  if hints == nil then
    local range = action_helpers.make_range()
    hints = M.get({
      range = {
        -- in `M.on_inlayhint`,
        -- the inlay hints are stored by byte indices, not lsp positions (utf-*),
        -- so we can't use `vim.range.to_lsp`
        start = { line = range.start.row, character = range.start.col },
        ['end'] = { line = range.end_.row, character = range.end_.col },
      },
      bufnr = bufnr,
    })
  end
  --- group inlay hints by clients.
  ---@type table<integer, lsp.InlayHint[]>
  local hints_by_clients = vim.defaulttable(function(_)
    return {}
  end)

  vim.iter(hints):each(
    ---@param item vim.lsp.inlay_hint.get.ret
    function(item)
      table.insert(hints_by_clients[item.client_id], item.inlay_hint)
    end
  )

  ---@type vim.lsp.Client[]
  local clients = vim
    .iter(vim.tbl_keys(hints_by_clients))
    :map(function(cli_id)
      return vim.lsp.get_client_by_id(cli_id)
    end)
    :totable()

  --- iterate through `clients` and requests for inlay hints.
  --- If a client provides no inlay hint (`nil` or `{}`) for the given range, or the provided hints don't contain
  --- the attributes needed for the the action, proceed to the next client. Otherwise, the action is
  --- successful. Terminate the iteration.
  --- @param idx? integer
  --- @param client? vim.lsp.Client
  local function do_action(idx, client)
    if idx == nil or client == nil or on_finish_cb_called then
      -- all clients have been consumed. Terminate the iteration.
      if callback and not on_finish_cb_called then
        callback({ bufnr = api.nvim_get_current_buf() })
      end
      return
    end

    local hints = hints_by_clients[client.id]

    if #hints == 0 then
      -- no hints in the given range.
      return do_action(next(clients, idx))
    end

    local support_resolve = client:supports_method('inlayHint/resolve', bufnr)
    local action_ctx = { bufnr = bufnr, client = client }

    if not support_resolve then
      -- no need to resolve because the client doesn't support it.
      if action_handler(hints, action_ctx, callback) == 0 then
        -- no actions invoked. proceed with the client.
        return do_action(next(clients, idx))
      else
        -- actions were taken. we're done with the actions.
        return
      end
    end

    --- NOTE: make async `inlayHint/resolve` requests in parallel

    -- use `num_processed` to keep track of the number of resolved hints.
    -- When this equals `#hints`, it means we're ready to invoke the actions.
    --- @type integer
    local num_processed = 0

    for i, h in ipairs(hints) do
      client:request('inlayHint/resolve', h, function(_, _result, _, _)
        if _result ~= nil and hints[i] then
          hints[i] = vim.tbl_deep_extend('force', hints[i], _result)
        end
        num_processed = num_processed + 1

        if num_processed == #hints then
          -- all hints have been resolved. we're now ready to invoke the action.
          if action_handler(hints, action_ctx, callback) == 0 then
            return do_action(next(clients, idx))
          else
            -- actions were taken. we're done with the actions.
            return
          end
        end
      end, bufnr)
    end
  end

  do_action(next(clients))
end

return M
