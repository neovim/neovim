local api = vim.api
local ext = require('vim._extui.shared')

---@class vim._extui.messages
local M = {
  rucol = nil, ---@type integer? Column of ruler extmark.
  ruler_id = nil, ---@type integer? ID of ruler extmark.
  showcmd_id = nil, ---@type integer? ID of showcmd extmark.
}

-- Floating message window box.
local Box = {
  width = 1, -- Current width of the message window.
  count = 0, -- Number of messages currently in the message window.
  prev_msg = '', -- Concatenated content of the previous message.
  dupe = 0, -- Number of times message is repeated.
  timer = nil, ---@type uv.uv_timer_t Timer that removes the most recent message.
}

--- (Re-)start a timer whose callback will remove the message from the message window.
---
---@param buf integer Buffer the message was written to.
---@param len integer Number of rows that should be removed.
---@param restart boolean Whether to stop to previous timer.
function Box:start_timer(buf, len, restart)
  -- Stop the timer that removes the previous duplicate message.
  if restart then
    self.timer:stop()
    self.timer:close()
  end
  self.timer = vim.defer_fn(function()
    if self.count == 0 or not api.nvim_buf_is_valid(buf) then
      return -- Messages moved to split or buffer was closed.
    end
    api.nvim_buf_set_lines(buf, 0, len, false, {})
    self.count = self.count - 1
    if self.count > 0 then
      M.set_pos(vim.o.cmdheight, 0, ext.wins[ext.tab].msg)
    else
      self.width, self.prev_msg = 1, ''
      api.nvim_win_set_config(ext.wins[ext.tab].msg, { hide = true })
    end
  end, 4000)
end

local showcmd_cols = 11
---@alias MsgChunk [integer, string, integer]
---@alias MsgContent MsgChunk[]
---@param target 'cmd'|'list'|'more'|'msg'
---@param content MsgContent
---@param replace_last boolean
function M.show_msg(target, content, replace_last)
  local msg, dupe_str = '', ''
  if target == 'msg' then
    for _, chunk in ipairs(content) do
      msg = msg .. chunk[2]
    end
    Box.dupe = (msg == Box.prev_msg and Box.dupe + 1 or 0)
    dupe_str = Box.dupe > 0 and ' (' .. Box.dupe .. ')' or ''
  end

  local col = 0
  local row = api.nvim_buf_line_count(ext.bufs[target])
    - ((replace_last or (target == 'msg' and (Box.count == 0 or Box.dupe > 0))) and 1 or 0)
  local start_row = row

  -- Insert and highlight message chunks, splitting at newline.
  for _, chunk in ipairs(content) do
    local scol, srow = col, row

    for str in (chunk[2] .. '\0'):gmatch('.-[\n%z]') do
      local is_last = str:sub(-1) == '\0'
      str = str:sub(1, -2) .. (is_last and dupe_str or '')
      if col == 0 then
        api.nvim_buf_set_lines(ext.bufs[target], row, -1, false, { str })
      else
        api.nvim_buf_set_text(ext.bufs[target], row, col, row, col, { str })
      end
      col = is_last and col + #str or 0
      row = row + (is_last and 0 or 1)
    end

    api.nvim_buf_set_extmark(ext.bufs[target], ext.ns, srow, scol, {
      end_row = row,
      end_col = col,
      hl_group = chunk[3],
      undo_restore = false,
      invalidate = true,
    })
  end

  if target == 'msg' then
    -- Set message window width to accommodate the longest row in the message.
    for line = start_row, row do
      api.nvim_win_set_cursor(ext.wins[ext.tab].msg, { line + 1, 0 })
      Box.width = math.max(Box.width, vim.fn.virtcol('$', false, ext.wins[ext.tab].msg) - 1)
    end
    api.nvim_win_set_width(ext.wins[ext.tab].msg, Box.width)

    local restart = Box.count > 0 and replace_last or Box.dupe > 0
    Box.count = Box.count + (restart and 0 or 1)
    -- Set message window position and start timer to remove the message unless
    -- messages were moved to more window.
    M.set_pos(vim.o.cmdheight, 0, ext.wins[ext.tab].msg)
    if Box.count ~= 0 then
      Box.prev_msg = msg
      Box:start_timer(ext.bufs.msg, row - start_row + 1, restart)
    end
  elseif target == 'list' then
    M.set_pos(vim.o.cmdheight, 0, ext.wins[ext.tab].list)
  elseif target == 'cmd' then
    ext.cmdhl.active[ext.bufs.cmd] = nil
  end

  -- Ensure first message is visible
  api.nvim_win_set_cursor(ext.wins[ext.tab][target], { 1, 0 })
end

--- Place message text in a bottom right floating window. A timer is started that will remove
--- the message after 3 seconds. Successive messages are put in the message window together.
--- When message window exceeds half of the screen, a "botright" split is opened instead.
---
---@param kind string
---@param content MsgContent
---@param replace_last boolean
M.msg_show = function(kind, content, replace_last)
  if kind == 'search_cmd' then
    return
  elseif kind == 'list_cmd' and ext.cmd.prompt then
    api.nvim_buf_set_lines(ext.bufs.list, 0, -1, false, { '' })
    M.show_msg('list', content, true)
  elseif kind == 'search_count' then
    -- Search count message goes in cmdline window, pad until ruler/showcmd column.
    local str = (' '):rep((M.rucol or vim.o.columns) - showcmd_cols - 2 - #content[1][2]) .. '%1  '
    str = content[1][2]:gsub('( W? %[>?%d+/>?%d+%])', str)
    api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, { str })
    ext.cmdhl.active[ext.bufs.cmd] = nil
  elseif kind == 'return_prompt' then
    vim.api.nvim_feedkeys(vim.keycode('<cr>'), 'n', false)
  else
    M.show_msg('msg', content, replace_last)
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
    M.show_msg('cmd', content, true)
    ext.cmd.shown = false
  end
end

--- Make sure 'showcmd' or 'ruler' does not overlap the last entered command.
---
---@param cropcol integer Column to which the cmdline text will be cropped.
local function crop_cmdline(cropcol)
  local text = api.nvim_buf_get_text(ext.bufs.cmd, 0, 0, 0, -1, {})
  if #text[1] > cropcol then
    text = { text[1]:sub(1, cropcol - 1) }
    api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, text)
  end
end

local function set_extmark(content, id)
  if id and #content == 0 then
    api.nvim_buf_del_extmark(ext.bufs.cmd, ext.ns, id)
  elseif #content > 0 and not (id == M.showcmd_id and content[1][2]:sub(0):match(':/?')) then
    local wincol = id == M.showcmd_id and (M.rucol or vim.o.columns) - showcmd_cols
      or vim.o.columns - content[1][2]:len() - 1
    crop_cmdline(wincol)
    return api.nvim_buf_set_extmark(ext.bufs.cmd, ext.ns, 0, 0, {
      virt_text = { { content[1][2]:sub(id == M.showcmd_id and -10 or 0), content[1][3] } },
      virt_text_win_col = wincol,
      undo_restore = false,
      invalidate = true,
      id = id,
    }),
      wincol
  end
end

--- Place text from the 'showcmd' buffer in the cmdline.
---
---@param content MsgContent
M.msg_showcmd = function(content)
  M.showcmd_id = set_extmark(content, M.showcmd_id)
end

--- Place the 'ruler' text in the cmdline window, unless that is still an active cmdline.
---
---@param content? MsgContent
M.msg_ruler = function(content)
  if not ext.cmd.active or #content == 0 then
    M.ruler_id, M.rucol = set_extmark(content, M.ruler_id)
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

  M.set_pos(ext.cmdheight, 0, ext.wins[ext.tab].more)
end

M.msg_history_clear = function() end

---@param closedid integer ID of window that will be closed.
---@return integer Height of the 'laststatus' status line.
local function ls_height(closedid)
  if ext.cmdheight == 0 and ext.cmd.active then
    return 1
  end
  local ls = vim.o.laststatus
  if ls == 1 then
    local win, wins, winlist = 1, 0, api.nvim_tabpage_list_wins(0)
    while wins < 2 and win <= #winlist do
      local id = winlist[win]
      wins = wins + ((id == closedid or api.nvim_win_get_config(id).zindex) and 0 or 1)
      win = win + 1
    end
    return (wins > 1 and 1 or 0)
  end
  return (ls == 0 and 0 or 1)
end

--- Adjust dimensions of the message windows after certain events.
---
---@param cmdheight integer Current 'cmdheight'.
---@param closedid integer ID of the to be closed window in a WinClosed event.
---@param win? integer ID of to be positioned window, or nil to position both after resize events.
function M.set_pos(cmdheight, closedid, win)
  local function win_set_pos(w)
    local cfg = api.nvim_win_is_valid(w) and api.nvim_win_get_config(w)
    if not cfg or not win and cfg.hide == true then
      return
    end

    -- More window has a border but is attached to cmdline (over laststatus).
    local border = cfg.border and w == ext.wins[ext.tab].msg and 2 or 0
    local h = win and api.nvim_win_text_height(w, {}).all or api.nvim_win_get_height(w)
    local max_height = math.ceil(vim.o.lines * 0.5)
    local tomore = win == ext.wins[ext.tab].msg
      and h + border > max_height
      and vim.fn.getcmdwintype() == '' -- Cannot go to more window when cmdwin is open.
    local more = tomore or win == ext.wins[ext.tab].more
    h = math.min(h, max_height)

    -- Move message float butter to more window when it exceeds max_height.
    if tomore then
      Box.count, Box.width, Box.prev_msg = 0, 1, ''
      api.nvim_win_set_buf(ext.wins[ext.tab].more, ext.bufs.msg)
      api.nvim_win_set_config(w, { hide = true })
      api.nvim_buf_delete(ext.bufs.more, {})
      ext.bufs.more = ext.bufs.msg
      w = ext.wins[ext.tab].more
      ext.bufs.msg = -1
      border = 0
    end
    -- Position the window.
    api.nvim_win_set_config(w, {
      hide = false,
      relative = 'editor',
      width = more and 10000 or nil,
      height = win and h or nil,
      row = vim.o.lines - cmdheight - h - border - ls_height(closedid),
      col = more and 0 or vim.o.columns - api.nvim_win_get_width(w),
      zindex = more and 299 or nil,
    })
    -- Make more window the current window, hide it when it is no longer current.
    if more and api.nvim_get_current_win() ~= w then
      api.nvim_set_current_win(w)
      api.nvim_create_autocmd('WinLeave', {
        once = true,
        callback = function()
          api.nvim_win_set_config(w, { hide = true })
        end,
        desc = 'Hide inactive history window.',
      })
    end
  end

  for _, w in ipairs(win and { win } or { ext.wins[ext.tab].msg, ext.wins[ext.tab].more }) do
    win_set_pos(w)
  end
end

return M
