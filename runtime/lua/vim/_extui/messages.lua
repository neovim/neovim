local api, fn = vim.api, vim.fn
local ext = require('vim._extui.shared')

---@class vim._extui.messages
local M = {
  dupe = 0, -- Number of times message is repeated.
  prev_msg = '', -- Concatenated content of the previous message.
  box = { -- Message box window.
    count = 0, -- Number of messages currently in the message window.
    width = 1, -- Current width of the message window.
    timer = nil, ---@type uv.uv_timer_t Timer that removes the most recent message.
  },
  cmd = { -- Cmdline message window.
    count = 0, -- Number of messages currently in the message window.
    lines = 0, -- Number of logical lines in cmdline buffer.
    msg_row = -1, -- Last row of message to distinguish for placing virt_text.
    last_col = vim.o.columns, -- Crop text to start column of 'last' virt_text.
  },
  virt = { -- Stored virt_text state.
    last = { {}, {}, {}, {} }, ---@type MsgContent[] status in last cmdline row.
    msg = { {}, {} }, ---@type MsgContent[] [(x)] indicators in message window.
    idx = { mode = 1, search = 2, cmd = 3, ruler = 4, spill = 1, dupe = 2 },
    ids = {}, ---@type { ['last'|'msg']: integer? } Table of mark IDs.
  },
}

--- Start a timer whose callback will remove the message from the message window.
---
---@param buf integer Buffer the message was written to.
---@param len integer Number of rows that should be removed.
function M.box:start_timer(buf, len)
  self.timer = vim.defer_fn(function()
    if self.count == 0 or not api.nvim_buf_is_valid(buf) then
      return -- Messages moved to split or buffer was closed.
    end
    api.nvim_buf_set_lines(buf, 0, len, false, {})
    self.count = self.count - 1
    if self.count > 0 then
      M.set_pos('box')
    else
      self.width = 1
      M.prev_msg = ext.cfg.msg.pos == 'box' and '' or M.prev_msg
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
  local appended = type == 'msg' and M.virt.msg or M.virt.last
  for _, content in ipairs(appended) do
    for _, chunk in ipairs(content) do
      chunks[#chunks + 1] = { chunk[2], chunk[3] }
      width = width + api.nvim_strwidth(chunk[2])
    end
  end

  if M.virt.ids[type] and #chunks == 0 then
    api.nvim_buf_del_extmark(ext.bufs.cmd, ext.ns, M.virt.ids[type])
    M.virt.ids[type] = nil
    M.cmd.last_col = type == 'last' and vim.o.columns or M.cmd.last_col
  elseif #chunks > 0 then
    local tar = type == 'msg' and ext.cfg.msg.pos or 'cmd'
    local win = ext.wins[ext.tab][tar]
    local max = api.nvim_win_get_height(win)
    local erow = tar == 'cmd' and M.cmd.msg_row or nil
    local srow = tar == 'box' and fn.line('w0', ext.wins[ext.tab].box) - 1 or nil
    local h = api.nvim_win_text_height(win, { start_row = srow, end_row = erow, max_height = max })
    local row = h.end_row ---@type integer
    local col = fn.virtcol2col(ext.wins[ext.tab][tar], row + 1, h.end_vcol)
    local pos = fn.screenpos(ext.wins[ext.tab][tar], row + 1, col)

    if type == 'msg' then
      -- Calculate at which row and column to overlay the virtual text such that it is at
      -- the end of the last visible message line, overlapping the message text if necessary.
      local offset = tar ~= 'box' and 0
        or api.nvim_win_get_position(win)[2] + (api.nvim_win_get_config(win).border and 1 or 0)

      M.box.width = math.min(vim.o.columns, pos.col - offset + width)
      if tar == 'box' and api.nvim_win_get_width(ext.wins[ext.tab].box) < M.box.width then
        api.nvim_win_set_width(win, M.box.width)
      end

      local mwidth = tar == 'box' and M.box.width or M.cmd.last_col
      while col > 0 and pos.col - offset + width > mwidth do
        col = col - 1
        pos = fn.screenpos(win, row + 1, col)
      end

      -- Give indicators the same highlight as the neighbouring message text.
      local opts = { type = 'highlight', details = true, overlap = true }
      local hl = api.nvim_buf_get_extmarks(ext.bufs[tar], ext.ns, { row, col }, { row, col }, opts)
      chunks[1][2] = hl[1] and hl[1][4].hl_group or 0
    else
      local mode = #M.virt.last[M.virt.idx.mode] > 0
      local pad = vim.o.columns - width ---@type integer
      M.cmd.last_col = (pos.row == vim.o.lines and mode) and 0 or vim.o.columns - width - 1
      local newlines = math.max(0, ext.cmdheight - h.all)
      row = row + newlines

      -- Ensure mark has a target row and does not overlap text.
      if newlines > 0 then
        newlines = fn['repeat']({ '' }, newlines)
        api.nvim_buf_set_lines(ext.bufs.cmd, row + 1, row + 1, false, newlines)
        col = 0
      else
        if pos.row == vim.o.lines and pos.col > M.cmd.last_col then
          while col > 0 and pos.row == vim.o.lines and pos.col > M.cmd.last_col do
            col = col - 1
            pos = fn.screenpos(win, row + 1, col)
          end
          M.prev_msg = (row <= M.cmd.msg_row and mode) and '' or M.prev_msg
          M.virt.msg = (row <= M.cmd.msg_row and mode) and { {}, {} } or M.virt.msg
          api.nvim_buf_set_text(ext.bufs.cmd, row, col, row, -1, { mode and ' ' or '' })
        end

        pad = pad - ((mode or col == 0) and 0 or pos.col)
      end
      table.insert(chunks, mode and 2 or 1, { (' '):rep(pad) })

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

---@param tar 'box'|'cmd'|'more'|'prompt'
---@param content MsgContent
---@param replace_last boolean
function M.show_msg(tar, content, replace_last)
  -- Save the concatenated message to determine repeated messages.
  local msg, restart, dupe = '', false, 0
  if M[tar] then
    replace_last = replace_last and M.prev_msg ~= '\n'
    if tar == ext.cfg.msg.pos then
      for _, chunk in ipairs(content) do
        msg = msg .. chunk[2]
      end
      M.dupe = (msg == M.prev_msg and M.dupe + 1 or 0)
      dupe = M.dupe
      M.prev_msg = msg
    end
    restart = M[tar].count > 0 and (replace_last or dupe > 0)
    -- Reset indicators the next event loop iteration.
    if M.cmd.count == 0 and tar == 'cmd' then
      vim.schedule(function()
        M.cmd.lines, M.cmd.count = 0, 0
      end)
    end
    M[tar].count = M[tar].count + ((restart or msg == '\n') and 0 or 1)
  end

  -- Filter out empty newline messages. TODO: don't emit them.
  if msg == '\n' then
    return
  end

  ---@type integer Start row after last line in the target buffer, unless
  ---this is the first message, or in case of a repeated or replaced message.
  local row = M[tar] and M[tar].count <= 1 and 0
    or api.nvim_buf_line_count(ext.bufs[tar]) - ((replace_last or dupe > 0) and 1 or 0)
  local start_row, col = row, 0
  local lines, marks = {}, {} ---@type string[], [integer, integer, vim.api.keyset.set_extmark][]

  -- Accumulate to be inserted and highlighted message chunks for a non-repeated message.
  for i, chunk in ipairs(dupe > 0 and tar == ext.cfg.msg.pos and {} or content) do
    local srow, scol = row, col
    -- Split at newline and concatenate first and last message chunks.
    for str in (chunk[2] .. '\0'):gmatch('.-[\n%z]') do
      local idx = i > 1 and row == srow and 0 or 1
      lines[#lines + idx] = idx > 0 and str:sub(1, -2) or lines[#lines] .. str:sub(1, -2)
      col = #lines[#lines]
      row = row + (str:sub(-1) == '\0' and 0 or 1)
      if tar == 'box' then
        M.box.width = math.max(M.box.width, api.nvim_strwidth(lines[#lines]))
      end
    end
    if chunk[3] > 0 then
      marks[#marks + 1] = { srow, scol, { end_col = col, end_row = row, hl_group = chunk[3] } }
    end
  end

  if tar ~= ext.cfg.msg.pos or dupe == 0 then
    -- Add highlighted message to buffer.
    api.nvim_buf_set_lines(ext.bufs[tar], start_row, -1, false, lines)
    for _, mark in ipairs(marks) do
      api.nvim_buf_set_extmark(ext.bufs[tar], ext.ns, mark[1], mark[2], mark[3])
    end
  end

  if tar == 'box' then
    api.nvim_win_set_width(ext.wins[ext.tab].box, M.box.width)
    M.set_pos('box')
    if restart then
      M.box.timer:stop()
      M.box.timer:set_repeat(4000)
      M.box.timer:again()
    else
      M.box:start_timer(ext.bufs.box, row - start_row + 1)
    end
  elseif tar == 'cmd' and dupe == 0 then
    -- Place [+x] indicator for lines that spill over 'cmdheight'.
    local h = api.nvim_win_text_height(ext.wins[ext.tab].cmd, {})
    M.cmd.lines, M.cmd.msg_row = h.all, h.end_row
    local spill = M.cmd.lines > ext.cmdheight and ('[+%d]'):format(M.cmd.lines - ext.cmdheight)
    M.virt.msg[M.virt.idx.spill][1] = spill and { 0, spill } or nil
    api.nvim_win_set_cursor(ext.wins[ext.tab][tar], { 1, 0 })
    ext.cmdhl.active[ext.bufs.cmd] = nil
  end
  -- Place (x) indicator for repeated messages.
  if tar == ext.cfg.msg.pos then
    M.virt.msg[M.virt.idx.dupe][1] = dupe > 0 and { 0, ('(%d)'):format(dupe) } or nil
  end
  if M[tar] then
    set_virttext('msg')
  end
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
    M.virt.msg = { {}, {} }
  elseif kind == 'search_count' then
    -- Extract only the search_count, not the search entered command.
    content[1][2] = content[1][2]:match('W? %[>?%d+/>?%d+%]') .. '  '
    M.virt.last[M.virt.idx.search] = content
    M.virt.last[M.virt.idx.cmd] = { { 0, (' '):rep(11) } }
    set_virttext('last')
    M.prev_msg = ''
  elseif kind == 'return_prompt' then
    -- Bypass hit enter prompt.
    vim.api.nvim_feedkeys(vim.keycode('<CR>'), 'n', false)
  elseif kind == 'verbose' then
    -- Verbose messages are sent too often to be meaningful in the cmdline:
    -- always route to box regardless of cfg.messages.pos.
    M.show_msg('box', content, replace_last)
  elseif ext.cmd.prompt then
    -- Route to prompt that stays open so long as the cmdline prompt is active.
    api.nvim_buf_set_lines(ext.bufs.prompt, 0, -1, false, { '' })
    M.show_msg('prompt', content, true)
    M.set_pos('prompt')
  elseif kind == 'list_cmd' then
    -- Route to more window.
    M.msg_history_show({ { kind, content } })
  else
    M.virt.last[M.virt.idx.search] = {}
    M.show_msg(ext.cfg.msg.pos, content, replace_last)
  end
end

M.msg_clear = function() end

--- Place the mode text in the cmdline.
---
---@param content MsgContent
M.msg_showmode = function(content)
  M.virt.last[M.virt.idx.mode][1] = content[1] and { 0, content[1][2], content[1][3] }
  M.virt.last[M.virt.idx.search] = {}
  set_virttext('last')
end

--- Place text from the 'showcmd' buffer in the cmdline.
---
---@param content MsgContent
M.msg_showcmd = function(content)
  local str = content[1] and content[1][2]:sub(-10) or ''
  M.virt.last[M.virt.idx.cmd][1] = (content[1] or M.virt.last[M.virt.idx.search][1])
    and { 0, str .. (' '):rep(11 - #str) }
  set_virttext('last')
end

--- Place the 'ruler' text in the cmdline window, unless that is still an active cmdline.
---
---@param content MsgContent
M.msg_ruler = function(content)
  M.virt.last[M.virt.idx.ruler] = content
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
  local function win_set_pos(win)
    local texth = type and api.nvim_win_text_height(win, {}) or 0
    local height = type and math.min(texth.all, math.ceil(vim.o.lines * 0.5))
    api.nvim_win_set_config(win, {
      hide = false,
      relative = 'laststatus',
      height = height,
      row = win == ext.wins[ext.tab].box and 0 or 1,
      col = 10000,
      zindex = type == 'more' and 299 or nil,
    })
    if type == 'box' then
      -- Ensure last line is visible and first line is at top of window.
      local row = (texth.all > height and texth.end_row or 0) + 1
      api.nvim_win_set_cursor(ext.wins[ext.tab].box, { row, 0 })
    elseif type == 'more' and api.nvim_get_current_win() ~= win then
      -- Make more window the current window, hide it when it is no longer current.
      api.nvim_create_autocmd('WinEnter', {
        once = true,
        callback = function()
          if api.nvim_win_is_valid(win) then
            api.nvim_win_set_config(win, { hide = true })
          end
        end,
        desc = 'Hide inactive more window.',
      })
      api.nvim_set_current_win(win)
    end
  end

  for t, win in pairs(ext.wins[ext.tab] or {}) do
    local cfg = (t == type or (type == nil and t ~= 'cmd'))
      and api.nvim_win_is_valid(win)
      and api.nvim_win_get_config(win)
    if cfg and (type or not cfg.hide) then
      win_set_pos(win)
    end
  end
end

return M
