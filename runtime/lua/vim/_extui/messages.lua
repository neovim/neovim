local api, fn = vim.api, vim.fn
local ext = require('vim._extui.shared')

-- Message box window.
local Box = {
  width = 1, -- Current width of the message window.
  timer = nil, ---@type uv.uv_timer_t Timer that removes the most recent message.
}

-- Cmdline message window.
local Cmd = {
  lines = 0, -- Number of logical lines in cmdline buffer.
  msg_row = 0, -- Last row of message to distinguish for placing virt_text.
  last_col = vim.o.columns, -- Crop text to start column of 'last' virt_text.
}

-- Stored virt_text state.
local Virt = {
  last = { {}, {}, {}, {} }, ---@type MsgContent[] status in last cmdline row.
  msg = { {}, {} }, ---@type MsgContent[] [(x)] indicators in message window.
  idx = { mode = 1, count = 2, cmd = 3, ruler = 4, spill = 1, dupe = 2 },
  ids = {}, ---@type { ['last'|'msg']: integer? } Table of mark IDs.
}

---@class vim._extui.messages
local M = {
  prev_msg = '', -- Concatenated content of the previous message.
  count = 0, -- Number of messages currently in the message window.
  dupe = 0, -- Number of times message is repeated.
  virt = Virt, -- Stored virt_text state.
}

--- Start a timer whose callback will remove the message from the message window.
---
---@param buf integer Buffer the message was written to.
---@param len integer Number of rows that should be removed.
function Box:start_timer(buf, len)
  self.timer = vim.defer_fn(function()
    if M.count == 0 or buf ~= ext.bufs.box or not api.nvim_buf_is_valid(buf) then
      return -- Messages moved to split or buffer was closed.
    end
    api.nvim_buf_set_lines(buf, 0, len, false, {})
    M.count = M.count - 1
    if M.count > 0 then
      M.set_pos('box')
    else
      self.width, M.prev_msg = 1, ''
      api.nvim_win_set_config(ext.wins[ext.tab].box, { hide = true })
      api.nvim_buf_clear_namespace(ext.bufs.box, -1, 0, -1)
    end
  end, 4000)
end

--- Place or delete a virtual text mark in the cmdline or message window.
---
---@param type 'last'|'msg'
local function set_virttext(type)
  local width, chunks = 0, {} ---@type integer, [string, integer|string][]
  local appended = type == 'msg' and Virt.msg or Virt.last
  for _, content in ipairs(appended) do
    for _, chunk in ipairs(content) do
      chunks[#chunks + 1] = { chunk[2], chunk[3] }
      width = width + api.nvim_strwidth(chunk[2])
    end
  end

  if Virt.ids[type] and #chunks == 0 then
    api.nvim_buf_del_extmark(ext.bufs.cmd, ext.ns, Virt.ids[type])
    Virt.ids[type] = nil
    Cmd.last_col = type == 'last' and vim.o.columns or Cmd.last_col
  elseif #chunks > 0 then
    local tar = type == 'msg' and ext.cfg.msg.pos or 'cmd'
    local win = ext.wins[ext.tab][tar]
    local max = api.nvim_win_get_height(win)
    local erow = type == 'msg' and tar == 'cmd' and Cmd.msg_row or -1
    local h = api.nvim_win_text_height(win, { max_height = max, end_row = erow })
    local row, col = h.end_row, h.end_vcol ---@type integer, integer
    local pos = fn.screenpos(ext.wins[ext.tab][tar], row + 1, col)

    if type == 'msg' then
      -- Calculate at which row and column to overlay the virtual text such that it is at
      -- the end of the last visible message line, overlapping the message text if necessary.
      local offset = tar ~= 'box' and 0
        or api.nvim_win_get_position(win)[2] + (api.nvim_win_get_config(win).border and 1 or 0)

      if tar == 'box' and (pos.col - offset + width) > Box.width and Box.width < vim.o.columns then
        Box.width = math.min(vim.o.columns, pos.col - offset + width)
        api.nvim_win_set_width(win, Box.width)
      end

      while col > 0 and pos.col - offset + width > (tar == 'box' and Box.width or Cmd.last_col) do
        col = col - 1
        pos = fn.screenpos(win, row + 1, col)
      end

      -- Give indicators the same highlight as the neighbouring message text.
      local opts = { type = 'highlight', details = true, overlap = true }
      local hl = api.nvim_buf_get_extmarks(ext.bufs[tar], ext.ns, { row, col }, { row, col }, opts)
      chunks[1][2] = hl[1] and hl[1][4].hl_group or 0
    else
      local mode = #Virt.last[Virt.idx.mode] > 0
      local pad = vim.o.columns - width ---@type integer
      Cmd.last_col = mode and 0 or vim.o.columns - width - 1
      local newlines = math.max(0, ext.cmdheight - h.all)
      row = row + newlines

      -- Ensure mark has a target row and does not overlap text.
      if newlines > 0 then
        newlines = fn['repeat']({ '' }, newlines)
        api.nvim_buf_set_lines(ext.bufs.cmd, row + 1, row + 1, false, newlines)
        col = 0
      else
        if pos.row == vim.o.lines and pos.col > Cmd.last_col then
          while col > 0 and pos.row == vim.o.lines and pos.col > Cmd.last_col do
            col = col - 1
            pos = fn.screenpos(win, row + 1, col)
          end
          Virt.msg = (row == Cmd.msg_row and mode) and { {}, {} } or Virt.msg
          api.nvim_buf_set_text(ext.bufs.cmd, row, col, row, -1, { mode and ' ' or '' })
        end

        M.prev_msg = row == Cmd.msg_row and mode and '' or M.prev_msg
        pad = pad - ((mode or col == 0) and 0 or pos.col)
      end
      table.insert(chunks, mode and 2 or 1, { (' '):rep(pad) })

      set_virttext('msg') -- Readjust to new Cmd.last_col or clear for mode.
    end

    Virt.ids[type] = api.nvim_buf_set_extmark(ext.bufs[tar], ext.ns, row, col, {
      virt_text = chunks,
      virt_text_pos = 'overlay',
      right_gravity = false,
      undo_restore = false,
      invalidate = true,
      id = Virt.ids[type],
      priority = type == 'msg' and 2 or 1,
    })
  end
end

---@param tar 'box'|'cmd'|'more'|'prompt'
---@param content MsgContent
---@param replace_last boolean
function M.show_msg(tar, content, replace_last)
  -- Save the concatenated message to determine repeated messages.
  local msg, restart = '', false
  if tar == ext.cfg.msg.pos then
    for _, chunk in ipairs(content) do
      msg = msg .. chunk[2]
    end
    replace_last = replace_last and M.prev_msg ~= '\n'
    M.dupe = (msg == M.prev_msg and M.dupe + 1 or 0)
    M.prev_msg = msg
    restart = M.count > 0 and replace_last or M.dupe > 0
    M.count = M.count + (restart and 0 or 1)
  end

  -- Filter out empty newline messages. TODO: don't emit them.
  if msg == '\n' then
    return
  end

  ---@type integer Start row after last line in the target buffer, unless
  ---this is the first message, or in case of a repeated or replaced message.
  local row = (tar == 'box' or tar == 'cmd') and M.count <= 1 and 0
    or api.nvim_buf_line_count(ext.bufs[tar]) - ((replace_last or M.dupe > 0) and 1 or 0)
  local start_row, col = row, 0
  local lines, marks = {}, {} ---@type string[], [integer, integer, vim.api.keyset.set_extmark][]

  -- Accumulate to be inserted and highlighted message chunks for a non-repeated message.
  for i, chunk in ipairs(M.dupe > 0 and tar == ext.cfg.msg.pos and {} or content) do
    local srow, scol = row, col
    -- Split at newline and concatenate first and last message chunks.
    for str in (chunk[2] .. '\0'):gmatch('.-[\n%z]') do
      local idx = i > 1 and row == srow and 0 or 1
      lines[#lines + idx] = idx > 0 and str:sub(1, -2) or lines[#lines] .. str:sub(1, -2)
      col = #lines[#lines]
      if tar == 'box' then
        Box.width = math.max(Box.width, api.nvim_strwidth(lines[#lines]))
      end
      row = row + (str:sub(-1) == '\0' and 0 or 1)
    end
    if chunk[3] > 0 then
      marks[#marks + 1] = { srow, scol }
      marks[#marks][3] = { end_col = col, end_row = row, hl_group = chunk[3] }
    end
  end

  if tar ~= ext.cfg.msg.pos or M.dupe == 0 then
    -- Add highlighted message to buffer.
    api.nvim_buf_set_lines(ext.bufs[tar], start_row, -1, false, lines)
    for _, mark in ipairs(marks) do
      api.nvim_buf_set_extmark(ext.bufs[tar], ext.ns, mark[1], mark[2], mark[3])
    end
  end

  if tar == 'box' then
    api.nvim_win_set_width(ext.wins[ext.tab].box, Box.width)
    M.set_pos('box') -- May move messages to more window, making count 0.
    if M.count ~= 0 then
      if restart then
        Box.timer:stop()
        Box.timer:set_repeat(4000)
        Box.timer:again()
      else
        Box:start_timer(ext.bufs.box, row - start_row + 1)
      end
    end
  elseif tar == 'cmd' and M.dupe == 0 then
    -- Place [+x] indicator for lines that spill over 'cmdheight'.
    local h = api.nvim_win_text_height(ext.wins[ext.tab].cmd, {})
    Cmd.lines, Cmd.msg_row = h.all, h.end_row
    local virt = Cmd.lines > ext.cmdheight and { 0, ('[+%d]'):format(Cmd.lines - ext.cmdheight) }
    Virt.msg[Virt.idx.spill][1] = virt or nil
    if ext.cfg.msg.pos == 'cmd' and M.count == 1 and not restart then
      vim.schedule(function()
        Cmd.lines, M.count = 0, 0
      end)
    end
    ext.cmdhl.active[ext.bufs.cmd] = nil
  end
  -- Place (x) indicator for repeated messages.
  if tar == ext.cfg.msg.pos then
    Virt.msg[Virt.idx.dupe][1] = M.dupe > 0 and { 0, ('(%d)'):format(M.dupe) } or nil
  end
  set_virttext('msg')

  -- Ensure first message is visible
  api.nvim_win_set_cursor(ext.wins[ext.tab][tar], { 1, 0 })
end

--- Place message text in a bottom right floating window. A timer is started that will remove
--- the message after 3 seconds. Successive messages are put in the message window together.
--- When message window exceeds half of the screen, a "botright" split is opened instead.
---
---@param kind string
---@alias MsgChunk [integer, string, integer]
---@alias MsgContent MsgChunk[]
---@param content MsgContent
---@param replace_last boolean
M.msg_show = function(kind, content, replace_last)
  if kind == 'search_cmd' then
    -- Set the entered search command in the cmdline.
    api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, { content[1][2] })
    Virt.msg = { {}, {} }
  elseif kind == 'search_count' then
    -- Extract only the search_count, not the search entered command.
    content[1][2] = content[1][2]:match('W? %[>?%d+/>?%d+%]') .. '  '
    Virt.last[Virt.idx.count] = content
    Virt.last[Virt.idx.cmd] = { { 0, (' '):rep(11) } }
    set_virttext('last')
    M.prev_msg = ''
  elseif kind == 'return_prompt' then
    -- Bypass hit enter prompt.
    vim.api.nvim_feedkeys(vim.keycode('<CR>'), 'n', false)
  elseif ext.cmd.prompt then
    -- Route to prompt that stays open so long as the cmdline prompt is active.
    api.nvim_buf_set_lines(ext.bufs.prompt, 0, -1, false, { '' })
    M.show_msg('prompt', content, true)
    M.set_pos('prompt')
  elseif ext.cfg.msg.pos == 'cmd' and kind == 'list_cmd' then
    -- Route to box so that set_pos() in turn routes it to more window.
    M.show_msg('box', content, replace_last)
  else
    Virt.last[Virt.idx.count] = {}
    M.show_msg(ext.cfg.msg.pos, content, replace_last)
  end
end

M.msg_clear = function() end

--- Place the mode text in the cmdline.
---
---@param content MsgContent
M.msg_showmode = function(content)
  Virt.last[Virt.idx.mode][1] = content[1] and { 0, content[1][2], content[1][3] }
  Virt.last[Virt.idx.count] = {}
  set_virttext('last')
end

--- Place text from the 'showcmd' buffer in the cmdline.
---
---@param content MsgContent
M.msg_showcmd = function(content)
  local str = content[1] and content[1][2]:sub(-10) or ''
  Virt.last[Virt.idx.cmd][1] = (content[1] or Virt.last[Virt.idx.count][1])
    and { 0, str .. (' '):rep(11 - #str) }
  set_virttext('last')
end

--- Place the 'ruler' text in the cmdline window, unless that is still an active cmdline.
---
---@param content MsgContent
M.msg_ruler = function(content)
  Virt.last[Virt.idx.ruler] = content
  set_virttext('last')
end

---@alias MsgHistory [string, MsgContent]
--- Zoom in on the message window with the message history.
---
---@param entries MsgHistory[]
M.msg_history_show = function(entries)
  if #entries == 0 then
    return
  end

  api.nvim_buf_set_lines(ext.bufs.more, 0, -1, false, {})
  for i, entry in ipairs(entries) do
    M.show_msg('more', entry[2], i == 1)
  end

  M.set_pos('more')
end

M.msg_history_clear = function() end

--- Adjust dimensions of the message windows after certain events.
---
---@param type? 'box'|'cmd'|'more'|'prompt' Type of to be positioned window (nil for all).
function M.set_pos(type)
  local function win_set_pos(w)
    local cfg = api.nvim_win_is_valid(w) and api.nvim_win_get_config(w)
    if not cfg or not type and cfg.hide == true then
      return
    end

    local max_height = math.ceil(vim.o.lines * 0.5)
    local h = type and api.nvim_win_text_height(w, {}).all or api.nvim_win_get_height(w)
    local tomore = type == 'box'
      and (h > max_height or ext.cfg.msg.pos == 'cmd')
      and fn.getcmdwintype() == '' -- Cannot go to more window when cmdwin is open.

    local more = tomore or type == 'more'
    h = math.min(h, tomore and math.ceil(vim.o.lines * 0.3) or max_height)

    -- Move message box content to more window when it exceeds max_height.
    if tomore then
      M.count, Box.width, M.prev_msg = 0, 1, ''
      api.nvim_win_set_config(w, { hide = true })
      if api.nvim_get_current_win() == ext.wins[ext.tab].more then
        -- More prompt still open, prepend new message box text.
        local msg = api.nvim_buf_get_lines(ext.bufs.box, 0, -1, false)
        api.nvim_buf_set_lines(ext.bufs.box, 0, -1, false, {})
        api.nvim_buf_set_lines(ext.bufs.more, 0, 0, false, msg)
        api.nvim_win_set_cursor(ext.wins[ext.tab].more, { 1, 0 })
        return
      end
      api.nvim_win_set_buf(ext.wins[ext.tab].more, ext.bufs.box)
      api.nvim_buf_delete(ext.bufs.more, {})
      ext.bufs.more = ext.bufs.box
      w = ext.wins[ext.tab].more
      ext.bufs.box = -1
    end
    -- Position the window.
    api.nvim_win_set_config(w, {
      hide = false,
      relative = 'laststatus',
      height = type and h or nil,
      row = w == ext.wins[ext.tab].box and 0 or 1,
      col = 10000,
      zindex = more and 299 or nil,
    })
    -- Make more window the current window, hide it when it is no longer current.
    if more and api.nvim_get_current_win() ~= w then
      api.nvim_create_autocmd('WinEnter', {
        once = true,
        callback = function()
          if api.nvim_win_is_valid(w) then
            api.nvim_win_set_config(w, { hide = true })
          end
        end,
        desc = 'Hide inactive more window.',
      })
      api.nvim_set_current_win(w)
    end
  end

  for t, w in pairs(ext.wins[ext.tab] or {}) do
    if t == type or type == nil and t ~= 'cmd' then
      win_set_pos(w)
    end
  end
end

return M
