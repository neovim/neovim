local api, fn, o = vim.api, vim.fn, vim.o
local ext = require('vim._extui.shared')

---@class vim._extui.messages
local M = {
  -- Message window. Used for regular messages with 'cmdheight' == 0 or,
  -- cfg.msg.target == 'msg'. Also used for verbose messages regardless of
  -- cfg.msg.target. Automatically resizes to the text dimensions up to a point,
  -- at which point only the most recent messages will fit and be shown.
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
    lines = 0, -- Number of lines in cmdline buffer (including wrapped lines).
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
  self.width, M.virt.msg = 1, { {}, {} }
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

--- Place or delete a virtual text mark in the cmdline or message window.
---
---@param type 'last'|'msg'
local function set_virttext(type)
  if type == 'last' and (ext.cmdheight == 0 or M.virt.delayed) then
    return
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
    local h = api.nvim_win_text_height(win, {
      max_height = api.nvim_win_get_height(win),
      start_row = tar == 'msg' and fn.line('w0', ext.wins.msg) - 1 or nil,
      end_row = erow or nil,
    })
    local row = h.end_row ---@type integer
    local col = fn.virtcol2col(win, row + 1, h.end_vcol)
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
        col = fn.virtcol2col(win, row + 1, h.end_vcol - (scol - offset + width - mwidth))
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
      local newlines = math.max(0, ext.cmdheight - h.all)
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
          local vcol = h.end_vcol - (scol - M.cmd.last_col) ---@type integer
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
local col, will_pager, hlopts = 0, false, { undo_restore = false, invalidate = true, priority = 1 }
--- Move message to pager, appending if window was already open.
local function msg_to_pager(tar)
  if will_pager then
    return
  end
  will_pager, M.prev_msg = true, ''

  vim.schedule(function()
    local hidden = api.nvim_win_get_config(ext.wins.pager).hide
    local marks = api.nvim_buf_get_extmarks(ext.bufs[tar], -1, 0, -1, { details = true })
    local lines = api.nvim_buf_get_lines(ext.bufs[tar], 0, -1, false)
    api.nvim_buf_set_lines(ext.bufs.pager, hidden and 0 or -1, -1, false, lines)
    local rows = api.nvim_buf_line_count(ext.bufs.pager) - #lines
    api.nvim_buf_set_lines(ext.bufs[tar], 0, -1, false, {})
    for _, mark in ipairs(marks) do
      hlopts.end_col, hlopts.hl_group = mark[4].end_col, mark[4].hl_group
      api.nvim_buf_set_extmark(ext.bufs.pager, ext.ns, mark[2] + rows, mark[3], hlopts)
    end
    M.msg:close()
    M.set_pos('pager')
    if not hidden then
      api.nvim_command('norm! G')
    end
    M[tar].count, col, will_pager = 0, 0, false
  end)
end

---@param tar 'cmd'|'dialog'|'msg'|'pager'
---@param content MsgContent
---@param replace_last boolean
---@param append boolean
---@param pager boolean? If true, route messages that exceed the target window to the pager.
function M.show_msg(tar, content, replace_last, append, pager)
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
    if tar == 'cmd' and not will_pager and dupe == 0 and M.cmd.count == 0 then
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
  local row = M[tar] and count <= 1 and not will_pager and (tar == 'cmd' and ext.cmd.row or 0)
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
    local h = api.nvim_win_text_height(ext.wins.msg, { start_row = start_row })
    if pager and h.all > 1 then
      msg_to_pager(tar)
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
      local h = api.nvim_win_text_height(ext.wins.cmd, {})
      local want_pager = pager or will_pager or not api.nvim_win_get_config(ext.wins.pager).hide
      if want_pager and h.all > ext.cmdheight then
        msg_to_pager(tar)
        return
      end

      api.nvim_win_set_cursor(ext.wins[tar], { 1, 0 })
      ext.cmd.highlighter.active[ext.bufs.cmd] = nil
      -- Place [+x] indicator for lines that spill over 'cmdheight'.
      M.cmd.lines, M.cmd.msg_row = h.all, h.end_row
      local spill = M.cmd.lines > ext.cmdheight and ('[+%d]'):format(M.cmd.lines - ext.cmdheight)
      M.virt.msg[M.virt.idx.spill][1] = spill and { 0, spill } or nil
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
      col, M.cmd.lines, M.cmd.count = 0, 0, 0
    end)
  end
end

local replace_bufwrite = false
--- Route the message to the appropriate sink.
---
---@param kind string
---@alias MsgChunk [integer, string, integer]
---@alias MsgContent MsgChunk[]
---@param content MsgContent
--@param replace_last boolean
--@param history boolean
---@param append boolean
function M.msg_show(kind, content, _, _, append)
  if kind == 'search_count' then
    -- Extract only the search_count, not the entered search command.
    -- Match any of search.c:cmdline_search_stat():' [(x | >x | ?)/(y | >y | ??)]'
    content = { content[#content] }
    content[1][2] = content[1][2]:match('W? %[>?%d*%??/>?%d*%?*%]') .. '  '
    M.virt.last[M.virt.idx.search] = content
    M.virt.last[M.virt.idx.cmd] = { { 0, (' '):rep(11) } }
    set_virttext('last')
  elseif kind == 'return_prompt' then
    -- Bypass hit enter prompt.
    vim.api.nvim_feedkeys(vim.keycode('<CR>'), 'n', false)
  elseif kind == 'verbose' then
    -- Verbose messages are sent too often to be meaningful in the cmdline:
    -- always route to message window regardless of cfg.msg.target.
    M.show_msg('msg', content, false, append)
  elseif ext.cmd.prompt then
    -- Route to dialog that stays open so long as the cmdline prompt is active.
    M.show_msg('dialog', content, api.nvim_win_get_config(ext.wins.dialog).hide, append)
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

    -- Typed "inspection" messages should be routed to the pager.
    local inspect = { 'echo', 'echomsg', 'lua_print' }
    local pager = kind == 'list_cmd' or (ext.cmd.level >= 0 and vim.tbl_contains(inspect, kind))
    M.show_msg(tar, content, replace_bufwrite, append, pager)
    -- Replace message for every second bufwrite message.
    replace_bufwrite = not replace_bufwrite and kind == 'bufwrite'
    -- Don't remember search_cmd message as actual message.
    if kind == 'search_cmd' then
      M.cmd.lines, M.cmd.count, M.prev_msg = 0, 0, ''
    end
  end
end

function M.msg_clear() end

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
function M.msg_history_show(entries)
  if #entries == 0 then
    return
  end

  api.nvim_buf_set_lines(ext.bufs.pager, 0, -1, false, {})
  for i, entry in ipairs(entries) do
    M.show_msg('pager', entry[2], i == 1, entry[3])
  end

  M.set_pos('pager')
end

function M.msg_history_clear() end

--- Adjust dimensions of the message windows after certain events.
---
---@param type? 'cmd'|'dialog'|'msg'|'pager' Type of to be positioned window (nil for all).
function M.set_pos(type)
  local function win_set_pos(win)
    local texth = type and api.nvim_win_text_height(win, {}) or 0
    local height = type and math.min(texth.all, math.ceil(o.lines * 0.5))
    local config = {
      hide = false,
      relative = 'laststatus',
      height = height,
      row = win == ext.wins.msg and 0 or 1,
      col = 10000,
    }

    if type == 'msg' then
      -- Ensure last line is visible and first line is at top of window.
      local row = (texth.all > height and texth.end_row or 0) + 1
      api.nvim_win_set_cursor(ext.wins.msg, { row, 0 })
    elseif type == 'pager' and api.nvim_win_get_config(win).hide then
      -- Cannot leave the cmdwin to enter the pager, so close it.
      -- NOTE: regression w.r.t. the message grid, which allowed this. Resolving
      -- that would require somehow bypassing textlock for the pager.
      if fn.getcmdwintype() ~= '' then
        api.nvim_command('quit')
      end

      -- It's actually closed one event iteration later so schedule in case it was open.
      vim.schedule(function()
        api.nvim_set_current_win(win)
        api.nvim_create_autocmd({ 'WinEnter', 'CmdwinEnter', 'CmdwinLeave' }, {
          callback = function(ev)
            -- Make pager relative to cmdwin when it is opened, restore when it is closed.
            config = ev.event == 'CmdwinLeave' and config
              or ev.event == 'WinEnter' and { hide = true }
              or { relative = 'win', win = 0, row = 0, col = 0 }
            if api.nvim_win_is_valid(win) then
              api.nvim_win_set_config(win, config)
            end
            -- Delete autocmd when a window other than the cmdwin is entered.
            return ev.event == 'WinEnter'
          end,
          desc = 'Hide inactive pager window.',
        })
      end)
    end
    api.nvim_win_set_config(win, config)
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
