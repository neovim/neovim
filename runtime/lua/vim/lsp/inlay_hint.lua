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

--- @alias vim.lsp.inlay_hint.action.callback fun(hints: lsp.InlayHint[], ctx: vim.lsp.inlay_hint.action.context):integer

--- @alias vim.lsp.inlay_hint.action.name
---| 'textEdits' -- insert texts into the buffer
---| 'command' -- See 'workspace/executeCommand'
---| 'location' -- Jump to the location (usually the definition of the identifier or type)
---| 'tooltip' -- show a hover-like window, containing availabletooltips, commands and locations

--- @alias vim.lsp.inlay_hint.action
---| vim.lsp.inlay_hint.action.name
---| vim.lsp.inlay_hint.action.callback

--- @class vim.lsp.inlay_hint.action.context
--- @inlinedoc
--- @field bufnr integer
--- @field client vim.lsp.Client

--- @class (private) vim.lsp.inlay_hint.action.LocationItem
--- @field hint_name string
--- @field hint_position lsp.Position
--- @field label_name string
--- @field location lsp.Location

--- @class (private) vim.lsp.inlay_hint.action.hint_label
--- @field hint lsp.InlayHint
--- @field labal lsp.InlayHintLabelPart

local action_helpers = {
  --- @param hint lsp.InlayHint
  --- @param with_padding boolean?
  --- @return string
  get_label_text = function(hint, with_padding)
    --- @type string?
    local label
    if type(hint.label) == 'string' then
      label = tostring(hint.label)
    elseif vim.islist(hint.label) then
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
    path = vim.fs.abspath(path)
    base = base or vim.env.HOME
    return vim.fs.relpath(base, path, {}) or path
  end,

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

    return vim.range(range.start, range['end'])
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
          hint_labels[#hint_labels + 1] = {
            hint = hint,
            labal = label,
          }
        end
      end
    )
  end

  if #hint_labels > 0 then
    return hint_labels
  end
end

--- @type table<vim.lsp.inlay_hint.action.name, vim.lsp.inlay_hint.action.callback>
local inlayhint_actions = {
  textEdits = function(hints, ctx)
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
      end)
    end
    return #valid_hints
  end,
  location = function(hints, ctx)
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
            local hint = loc.hint
            local label = loc.labal
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
            hint_labels[idx].labal.location,
            ctx.client.offset_encoding,
            { reuse_win = true, focus = true }
          )
        end
      end
    )

    return count
  end,

  tooltip = function(hints, ctx)
    if #hints ~= 1 then
      vim.schedule(function()
        vim.notify(
          'vim.lsp.inlay_hint.apply_action("tooltip") only supports showing tooltips for a single inlay hint.',
          vim.log.levels.WARN
        )
      end)
    end

    local hint = hints[1]
    local hint_labels = action_helpers.get_hint_labels(hint, { 'location', 'command' })

    local lines = { string.format('# `%s`', action_helpers.get_label_text(hint, false)), '' }

    if hint.tooltip then
      util.convert_input_to_markdown_lines(hint.tooltip, lines)
    end

    if hint_labels then
      vim.iter(hint_labels):each(
        --- @param hint_label vim.lsp.inlay_hint.action.hint_label
        function(hint_label)
          local label = hint_label.labal
          lines[#lines + 1] = ''
          lines[#lines + 1] = string.format('## `%s`', label.value)
          lines[#lines + 1] = ''
          if label.tooltip then
            util.convert_input_to_markdown_lines(label.tooltip, lines)
          end
          if label.location then
            lines[#lines + 1] = string.format(
              '_Location_: `%s`:%d',
              action_helpers.cleanup_path(vim.uri_to_fname(label.location.uri), ctx.client.root_dir),
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
      )
    end

    if #lines == 2 then
      -- no tooltip/command/location has been found. Skip this hint.
      return 0
    end

    util.open_floating_preview(lines, 'markdown')
    return 1
  end,

  command = function(hints, ctx)
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
    local hint_labels = action_helpers.get_hint_labels(hints[1], { 'command' })
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
            local label = item.labal
            local entry_line = string.format('%s: %s', label.value, label.command.title)
            if label.tooltip then
              entry_line = entry_line .. string.format(' (%s)', label.tooltip)
            end
            return entry_line
          end
        )
        :totable(),
      { prompt = 'Command to execute' },
      function(_, idx)
        ctx.client:request(
          'workspace/executeCommand',
          hint_labels[idx].labal.command,
          nil,
          ctx.bufnr
        )
      end
    )
    return 1
  end,
}

--- @class vim.lsp.inlay_hint.action.Opts
--- @inlinedoc
--- @field range? vim.Range

--- Apply one of the following actions provided by inlay hints in the
--- selected range.
---
--- - In |Normal-mode|, the action applies to inlay hints that are adjacent to the cursor.
--- - In |Visual-mode|, the action applies to inlay hints that are in the visually selected range.
---
--- Example usage:
--- ```lua
--- vim.keymap.set(
---   { 'n', 'v' },
---   'gI',
---   function()
---     vim.lsp.inlay_hint.apply_action('textEdits')
---   end,
---   { desc = 'Apply inlay hint edits' }
--- )
--- ```
---
--- @param action vim.lsp.inlay_hint.action
--- Possible actions:
--- - `"textEdits"`
--- - `"tooltip"`
--- - `"location"`
--- - `"command"`
--- - a custom callback:
--- `fun(hints: lsp.InlayHint[], ctx: vim.lsp.inlay_hint.action.context):integer`, which accepts the resolved inlay hints in the given range and some context, perform some actions and returns the number of hints on which the actions were taken.
--- @param opts? vim.lsp.inlay_hint.action.Opts
function M.apply_action(action, opts)
  local action_callback = action
  if type(action) == 'string' then
    action_callback = inlayhint_actions[action]
    --- @cast action_callback -vim.lsp.inlay_hint.action.name
  end
  if type(action_callback) ~= 'function' then
    return error('Unsupported action: ' .. action)
  end

  opts = opts or {}

  local bufnr = api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/inlayHint' })

  local range = opts.range or action_helpers.make_range()

  --- @param idx? integer
  --- @param client vim.lsp.Client
  local function do_insert(idx, client)
    if idx == nil then
      return
    end

    local params = util.make_given_range_params(
      range.start:to_cursor(),
      range.end_:to_cursor(),
      bufnr,
      client.offset_encoding
    )
    local support_resolve = client:supports_method('inlayHint/resolve', bufnr)

    client:request(
      'textDocument/inlayHint',
      params,
      --- @param result lsp.InlayHint[]?
      function(_, result, _, _)
        if result ~= nil then
          --- @type lsp.InlayHint[]
          local hints = vim
            .iter(result)
            :filter(
              --- @param hint lsp.InlayHint
              function(hint)
                -- TODO: use `vim.Range.has_pos` when available. See https://github.com/neovim/neovim/pull/36397
                local hint_pos = vim.pos.lsp(bufnr, hint.position, client.offset_encoding)
                return hint_pos < range.end_ and hint_pos >= range.start
              end
            )
            :totable()
          if #hints > 0 then
            if not support_resolve then
              if action_callback(hints, { bufnr = bufnr, client = client }) == 0 then
                -- no edits applied. proceed with the iteration.
                return do_insert(next(clients, idx))
              else
                -- we're done with the edits.
                return
              end
            end

            -- keep track of the number of resolved edits
            --- @type integer
            local num_processed = 0

            for i, h in ipairs(hints) do
              client:request('inlayHint/resolve', h, function(_, _result, _, _)
                if _result ~= nil then
                  hints[i] = _result
                end
                num_processed = num_processed + 1

                if num_processed == #hints then
                  if action_callback(hints, { bufnr = bufnr, client = client }) == 0 then
                    return do_insert(next(clients, idx))
                  else
                    return
                  end
                end
              end, bufnr)
            end
          else
            -- no hints in the given range.
            return do_insert(next(clients, idx))
          end
        else
          -- result is nil. Proceed to next client.
          return do_insert(next(clients, idx))
        end
      end,
      bufnr
    )
  end

  do_insert(next(clients))
end

return M
