local ext = require('vim.ui.ext')
local api = vim.api
local M = {}

local width = 1 -- Current width of the message window.
local prev_msg = '' -- Concatenated content of the previous message.
local msg_count = 0 -- Number of messages currently in the message window.
--- Hide the message float after opening a spit or removing all messages. Reset some variables.
local function hide_msg_float()
  msg_count, width, prev_msg = 0, 1, ''
  api.nvim_win_set_config(ext.wins[ext.tab].msg, { hide = true })
end

local msgtimer ---@type uv.uv_timer_t Timer that removes the most recent message.
--- Create a timer whose callback will remove the message from the message window.
--- When the previous message was the same restart the current timer instead.
---
---@param buf integer Buffer the message was written to.
---@param len integer Number of rows that should be removed.
local function start_msg_timer(buf, len)
  local function remove_msg()
    if msg_count == 0 or not api.nvim_buf_is_valid(buf) then
      return -- Messages moved to split or buffer was closed.
    end
    api.nvim_buf_set_lines(buf, 0, len, false, {})
    msg_count = msg_count - 1
    if msg_count > 0 then
      ext.msg_set_pos(true, vim.o.cmdheight, 0)
    else
      hide_msg_float()
    end
  end
  msgtimer = assert(vim.uv.new_timer())
  msgtimer:start(3000, 0, vim.schedule_wrap(remove_msg))
end

local len = 0 -- Number of rows message was written to.
local row = 0 -- Row next message chunk will be written to.
local col = 0 -- Column next message chunk will be written to.
---@alias MsgChunk table<integer,string>
---@alias MsgContent MsgChunk[]
---@param win integer
---@param buf integer
--@param kind string
---@param content MsgContent
local function show_msg(win, buf, _, content)
  local msg = ''
  local startrow = buf == ext.cmdbuf and 0
    or buf ~= ext.msgbuf and row + 1 -- :messages buffer
    or vim.fn.line('$', win) - ((col == 0 or msg_count == 0) and 1 or 0)
  row = startrow

  if buf == ext.msgbuf then
    for _, chunk in ipairs(content) do
      msg = msg .. chunk[2]
    end
  end

  -- Don't show a message identical to the previous one.
  if buf ~= ext.msgbuf or msg ~= prev_msg then
    col = 0
    -- Loop over all chunks and split at newline.
    for _, chunk in ipairs(content) do
      local start_col, start_row, sub_start = col, row, 1

      for i = 1, #chunk[2] do
        local newline = chunk[2]:sub(i, i) == '\n'
        -- Set buffer text at newline or end of chunk.
        if newline or i == #chunk[2] then
          local empty = newline and i == sub_start and col == 0
          local str = empty and '' or chunk[2]:sub(sub_start, i - (newline and 1 or 0))

          if col == 0 then
            api.nvim_buf_set_lines(buf, row, -1, false, { str })
          elseif col > 0 then
            api.nvim_buf_set_text(buf, row, col, row, col, { str })
          end

          -- Increment row at newline and add empty line at end of chunk.
          if newline then
            row = row + 1
            sub_start = i + 1
            if i == #chunk[2] then
              api.nvim_buf_set_lines(buf, row, -1, false, { '' })
            end
          end
          col = newline and 0 or col + i - sub_start + 1
        end
      end

      -- Set highlight group for chunk.
      api.nvim_buf_set_extmark(buf, ext.ns, start_row, start_col, {
        end_row = row,
        end_col = col,
        hl_group = chunk[1],
        undo_restore = false,
        invalidate = true,
      })
    end
  end

  if buf == ext.msgbuf then
    if msg == prev_msg then
      msgtimer:stop()
      start_msg_timer(ext.msgbuf, len)
    else
      -- Set message window width to accommodate the longest row in the message.
      for line = startrow, row do
        api.nvim_win_set_cursor(win, { line + 1, 0 })
        width = math.max(width, vim.fn.virtcol('$', false, win) - 1)
      end
      api.nvim_win_set_width(win, width)

      -- Set message window position and start timer to remove the message unless
      -- a split was opened to display a large message.
      msg_count = msg_count + 1
      ext.msg_set_pos(true, vim.o.cmdheight, 0)
      if msg_count ~= 0 then
        prev_msg = msg
        len = row - startrow + 1
        start_msg_timer(ext.msgbuf, len)
      end
    end
  elseif buf == ext.cmdbuf then
    -- Disable treesitter highlighter for 'showmode' messages.
    ext.cmdhl.active[ext.cmdbuf] = nil
  end

  -- Ensure first message is visible
  api.nvim_win_set_cursor(win, { 1, 0 })
end

--- Place message text in a bottom right floating window. When message text height exceeds
--- half of the screen, open a "botright" split instead. A timer is started that will remove
--- the message after 3 seconds. Successive messages are put in the message window together.
---
---@alias Message table<string, MsgContent, boolean>
---@param messages Message[]
M.msg_show = function(messages)
  for _, msg in ipairs(messages) do
    show_msg(ext.wins[ext.tab].msg, ext.msgbuf, unpack(msg))
  end
end

M.msg_clear = function() end

--- Place the mode text in the cmdline.
---
---@param content MsgContent
M.msg_showmode = function(content)
  if #content == 0 and not ext.cmdline then
    api.nvim_buf_set_lines(ext.cmdbuf, 0, -1, false, { '' })
  elseif #content > 0 then
    show_msg(ext.wins[ext.tab].cmd, ext.cmdbuf, 'showmode', content)
    ext.cmdline = false
  end
end

local scid ---@type integer
local ruid ---@type integer
local rucol ---@type integer?

--- Make sure 'showcmd' or 'ruler' does not overlap the last entered command.
---
---@param cropcol integer Column to which the cmdline text will be cropped.
local function crop_cmdline(cropcol)
  local text = api.nvim_buf_get_text(ext.cmdbuf, 0, 0, 0, -1, {})
  if #text[1] > cropcol then
    text = { text[1]:sub(1, cropcol - 1) }
    api.nvim_buf_set_lines(ext.cmdbuf, 0, -1, false, text)
    M.msg_ruler(ext.last_ruler)
  end
end

--- Place text from the 'showcmd' buffer in the cmdline.
---
---@param content MsgContent
M.msg_showcmd = function(content)
  if scid and #content == 0 then
    api.nvim_buf_del_extmark(ext.cmdbuf, ext.ns, scid)
  elseif #content > 0 and not content[1][2]:sub(0):match(':/?') then
    -- Place at the end of the line or just before the ruler.
    local cmdcol = (rucol or vim.o.columns) - 11
    crop_cmdline(cmdcol)
    scid = api.nvim_buf_set_extmark(ext.cmdbuf, ext.ns, 0, 0, {
      virt_text = { { content[1][2]:sub(-10), 'Normal' } },
      virt_text_win_col = cmdcol,
      undo_restore = false,
      invalidate = true,
      id = scid,
    })
  end
end

--- Place the 'ruler' text in the cmdline.
---
---@param content MsgContent
M.msg_ruler = function(content)
  ext.last_ruler = content
  if ruid and content and #content == 0 then
    api.nvim_buf_del_extmark(ext.cmdbuf, ext.ns, ruid)
    rucol = nil
  elseif content and #content > 0 then
    rucol = vim.o.columns - content[1][2]:len() - 1
    crop_cmdline(rucol)
    ruid = api.nvim_buf_set_extmark(ext.cmdbuf, ext.ns, 0, 0, {
      virt_text = { { content[1][2], 'Normal' } },
      virt_text_win_col = rucol,
      undo_restore = false,
      invalidate = true,
      id = ruid,
    })
  end
end

local hstbuf = -1 -- Buffer id for message history (:messages).
local hstwin = -1 -- Window id for message history.
---@alias MsgHistory table<string,MsgContent>
--- Open a botright split with the message history.
---
---@param entries MsgHistory[]
M.msg_history_show = function(entries)
  if #entries == 0 then
    return
  end

  if not api.nvim_buf_is_valid(hstbuf) then
    hstbuf = api.nvim_create_buf(false, true)
  else
    api.nvim_buf_set_lines(hstbuf, 0, -1, false, {})
  end
  if not api.nvim_win_is_valid(hstwin) then
    hstwin = api.nvim_open_win(hstbuf, true, { win = -1, split = 'below', style = 'minimal' })
    api.nvim_set_option_value('statusline', 'Messages', { win = hstwin })
  end

  row = -1
  for _, content in ipairs(entries) do
    show_msg(hstwin, hstbuf, unpack(content))
  end

  local h = math.min(math.ceil(vim.o.lines * 0.5), api.nvim_win_text_height(hstwin, {}).all)
  api.nvim_win_set_height(hstwin, h)
  api.nvim_win_set_cursor(hstwin, { row + 1, 0 })
end

M.msg_history_clear = function() end

local splitid = -1
--- Open a botright split to display a large message buffer. Create buffer for new messages.
M.msg_to_split = function()
  -- Replace long message in already open split window or move float buffer to new split.
  if api.nvim_win_is_valid(splitid) then
    api.nvim_win_set_buf(splitid, ext.msgbuf)
  else
    splitid = api.nvim_open_win(ext.msgbuf, true, { win = -1, split = 'below', style = 'minimal' })
    api.nvim_set_option_value('statusline', 'Messages', { win = splitid })
  end
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = ext.msgbuf })
  ext.msgbuf = api.nvim_create_buf(false, true)
  api.nvim_win_set_buf(ext.wins[ext.tab].msg, ext.msgbuf)
  api.nvim_win_set_hl_ns(ext.wins[ext.tab].msg, ext.ns)
  hide_msg_float()
end

return M
