local api, fn = vim.api, vim.fn
local ext = require('vim._extui.shared')

---@class vim._extui.messages
local M = {
  prev_msg = '', -- Concatenated content of the previous message.
  count = 0, -- Number of messages currently in the message window.
  dupe = 0, -- Number of times message is repeated.
  marks = {}, ---@type { ['msg'|ruler'|'showcmd']: integer? } Table of mark IDs.
}

-- Message box window.
local Box = {
  width = 1, -- Current width of the message window.
  timer = nil, ---@type uv.uv_timer_t Timer that removes the most recent message.
}

-- Cmdline message window.
local Cmd = {
  rucol = nil, ---@type integer? Column of ruler extmark.
  lines = 0, -- Number of logical lines in cmdline buffer.
  spill = nil, ---@type string? (x) string indicating how many lines spill 'cmdheight'.
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

--- Place or delete a virtual text mark in the cmdline window.
---
---@param type 'msg'|'ruler'|'showcmd'
---@alias MsgChunk [integer, string, integer]
---@alias MsgContent MsgChunk[]
---@param content MsgContent Or empty to delete the extmark.
---@param col? integer Window column to place extmark at. Placed at end of text if nil.
---@return integer? -- Mark ID
local function set_virttext(type, content, col)
  if M.marks[type] and #content == 0 then
    api.nvim_buf_del_extmark(ext.bufs.cmd, ext.ns, M.marks[type])
  elseif #content > 0 and not (type == 'showcmd' and content[1][2]:sub(0):match(':/?')) then
    local row, scol = 0, 0
    local tar = col and 'cmd' or ext.cfg.messages.pos
    local win = ext.wins[ext.tab][tar]

    if col then
      -- Ensure ruler or showcmd virtual text does not overlap text.
      local text = api.nvim_buf_get_text(ext.bufs.cmd, row, 0, row, -1, {})[1]
      scol = fn.virtcol2col(win, row + 1, col)
      if #text > scol then
        api.nvim_buf_set_text(ext.bufs.cmd, 0, scol - 1, -1, -1, {})
      end
    else
      -- Ensure msg virtual text fits and has the same highlight.
      local max = api.nvim_win_get_height(win)
      local h = api.nvim_win_text_height(win, { max_height = max })
      local wincol = 0
      if tar == 'box' then
        wincol = api.nvim_win_get_position(win)[2] + (vim.o.termguicolors and 0 or 1)
      end
      row = h.end_row
      scol = fn.screenpos(win, h.end_row + 1, h.end_vcol).col - wincol ---@type integer

      if tar == 'box' and scol + #content[1][2] > Box.width and Box.width < vim.o.columns then
        Box.width = math.min(vim.o.columns, scol + #content[1][2])
        api.nvim_win_set_width(win, Box.width)
      end

      while scol + #content[1][2] > (tar == 'cmd' and (Cmd.rucol or vim.o.columns) or Box.width) do
        h.end_vcol = h.end_vcol - 1
        scol = fn.screenpos(win, h.end_row + 1, h.end_vcol).col - wincol ---@type integer
      end
      scol = h.end_vcol

      local hl = api.nvim_buf_get_extmarks(ext.bufs[tar], ext.ns, { row, scol }, { row, scol }, {
        type = 'highlight',
        details = true,
        overlap = true,
      })
      content[1][3] = #hl == 0 and 0 or hl[1][4].hl_group --[[@as integer]]
    end

    return api.nvim_buf_set_extmark(ext.bufs[tar], ext.ns, row, scol, {
      virt_text = { { content[1][2]:sub(type == 'showcmd' and -10 or 0), content[1][3] } },
      virt_text_win_col = col or nil,
      virt_text_pos = not col and 'overlay' or nil,
      right_gravity = false,
      invalidate = true,
      id = M.marks[type],
    })
  end
end

---@param target 'box'|'cmd'|'more'|'prompt'
---@param content MsgContent
---@param replace_last boolean
---@param showmode? boolean
function M.show_msg(target, content, replace_last, showmode)
  -- Save the concatenated message to determine repeated messages.
  local msg, restart = '', false
  if target == ext.cfg.messages.pos then
    for _, chunk in ipairs(showmode and {} or content) do
      msg = msg .. chunk[2]
    end
    replace_last = replace_last and M.prev_msg ~= '\n'
    M.dupe = showmode and 0 or (msg == M.prev_msg and M.dupe + 1 or 0)
    M.prev_msg = showmode and '' or msg
    restart = M.count > 0 and replace_last or M.dupe > 0
    M.count = M.count + (restart and 0 or 1)
  end

  -- Filter out empty newline messages. TODO: don't emit them.
  if msg == '\n' then
    return
  end

  ---@type integer Start row after last line in the target buffer, unless
  ---this is the first message, or in case of a repeated or replaced message.
  local row = (showmode or ((target == 'box' or target == 'cmd') and M.count == 1)) and 0
    or api.nvim_buf_line_count(ext.bufs[target]) - ((replace_last or M.dupe > 0) and 1 or 0)
  local start_row, col = row, 0
  local lines, marks = {}, {} ---@type string[], [integer, integer, vim.api.keyset.set_extmark][]

  -- Accumulate to be inserted and highlighted message chunks for a non-repeated message.
  for i, chunk in ipairs(M.dupe > 0 and target == ext.cfg.messages.pos and {} or content) do
    local srow, scol = row, col
    -- Split at newline and concatenate first and last message chunks.
    for str in (chunk[2] .. '\0'):gmatch('.-[\n%z]') do
      local idx = i > 1 and row == srow and 0 or 1
      lines[#lines + idx] = idx > 0 and str:sub(1, -2) or lines[#lines] .. str:sub(1, -2)
      col = #lines[#lines]
      if target == 'box' then
        Box.width = math.max(Box.width, api.nvim_strwidth(lines[#lines]))
      end
      row = row + (str:sub(-1) == '\0' and 0 or 1)
    end
    if chunk[3] > 0 then
      marks[#marks + 1] = { srow, scol }
      marks[#marks][3] = { end_col = col, end_row = row, hl_group = chunk[3] }
    end
  end

  if target ~= ext.cfg.messages.pos or M.dupe == 0 then
    -- Add highlighted message to buffer.
    api.nvim_buf_set_lines(ext.bufs[target], start_row, -1, false, lines)
    for _, mark in ipairs(marks) do
      api.nvim_buf_set_extmark(ext.bufs[target], ext.ns, mark[1], mark[2], mark[3])
    end
  end

  if target == 'box' then
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
  elseif target == 'cmd' then
    -- Place [+x] indicator for lines that spill over 'cmdheight'.
    Cmd.lines = showmode and 0 or api.nvim_win_text_height(ext.wins[ext.tab].cmd, {}).all
    Cmd.spill = Cmd.lines > ext.cmdheight and (' [+%d]'):format(Cmd.lines - ext.cmdheight)
    M.marks.msg = set_virttext('msg', Cmd.spill and { { 0, Cmd.spill } } or {})
    if ext.cfg.messages.pos == 'cmd' and M.count == 1 and not restart then
      vim.schedule(function()
        Cmd.lines, M.count = 0, 0
      end)
    end
    ext.cmdhl.active[ext.bufs.cmd] = nil
    ext.cmd.shown = false
  end
  -- Place (x) indicator for repeated messages.
  if target == ext.cfg.messages.pos and M.dupe > 0 then
    M.marks.msg = set_virttext('msg', { { 0, (' (%d)'):format(M.dupe) .. (Cmd.spill or '') } })
  end

  -- Ensure first message is visible
  api.nvim_win_set_cursor(ext.wins[ext.tab][target], { 1, 0 })
end

local showcmd_cols = 11
--- Place message text in a bottom right floating window. A timer is started that will remove
--- the message after 3 seconds. Successive messages are put in the message window together.
--- When message window exceeds half of the screen, a "botright" split is opened instead.
---
---@param kind string
---@param content MsgContent
---@param replace_last boolean
M.msg_show = function(kind, content, replace_last)
  if kind == 'search_cmd' then
    -- Unwanted, usually still visible in cmdline.
    return
  elseif kind == 'search_count' then
    -- Route to cmdline and pad until ruler/showcmd column.
    local str = (' '):rep((Cmd.rucol or vim.o.columns) - showcmd_cols - 2 - #content[1][2])
    str = content[1][2]:gsub('( W? %[>?%d+/>?%d+%])', str .. '%1  ')
    api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, { str })
    ext.cmdhl.active[ext.bufs.cmd] = nil
  elseif kind == 'return_prompt' then
    -- Bypass hit enter prompt.
    vim.api.nvim_feedkeys(vim.keycode('<cr>'), 'n', false)
  elseif ext.cmd.prompt then
    -- Route to prompt that stays open so long as the cmdline prompt is active.
    api.nvim_buf_set_lines(ext.bufs.prompt, 0, -1, false, { '' })
    M.show_msg('prompt', content, true)
    M.set_pos('prompt')
  elseif ext.cfg.messages.pos == 'cmd' and kind == 'list_cmd' then
    -- Route to box so that set_pos() in turn routes it to more window.
    M.show_msg('box', content, replace_last)
  else
    M.show_msg(ext.cfg.messages.pos, content, replace_last)
  end
end

M.msg_clear = function() end

--- Place the mode text in the cmdline.
---
---@param content MsgContent
M.msg_showmode = function(content)
  if not ext.cmd.shown and #content == 0 then
    api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, { '' })
  elseif not ext.cmd.active and #content > 0 then
    M.show_msg('cmd', content, true, true)
  end
end

--- Place text from the 'showcmd' buffer in the cmdline.
---
---@param content MsgContent
M.msg_showcmd = function(content)
  local col = (Cmd.rucol or vim.o.columns) - showcmd_cols
  M.marks.showcmd = set_virttext('showcmd', content, col)
end

--- Place the 'ruler' text in the cmdline window, unless that is still an active cmdline.
---
---@param content MsgContent
M.msg_ruler = function(content)
  if not ext.cmd.active or #content == 0 then
    Cmd.rucol = vim.o.columns - #content[1][2] - 1
    M.marks.ruler = set_virttext('ruler', content, Cmd.rucol)
  end
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
      and (h > max_height or ext.cfg.messages.pos == 'cmd')
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
