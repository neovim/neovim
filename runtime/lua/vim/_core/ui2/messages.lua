local api, fn, o = vim.api, vim.fn, vim.o
local ui = require('vim._core.ui2')

---@alias Msg { extid: integer, timer: uv.uv_timer_t? }
---@class vim._core.ui2.messages
local M = {
  -- Message window. Used for regular messages with cfg.msg.target == 'msg'.
  -- Automatically resizes to the text dimensions up to a point, at which point
  -- only the most recent messages will fit and be shown. A timer is started for
  -- each message whose callback will remove the message from the window again.
  msg = {
    ids = {}, ---@type table<string|integer, Msg> List of visible messages.
    width = 1, -- Current width of the message window.
  },
  -- Cmdline message window. Used for regular messages with cfg.msg.target == 'cmd'.
  -- Also contains 'ruler', 'showcmd' and search_cmd/count messages as virt_text.
  -- Messages that don't fit the 'cmdheight' are first shown in an expanded cmdline.
  -- Otherwise, or after an expanded cmdline is closed upon the first keypress, the
  -- cmdline contains the messages with spilled and duplicate lines indicators.
  cmd = {
    ids = {}, ---@type table<string|integer, Msg> List of visible messages.
    msg_row = -1, -- Last row of message to distinguish for placing virt_text.
    last_col = o.columns, -- Crop text to start column of 'last' virt_text.
    last_emsg = 0, -- Time an error was printed that should not be overwritten.
  },
  dupe = 0, -- Number of times message is repeated.
  prev_id = 0, ---@type string|integer Message id of the previous message.
  prev_msg = '', -- Concatenated content of the previous message.
  virt = { -- Stored virt_text state.
    last = { {}, {}, {}, {} }, ---@type MsgContent[] status in last cmdline row.
    msg = { {}, {} }, ---@type MsgContent[] [(x)] indicators in msg window.
    top = { {} }, ---@type MsgContent[] [+x] top indicator in dialog window.
    bot = { {} }, ---@type MsgContent[] [+x] bottom indicator in dialog window.
    idx = { mode = 1, search = 2, cmd = 3, ruler = 4, spill = 1, dupe = 2 },
    ids = {}, ---@type { ['last'|'msg'|'top'|'bot']: integer? } Table of mark IDs.
    delayed = false, -- Whether placement of 'last' virt_text is delayed.
  },
  dialog_on_key = nil, ---@type integer? vim.on_key namespace for paging in the dialog window.
  cmd_on_key = nil, ---@type integer? vim.on_key namespace while cmdline is expanded.
}

-- An external redraw indicates the start of a new batch of messages in the cmdline.
api.nvim_set_decoration_provider(ui.ns, {
  on_start = function()
    M.cmd.ids = (ui.redrawing or M.cmd_on_key) and M.cmd.ids or {}
  end,
})

--- Start a timer whose callback will remove the message from the message window.
---
---@param buf integer Buffer the message was written to.
---@param id integer|string Message ID.
function M.msg:start_timer(buf, id)
  if self.ids[id].timer then
    self.ids[id].timer:stop()
  end
  self.ids[id].timer = vim.defer_fn(function()
    local extid = api.nvim_buf_is_valid(buf) and self.ids[id] and self.ids[id].extid
    local mark = extid and api.nvim_buf_get_extmark_by_id(buf, ui.ns, extid, { details = true })
    self.ids[id] = nil
    if not mark or not mark[1] then
      return
    end
    -- Clear prev_msg when line that may have dupe marker is removed.
    local erow = api.nvim_buf_line_count(buf) - 1
    M.prev_msg = ui.cfg.msg.target == 'msg' and mark[3].end_row == erow and '' or M.prev_msg

    -- Remove message (including potentially leftover empty line).
    api.nvim_buf_set_text(buf, mark[1], mark[2], mark[3].end_row, mark[3].end_col, {})
    if api.nvim_buf_get_lines(buf, mark[1], mark[1] + 1, false)[1] == '' then
      api.nvim_buf_set_lines(buf, mark[1], mark[1] + 1, false, {})
    end

    -- Resize or hide message window for removed message.
    if next(self.ids) then
      M.set_pos('msg')
    else
      pcall(api.nvim_win_set_config, ui.wins.msg, { hide = true })
      self.width, M.virt.msg[M.virt.idx.dupe][1] = 1, nil
    end
  end, ui.cfg.msg.msg.timeout)
end

--- Place or delete a virtual text mark in the cmdline or message window.
---
---@param type 'last'|'msg'|'top'|'bot'
---@param tgt? 'cmd'|'msg'|'dialog'
local function set_virttext(type, tgt)
  if type == 'last' and (ui.cmdheight == 0 or M.virt.delayed) then
    return -- Don't show virtual text while cmdline is expanded or delaying for error.
  end

  -- Concatenate the components of M.virt[type] and calculate the concatenated width.
  local width, chunks = 0, {} ---@type integer, [string, integer|string][]
  local contents = M.virt[type] ---@type MsgContent[]
  for _, content in ipairs(contents) do
    for _, chunk in ipairs(content) do
      chunks[#chunks + 1] = { chunk[2], chunk[3] }
      width = width + api.nvim_strwidth(chunk[2])
    end
  end
  tgt = tgt or type == 'msg' and ui.cfg.msg.target or 'cmd'

  if M.virt.ids[type] and #chunks == 0 then
    api.nvim_buf_del_extmark(ui.bufs[tgt], ui.ns, M.virt.ids[type])
    M.cmd.last_col = type == 'last' and o.columns or M.cmd.last_col
    M.virt.ids[type] = nil
  elseif #chunks > 0 then
    local win = ui.wins[tgt]
    local line = (tgt == 'msg' or type == 'top') and 'w0' or type == 'bot' and 'w$'
    local srow = line and fn.line(line, ui.wins.dialog) - 1
    local erow = tgt == 'cmd' and math.min(M.cmd.msg_row, api.nvim_buf_line_count(ui.bufs.cmd) - 1)
    local texth = api.nvim_win_text_height(win, {
      max_height = (type == 'top' or type == 'bot') and 1 or api.nvim_win_get_height(win),
      start_row = srow or nil,
      end_row = erow or nil,
    })
    local row = texth.end_row
    local col = fn.virtcol2col(win, row + 1, texth.end_vcol)
    local scol = fn.screenpos(win, row + 1, col).col ---@type integer

    if type ~= 'last' then
      -- Calculate at which column to place the virt_text such that it is at the end
      -- of the last visible message line, overlapping the message text if necessary,
      -- but not overlapping the 'last' virt_text.
      local offset = tgt ~= 'msg' and 0
        or api.nvim_win_get_position(win)[2]
          + (api.nvim_win_get_config(win).border ~= 'none' and 1 or 0)

      -- Check if adding the virt_text on this line will exceed the current window width.
      local maxwidth = math.max(M.msg.width, math.min(o.columns, scol - offset + width))
      if tgt == 'msg' and api.nvim_win_get_width(win) < maxwidth then
        api.nvim_win_set_width(win, maxwidth)
        M.msg.width = maxwidth
      end

      local mwidth = tgt == 'msg' and M.msg.width or tgt == 'dialog' and o.columns or M.cmd.last_col
      if scol - offset + width > mwidth then
        col = fn.virtcol2col(win, row + 1, texth.end_vcol - (scol - offset + width - mwidth))
      end

      -- Give virt_text the same highlight as the message tail.
      local pos, opts = { row, col }, { details = true, overlap = true, type = 'highlight' }
      local hl = api.nvim_buf_get_extmarks(ui.bufs[tgt], ui.ns, pos, pos, opts)
      for _, chunk in ipairs(hl[1] and chunks or {}) do
        chunk[2] = hl[1][4].hl_group
      end
    else
      local mode = #M.virt.last[M.virt.idx.mode]
      local pad = o.columns - width ---@type integer
      local newlines = math.max(0, ui.cmdheight - texth.all)
      row = row + newlines
      M.cmd.last_col = mode > 0 and 0 or o.columns - (newlines > 0 and 0 or width)

      if newlines > 0 then
        -- Add empty lines to place virt_text on the last screen row.
        api.nvim_buf_set_lines(ui.bufs.cmd, -1, -1, false, fn['repeat']({ '' }, newlines))
        col = 0
      else
        if scol > M.cmd.last_col then
          -- Give the user some time to read an important message.
          if os.time() - M.cmd.last_emsg < 2 then
            M.virt.delayed = true
            vim.defer_fn(function()
              M.virt.delayed = false
              set_virttext('last')
            end, 2000)
            return
          end

          -- Crop text on last screen row and find byte offset to place mark at.
          local vcol = texth.end_vcol - (scol - M.cmd.last_col)
          col = vcol <= 0 and 0 or fn.virtcol2col(win, row + 1, vcol)
          M.prev_msg = mode > 0 and '' or M.prev_msg
          M.virt.msg = mode > 0 and { {}, {} } or M.virt.msg
          api.nvim_buf_set_text(ui.bufs.cmd, row, col, row, -1, { mode > 0 and ' ' or '' })
        end

        pad = pad - ((mode > 0 or col == 0) and 0 or math.min(M.cmd.last_col, scol))
      end
      table.insert(chunks, mode + 1, { (' '):rep(pad) })
      -- Readjust to new M.cmd.last_col or clear for mode, but don't overwrite
      -- locked spill indicator while cmdline is expanded for messages.
      if not M.cmd_on_key then
        set_virttext('msg')
      end
    end

    local opts = { undo_restore = false, invalidate = true, id = M.virt.ids[type] }
    opts.priority = type == 'msg' and 2 or 1
    opts.virt_text_pos = 'overlay'
    opts.virt_text = chunks
    M.virt.ids[type] = api.nvim_buf_set_extmark(ui.bufs[tgt], ui.ns, row, col, opts)
  end
end

local hlopts = { undo_restore = false, invalidate = true, priority = 1 }
--- Move messages to expanded cmdline, dialog or pager to show in full.
function M.expand_msg(src, tgt)
  -- Copy and clear message from src to enlarged cmdline that is dismissed by any
  -- key press. Append to pager instead if it isn't hidden or we want to enter it
  -- after cmdline was entered during expanded cmdline.
  local hidden = api.nvim_win_get_config(ui.wins.pager).hide
  tgt = tgt or not hidden and 'pager' or 'cmd'
  if tgt ~= src then
    local srow = hidden and 0 or api.nvim_buf_line_count(ui.bufs.pager)
    local opts = { details = true, type = 'highlight' }
    local marks = api.nvim_buf_get_extmarks(ui.bufs[src], -1, 0, -1, opts)
    local lines = api.nvim_buf_get_lines(ui.bufs[src], 0, -1, false)
    -- Clear unless we want to keep the entered command.
    if ui.cmd.expand == 0 then
      M.msg_clear()
    end
    M.virt.msg = { {}, {} } -- Clear msg virtual text regardless.

    api.nvim_buf_set_lines(ui.bufs[tgt], srow, -1, false, lines)
    for _, mark in ipairs(marks) do
      hlopts.end_col, hlopts.hl_group = mark[4].end_col, mark[4].hl_group
      api.nvim_buf_set_extmark(ui.bufs[tgt], ui.ns, srow + mark[2], mark[3], hlopts)
    end
  else
    M.virt.msg[M.virt.idx.dupe][1] = nil
    for _, id in pairs(M.virt.ids) do
      api.nvim_buf_del_extmark(ui.bufs.cmd, ui.ns, id)
    end
  end
  M.set_pos(tgt)
end

-- Keep track of the current message column to be able to
-- append or overwrite messages for :echon or carriage returns.
local col = 0
local cmd_timer ---@type uv.uv_timer_t? Timer resetting cmdline state next event loop.
---@param tgt 'cmd'|'dialog'|'msg'|'pager'
---@param kind string
---@param content MsgContent
---@param replace_last boolean
---@param append boolean
---@param id integer|string
function M.show_msg(tgt, kind, content, replace_last, append, id)
  local mark, msg, cr, dupe, buf = {}, '', false, 0, ui.bufs[tgt]

  if M[tgt] then -- tgt == 'cmd'|'msg'
    local extid = M[tgt].ids[id] and M[tgt].ids[id].extid
    if tgt == ui.cfg.msg.target then
      -- Save the concatenated message to identify repeated messages.
      for _, chunk in ipairs(content) do
        msg = msg .. chunk[2]
      end
      local reset = extid or append or msg ~= M.prev_msg or ui.cmd.srow > 0
      dupe = (reset and 0 or M.dupe + 1)
    end

    cr = next(M[tgt].ids) ~= nil and msg:sub(1, 1) == '\r'
    replace_last = next(M[tgt].ids) ~= nil and not extid and (replace_last or dupe > 0)
    extid = extid or replace_last and M[tgt].ids[M.prev_id] and M[tgt].ids[M.prev_id].extid
    mark = extid and api.nvim_buf_get_extmark_by_id(buf, ui.ns, extid, { details = true }) or {}

    -- Ensure cmdline is clear when writing the first message.
    if tgt == 'cmd' and dupe == 0 and not next(M.cmd.ids) and ui.cmd.srow == 0 then
      api.nvim_buf_set_lines(buf, 0, -1, false, {})
    end
  end

  -- Filter out empty newline messages. TODO: don't emit them.
  if msg == '\n' then
    return
  end

  local line_count = api.nvim_buf_line_count(buf)
  ---@type integer Start row after last line in the target buffer, unless
  ---this is the first message, or in case of a repeated or replaced message.
  local row = mark[1]
    or (M[tgt] and not next(M[tgt].ids) and ui.cmd.srow == 0 and 0)
    or (line_count - ((replace_last or cr or append) and 1 or 0))
  local curline = (cr or append) and api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  local start_row, width = row, M.msg.width
  col = mark[2] or (append and not cr and math.min(col, #curline) or 0)
  local start_col, insert = col, false

  -- Accumulate to be inserted and highlighted message chunks.
  for i, chunk in ipairs(content) do
    -- Split at newline and write to start of line after carriage return.
    for str in (chunk[2] .. '\0'):gmatch('.-[\n\r%z]') do
      local repl, pat = str:sub(1, -2), str:sub(-1)
      local end_col = col + #repl ---@type integer

      -- Insert new line at end of buffer or when inserting lines for a replaced message.
      if line_count < row + 1 or insert then
        api.nvim_buf_set_lines(buf, row, row > start_row and row or -1, false, { repl })
        insert, line_count = false, line_count + 1
      else
        local erow = mark[3] and mark[3].end_row or row
        local ecol = mark[3] and mark[3].end_col or curline and math.min(end_col, #curline) or -1
        api.nvim_buf_set_text(buf, row, col, erow, ecol, { repl })
      end
      curline = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
      mark[3] = nil

      if chunk[3] > 0 then
        hlopts.end_col, hlopts.hl_group = end_col, chunk[3]
        api.nvim_buf_set_extmark(buf, ui.ns, row, col, hlopts)
      end

      if pat == '\n' then
        row, col, insert = row + 1, 0, mark[1] ~= nil
      else
        col = pat == '\r' and 0 or end_col
      end
      if tgt == 'msg' and (pat == '\n' or (i == #content and pat == '\0')) then
        width = api.nvim_win_call(ui.wins.msg, function()
          return math.max(width, fn.strdisplaywidth(curline))
        end)
      end
    end
  end

  if M[tgt] then
    -- Keep track of message span to replace by ID.
    local opts = { end_row = row, end_col = col, invalidate = true, undo_restore = false }
    M[tgt].ids[id] = M[tgt].ids[id] or {}
    M[tgt].ids[id].extid = api.nvim_buf_set_extmark(buf, ui.ns, start_row, start_col, opts)
    M.prev_id, M.prev_msg, M.dupe = id, msg, dupe
    if tgt == 'cmd' or row == api.nvim_buf_line_count(buf) - 1 then
      -- Place (x) indicator for repeated messages. Mainly to mitigate unnecessary
      -- resizing of the message window, but also placed in the cmdline.
      M.virt.msg[M.virt.idx.dupe][1] = dupe > 0 and { 0, ('(%d)'):format(dupe) } or nil
      set_virttext('msg')
    end
  end

  if tgt == 'msg' then
    api.nvim_win_set_width(ui.wins.msg, width)
    local texth = api.nvim_win_text_height(ui.wins.msg, { start_row = start_row, end_row = row })
    if texth.all > math.ceil(o.lines * 0.5) then
      M.expand_msg(tgt)
    else
      M.msg.width = width
      M.msg:start_timer(buf, id)
    end
  elseif tgt == 'cmd' and dupe == 0 then
    fn.clearmatches(ui.wins.cmd) -- Clear matchparen highlights.
    if ui.cmd.srow > 0 then
      -- In block mode the cmdheight is already dynamic, so just print the full message
      -- regardless of height. Put cmdline below message.
      ui.cmd.srow = row + 1
    else
      api.nvim_win_set_cursor(ui.wins.cmd, { 1, 0 }) -- ensure first line is visible
      -- Place [+x] indicator for lines that spill over 'cmdheight'.
      local texth = api.nvim_win_text_height(ui.wins.cmd, {})
      local spill = texth.all > ui.cmdheight and (' [+%d]'):format(texth.all - ui.cmdheight)
      M.virt.msg[M.virt.idx.spill][1] = spill and { 0, spill } or nil
      M.cmd.msg_row = texth.end_row

      -- Expand the cmdline for a non-error message that doesn't fit.
      local error_kinds = { rpc_error = 1, emsg = 1, echoerr = 1, lua_error = 1 }
      if texth.all > ui.cmdheight and (ui.cmdheight == 0 or not error_kinds[kind]) then
        M.expand_msg(tgt)
      end
    end
  end

  -- Set pager/dialog/msg dimensions unless sent to expanded cmdline.
  if tgt ~= 'cmd' and (tgt ~= 'msg' or M.msg.ids[id]) then
    M.set_pos(tgt)
  end

  -- Reset message state the next event loop iteration.
  if not cmd_timer and (col > 0 or next(M.cmd.ids) ~= nil) then
    cmd_timer = vim.defer_fn(function()
      M.cmd.ids, cmd_timer, col = M.cmd_on_key and M.cmd.ids or {}, nil, 0
    end, 0)
  end
end

local in_pager = false -- Whether the pager is or will be the current window.
--- Route the message to the appropriate sink.
---
---@param kind string
---@alias MsgChunk [integer, string, integer]
---@alias MsgContent MsgChunk[]
---@param content MsgContent
---@param replace_last boolean
--@param history boolean
---@param append boolean
---@param id integer|string
---@param trigger string
function M.msg_show(kind, content, replace_last, _, append, id, trigger)
  -- Set the entered search command in the cmdline (if available).
  local tgt = kind == 'search_cmd' and 'cmd'
    -- When the pager is open always route typed commands there. This better simulates
    -- the UI1 behavior after opening the cmdline below a previous multiline message,
    -- and seems useful enough even when the pager was entered manually.
    or (trigger == 'typed_cmd' and in_pager and fn.getcmdwintype() == '') and 'pager'
    -- Otherwise route to configured target: trigger takes precedence over kind.
    or ui.cfg.msg.targets[trigger]
    or ui.cfg.msg.targets[kind]
    or ui.cfg.msg.target
  if kind == 'search_cmd' and ui.cmdheight == 0 then
    -- Blocked by messaging() without ext_messages. TODO: look at other messaging() guards.
    return
  elseif kind == 'empty' then
    -- A sole empty message clears the cmdline.
    if ui.cfg.msg.target == 'cmd' and not next(M.cmd.ids) and ui.cmd.srow == 0 then
      M.msg_clear()
    end
  elseif kind == 'search_count' then
    -- Extract only the search_count, not the entered search command.
    -- Match any of search.c:cmdline_search_stat():' [(x | >x | ?)/(y | >y | ??)]'
    content = { content[#content] }
    content[1][2] = content[1][2]:match('W? %[>?%d*%??/>?%d*%?*%]') .. '  '
    M.virt.last[M.virt.idx.search] = content
    M.virt.last[M.virt.idx.cmd] = { { 0, (' '):rep(11) } }
    set_virttext('last')
  elseif (ui.cmd.prompt or (ui.cmd.level > 0 and tgt == 'cmd')) and ui.cmd.srow == 0 then
    -- Route to dialog when a prompt is active, or message would overwrite active cmdline.
    replace_last = api.nvim_win_get_config(ui.wins.dialog).hide or kind == 'wildlist'
    if kind == 'wildlist' then
      api.nvim_buf_set_lines(ui.bufs.dialog, 0, -1, false, {})
    end
    ui.cmd.dialog = true -- Ensure dialog is closed when cmdline is hidden.
    M.show_msg('dialog', kind, content, replace_last, append, id)
  else
    if tgt == 'cmd' then
      -- Store the time when an important message was emitted in order to not overwrite
      -- it with 'last' virt_text in the cmdline so that the user has a chance to read it.
      M.cmd.last_emsg = (kind == 'emsg' or kind == 'wmsg') and os.time() or M.cmd.last_emsg
      -- Should clear the search count now, mark itself is cleared by invalidate.
      M.virt.last[M.virt.idx.search][1] = nil
    end
    -- When message was emitted below an already expanded cmdline, move and route to pager.
    tgt = ui.cmd.expand > 0 and 'pager' or tgt
    if ui.cmd.expand == 1 then
      M.expand_msg('dialog', 'pager')
    end
    ui.cmd.expand = ui.cmd.expand + (ui.cmd.expand > 0 and 1 or 0)

    local enter_pager = tgt == 'pager' and not in_pager
    M.show_msg(tgt, kind, content, replace_last or enter_pager, append, id)
    if kind == 'search_cmd' then
      -- Don't remember search_cmd message as actual message.
      M.cmd.ids, M.prev_msg = {}, ''
    elseif tgt == 'pager' then
      -- Position cursor at start of first or last message at bottom of window.
      fn.win_execute(ui.wins.pager, 'norm! ' .. (enter_pager and 'gg0' or 'G0zb'))
    end
  end
end

---Clear currently visible messages.
function M.msg_clear()
  api.nvim_buf_set_lines(ui.bufs.cmd, 0, -1, false, {})
  api.nvim_buf_set_lines(ui.bufs.msg, 0, -1, false, {})
  api.nvim_win_set_config(ui.wins.msg, { hide = true })
  M[ui.cfg.msg.target].ids, M.dupe, M.cmd.msg_row, M.msg.width = {}, 0, -1, 1
  M.prev_msg, M.virt.msg = '', { {}, {} }
end

--- Place the mode text in the cmdline.
---
---@param content MsgContent
function M.msg_showmode(content)
  M.virt.last[M.virt.idx.mode] = ui.cmd.level > 0 and {} or content
  M.virt.last[M.virt.idx.search] = {}
  set_virttext('last')
end

--- Place text from the 'showcmd' buffer in the cmdline.
---
---@param content MsgContent
function M.msg_showcmd(content)
  local str = content[1] and content[1][2]:sub(-10) or ''
  M.virt.last[M.virt.idx.cmd][1] = (content[1] or M.virt.last[M.virt.idx.search][1])
    and { 0, str .. (' '):rep(11 - #str) }
  set_virttext('last')
end

--- Place the 'ruler' text in the cmdline window.
---
---@param content MsgContent
function M.msg_ruler(content)
  M.virt.last[M.virt.idx.ruler] = (ui.cmd.level > 0 or M.cmd_on_key) and {} or content
  set_virttext('last')
end

---@alias MsgHistory [string, MsgContent, boolean]
--- Open the message history in the pager.
---
---@param entries MsgHistory[]
---@param prev_cmd boolean
function M.msg_history_show(entries, prev_cmd)
  if #entries == 0 then
    return
  end

  -- Showing output of previous command, clear in case still visible.
  if M.cmd_on_key or prev_cmd then
    M.msg_clear()
  end

  api.nvim_buf_set_lines(ui.bufs.pager, 0, -1, false, {})
  for i, entry in ipairs(entries) do
    M.show_msg('pager', entry[1], entry[2], i == 1, entry[3], 0)
  end
  api.nvim_win_set_cursor(ui.wins.pager, { 1, 0 })

  M.set_pos('pager')
end

local typed_g = false
local cmd_on_key = function(key, typed)
  typed = typed and fn.keytrans(typed)
  -- Don't dismiss for non-typed keys and mouse movement. When 'g' is passed (typed
  -- or mapped), wait until the next key to avoid flickering when the pager is opened.
  if not typed_g and (not typed or typed == '<MouseMove>' or typed == 'g' or key == 'g') then
    typed_g = typed == 'g' or key == 'g'
    return
  end
  vim.on_key(nil, ui.ns)
  if typed == ':' then
    return -- Keep expanded messages open until cmdline closes.
  end

  -- Check if window was entered and reopen with original config.
  local mode = not api.nvim_get_mode().mode:match('[it]')
  local entered = mode and (typed == '<CR>' or typed_g and (typed == '<lt>' or key == '<'))
    or (typed:find('LeftMouse') and fn.getmousepos().winid == ui.wins.cmd)
  if entered then
    M.expand_msg('cmd', 'pager')
  end
  pcall(api.nvim_win_close, ui.wins.cmd, true)
  ui.check_targets()
  set_virttext('msg')
  api.nvim__redraw({ flush = true })

  typed_g, M.cmd_on_key, M.cmd.ids = false, nil, {}
  return entered and '' or nil
end

--- Add virtual [+x] text to indicate scrolling is possible.
local function set_top_bot_spill()
  local topspill = fn.line('w0', ui.wins.dialog) - 1
  local botspill = api.nvim_buf_line_count(ui.bufs.dialog) - fn.line('w$', ui.wins.dialog)
  M.virt.top[1][1] = topspill > 0 and { 0, (' [+%d]'):format(topspill) } or nil
  set_virttext('top', 'dialog')
  M.virt.bot[1][1] = botspill > 0 and { 0, (' [+%d]'):format(botspill) } or nil
  set_virttext('bot', 'dialog')
  api.nvim__redraw({ flush = true })
  return topspill > 0 or botspill > 0
end

--- Allow paging in the dialog window, consume the key if the topline changes.
local dialog_on_key = function(_, typed)
  typed = typed and fn.keytrans(typed)
  if not typed then
    return
  elseif typed == '<Esc>' then
    -- Stop paging, redraw empty title to reflect paging is no longer active.
    api.nvim_win_set_config(ui.wins.dialog, { title = '' })
    api.nvim__redraw({ flush = true })
    vim.on_key(nil, M.dialog_on_key)
    M.dialog_on_key = nil
    return ''
  end

  local page_keys = {
    g = 'gg',
    G = 'G',
    j = 'Lj',
    k = 'Hk',
    d = [[\<C-D>]],
    u = [[\<C-U>]],
    f = [[\<C-F>]],
    b = [[\<C-B>]],
  }
  local info = page_keys[typed] and fn.getwininfo(ui.wins.dialog)[1]
  if info and (typed ~= 'f' or info.botline < api.nvim_buf_line_count(ui.bufs.dialog)) then
    fn.win_execute(ui.wins.dialog, ('exe "norm! %s"'):format(page_keys[typed]))
    set_top_bot_spill()
    return fn.getwininfo(ui.wins.dialog)[1].topline ~= info.topline and '' or nil
  end
end

local was_cmdwin = ''
---@param min integer Minimum window height.
local function win_row_height(tgt, min)
  local cfgmin = ui.cfg.msg[tgt].height --[[@as number]]
  cfgmin = cfgmin > 1 and cfgmin or math.ceil(o.lines * cfgmin)
  if tgt ~= 'pager' then
    return (tgt == 'msg' and 0 or 1) - ui.cmd.wmnumode, math.min(min, cfgmin)
  end
  local cmdwin = fn.getcmdwintype() ~= was_cmdwin and api.nvim_win_get_height(0) or 0
  local global_stl = (cmdwin > 0 or o.laststatus == 3) and 1 or 0
  local row = 1 - cmdwin - global_stl
  return row, math.min(math.min(cfgmin, min), o.lines - 1 - ui.cmdheight - global_stl - cmdwin)
end

local function enter_pager()
  -- Cannot leave the cmdwin to enter the pager, so close and re-open it.
  in_pager, was_cmdwin = true, fn.getcmdwintype()
  if was_cmdwin ~= '' then
    api.nvim_command('quit')
  elseif M.cmd_on_key then
    api.nvim_feedkeys(vim.keycode('<Esc>'), 'n', false)
  end
  -- Cmdwin is closed one event iteration later so schedule in case it was open.
  vim.schedule(function()
    local height, id = api.nvim_win_get_height(ui.wins.pager), 0
    api.nvim_set_option_value('eiw', '', { scope = 'local', win = ui.wins.pager })
    api.nvim_set_current_win(ui.wins.pager)
    id = api.nvim_create_autocmd({ 'WinEnter', 'CmdwinEnter', 'WinResized' }, {
      group = ui.augroup,
      callback = function(ev)
        if fn.getcmdtype() ~= '' then
          -- WinEnter fires before we can detect cmdwin will be entered: keep open.
          return
        elseif ev.event == 'WinResized' and fn.getcmdwintype() == '' then
          -- Remember height to be restored when cmdwin is closed.
          height = api.nvim_win_get_height(ui.wins.pager)
        elseif ev.event == 'WinEnter' then
          -- Close when no longer current window.
          in_pager = api.nvim_get_current_win() == ui.wins.pager
        end
        in_pager = in_pager and api.nvim_win_is_valid(ui.wins.pager)
        local cfg = in_pager and { relative = 'laststatus', col = 0 } or { hide = true }
        if in_pager then
          cfg.row, cfg.height = win_row_height('pager', height)
        else
          pcall(api.nvim_set_option_value, 'eiw', 'all', { scope = 'local', win = ui.wins.pager })
          api.nvim_del_autocmd(id)
          if was_cmdwin ~= '' then
            api.nvim_feedkeys('q' .. was_cmdwin, 'n', false)
            was_cmdwin = ''
          end
        end
        pcall(api.nvim_win_set_config, ui.wins.pager, cfg)
      end,
      desc = 'Hide or reposition pager window.',
    })
  end)
end

--- Adjust visibility and dimensions of the message windows after certain events.
---
---@param tgt? 'cmd'|'dialog'|'msg'|'pager' Target window to be positioned (nil for all).
function M.set_pos(tgt)
  for t, win in pairs(ui.wins) do
    local cfg = (t == tgt or (tgt == nil and t ~= 'cmd'))
      and api.nvim_win_is_valid(win)
      and api.nvim_win_get_config(win)
    if cfg and (tgt or not cfg.hide) then
      local texth = api.nvim_win_text_height(win, {})
      local top = { vim.opt.fcs:get().msgsep or ' ', 'MsgSeparator' }
      local hint = 'f/d/j: screen/page/line down, b/u/k: up, <Esc>: stop paging'
      cfg = { hide = false, relative = 'laststatus', col = 10000 } ---@type table
      cfg.row, cfg.height = win_row_height(t, texth.all)
      cfg.border = t ~= 'msg' and { '', top, '', '', '', '', '', '' } or nil
      cfg.mouse = tgt == 'cmd' or nil
      cfg.title = tgt == 'dialog'
          and { { ui.cmd.expand == 0 and cfg.height < texth.all and hint or '', 'MsgMore' } }
        or nil
      api.nvim_win_set_config(win, cfg)

      if tgt == 'cmd' then
        -- Dismiss temporarily expanded cmdline on next keypress and update spill indicator.
        local spill = texth.all > cfg.height and (' [+%d]'):format(texth.all - cfg.height)
        M.virt.msg[M.virt.idx.spill][1] = spill and { 0, spill } or nil
        set_virttext('msg', 'cmd')
        M.virt.msg[M.virt.idx.spill][1] = { 0, (' [+%d]'):format(texth.all - ui.cmdheight) }
        M.cmd_on_key = vim.on_key(cmd_on_key, ui.ns)
      elseif tgt == 'dialog' and set_top_bot_spill() and #cfg.title[1][1] > 0 then
        M.dialog_on_key = vim.on_key(dialog_on_key, M.dialog_on_key)
      elseif tgt == 'msg' then
        -- Ensure last line is visible and first line is at top of window.
        fn.win_execute(ui.wins.msg, 'norm! Gzb')
      elseif tgt == 'pager' and not in_pager then
        enter_pager()
      end
    end
  end
end

return M
