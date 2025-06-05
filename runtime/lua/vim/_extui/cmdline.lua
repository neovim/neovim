local ext = require('vim._extui.shared')
local api, fn = vim.api, vim.fn
---@class vim._extui.cmdline
local M = {
  highlighter = nil, ---@type vim.treesitter.highlighter?
  indent = 0, -- Current indent for block event.
  prompt = false, -- Whether a prompt is active; messages are placed in the 'prompt' window.
  row = 0, -- Current row in the cmdline buffer, > 0 for block events.
  level = -1, -- Current cmdline level, 0 when inactive, -1 one loop iteration after closing.
}

--- Set the 'cmdheight' and cmdline window height. Reposition message windows.
---
---@param win integer Cmdline window in the current tabpage.
---@param hide boolean Whether to hide or show the window.
---@param height integer (Text)height of the cmdline window.
local function win_config(win, hide, height)
  if ext.cmdheight == 0 and api.nvim_win_get_config(win).hide ~= hide then
    api.nvim_win_set_config(win, { hide = hide, height = not hide and height or nil })
  elseif api.nvim_win_get_height(win) ~= height then
    api.nvim_win_set_height(win, height)
  end
  if vim.o.cmdheight ~= height then
    -- Avoid moving the cursor with 'splitkeep' = "screen", and altering the user
    -- configured value with noautocmd.
    vim._with({ noautocmd = true, o = { splitkeep = 'screen' } }, function()
      vim.o.cmdheight = height
    end)
    ext.msg.set_pos()
  end
end

local cmdbuff ---@type string Stored cmdline used to calculate translation offset.
local promptlen = 0 -- Current length of the prompt, stored for use in "cmdline_pos"
--- Concatenate content chunks and set the text for the current row in the cmdline buffer.
---
---@alias CmdChunk [integer, string]
---@alias CmdContent CmdChunk[]
---@param content CmdContent
---@param prompt string
local function set_text(content, prompt)
  promptlen, cmdbuff = #prompt, ''
  for _, chunk in ipairs(content) do
    cmdbuff = cmdbuff .. chunk[2]
  end
  api.nvim_buf_set_lines(ext.bufs.cmd, M.row, -1, false, { prompt .. fn.strtrans(cmdbuff) .. ' ' })
end

--- Set the cmdline buffer text and cursor position.
---
---@param content CmdContent
---@param pos integer
---@param firstc string
---@param prompt string
---@param indent integer
---@param level integer
---@param hl_id integer
function M.cmdline_show(content, pos, firstc, prompt, indent, level, hl_id)
  M.level, M.indent, M.prompt = level, indent, #prompt > 0
  -- Only enable TS highlighter for Ex commands (not search or filter commands).
  M.highlighter.active[ext.bufs.cmd] = firstc == ':' and M.highlighter or nil
  set_text(content, ('%s%s%s'):format(firstc, prompt, (' '):rep(indent)))
  if promptlen > 0 and hl_id > 0 then
    api.nvim_buf_set_extmark(ext.bufs.cmd, ext.ns, 0, 0, { hl_group = hl_id, end_col = promptlen })
  end

  local height = math.max(ext.cmdheight, api.nvim_win_text_height(ext.wins.cmd, {}).all)
  win_config(ext.wins.cmd, false, height)
  M.cmdline_pos(pos)

  -- Clear message cmdline state; should not be shown during, and reset after cmdline.
  if ext.cfg.msg.pos == 'cmd' and ext.msg.cmd.msg_row ~= -1 then
    ext.msg.prev_msg, ext.msg.dupe, ext.msg.cmd.msg_row = '', 0, -1
    api.nvim_buf_clear_namespace(ext.bufs.cmd, ext.ns, 0, -1)
    ext.msg.virt.msg = { {}, {} }
  end
  ext.msg.virt.last = { {}, {}, {}, {} }
end

--- Insert special character at cursor position.
---
---@param c string
---@param shift boolean
--@param level integer
function M.cmdline_special_char(c, shift)
  api.nvim_win_call(ext.wins.cmd, function()
    api.nvim_put({ c }, shift and '' or 'c', false, false)
  end)
end

local curpos = { 0, 0 } -- Last drawn cursor position.
--- Set the cmdline cursor position.
---
---@param pos integer
--@param level integer
function M.cmdline_pos(pos)
  pos = #fn.strtrans(cmdbuff:sub(1, pos))
  if curpos[1] ~= M.row + 1 or curpos[2] ~= promptlen + pos then
    curpos[1], curpos[2] = M.row + 1, promptlen + pos
    -- Add matchparen highlighting to non-prompt part of cmdline.
    if pos > 0 and fn.exists('#matchparen') then
      api.nvim_win_set_cursor(ext.wins.cmd, { curpos[1], curpos[2] - 1 })
      vim._with({ win = ext.wins.cmd, wo = { eventignorewin = '' } }, function()
        api.nvim_exec_autocmds('CursorMoved', {})
      end)
    end
    api.nvim_win_set_cursor(ext.wins.cmd, curpos)
  end
end

--- Leaving the cmdline, restore 'cmdheight' and 'ruler'.
---
--@param level integer
---@param abort boolean
function M.cmdline_hide(_, abort)
  if M.row > 0 then
    return -- No need to hide when still in cmdline_block.
  end

  fn.clearmatches(ext.wins.cmd) -- Clear matchparen highlights.
  api.nvim_win_set_cursor(ext.wins.cmd, { 1, 0 })
  if abort then
    -- Clear cmd buffer for aborted command (non-abort is left visible).
    api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, {})
  end

  local clear = vim.schedule_wrap(function(was_prompt)
    -- Avoid clearing prompt window when it is re-entered before the next event
    -- loop iteration. E.g. when a non-choice confirm button is pressed.
    if was_prompt and not M.prompt then
      api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, {})
      api.nvim_win_set_config(ext.wins.prompt, { hide = true })
    end
    -- Messages emitted as a result of a typed command are treated specially:
    -- remember if the cmdline was used this event loop iteration.
    -- NOTE: Message event callbacks are themselves scheduled, so delay two iterations.
    vim.schedule(function()
      M.level = -1
    end)
  end)
  clear(M.prompt)

  M.prompt, M.level, curpos[1], curpos[2] = false, 0, 0, 0
  win_config(ext.wins.cmd, true, ext.cmdheight)
end

--- Set multi-line cmdline buffer text.
---
---@param lines CmdContent[]
function M.cmdline_block_show(lines)
  for _, content in ipairs(lines) do
    set_text(content, ':')
    M.row = M.row + 1
  end
end

--- Append line to a multiline cmdline.
---
---@param line CmdContent
function M.cmdline_block_append(line)
  set_text(line, ':')
  M.row = M.row + 1
end

--- Clear cmdline buffer and leave the cmdline.
function M.cmdline_block_hide()
  M.row = 0
  M.cmdline_hide(nil, true)
end

return M
