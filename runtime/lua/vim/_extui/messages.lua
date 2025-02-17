local api = vim.api
local ext = require('vim._extui.shared')

---@class vim._extui.messages
local M = {
  rucol = nil, ---@type integer? Column of ruler extmark.
  ruler_id = nil, ---@type integer? ID of ruler extmark.
  showcmd_id = nil, ---@type integer? ID of showcmd extmark.
  prev_msg = '', -- Concatenated content of the previous message.
  dupe = 0, -- Number of times message is repeated.
}

-- Message box window.
local Box = {
  width = 1, -- Current width of the message window.
  count = 0, -- Number of messages currently in the message window.
  timer = nil, ---@type uv.uv_timer_t Timer that removes the most recent message.
}

--- Start a timer whose callback will remove the message from the message window.
---
---@param buf integer Buffer the message was written to.
---@param len integer Number of rows that should be removed.
function Box:start_timer(buf, len)
  self.timer = vim.defer_fn(function()
    if self.count == 0 or not api.nvim_buf_is_valid(buf) then
      return -- Messages moved to split or buffer was closed.
    end
    api.nvim_buf_set_lines(buf, 0, len, false, {})
    self.count = self.count - 1
    if self.count > 0 then
      M.set_pos('box')
    else
      self.width, M.prev_msg = 1, ''
      api.nvim_win_set_config(ext.wins[ext.tab].box, { hide = true })
    end
  end, 4000)
end

local showcmd_cols = 11
---@alias MsgChunk [integer, string, integer]
---@alias MsgContent MsgChunk[]
---@param target 'box'|'cmd'|'more'|'prompt'
---@param content MsgContent
---@param replace_last boolean
function M.show_msg(target, content, replace_last)
  local msg = ''
  if target == ext.cfg.messages.pos then
    for _, chunk in ipairs(content) do
      msg = msg .. chunk[2]
    end
    M.dupe = (msg == M.prev_msg and M.dupe + 1 or 0)
    M.prev_msg = msg
  end

  local row = target == 'cmd' and 0
    or api.nvim_buf_line_count(ext.bufs[target])
      - ((replace_last or (target == 'box' and (Box.count == 0 or M.dupe > 0))) and 1 or 0)
  local start_row, col = row, 0
  local lines, marks = {}, {} ---@type string[], [integer, integer, vim.api.keyset.set_extmark][]

  -- Accumulate to be inserted and highlighted message chunks. or false
  for i, chunk in ipairs(M.dupe > 0 and {} or content) do
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
      marks[#marks][3] = {
        end_col = col,
        end_row = row,
        hl_group = chunk[3],
        invalidate = true,
        undo_restore = false,
        end_right_gravity = (i == #content), -- extend highlight for dupe/trunc indicator.
      }
    end
  end

  local trunc = target == 'cmd' and row + 1 - ext.cmdheight
  -- Add highlighted message or `dupe_str` to buffer.
  if M.dupe > 0 then
    local str = ('%s(%d)'):format(trunc > 0 and '' or ' ', M.dupe)
    local scol = M.dupe == 1 and -1 or (-3 - (trunc > 0 and 0 or 1) - #tostring(M.dupe - 1))
    api.nvim_buf_set_text(ext.bufs[ext.cfg.messages.pos], row, scol, row, -1, { str })
    if ext.cfg.messages.pos == 'box' then
      local line = api.nvim_buf_get_lines(ext.bufs[ext.cfg.messages.pos], -2, -1, false)[1]
      Box.width = math.max(Box.width, api.nvim_strwidth(line))
    end
  else
    api.nvim_buf_set_lines(ext.bufs[target], start_row, -1, false, lines)
    for _, mark in ipairs(marks) do
      api.nvim_buf_set_extmark(ext.bufs[target], ext.ns, mark[1], mark[2], mark[3])
    end
    if trunc > 0 then
      local bot = ext.cmdheight - 1
      api.nvim_buf_set_text(ext.bufs.cmd, bot, -1, bot, -1, { (' [+%d]'):format(trunc) })
    end
  end

  if target == 'box' then
    local restart = Box.count > 0 and replace_last or M.dupe > 0
    Box.count = Box.count + (restart and 0 or 1)
    api.nvim_win_set_width(ext.wins[ext.tab].box, Box.width)
    M.set_pos('box') -- May move messages to more window, making count 0.
    if Box.count ~= 0 then
      if restart then
        Box.timer:stop()
        Box.timer:set_repeat(4000)
        Box.timer:again()
      else
        Box:start_timer(ext.bufs.box, row - start_row + 1)
      end
    end
  end

  if target == 'cmd' then
    ext.cmdhl.active[ext.bufs.cmd] = false
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
  elseif kind == 'search_count' then
    -- Search count message goes in cmdline window, pad until ruler/showcmd column.
    local str = (' '):rep((M.rucol or vim.o.columns) - showcmd_cols - 2 - #content[1][2]) .. '%1  '
    str = content[1][2]:gsub('( W? %[>?%d+/>?%d+%])', str)
    api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, { str })
    ext.cmdhl.active[ext.bufs.cmd] = nil
  elseif kind == 'return_prompt' then
    vim.api.nvim_feedkeys(vim.keycode('<cr>'), 'n', false)
  elseif ext.cmd.prompt then
    api.nvim_buf_set_lines(ext.bufs.prompt, 0, -1, false, { '' })
    M.show_msg('prompt', content, true)
    M.set_pos('prompt')
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
    M.show_msg('cmd', content, true)
    ext.cmdhl.active[ext.bufs.cmd] = nil
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
      or vim.o.columns - #content[1][2] - 1
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
    -- Cannot go to more window when cmdwin is open.
    local tomore = type == 'box' and h > max_height and vim.fn.getcmdwintype() == ''
    local more = tomore or type == 'more'
    h = math.min(h, max_height)

    -- Move message box content to more window when it exceeds max_height.
    if tomore then
      Box.count, Box.width, M.prev_msg = 0, 1, ''
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
      -- api.nvim_set_option_value('ei', 'all', { scope = 'local', win = ext.wins[ext.tab].more })
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

  for t, w in pairs(ext.wins[ext.tab]) do
    if t == type or type == nil and t ~= 'cmd' then
      win_set_pos(w)
    end
  end
end

return M
