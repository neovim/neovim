local api, fn, o = vim.api, vim.fn, vim.o
local ext = require('vim._extui.shared')

---@class vim._extui.messages
local M = {
  -- Message window. Used for regular messages with 'cmdheight' == 0 or,
  -- cfg.msg.target == 'msg'. Automatically resizes to the text dimensions up to
  -- a point, at which point only the most recent messages will fit and be shown.
  -- A timer is started for each message whose callback will remove the message
  -- from the window again.
  msg = {
    count = 0, -- Number of messages currently in the message window.
    width = 1, -- Current width of the message window.
    timer = nil, ---@type uv.uv_timer_t Timer that removes the most recent message.
  },
  -- Cmdline message window. Used for regular messages with 'cmdheight' > 0.
  -- Also contains 'ruler', 'showcmd' and search_cmd/count messages as virt_text.
  -- Messages that don't fit the 'cmdheight' are cut off and virt_text is added
  -- to indicate the number of spilled lines and repeated messages.
  cmd = {
    count = 0, -- Number of messages currently in the message window.
    msg_row = -1, -- Last row of message to distinguish for placing virt_text.
    last_col = o.columns, -- Crop text to start column of 'last' virt_text.
    last_emsg = 0, -- Time an error was printed that should not be overwritten.
  },
  dupe = 0, -- Number of times message is repeated.
  prev_msg = '', -- Concatenated content of the previous message.
  virt = { -- Stored virt_text state.
    last = { {}, {}, {}, {} }, ---@type MsgContent[] status in last cmdline row.
    msg = { {}, {} }, ---@type MsgContent[] [(x)] indicators in message window.
    idx = { mode = 1, search = 2, cmd = 3, ruler = 4, spill = 1, dupe = 2 },
    ids = {}, ---@type { ['last'|'msg']: integer? } Table of mark IDs.
    delayed = false, -- Whether placement of 'last' virt_text is delayed.
  },
}

function M.msg:close()
  self.width, M.virt.msg[M.virt.idx.dupe][1] = 1, nil
  M.prev_msg = ext.cfg.msg.target == 'msg' and '' or M.prev_msg
  api.nvim_buf_clear_namespace(ext.bufs.msg, -1, 0, -1)
  if api.nvim_win_is_valid(ext.wins.msg) then
    api.nvim_win_set_config(ext.wins.msg, { hide = true })
  end
end

--- Start a timer whose callback will remove the message from the message window.
---
---@param buf integer Buffer the message was written to.
---@param len integer Number of rows that should be removed.
function M.msg:start_timer(buf, len)
  self.timer = vim.defer_fn(function()
    if self.count == 0 or not api.nvim_buf_is_valid(buf) then
      return -- Messages moved to pager or buffer was closed.
    end
    api.nvim_buf_set_lines(buf, 0, len, false, {})
    self.count = self.count - 1
    -- Resize or hide message window for removed message.
    if self.count > 0 then
      M.set_pos('msg')
    else
      self:close()
    end
  end, ext.cfg.msg.timeout)
end

local cmd_on_key = nil
--- Place or delete a virtual text mark in the cmdline or message window.
---
---@param type 'last'|'msg'
local function set_virttext(type)
  if (type == 'last' and (ext.cmdheight == 0 or M.virt.delayed)) or cmd_on_key then
    return -- Don't show virtual text while cmdline, error or full message in cmdline is shown.
  end

  -- Concatenate the components of M.virt[type] and calculate the concatenated width.
  local width, chunks = 0, {} ---@type integer, [string, integer|string][]
  local contents = type == 'last' and M.virt.last or M.virt.msg
  for _, content in ipairs(contents) do
    for _, chunk in ipairs(content) do
      chunks[#chunks + 1] = { chunk[2], chunk[3] }
      width = width + api.nvim_strwidth(chunk[2])
    end
  end

  if M.virt.ids[type] and #chunks == 0 then
    api.nvim_buf_del_extmark(ext.bufs.cmd, ext.ns, M.virt.ids[type])
    M.virt.ids[type] = nil
    M.cmd.last_col = type == 'last' and o.columns or M.cmd.last_col
  elseif #chunks > 0 then
    local tar = type == 'msg' and ext.cfg.msg.target or 'cmd'
    local win = ext.wins[tar]
    local erow = tar == 'cmd' and math.min(M.cmd.msg_row, api.nvim_buf_line_count(ext.bufs.cmd) - 1)
    local texth = api.nvim_win_text_height(win, {
      max_height = api.nvim_win_get_height(win),
      start_row = tar == 'msg' and fn.line('w0', ext.wins.msg) - 1 or nil,
      end_row = erow or nil,
    })
    local row = texth.end_row
    local col = fn.virtcol2col(win, row + 1, texth.end_vcol)
    local scol = fn.screenpos(win, row + 1, col).col ---@type integer

    if type == 'msg' then
      -- Calculate at which column to place the virt_text such that it is at the end
      -- of the last visible message line, overlapping the message text if necessary,
      -- but not overlapping the 'last' virt_text.
      local offset = tar ~= 'msg' and 0
        or api.nvim_win_get_position(win)[2] + (api.nvim_win_get_config(win).border and 1 or 0)

      -- Check if adding the virt_text on this line will exceed the current window width.
      local maxwidth = math.max(M.msg.width, math.min(o.columns, scol - offset + width))
      if tar == 'msg' and api.nvim_win_get_width(win) < maxwidth then
        api.nvim_win_set_width(win, maxwidth)
        M.msg.width = maxwidth
      end

      local mwidth = tar == 'msg' and M.msg.width or M.cmd.last_col
      if scol - offset + width > mwidth then
        col = fn.virtcol2col(win, row + 1, texth.end_vcol - (scol - offset + width - mwidth))
      end

      -- Give virt_text the same highlight as the message tail.
      local pos, opts = { row, col }, { details = true, overlap = true, type = 'highlight' }
      local hl = api.nvim_buf_get_extmarks(ext.bufs[tar], ext.ns, pos, pos, opts)
      for _, chunk in ipairs(hl[1] and chunks or {}) do
        chunk[2] = hl[1][4].hl_group
      end
    else
      local mode = #M.virt.last[M.virt.idx.mode]
      local pad = o.columns - width ---@type integer
      local newlines = math.max(0, ext.cmdheight - texth.all)
      row = row + newlines
      M.cmd.last_col = mode > 0 and 0 or o.columns - (newlines > 0 and 0 or width)

      if newlines > 0 then
        -- Add empty lines to place virt_text on the last screen row.
        api.nvim_buf_set_lines(ext.bufs.cmd, -1, -1, false, fn['repeat']({ '' }, newlines))
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
          api.nvim_buf_set_text(ext.bufs.cmd, row, col, row, -1, { mode > 0 and ' ' or '' })
        end

        pad = pad - ((mode > 0 or col == 0) and 0 or math.min(M.cmd.last_col, scol))
      end
      table.insert(chunks, mode + 1, { (' '):rep(pad) })
      set_virttext('msg') -- Readjust to new M.cmd.last_col or clear for mode.
    end

    M.virt.ids[type] = api.nvim_buf_set_extmark(ext.bufs[tar], ext.ns, row, col, {
      virt_text = chunks,
      virt_text_pos = 'overlay',
      right_gravity = false,
      undo_restore = false,
      invalidate = true,
      id = M.virt.ids[type],
      priority = type == 'msg' and 2 or 1,
    })
  end
end

-- We need to keep track of the current message column to be able to
-- append or overwrite messages for :echon or carriage returns.
local col, will_full, hlopts = 0, false, { undo_restore = false, invalidate = true, priority = 1 }
--- Move messages to cmdline or pager to show in full.
local function msg_to_full(src)
  if will_full then
    return
  end
  will_full, M.prev_msg = true, ''

  vim.schedule(function()
    -- Copy and clear message from src to enlarged cmdline that is dismissed by any
    -- key press, or append to pager in case that is already open (not hidden).
    local hidden = api.nvim_win_get_config(ext.wins.pager).hide
    local tar = hidden and 'cmd' or 'pager'
    if tar ~= src then
      local srow = hidden and 0 or api.nvim_buf_line_count(ext.bufs.pager)
      local marks = api.nvim_buf_get_extmarks(ext.bufs[src], -1, 0, -1, { details = true })
      local lines = api.nvim_buf_get_lines(ext.bufs[src], 0, -1, false)
      api.nvim_buf_set_lines(ext.bufs[src], 0, -1, false, {})
      api.nvim_buf_set_lines(ext.bufs[tar], srow, -1, false, lines)
      for _, mark in ipairs(marks) do
        hlopts.end_col, hlopts.hl_group = mark[4].end_col, mark[4].hl_group
        api.nvim_buf_set_extmark(ext.bufs[tar], ext.ns, srow + mark[2], mark[3], hlopts)
      end
      api.nvim_command('norm! G')
      M.virt.msg[M.virt.idx.spill][1] = nil
    else
      for _, id in pairs(M.virt.ids) do
        api.nvim_buf_del_extmark(ext.bufs.cmd, ext.ns, id)
      end
    end
    M.msg:close()
    M.set_pos(tar)
    M[src].count, col, will_full = 0, 0, false
  end)
end

---@param tar 'cmd'|'dialog'|'msg'|'pager'
---@param content MsgContent
---@param replace_last boolean
---@param append boolean
---@param full boolean? If true, show messages that exceed target window in full.
function M.show_msg(tar, content, replace_last, append, full)
  local msg, restart, cr, dupe, count = '', false, false, 0, 0
  append = append and col > 0

  if M[tar] then -- tar == 'cmd'|'msg'
    if tar == ext.cfg.msg.target then
      -- Save the concatenated message to identify repeated messages.
      for _, chunk in ipairs(content) do
        msg = msg .. chunk[2]
      end
      dupe = (msg == M.prev_msg and ext.cmd.row == 0 and M.dupe + 1 or 0)
    end

    cr = M[tar].count > 0 and msg:sub(1, 1) == '\r'
    restart = M[tar].count > 0 and (replace_last or dupe > 0)
    count = M[tar].count + ((restart or msg == '\n') and 0 or 1)

    -- Ensure cmdline is clear when writing the first message.
    if tar == 'cmd' and not will_full and dupe == 0 and M.cmd.count == 0 and ext.cmd.row == 0 then
      api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, {})
    end
  end

  -- Filter out empty newline messages. TODO: don't emit them.
  if msg == '\n' then
    return
  end

  local line_count = api.nvim_buf_line_count(ext.bufs[tar])
  ---@type integer Start row after last line in the target buffer, unless
  ---this is the first message, or in case of a repeated or replaced message.
  local row = M[tar] and count <= 1 and not will_full and (tar == 'cmd' and ext.cmd.row or 0)
    or line_count - ((replace_last or restart or cr or append) and 1 or 0)
  local curline = (cr or append) and api.nvim_buf_get_lines(ext.bufs[tar], row, row + 1, false)[1]
  local start_row, width = row, M.msg.width
  col = append and not cr and math.min(col, #curline) or 0

  -- Accumulate to be inserted and highlighted message chunks for a non-repeated message.
  for _, chunk in ipairs((not M[tar] or dupe == 0) and content or {}) do
    -- Split at newline and write to start of line after carriage return.
    for str in (chunk[2] .. '\0'):gmatch('.-[\n\r%z]') do
      local repl, pat = str:sub(1, -2), str:sub(-1)
      local end_col = col + #repl ---@type integer

      if line_count < row + 1 then
        api.nvim_buf_set_lines(ext.bufs[tar], row, -1, false, { repl })
        line_count = line_count + 1
      else
        local ecol = curline and math.min(end_col, #curline) or -1
        api.nvim_buf_set_text(ext.bufs[tar], row, col, row, ecol, { repl })
      end
      curline = api.nvim_buf_get_lines(ext.bufs[tar], row, row + 1, false)[1]
      width = tar == 'msg' and math.max(width, api.nvim_strwidth(curline)) or 0

      if chunk[3] > 0 then
        hlopts.end_col, hlopts.hl_group = end_col, chunk[3]
        api.nvim_buf_set_extmark(ext.bufs[tar], ext.ns, row, col, hlopts)
      end

      if pat == '\n' then
        row, col = row + 1, 0
      else
        col = pat == '\r' and 0 or end_col
      end
    end
  end

  if tar == 'msg' then
    api.nvim_win_set_width(ext.wins.msg, width)
    local texth = api.nvim_win_text_height(ext.wins.msg, { start_row = start_row })
    if full and texth.all > 1 then
      msg_to_full(tar)
      return
    end

    M.set_pos('msg')
    M.msg.width = width
    if restart then
      M.msg.timer:stop()
      M.msg.timer:set_repeat(4000)
      M.msg.timer:again()
    else
      M.msg:start_timer(ext.bufs.msg, row - start_row + 1)
    end
  elseif tar == 'cmd' and dupe == 0 then
    fn.clearmatches(ext.wins.cmd) -- Clear matchparen highlights.
    if ext.cmd.row > 0 then
      -- In block mode the cmdheight is already dynamic, so just print the full message
      -- regardless of height. Spoof cmdline_show to put cmdline below message.
      ext.cmd.row = ext.cmd.row + 1 + row - start_row
      ext.cmd.cmdline_show({}, 0, ':', '', ext.cmd.indent, 0, 0)
      api.nvim__redraw({ flush = true, cursor = true, win = ext.wins.cmd })
    else
      api.nvim_win_set_cursor(ext.wins.cmd, { 1, 0 }) -- ensure first line is visible
      if ext.cmd.highlighter then
        ext.cmd.highlighter.active[ext.bufs.cmd] = nil
      end
      -- Place [+x] indicator for lines that spill over 'cmdheight'.
      local texth = api.nvim_win_text_height(ext.wins.cmd, {})
      local spill = texth.all > ext.cmdheight and ('[+%d]'):format(texth.all - ext.cmdheight)
      M.virt.msg[M.virt.idx.spill][1] = spill and { 0, spill } or nil
      M.cmd.msg_row = texth.end_row

      local want_full = full or will_full or not api.nvim_win_get_config(ext.wins.pager).hide
      if want_full and texth.all > ext.cmdheight then
        msg_to_full(tar)
        return
      end
    end
  end

  if M[tar] then
    -- Place (x) indicator for repeated messages. Mainly to mitigate unnecessary
    -- resizing of the message window, but also placed in the cmdline.
    M.virt.msg[M.virt.idx.dupe][1] = dupe > 0 and { 0, ('(%d)'):format(dupe) } or nil
    M.prev_msg, M.dupe, M[tar].count = msg, dupe, count
    set_virttext('msg')
  end

  -- Reset message state the next event loop iteration.
  if start_row == 0 or ext.cmd.row > 0 then
    vim.schedule(function()
      col, M.cmd.count = 0, 0
    end)
  end
end

--- Route the message to the appropriate sink.
---
---@param kind string
---@alias MsgChunk [integer, string, integer]
---@alias MsgContent MsgChunk[]
---@param content MsgContent
---@param replace_last boolean
--@param history boolean
---@param append boolean
function M.msg_show(kind, content, replace_last, _, append)
  if kind == 'empty' then
    -- A sole empty message clears the cmdline.
    if ext.cfg.msg.target == 'cmd' and M.cmd.count == 0 then
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
  elseif ext.cmd.prompt or kind == 'wildlist' then
    -- Route to dialog that stays open so long as the cmdline prompt is active.
    replace_last = api.nvim_win_get_config(ext.wins.dialog).hide or kind == 'wildlist'
    if kind == 'wildlist' then
      api.nvim_buf_set_lines(ext.bufs.dialog, 0, -1, false, {})
      ext.cmd.prompt = true -- Ensure dialog is closed when cmdline is hidden.
    end
    M.show_msg('dialog', content, replace_last, append)
    M.set_pos('dialog')
  else
    -- Set the entered search command in the cmdline (if available).
    local tar = kind == 'search_cmd' and 'cmd' or ext.cfg.msg.target
    if tar == 'cmd' then
      if ext.cmdheight == 0 or (ext.cmd.level > 0 and ext.cmd.row == 0) then
        return -- Do not overwrite an active cmdline unless in block mode.
      end
      -- Store the time when an error message was emitted in order to not overwrite
      -- it with 'last' virt_text in the cmdline to give the user a chance to read it.
      M.cmd.last_emsg = kind == 'emsg' and os.time() or M.cmd.last_emsg
      -- Should clear the search count now, mark itself is cleared by invalidate.
      M.virt.last[M.virt.idx.search][1] = nil
    end

    -- Typed "inspection" messages should be shown in full.
    local inspect = { 'echo', 'echomsg', 'lua_print' }
    local full = kind == 'list_cmd' or (ext.cmd.level >= 0 and vim.tbl_contains(inspect, kind))
    M.show_msg(tar, content, replace_last, append, full)
    -- Don't remember search_cmd message as actual message.
    if kind == 'search_cmd' then
      M.cmd.count, M.prev_msg = 0, ''
    end
  end
end

---Clear currently visible messages.
function M.msg_clear()
  api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, {})
  api.nvim_buf_set_lines(ext.bufs.msg, 0, -1, false, {})
  api.nvim_win_set_config(ext.wins.msg, { hide = true })
  M.dupe, M[ext.cfg.msg.target].count, M.cmd.msg_row, M.msg.width = 0, 0, -1, 1
  M.prev_msg, M.virt.msg = '', { {}, {} }
end

--- Place the mode text in the cmdline.
---
---@param content MsgContent
function M.msg_showmode(content)
  M.virt.last[M.virt.idx.mode] = ext.cmd.level > 0 and {} or content
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
  M.virt.last[M.virt.idx.ruler] = ext.cmd.level > 0 and {} or content
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

  if prev_cmd then
    M.msg_clear() -- Showing output of previous command, clear in case still visible.
  end
  api.nvim_buf_set_lines(ext.bufs.pager, 0, -1, false, {})
  for i, entry in ipairs(entries) do
    M.show_msg('pager', entry[2], i == 1, entry[3])
  end

  M.set_pos('pager')
end

--- Adjust dimensions of the message windows after certain events.
---
---@param type? 'cmd'|'dialog'|'msg'|'pager' Type of to be positioned window (nil for all).
function M.set_pos(type)
  local function win_set_pos(win)
    local texth = type and api.nvim_win_text_height(win, {}) or {}
    local height = type and math.min(texth.all, math.ceil(o.lines * 0.5))
    local top = { vim.opt.fcs:get().horiz or o.ambw == 'single' and '─' or '-', 'WinSeparator' }
    local border = type ~= 'msg' and { '', top, '', '', '', '', '', '' } or nil
    local save_config = type == 'cmd' and api.nvim_win_get_config(win) or {}
    local config = {
      hide = false,
      relative = 'laststatus',
      border = border,
      height = height,
      row = type == 'msg' and 0 or 1,
      col = 10000,
      focusable = type == 'cmd' or nil, -- Allow entering the cmdline window.
    }
    api.nvim_win_set_config(win, config)

    if type == 'cmd' then
      -- Temporarily showing a full message in the cmdline, until next key press.
      local save_spill = M.virt.msg[M.virt.idx.spill][1]
      local spill = texth.all > height and ('[+%d]'):format(texth.all - height)
      M.virt.msg[M.virt.idx.spill][1] = spill and { 0, spill } or nil
      set_virttext('msg')
      M.virt.msg[M.virt.idx.spill][1] = save_spill
      cmd_on_key = vim.on_key(function(_, typed)
        if not typed or fn.keytrans(typed) == '<MouseMove>' then
          return
        end
        vim.schedule(function()
          api.nvim_win_set_config(win, save_config)
          cmd_on_key = nil
          local entered = api.nvim_get_current_win() == win
          -- Show or clear the message depending on if the pager was opened.
          if entered or not api.nvim_win_get_config(ext.wins.pager).hide then
            M.virt.msg[M.virt.idx.spill][1] = nil
            api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, {})
            if entered then
              api.nvim_command('norm! g<') -- User entered the cmdline window: open the pager.
            end
          elseif ext.cfg.msg.target == 'cmd' and ext.cmd.level <= 0 then
            set_virttext('msg')
          end
          api.nvim__redraw({ flush = true }) -- NOTE: redundant unless cmdline was opened.
        end)
        vim.on_key(nil, ext.ns)
      end, ext.ns)
    elseif type == 'msg' then
      -- Ensure last line is visible and first line is at top of window.
      local row = (texth.all > height and texth.end_row or 0) + 1
      api.nvim_win_set_cursor(ext.wins.msg, { row, 0 })
    elseif type == 'pager' then
      if fn.getcmdwintype() ~= '' then
        -- Cannot leave the cmdwin to enter the pager, so close it.
        -- NOTE: regression w.r.t. the message grid, which allowed this.
        -- Resolving that would require somehow bypassing textlock for the pager.
        api.nvim_command('quit')
      end

      -- Cmdwin is actually closed one event iteration later so schedule in case it was open.
      vim.schedule(function()
        api.nvim_set_current_win(win)
        -- Make pager relative to cmdwin when it is opened, restore when it is closed.
        api.nvim_create_autocmd({ 'WinEnter', 'CmdwinEnter', 'CmdwinLeave' }, {
          callback = function(ev)
            if api.nvim_win_is_valid(win) then
              local cfg = ev.event == 'CmdwinLeave' and config
                or ev.event == 'WinEnter' and { hide = true }
                or { relative = 'win', win = 0, row = 0, col = 0 }
              api.nvim_win_set_config(win, cfg)
            end
            return ev.event == 'WinEnter'
          end,
          desc = 'Hide or reposition pager window.',
        })
      end)
    end
  end

  for t, win in pairs(ext.wins) do
    local cfg = (t == type or (type == nil and t ~= 'cmd'))
      and api.nvim_win_is_valid(win)
      and api.nvim_win_get_config(win)
    if cfg and (type or not cfg.hide) then
      win_set_pos(win)
    end
  end
end

return M
